use anyhow::Result;
use bincode::serialize;
use std::{
    collections::HashMap,
    env,
    sync::{Arc, LazyLock},
};
use theballs_protocol::{
    client::ClientHead,
    server::{ServerHead, StateCode},
};
use tokio::{io::AsyncWriteExt, net::TcpStream, sync::RwLock};
use tracing::{event, span, Level};

use crate::game::{
    enemy::Enemy,
    object::{AsObject, Object},
    scene::Scene,
};

pub async fn verify_header(head: &ClientHead, stream: &mut TcpStream) -> Result<bool> {
    let _span = span!(Level::DEBUG, "verify_header");
    let (verified, cliname, cliversion) = client_verified(head);
    let client = format!("{:x?}-{}", cliname, cliversion);
    let peer = stream.peer_addr()?;
    if !verified {
        event!(Level::INFO, ?peer, ?client, "\nVerification failed");
        let head = ServerHead {
            state: StateCode::ClientVerifyFailed,
            scene_id: 0,
            player_id: 0,
        };
        let head = serialize(&head)?;
        stream.write(&head).await?;
    } else {
        event!(Level::INFO, ?peer, ?client, "\nverification success");
    }
    Ok(verified)
}

fn client_verified(header: &ClientHead) -> (bool, u128, String) {
    let cliversion = header.version.to_string();
    let cliname = header.name_md5;
    if cliversion != env!("CARGO_PKG_VERSION") {
        return (false, cliname, cliversion);
    }
    if !SIGNED_CLIENT_NAMES.contains(&cliname) {
        return (false, cliname, cliversion);
    }
    (true, cliname, cliversion)
}

static PLAYER_MAP: LazyLock<RwLock<HashMap<u128, Arc<RwLock<Player>>>>> =
    LazyLock::new(|| RwLock::new(HashMap::new()));

pub struct Player {
    id: u128,
    scene_id: u8,
    name: String,

    key: bool,

    game_obj: Object,
}

impl AsObject for Player {
    fn as_object(&self) -> &Object {
        &self.game_obj
    }

    fn as_object_mut(&mut self) -> &mut Object {
        &mut self.game_obj
    }

    fn is_player(&self) -> bool {
        true
    }

    fn as_player(&self) -> Option<&Player> {
        Some(self)
    }

    fn as_player_mut(&mut self) -> Option<&mut Player> {
        Some(self)
    }

    fn as_enemy(&self) -> Option<&Enemy> {
        None
    }

    fn as_enemy_mut(&mut self) -> Option<&mut Enemy> {
        None
    }
}

impl Player {
    pub fn set_name(&mut self, name: String) {
        self.name = name;
    }

    pub fn is_key_player(&self) -> bool {
        self.key
    }
}

impl Player {
    pub async fn add(id: u128, scene_id: u8) {
        let mut player = Player {
            id,
            scene_id,
            name: String::new(),
            key: false,
            game_obj: Object::new(id),
        };
        player.game_obj.is_player = true;
        let scene = Scene::get(scene_id).await.unwrap();
        let mut scene = scene.write().await;
        if scene.count_player().await == 0 {
            player.key = true;
        }
        let player = Arc::new(RwLock::new(player));
        let mut map = PLAYER_MAP.write().await;
        map.insert(id, Arc::clone(&player));
        scene.add_player(id, player).await;
    }

    pub async fn exit(id: u128) {
        let mut map = PLAYER_MAP.write().await;
        let p = map.remove(&id).unwrap();
        let scene = Scene::get(p.read().await.scene_id).await.unwrap();
        if p.read().await.is_key_player() {
            // 重新选择第一个被迭代到的player指定其为key player
            for (uuid, p) in map.iter_mut() {
                if p.read().await.is_key_player() {
                    p.write().await.key = true;
                    event!(Level::INFO, "\nAssign new key player: {}", *uuid);
                    break;
                }
            }
        }
        scene.write().await.remove(id);
    }

    pub async fn list() -> Vec<(u128, String)> {
        let map = PLAYER_MAP.read().await;
        let mut res = Vec::new();
        for (id, p) in map.iter() {
            res.push((*id, p.read().await.name.clone()));
        }
        res
    }

    pub async fn get(id: u128) -> Option<Arc<RwLock<Self>>> {
        let map = PLAYER_MAP.read().await;
        map.get(&id).map(|p| Arc::clone(p))
    }
}

static SIGNED_CLIENT_NAMES: [u128; 1] = [0xe2ee9b16d999349dab22b08daaf607bc];
