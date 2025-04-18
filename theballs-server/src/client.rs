use std::{
    net::SocketAddr,
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc,
    },
    time::SystemTime,
};

use anyhow::{anyhow, Result};
use bincode::{deserialize, serialize};
use bytes::BytesMut;
use theballs_protocol::{
    client::{ClientHead, ClientPackage},
    server::{EnemyEvent, PlayerEvent, ServerHead, ServerPackage, StateCode},
    FromTcpStream, Pack, PackObject, HEARTBEAT_DURATION,
};
use tokio::{
    io::{AsyncReadExt, AsyncWriteExt},
    net::TcpStream,
    select,
    signal::ctrl_c,
    sync::broadcast::Receiver,
    time::interval,
};
use tracing::{event, Level};

use crate::{
    game::{
        object::{AsObject, Object},
        scene::Scene,
    },
    player::{self, Player},
};

pub async fn handle(
    mut stream: TcpStream,
    addr: SocketAddr,
    running: Arc<AtomicBool>,
    mut scene_sync_rx: Receiver<ServerPackage>,
) -> Result<()> {
    let head = headers_exchange(&mut stream).await?;
    event!(Level::INFO, ?head.player_id, "\nNew connection from {}", addr);

    let scene = Scene::get(head.scene_id).await.unwrap();

    let mut last_beat = SystemTime::now();
    let mut heartbeat_interval = interval(HEARTBEAT_DURATION);

    let mut buf = BytesMut::new();

    while running.load(Ordering::Acquire) {
        select! {
            cpkg = ClientPackage::from_tcp_stream(&mut stream, &mut buf) => {
                match cpkg? {
                    Some(ClientPackage::HeartBeat) => {
                        last_beat = SystemTime::now();
                    }
                    Some(ClientPackage::Exit) => {
                        scene.write().await.broadcast(ServerPackage::PlayerEvent(PlayerEvent::Exit(head.player_id))).await?;
                        break;
                    }
                    Some(p) => {
                        let p = package_handle(&head, &mut *scene.write().await, p).await?;
                        if let Some(p) = p {
                            stream.write_all(&p.pack()?).await?;
                        }
                    }
                    None => (),
                }
            }
            Ok(pkg) = scene_sync_rx.recv() => {
                stream.write_all(&pkg.pack()?).await?;
            }
            _ = heartbeat_interval.tick() => {
                let dur = SystemTime::now().duration_since(last_beat)?;
                if dur > HEARTBEAT_DURATION * 4 {
                    event!(Level::WARN, ?head.player_id, "\nConnection lost");
                    break;
                }
            }
            _ = ctrl_c() => {
                stream.write_all(&ServerPackage::Exit.pack()?).await?;
                break;
            }
        }
    }

    Player::exit(head.player_id).await;

    event!(Level::INFO, ?head.player_id, "\nServing thread exited");
    Ok(())
}

/// This function don't handle `ClientPackage::HeartBeat` and `ClientPackage::Exit`
async fn package_handle(
    head: &ClientHead,
    scene: &mut Scene,
    cpkg: ClientPackage,
) -> Result<Option<ServerPackage>> {
    let now = SystemTime::now();

    let spkg = match cpkg {
        ClientPackage::TimeDeviation => ServerPackage::TimeDeviation(now),

        ClientPackage::SceneSync { object } => {
            let dynobj = Object::unpack_object(object.clone());
            if object.uuid == head.player_id {
                *scene
                    .objects_mut()
                    .get(&object.uuid)
                    .unwrap()
                    .write()
                    .await
                    .as_object_mut() = dynobj;
            } else if {
                scene
                    .objects()
                    .get(&head.player_id)
                    .unwrap()
                    .read()
                    .await
                    .as_player()
                    .unwrap()
                    .is_key_player()
            } {
                if let Some(enemy) = scene
                    .objects_mut()
                    .get(&object.uuid)
                    .unwrap()
                    .write()
                    .await
                    .as_enemy_mut()
                {
                    *enemy.as_object_mut() = dynobj;
                }
            }
            ServerPackage::None
        }

        ClientPackage::PlayerEvent(event) => match event {
            PlayerEvent::Enter { uuid: _, name, .. } => {
                let res = Player::list().await;
                event!(Level::DEBUG, "Send player list: {:?}", res);

                let player = Player::get(head.player_id).await.unwrap();
                let mut player = player.write().await;
                player.set_name(name.clone());
                scene
                    .broadcast(ServerPackage::PlayerEvent(PlayerEvent::Enter {
                        uuid: head.player_id,
                        name,
                        position: [
                            player.as_object().position.x as i64,
                            player.as_object().position.y as i64,
                            player.as_object().position.z as i64,
                        ],
                    }))
                    .await?;

                ServerPackage::PlayerList(res)
            }

            _ => ServerPackage::None,
        },

        ClientPackage::EnemyEvent(event) => match event {
            EnemyEvent::TookDamage {
                uuid,
                damage,
                source_uuid,
                ulti,
            } => {
                scene
                    .broadcast(ServerPackage::EnemyEvent(EnemyEvent::TookDamage {
                        uuid,
                        damage,
                        source_uuid,
                        ulti,
                    }))
                    .await?;
                ServerPackage::None
            }
            EnemyEvent::Die { uuid } => {
                scene.objects_mut().remove(&uuid);
                scene
                    .broadcast(ServerPackage::EnemyEvent(EnemyEvent::Die { uuid }))
                    .await?;
                ServerPackage::None
            }
            _ => ServerPackage::None,
        },

        _ => ServerPackage::None,
    };
    Ok(Some(spkg))
}

async fn headers_exchange(stream: &mut TcpStream) -> Result<ClientHead> {
    let mut head = [0u8; size_of::<ClientHead>()];
    stream.read(&mut head).await?;
    let mut head: ClientHead = deserialize(&head)?;
    if !player::verify_header(&head, stream).await? {
        return Err(anyhow!("Verify failed"));
    }
    if head.scene_id == 0 {
        let scene_id = Scene::main_id();
        head.scene_id = scene_id;
        Player::add(head.player_id, head.scene_id).await;
        let player = Player::get(head.player_id).await.unwrap();
        let scene = Scene::get(scene_id).await.unwrap();
        let mut scene = scene.write().await;
        scene.add_player(head.player_id, player).await;
        drop(scene);
        let res = ServerHead {
            state: StateCode::Success,
            scene_id,
            player_id: head.player_id,
        };
        let res = serialize(&res)?;
        stream.write_all(&res).await?;
    } else {
        let scene = if let Some(scene) = Scene::get(head.scene_id).await {
            scene
        } else {
            let res_ = ServerHead {
                state: StateCode::NoSceneId,
                scene_id: head.scene_id,
                player_id: head.player_id,
            };
            let res = serialize(&res_)?;
            stream.write_all(&res).await?;
            event!(Level::TRACE, ?head.player_id, "\n{:?}", res_);
            return Err(anyhow!("No world id"));
        };
        let scene = scene.write().await;
        if let None = Player::get(head.player_id).await {
            let res_ = ServerHead {
                state: StateCode::NoPlayerId,
                scene_id: head.scene_id,
                player_id: head.player_id,
            };
            let res = serialize(&res_)?;
            stream.write_all(&res).await?;
            event!(Level::TRACE, ?head.player_id, "\n{:?}", res_);
            return Err(anyhow!("No player id"));
        };
        if let None = scene.objects().get(&head.player_id) {
            let res_ = ServerHead {
                state: StateCode::PlayerIdNotFoundInScene,
                scene_id: head.scene_id,
                player_id: head.player_id,
            };
            let res = serialize(&res_)?;
            stream.write_all(&res).await?;
            event!(Level::TRACE, ?head.player_id, "\n{:?}", res_);
            return Err(anyhow!("Player id not found in world"));
        }
        let res = ServerHead {
            state: StateCode::Success,
            scene_id: head.scene_id,
            player_id: head.player_id,
        };
        let res = serialize(&res)?;
        stream.write_all(&res).await?;
    }
    Ok(head)
}
