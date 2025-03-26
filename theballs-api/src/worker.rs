use std::{
    io,
    ptr::{addr_of_mut, null_mut},
    sync::Arc,
    time::{Duration, SystemTime},
};

use anyhow::{anyhow, Result};
use bincode::{deserialize, serialize};
use bytes::BytesMut;
use theballs_protocol::{
    client::{ClientHead, ClientPackage, Version},
    server::{ServerHead, ServerPackage, StateCode},
    FromTcpStream, Pack, HEARTBEAT_DURATION,
};
use tokio::{
    io::{AsyncReadExt, AsyncWriteExt},
    net::{TcpStream, ToSocketAddrs},
    select,
    sync::{
        mpsc::{Receiver, Sender},
        RwLock,
    },
    time::{interval, sleep, timeout},
};
use tracing::{event, Level};

use crate::{api::APIWorker, APISignalsSender};

/// Never moved or write by other thread during runtime.
static mut PING_PTR: *mut Duration = null_mut();
/// Never moved or write by other thread during runtime.
static mut DELAY_PTR: *mut Duration = null_mut();

pub async fn worker<A: ToSocketAddrs + Clone>(
    mut worker_self_rx: Receiver<Arc<RwLock<APIWorker>>>,
    addr: A,
    player_id: u128,
    scene_id: u8,
    mut client_rx: Receiver<ClientPackage>,
    sync_sends: Sender<ServerPackage>,
    api_signal_tx: APISignalsSender,
) -> Result<()> {
    let worker_self = worker_self_rx.recv().await.unwrap();
    let stream = connect(&worker_self, addr, &api_signal_tx).await?;

    let client_head = ClientHead {
        name_md5: 0x46bfd4e206ca470e0187511fd966dd53, // jungle
        version: Version::from(env!("CARGO_PKG_VERSION")),
        scene_id,
        player_id,
    };
    let client_head = serialize(&client_head)?;
    stream.write().await.write_all(&client_head).await?;

    let mut server_head = [0u8; size_of::<ServerHead>()];
    stream.write().await.read(&mut server_head).await?;
    let server_head: ServerHead = deserialize(&server_head)?;
    if server_head.state != StateCode::Success {
        worker_self.write().await.state_code = server_head.state;
        return Ok(());
    } else {
        api_signal_tx.send_setup().await?;
    }
    event!(Level::INFO, "..");
    let scene_id = server_head.scene_id;
    {
        let mut worker_self_wg = worker_self.write().await;
        worker_self_wg.world_id = scene_id;
        worker_self_wg.player_uuid = player_id;
    }

    event!(Level::INFO, "Connection setup.");

    let mut heartbeat_interval = interval(HEARTBEAT_DURATION);
    let mut timedeviation_interval = interval(Duration::from_millis(500));

    let mut timedevi_tmp = SystemTime::now();

    unsafe {
        let mut worker_self = worker_self.write().await;
        PING_PTR = addr_of_mut!(worker_self.ping);
        DELAY_PTR = addr_of_mut!(worker_self.delay);
    }

    let mut buf = BytesMut::new();

    loop {
        let mut stream_guard = stream.write().await;
        select! {
            cpkg = client_rx.recv() => {
                drop(stream_guard);
                if let Some(cpkg) = cpkg {
                    stream.write().await.write_all(&cpkg.pack()?).await?;
                } else {
                    stream.write().await.write_all(&ClientPackage::Exit.pack()?).await?;
                }
            }
            spkg = ServerPackage::from_tcp_stream(&mut *stream_guard, &mut buf) => {
                drop(stream_guard);
                match spkg? {
                    Some(ServerPackage::TimeDeviation(time)) => {
                        let now = SystemTime::now();
                        unsafe {
                            *PING_PTR = now.duration_since(timedevi_tmp)?;
                            *DELAY_PTR = now.duration_since(time)?;
                        }
                    }
                    Some(ServerPackage::Exit) => break,
                    Some(p) => {
                        sync_sends.send(p).await?;
                    }
                    None => (),
                }
            }
            _ = heartbeat_interval.tick() => {
                drop(stream_guard);
                stream.write().await.write_all(&ClientPackage::HeartBeat.pack()?).await?;
            }
            _ = timedeviation_interval.tick() => {
                drop(stream_guard);
                timedevi_tmp = SystemTime::now();
                stream.write().await.write_all(&ClientPackage::TimeDeviation.pack()?).await?;
            }
        }
    }

    api_signal_tx.send_exited().await?;

    worker_self.write().await.state_code = StateCode::Exited;

    Ok(())
}

async fn connect<A: ToSocketAddrs + Clone>(
    worker_self: &Arc<RwLock<APIWorker>>,
    addr: A,
    api_signal_tx: &APISignalsSender,
) -> Result<Arc<RwLock<TcpStream>>> {
    worker_self.write().await.state_code = StateCode::TryingToConnect;
    let stream = timeout(Duration::from_secs(10), async {
        let mut stream = Err(io::Error::last_os_error());
        for i in 0..5 {
            event!(Level::DEBUG, "Trying to connect server.");
            let res = TcpStream::connect(addr.clone()).await;
            stream = match res {
                Ok(stream_) => Ok(stream_),
                Err(e) => {
                    stream = Err(e);
                    if i == 4 {
                        continue;
                    }
                    sleep(Duration::from_secs(1)).await;
                    continue;
                }
            };
            break;
        }
        stream
    })
    .await;
    if let Err(e) = stream {
        api_signal_tx.send_timeout().await?;
        worker_self.write().await.state_code = StateCode::Timeout;
        event!(Level::ERROR, "Timeout: {:?}", e);
        return Err(anyhow!(io::Error::last_os_error()));
    }
    let stream = stream?;
    if let Err(e) = stream {
        api_signal_tx
            .send_connection_failed(format!("{}", e))
            .await?;
        worker_self.write().await.state_code = StateCode::ConnectionFailed;
        event!(Level::ERROR, "ConnectionFailed: {:?}", e);
        return Err(anyhow!(io::Error::last_os_error()));
    }
    Ok(Arc::new(RwLock::new(stream?)))
}
