use std::{collections::HashMap, sync::Arc, time::Duration};

use theballs_protocol::{ObjectPack, PackObject};
use tokio::sync::RwLock;

use super::{object::AsObject, scene::Scene};

pub const TICK: Duration = Duration::from_millis(20);

pub async fn tick(scene: Arc<RwLock<Scene>>, delta: f64) {
    let mut objs = scene.write().await;

    let mut players_pos = Vec::new();

    let objs = objs.objects_mut();
    for obj in objs.values_mut() {
        let mut obj = obj.write().await;
        // if !obj.is_player()
        {
            let obj = obj.as_object_mut();
            obj.gravity(delta);
        }
        if let Some(obj) = obj.as_player() {
            players_pos.push(obj.as_object().position);
        }
    }
    for obj in objs.values_mut() {
        let mut obj = obj.write().await;
        if let Some(obj) = obj.as_enemy_mut() {
            if obj.spawning_zoom(delta) {
                continue;
            }
            if players_pos.is_empty() {
                continue;
            }
            let p = players_pos
                .iter()
                .min_by_key(|p| ((*p - obj.game_obj.position).norm().abs() * 10000.) as usize)
                .unwrap();
            obj.follow(*p, delta);
        }
    }
}
