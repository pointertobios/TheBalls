use std::{sync::Arc, time::Duration};

use theballs_protocol::PackObject;
use tokio::sync::RwLock;

use super::scene::Scene;

pub const TICK: Duration = Duration::from_millis(50);

pub async fn tick(scene: Arc<RwLock<Scene>>, delta: f64) {
    let objs = scene.write().await;
    let mut objs_pack = Vec::new();
    for obj in objs.objects().values() {
        objs_pack.push(obj.read().await.as_object().clone());
    }
    let objs_pack = PackObject::pack_objects_iter(objs_pack.into_iter());
}
