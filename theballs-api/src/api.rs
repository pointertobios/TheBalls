use std::{
    marker::PhantomPinned,
    pin::{pin, Pin},
    sync::Arc,
    time::Duration,
};

use anyhow::Result;
use godot::prelude::*;
use theballs_protocol::{
    client::ClientPackage,
    server::{PlayerEvent, ServerPackage, StateCode},
};
use tokio::{
    runtime::{self, Runtime},
    sync::{
        mpsc::{self, Receiver, Sender},
        RwLock,
    },
    task::JoinHandle,
};
use tracing::{event, Level};

use crate::{api_signal_channel, logging_init, worker::worker, APISignalsReceiver, SafeCallable};

const PIPE_BUFFER_SIZE: usize = 1000;

/// You might discover that APIWorker is referenced by raw pointer in `csbind.rs`.
/// It's to avoid the dead lock in the worker thread.
/// But there is no where protecting the raw pointers from hanging references.
/// However, do not forget the global static mut variable in `csbind.rs`, it will never been
/// freed or moved during the whole runtime.
pub struct APIWorker {
    client_tx: Sender<ClientPackage>,
    jh: JoinHandle<Result<()>>,

    pub(crate) world_id: u8,
    pub(crate) player_uuid: u128,

    pub(crate) state_code: StateCode,

    pub(crate) ping: Duration,
    pub(crate) delay: Duration,

    pub(crate) signal_rx: APISignalsReceiver,

    sync_recv_rx: Receiver<ServerPackage>,
    api_recv_buffer: Vec<ServerPackage>,

    _tokio_rt: Runtime,

    _p: PhantomPinned,
}

impl APIWorker {
    pub fn connect(host: String, player_id: u128, world_id: u8) -> Arc<RwLock<Self>> {
        logging_init();
        let (client_tx, client_rx) = mpsc::channel(PIPE_BUFFER_SIZE);
        let (worker_self_tx, worker_self_rx) = mpsc::channel(1);
        let (sync_recv_tx, sync_recv_rx) = mpsc::channel(PIPE_BUFFER_SIZE);
        let (signal_tx, signal_rx) = api_signal_channel(PIPE_BUFFER_SIZE);
        let tokio_rt = runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .unwrap();
        let jh = tokio_rt.spawn(async move {
            worker(
                worker_self_rx,
                host,
                player_id,
                world_id,
                client_rx,
                sync_recv_tx,
                signal_tx,
            )
            .await
        });
        let res = Arc::new(RwLock::new(Self {
            client_tx,
            jh,
            world_id: 0,
            player_uuid: 0,
            state_code: StateCode::NotStarted,
            ping: Duration::from_secs(0),
            delay: Duration::from_secs(0),
            signal_rx,
            sync_recv_rx,
            api_recv_buffer: Vec::new(),
            _tokio_rt: tokio_rt,
            _p: PhantomPinned,
        }));
        let res_ref = Arc::clone(&res);
        let _ = res
            .blocking_read()
            ._tokio_rt
            .spawn(async move { worker_self_tx.send(res_ref).await });
        while res.blocking_read().state_code == StateCode::NotStarted {}
        res
    }

    pub fn wait_timeout(&mut self, call: Callable) {
        if self
            ._tokio_rt
            .block_on(async { self.signal_rx.timeout.recv().await })
            .unwrap()
        {
            call.call(&[]);
        }
    }

    pub fn wait_connection_failed(&mut self, call: Callable) {
        if let Some(reason) = self
            ._tokio_rt
            .block_on(async { self.signal_rx.connection_failed.recv().await })
            .unwrap()
        {
            call.call(&[reason.to_variant()]);
        }
    }

    pub fn wait_started(&mut self, call: Callable) {
        if self
            ._tokio_rt
            .block_on(async { self.signal_rx.setup.recv().await })
            .unwrap()
        {
            call.call(&[]);
        }
    }

    pub fn wait_exited(&mut self, call: Callable) {
        if self
            ._tokio_rt
            .block_on(async { self.signal_rx.exited.recv().await })
            .unwrap()
        {
            call.call(&[]);
        }
    }

    pub fn send(&mut self, pkg: ClientPackage) {
        let res = self
            ._tokio_rt
            .block_on(async { self.client_tx.send(pkg).await });
        if let Err(e) = res {
            event!(Level::ERROR, "Failed to send package: {:?}", e);
        }
    }

    #[inline]
    pub fn check_state(&self) -> StateCode {
        self.state_code
    }

    #[inline]
    pub fn world_id(&self) -> u8 {
        self.world_id
    }

    #[inline]
    pub fn exit(&mut self) {
        self.send(ClientPackage::Exit);
    }

    #[inline]
    pub fn ping(&self) -> i64 {
        self.ping.as_millis() as i64
    }

    #[inline]
    pub fn delay(&self) -> i64 {
        self.delay.as_millis() as i64
    }

    pub fn pkg_recv(&mut self, type_id: u8) -> Option<ServerPackage> {
        for i in 0..self.api_recv_buffer.len() {
            if self.api_recv_buffer[i].discriminant() == type_id {
                return Some(self.api_recv_buffer.remove(i));
            }
        }
        while let Some(pkg) = self
            ._tokio_rt
            .block_on(async { self.sync_recv_rx.recv().await })
        {
            if pkg.discriminant() == type_id {
                return Some(pkg);
            }
            self.api_recv_buffer.push(pkg);
        }
        None
    }

    pub fn player_enter(&mut self, name: String) {
        self.send(ClientPackage::PlayerEvent(PlayerEvent::Enter(name)));
    }
}

#[derive(GodotClass)]
#[class(no_init)]
struct TheBallsWorker {
    worker: Arc<RwLock<APIWorker>>,

    _p: PhantomPinned,
}

#[godot_api]
impl TheBallsWorker {
    #[func]
    fn connect(host: GString, player_id: GString) -> Gd<Self> {
        let player_id = u128::from_str_radix(player_id.to_string().as_str(), 16).unwrap();
        let worker = APIWorker::connect(host.to_string(), player_id, 0);
        Gd::from_init_fn(|_| Self {
            worker,
            _p: PhantomPinned,
        })
    }

    #[func]
    fn timeout(&mut self, call: Callable) {
        self.worker.blocking_write().wait_timeout(call);
    }

    #[func]
    fn connection_failed(&mut self, call: Callable) {
        self.worker.blocking_write().wait_connection_failed(call);
    }

    #[func]
    fn started(&mut self, call: Callable) {
        self.worker.blocking_write().wait_started(call);
    }

    #[func]
    fn exited(&mut self, call: Callable) {
        self.worker.blocking_write().wait_exited(call);
    }

    #[func]
    fn check_state(&self) -> GString {
        GString::from(self.worker.blocking_read().check_state().to_string())
    }

    #[func]
    fn scene_id(&self) -> i64 {
        self.worker.blocking_read().world_id() as i64
    }

    #[func]
    fn exit(&mut self) {
        self.worker.blocking_write().exit();
    }

    #[func]
    fn ping(&self) -> i64 {
        self.worker.blocking_read().ping()
    }

    #[func]
    fn delay(&self) -> i64 {
        self.worker.blocking_read().delay()
    }

    #[func]
    fn player_enter(&mut self, name: GString) {
        self.worker.blocking_write().player_enter(name.to_string());
    }

    #[func]
    fn recv_player_enter(&mut self, call: Callable) {
        match self
            .worker
            .blocking_write()
            .pkg_recv(ServerPackage::PlayerEvent(PlayerEvent::None).discriminant())
        {
            Some(ServerPackage::PlayerEvent(PlayerEvent::Enter(name))) => {
                call.call(&[name.to_variant()]);
            }
            p => {
                self.worker
                    .blocking_write()
                    .api_recv_buffer
                    .push(p.unwrap());
            }
        }
    }
}
