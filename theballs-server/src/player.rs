use anyhow::Result;
use bincode::serialize;
use theballs_protocol::{
    client::ClientHead,
    server::{ServerHead, StateCode},
};
use std::{
    collections::HashMap,
    env,
    sync::{Arc, LazyLock},
};
use tokio::{io::AsyncWriteExt, net::TcpStream, sync::RwLock};
use tracing::{event, span, Level};

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
    skin_id: Option<u64>,
    world_id: u8,
}

impl Player {
    pub async fn add(id: u128, world_id: u8) {
        let mut map = PLAYER_MAP.write().await;
        map.insert(
            id,
            Arc::new(RwLock::new(Player {
                id,
                skin_id: None,
                world_id,
            })),
        );
    }

    pub async fn get(id: u128) -> Option<Arc<RwLock<Self>>> {
        let map = PLAYER_MAP.read().await;
        map.get(&id).map(|p| Arc::clone(p))
    }
}

static SIGNED_CLIENT_NAMES: [u128; 1] = [
    0x46bfd4e206ca470e0187511fd966dd53,
];
