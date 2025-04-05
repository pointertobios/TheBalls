use std::{
    collections::HashMap,
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc, LazyLock,
    },
    time::SystemTime,
};

use anyhow::{Ok, Result};
use theballs_protocol::server::ServerPackage;
use tokio::{
    select,
    signal::ctrl_c,
    sync::{
        broadcast::{Receiver, Sender},
        RwLock,
    },
    time::interval,
};

use crate::{
    game::{gametick, physicstick},
    player::Player,
};

use super::object::AsObject;

pub struct Scene {
    id: u8,
    objects: HashMap<u128, Arc<RwLock<dyn AsObject>>>,
    sync_data_sender: Sender<ServerPackage>,
}

impl Scene {
    #[allow(static_mut_refs)]
    pub async fn new(
        running: Arc<AtomicBool>,
        sync_data_sender: Sender<ServerPackage>,
    ) -> Arc<RwLock<Self>> {
        let id = Self::new_id();
        let res = Self {
            id,
            objects: HashMap::new(),
            sync_data_sender,
        };
        let res = Arc::new(RwLock::new(res));
        unsafe {
            SCENE_MAP.write().await.insert(id, Arc::clone(&res));
        }
        let res_cl = Arc::clone(&res);
        tokio::spawn(async move {
            let mut gt = interval(gametick::TICK);
            let mut gt_last = SystemTime::now();
            let mut pt = interval(physicstick::TICK);
            let mut pt_last = SystemTime::now();
            while running.load(Ordering::Acquire) {
                select! {
                    _ = gt.tick() => {
                        let delta = gt_last.elapsed().unwrap().as_secs_f64();
                        gt_last = SystemTime::now();
                        gametick::tick(Arc::clone(&res_cl), delta).await?;
                    }
                    _ = pt.tick() => {
                        let delta = pt_last.elapsed().unwrap().as_secs_f64();
                        pt_last = SystemTime::now();
                        physicstick::tick(Arc::clone(&res_cl), delta).await;
                    }
                    _ = ctrl_c() => {
                        break;
                    }
                }
            }
            Ok(())
        });
        res
    }

    pub async fn broadcast(&self, pkg: ServerPackage) -> Result<()> {
        self.sync_data_sender.send(pkg)?;
        Ok(())
    }

    pub fn register_receiver(&self) -> Receiver<ServerPackage> {
        self.sync_data_sender.subscribe()
    }

    pub fn add_player(&mut self, id: u128, player: Arc<RwLock<Player>>) {
        self.objects.insert(id, player);
    }

    pub fn objects(&self) -> &HashMap<u128, Arc<RwLock<dyn AsObject>>> {
        &self.objects
    }

    pub fn objects_mut(&mut self) -> &mut HashMap<u128, Arc<RwLock<dyn AsObject>>> {
        &mut self.objects
    }

    pub fn remove(&mut self, uuid: u128) {
        self.objects.remove(&uuid);
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
