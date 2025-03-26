use std::{
    collections::HashMap,
    sync::{Arc, LazyLock},
};

use tokio::sync::RwLock;

use crate::player::Player;

pub struct Scene {
    id: u8,
    players: HashMap<u128, Arc<RwLock<Player>>>,
}

impl Scene {
    #[allow(static_mut_refs)]
    pub async fn new() -> Arc<RwLock<Self>> {
        let id = Self::new_id();
        let res = Self {
            id,
            players: HashMap::new(),
        };
        let res = Arc::new(RwLock::new(res));
        unsafe {
            SCENE_MAP.write().await.insert(id, Arc::clone(&res));
        }
        res
    }

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
    pub fn new_id() -> u8 {
        static mut ID: u8 = 0;
        unsafe {
            let res = ID;
            ID += 1;
            res
        }
    }

    pub async fn get(id: u8) -> Option<Arc<RwLock<Self>>> {
        let scene = unsafe { SCENE_MAP.read().await.get(&id).cloned() };
        scene
    }

    pub fn main_id() -> u8 {
        0
    }
}
