use std::{sync::Arc, time::Duration};

use anyhow::{Ok, Result};
use theballs_protocol::{server::ServerPackage, PackObject};
use tokio::sync::RwLock;
use tracing::{event, Level};

use super::scene::Scene;

pub const TICK: Duration = Duration::from_millis(50);

pub async fn tick(scene: Arc<RwLock<Scene>>, delta: f64) -> Result<()> {
    let scene = scene.write().await;
    let mut objs_pack = Vec::new();
    for obj in scene.objects().values() {
        objs_pack.push(obj.read().await.as_object().clone());
    }
    let objs_pack = PackObject::pack_objects_iter(objs_pack.into_iter());
    scene
        .broadcast(ServerPackage::SceneSync { objects: objs_pack })
        .await?;
    Ok(())
}
