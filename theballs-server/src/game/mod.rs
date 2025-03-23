use std::{
    collections::HashMap,
    sync::{Arc, LazyLock},
};

use tokio::sync::RwLock;

use crate::player::Player;

pub struct Scene {
    players: HashMap<u128, Arc<RwLock<Player>>>,
}

impl Scene {
    pub fn add_player(&mut self, id: u128, player: Arc<RwLock<Player>>) {
        self.players.insert(id, player);
    }

    pub fn players(&self) -> &HashMap<u128, Arc<RwLock<Player>>> {
        &self.players
    }
}

static mut SCENE_MAP: LazyLock<RwLock<HashMap<u8, Arc<RwLock<Scene>>>>> =
    LazyLock::new(|| RwLock::new(HashMap::new()));

#[allow(static_mut_refs)]
impl Scene {
    pub async fn get(id: u8) -> Option<Arc<RwLock<Self>>> {
        let scene = unsafe { SCENE_MAP.read().await.get(&id).cloned() };
        scene
    }

    pub fn main_id() -> u8 {
        0
    }
}
