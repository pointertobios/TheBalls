use std::{sync::Arc, time::Duration};

use tokio::sync::RwLock;
use tracing::{event, Level};

use super::scene::Scene;

pub const TICK: Duration = Duration::from_millis(20);

pub async fn tick(scene: Arc<RwLock<Scene>>, delta: f64) {
    let mut objs = scene.write().await;
    let objs = objs.objects_mut();
    for (uuid, obj) in objs.iter_mut() {
        let mut obj = obj.write().await;
        let obj = obj.as_object_mut();
        obj.gravity(delta).await;
    }
}
