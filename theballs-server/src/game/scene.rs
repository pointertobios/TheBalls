use std::{
    collections::HashMap,
    fmt::Debug,
    sync::{
        atomic::{AtomicBool, AtomicUsize, Ordering},
        Arc, LazyLock,
    },
    time::{Duration, SystemTime},
};

use anyhow::{Ok, Result};
use theballs_protocol::server::{EnemyEvent, ServerPackage};
use tokio::{
    select,
    signal::ctrl_c,
    sync::{
        broadcast::{Receiver, Sender},
        RwLock,
    },
    time::interval,
};
use tracing::{event, Level};

use crate::{
    game::{enemy::Enemy, gametick, physicstick},
    player::Player,
};

use super::object::AsObject;

pub struct Scene {
    id: u8,
    objects: HashMap<u128, Arc<RwLock<dyn AsObject>>>,
    enemy_count: Arc<AtomicUsize>,
    sync_data_sender: Sender<ServerPackage>,

    game_start: bool,
}

impl Debug for Scene {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("Scene").field("id", &self.id).finish()
    }
}

impl Scene {
    #[allow(static_mut_refs)]
    pub async fn new(
        running: Arc<AtomicBool>,
        sync_data_sender: Sender<ServerPackage>,
    ) -> Arc<RwLock<Self>> {
        let id = Self::new_id();
        let enemy_count = Arc::new(AtomicUsize::new(0));
        let r_enemy_count = Arc::clone(&enemy_count);
        let res = Self {
            id,
            objects: HashMap::new(),
            enemy_count,
            sync_data_sender,
            game_start: false,
        };
        let res = Arc::new(RwLock::new(res));
        unsafe {
            SCENE_MAP.write().await.insert(id, Arc::clone(&res));
        }
        let selfp = Arc::clone(&res);
        tokio::spawn(async move {
            event!(Level::INFO, "\nScene started.");
            let mut gt = interval(gametick::TICK);
            let mut gt_last = SystemTime::now();
            let mut pt = interval(physicstick::TICK);
            let mut pt_last = SystemTime::now();
            let mut enemy_spawn = interval(Duration::from_secs(5));
            while running.load(Ordering::Acquire) {
                select! {
                    _ = gt.tick() => {
                        let delta = gt_last.elapsed().unwrap().as_secs_f64();
                        gt_last = SystemTime::now();
                        gametick::tick(Arc::clone(&selfp), delta).await?;
                    }
                    _ = pt.tick() => {
                        let delta = pt_last.elapsed().unwrap().as_secs_f64();
                        pt_last = SystemTime::now();
                        physicstick::tick(Arc::clone(&selfp), delta).await;
                    }
                    _ = enemy_spawn.tick() => {
                        let enemy_count = Arc::clone(&r_enemy_count);
                        if selfp.read().await.game_start && enemy_count.load(Ordering::Acquire) < 15 {
                            enemy_count.fetch_add(1, Ordering::SeqCst);
                            let ene = Enemy::new();
                            let uuid = ene.game_obj.uuid;
                            let pos = ene.game_obj.position;
                            selfp
                            .read()
                            .await
                            .broadcast(ServerPackage::EnemyEvent(EnemyEvent::Spawn {
                                uuid,
                                position: [pos.x as i64, pos.y as i64, pos.z as i64],
                                hp: ene.game_obj.hp_max,
                            }))
                            .await?;
                            let ene = Arc::new(RwLock::new(ene));
                            selfp.write().await.objects_mut().insert(uuid, ene);
                        }
                    }
                    _ = ctrl_c() => {
                        break;
                    }
                }
            }
            event!(Level::INFO, "\nScene ended.");
            Ok(())
        });
        res
    }

    pub async fn broadcast(&self, pkg: ServerPackage) -> Result<()> {
        let _ = self.sync_data_sender.send(pkg);
        Ok(())
    }

    pub fn subscribe_receiver(&self) -> Receiver<ServerPackage> {
        self.sync_data_sender.subscribe()
    }

    pub fn add_player(&mut self, id: u128, player: Arc<RwLock<Player>>) {
        self.objects.insert(id, player);
        if self
            .objects
            .iter()
            .filter(|(_, v)| v.blocking_read().is_player())
            .count()
            >= 3
        {
            self.game_start = true;
        }
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
        static mut ID: u8 = 2;
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
        1
    }
}
