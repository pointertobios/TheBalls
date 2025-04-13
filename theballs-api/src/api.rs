use std::{
    marker::PhantomPinned,
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc,
    },
    time::Duration,
};

use anyhow::{Ok, Result};
use godot::prelude::*;
use theballs_protocol::{
    client::ClientPackage,
    server::{EnemyEvent, PlayerEvent, ServerPackage, StateCode},
    ObjectPack,
};
use tokio::{
    runtime::{self, Runtime},
    sync::{
        broadcast,
        mpsc::{self, Sender},
        RwLock,
    },
    task::JoinHandle,
};
use tracing::{event, Level};

use crate::{
    api_signal_channel, logging_init, worker::worker, APISignalsReceiver, SafeCallable, SafePointer,
};

const PIPE_BUFFER_SIZE: usize = 1000;

/// You might discover that APIWorker is referenced by raw pointer in `csbind.rs`.
/// It's to avoid the dead lock in the worker thread.
/// But there is no where protecting the raw pointers from hanging references.
/// However, do not forget the global static mut variable in `csbind.rs`, it will never been
/// freed or moved during the whole runtime.
pub struct APIWorker {
    client_tx: Sender<ClientPackage>,
    _jh: JoinHandle<Result<()>>,

    pub(crate) world_id: u8,
    pub(crate) player_uuid: u128,

    pub(crate) state_code: StateCode,

    pub(crate) ping: Duration,
    pub(crate) delay: Duration,

    pub(crate) signal_rx: APISignalsReceiver,

    api_recv_buffer: Arc<RwLock<Vec<ServerPackage>>>,
    recv_notifier: Arc<RwLock<broadcast::Sender<()>>>,

    running: Arc<AtomicBool>,
    true_exit: Arc<AtomicBool>,
    _tokio_rt: Runtime,

    _p: PhantomPinned,
}

static mut API_WORKER_INSTANCE: RwLock<Option<Arc<RwLock<APIWorker>>>> = RwLock::const_new(None);

impl APIWorker {
    pub fn connect(host: String, player_id: u128) -> Arc<RwLock<Self>> {
        logging_init();
        let (client_tx, client_rx) = mpsc::channel(PIPE_BUFFER_SIZE);
        let (worker_self_tx, mut worker_self_rx) = mpsc::channel(1);
        let (signal_tx, signal_rx) = api_signal_channel(PIPE_BUFFER_SIZE);
        let tokio_rt = runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .unwrap();
        let api_recv_buffer = Arc::new(RwLock::new(Vec::new()));
        let buffer = Arc::clone(&api_recv_buffer);
        let running = Arc::new(AtomicBool::new(true));
        let running_ref = Arc::clone(&running);
        let (recv_notifier, _) = broadcast::channel(64);
        let recv_notifier = Arc::new(RwLock::new(recv_notifier));
        let notifier = Arc::clone(&recv_notifier);
        let _host = host.clone();
        let true_exit = Arc::new(AtomicBool::new(false));
        let true_exit_ref = Arc::clone(&true_exit);
        let jh = tokio_rt.spawn(async move {
            let worker_self = worker_self_rx.recv().await.unwrap();
            let client_rx = Arc::new(RwLock::new(client_rx));
            let signal_tx = Arc::new(RwLock::new(signal_tx));
            let running = Arc::clone(&running_ref);
            let mut world_id = 0;
            while running.load(Ordering::Acquire) {
                let e = worker(
                    Arc::clone(&worker_self),
                    _host.clone(),
                    player_id,
                    &mut world_id,
                    Arc::clone(&client_rx),
                    Arc::clone(&buffer),
                    Arc::clone(&notifier),
                    Arc::clone(&signal_tx),
                    Arc::clone(&running_ref),
                )
                .await;
                event!(Level::ERROR, "worker exited: {:?}", e);
                running.store(true, Ordering::SeqCst);
                if true_exit_ref.load(Ordering::Acquire) {
                    break;
                }
            }
            Ok(())
        });
        let res = Arc::new(RwLock::new(Self {
            client_tx,
            _jh: jh,
            world_id: 0,
            player_uuid: 0,
            state_code: StateCode::NotStarted,
            ping: Duration::from_secs(0),
            delay: Duration::from_secs(0),
            signal_rx,
            api_recv_buffer,
            recv_notifier,
            running,
            true_exit,
            _tokio_rt: tokio_rt,
            _p: PhantomPinned,
        }));
        let res_ref = Arc::clone(&res);
        res.blocking_read()
            ._tokio_rt
            .spawn(async move { worker_self_tx.send(res_ref).await });
        while res.blocking_read().state_code == StateCode::NotStarted {}
        let w = Arc::clone(&res);
        res.blocking_read()
            ._tokio_rt
            .spawn(async move { unsafe { *API_WORKER_INSTANCE.write().await = Some(w) } });
        res
    }

    pub fn wait_timeout(&mut self, call: SafeCallable) {
        let selfp = SafePointer(self as *mut APIWorker);
        self._tokio_rt.spawn(async move {
            let mut selfp = selfp;
            if selfp.signal_rx.timeout.recv().await.unwrap() {
                call.call(&[]);
            }
        });
    }

    pub fn wait_connection_failed(&mut self, call: SafeCallable) {
        let selfp = SafePointer(self as *mut APIWorker);
        self._tokio_rt.spawn(async move {
            let mut selfp = selfp;
            if let Some(Some(reason)) = selfp.signal_rx.connection_failed.recv().await {
                call.call(&[reason.to_variant()]);
            }
        });
    }

    pub fn wait_started(&mut self, call: SafeCallable) {
        let selfp = SafePointer(self as *mut APIWorker);
        self._tokio_rt.spawn(async move {
            let mut selfp = selfp;
            if selfp.signal_rx.setup.recv().await.unwrap() {
                call.call(&[]);
            }
        });
    }

    pub fn wait_exited(&mut self, call: SafeCallable) {
        let selfp = SafePointer(self as *mut APIWorker);
        self._tokio_rt.spawn(async move {
            let mut selfp = selfp;
            if selfp.signal_rx.exited.recv().await.unwrap() {
                call.call(&[]);
            }
        });
    }

    pub fn send(&mut self, pkg: ClientPackage) {
        let res = self
            ._tokio_rt
            .block_on(async { self.client_tx.send(pkg).await });
        if let Err(e) = res {
            event!(Level::ERROR, "Failed to send package: {:?}", e);
            self.running.store(false, Ordering::SeqCst);
        }
    }

    #[inline]
    pub fn check_state(&self) -> StateCode {
        self.state_code
    }

    #[inline]
    pub fn world_id(&self) -> u8 {
        self.world_id
    }

    #[inline]
    pub fn exit(&mut self) {
        self.send(ClientPackage::Exit);
        self.true_exit.store(true, Ordering::SeqCst);
    }

    #[inline]
    pub fn ping(&self) -> i64 {
        self.ping.as_millis() as i64
    }

    #[inline]
    pub fn delay(&self) -> i64 {
        self.delay.as_millis() as i64
    }

    pub async fn get_pkg_from_buffer(&mut self, type_id: u8) -> Option<ServerPackage> {
        let mut buffer = self.api_recv_buffer.write().await;
        for i in 0..buffer.len() {
            if buffer[i].discriminant() == type_id {
                return Some(buffer.remove(i));
            }
        }
        None
    }

    pub async fn pkg_recv(&mut self, type_id: u8) -> Option<ServerPackage> {
        loop {
            if let Some(pkg) = self.get_pkg_from_buffer(type_id).await {
                break Some(pkg);
            }
            let mut rx = self.recv_notifier.read().await.subscribe();
            if let Err(_) = rx.recv().await {
                break None;
            }
        }
    }

    pub fn recv_player_exit(&mut self, call: SafeCallable) {
        let selfp = SafePointer(self as *mut APIWorker);
        let _: JoinHandle<Result<()>> = self._tokio_rt.spawn(async move {
            let mut selfp = selfp;
            loop {
                match selfp
                    .pkg_recv(ServerPackage::PlayerEvent(PlayerEvent::Exit(0)).discriminant())
                    .await
                {
                    Some(ServerPackage::PlayerEvent(PlayerEvent::Exit(uuid))) => {
                        call.call(&[format!("{:032x}", uuid).to_variant()]);
                    }
                    Some(pkg) => {
                        selfp.api_recv_buffer.write().await.push(pkg);
                        selfp.recv_notifier.read().await.send(())?;
                    }
                    None => break,
                }
            }
            event!(Level::INFO, "Exited recv_player_exit");
            Ok(())
        });
    }

    pub fn recv_enemy_spawn(&mut self, call: SafeCallable) {
        let selfp = SafePointer(self as *mut APIWorker);
        self._tokio_rt.spawn(async move {
            let mut selfp = selfp;
            loop {
                match selfp
                    .pkg_recv(ServerPackage::EnemyEvent(EnemyEvent::None).discriminant())
                    .await
                {
                    Some(ServerPackage::EnemyEvent(EnemyEvent::Spawn {
                        uuid,
                        position,
                        hp,
                        color,
                    })) => {
                        call.call(&[
                            format!("{:032x}", uuid).to_variant(),
                            position.to_variant(),
                            hp.to_variant(),
                            color.to_variant(),
                        ]);
                    }
                    Some(pkg) => {
                        selfp.api_recv_buffer.write().await.push(pkg);
                        selfp.recv_notifier.read().await.send(())?;
                    }
                    None => break,
                }
            }
            Ok(())
        });
    }

    pub fn scene_sync(&mut self, object: ObjectPack) {
        self.send(ClientPackage::SceneSync { object });
    }

    pub fn recv_scene_sync(&mut self, call: SafeCallable) {
        let selfp = SafePointer(self as *mut APIWorker);
        self._tokio_rt.spawn(async move {
            let mut selfp = selfp;
            while let Some(ServerPackage::SceneSync { objects }) = selfp
                .pkg_recv(
                    ServerPackage::SceneSync {
                        objects: Vec::new(),
                    }
                    .discriminant(),
                )
                .await
            {
                let objects: Vec<_> = objects.into_iter().map(|obj| obj.to_variant()).collect();
                call.call(&[objects.to_variant()]);
            }
            event!(Level::INFO, "Exited recv_scene_sync");
        });
    }

    pub fn player_enter(&mut self, uuid: u128, name: String) {
        self.send(ClientPackage::PlayerEvent(PlayerEvent::Enter {
            uuid,
            name,
            position: [0, 0, 0],
        }));
    }

    pub fn recv_player_enter(&mut self, call: SafeCallable) {
        let selfp = SafePointer(self as *mut APIWorker);
        let _: JoinHandle<Result<()>> = self._tokio_rt.spawn(async move {
            let mut selfp = selfp;
            loop {
                match selfp
                    .pkg_recv(ServerPackage::PlayerEvent(PlayerEvent::None).discriminant())
                    .await
                {
                    Some(ServerPackage::PlayerEvent(PlayerEvent::Enter {
                        uuid,
                        name,
                        position,
                    })) => {
                        call.call(&[
                            format!("{:032x}", uuid).to_variant(),
                            name.to_variant(),
                            position.to_variant(),
                        ]);
                    }
                    Some(pkg) => {
                        selfp.api_recv_buffer.write().await.push(pkg);
                        selfp.recv_notifier.read().await.send(())?;
                    }
                    None => break,
                }
            }
            event!(Level::INFO, "Exited recv_player_enter");
            Ok(())
        });
    }

    pub fn recv_player_list(&mut self, call: SafeCallable) {
        let selfp = SafePointer(self as *mut APIWorker);
        self._tokio_rt.spawn(async move {
            let mut selfp = selfp;
            while let Some(ServerPackage::PlayerList(list)) = selfp
                .pkg_recv(ServerPackage::PlayerList(vec![]).discriminant())
                .await
            {
                let (ids, names): (Vec<u128>, Vec<String>) = list.into_iter().unzip();
                let ids: Array<GString> = ids
                    .into_iter()
                    .map(|id| GString::from(format!("{:032x}", id)))
                    .collect();
                let names: Array<GString> =
                    names.into_iter().map(|name| GString::from(name)).collect();
                call.call(&[ids.to_variant(), names.to_variant()]);
            }
            event!(Level::INFO, "Exited recv_player_list")
        });
    }

    pub fn enemy_took_damage(&mut self, uuid: u128, damage: f64, source_uuid: u128, ulti: bool) {
        self.send(ClientPackage::EnemyEvent(EnemyEvent::TookDamage {
            uuid,
            damage,
            source_uuid,
            ulti,
        }));
    }

    pub fn recv_enemy_took_damage(&mut self, call: SafeCallable) {
        let selfp = SafePointer(self as *mut APIWorker);
        self._tokio_rt.spawn(async move {
            let mut selfp = selfp;
            loop {
                match selfp
                    .pkg_recv(ServerPackage::EnemyEvent(EnemyEvent::None).discriminant())
                    .await
                {
                    Some(ServerPackage::EnemyEvent(EnemyEvent::TookDamage {
                        uuid,
                        damage,
                        source_uuid,
                        ulti,
                    })) => {
                        call.call(&[
                            format!("{:032x}", uuid).to_variant(),
                            damage.to_variant(),
                            format!("{:032x}", source_uuid).to_variant(),
                            ulti.to_variant(),
                        ]);
                    }
                    Some(pkg) => {
                        selfp.api_recv_buffer.write().await.push(pkg);
                        selfp.recv_notifier.read().await.send(())?;
                    }
                    None => break,
                }
            }
            Ok(())
        });
    }

    pub fn enemy_die(&mut self, uuid: u128) {
        self.send(ClientPackage::EnemyEvent(EnemyEvent::Die { uuid }));
    }

    pub fn recv_enemy_die(&mut self, call: SafeCallable) {
        let selfp = SafePointer(self as *mut APIWorker);
        self._tokio_rt.spawn(async move {
            let mut selfp = selfp;
            loop {
                match selfp
                    .pkg_recv(ServerPackage::EnemyEvent(EnemyEvent::None).discriminant())
                    .await
                {
                    Some(ServerPackage::EnemyEvent(EnemyEvent::Die { uuid })) => {
                        call.call(&[format!("{:032x}", uuid).to_variant()]);
                    }
                    Some(pkg) => {
                        selfp.api_recv_buffer.write().await.push(pkg);
                        selfp.recv_notifier.read().await.send(())?;
                    }
                    None => break,
                }
            }
            Ok(())
        });
    }
}

#[derive(GodotClass)]
#[class(no_init)]
pub struct TheBallsWorker {
    worker: Arc<RwLock<APIWorker>>,

    _p: PhantomPinned,
}

#[godot_api]
impl TheBallsWorker {
    #[func]
    fn connect(host: GString, player_id: GString) -> Gd<Self> {
        let player_id = u128::from_str_radix(player_id.to_string().as_str(), 16).unwrap();
        let worker = APIWorker::connect(host.to_string(), player_id);
        Gd::from_init_fn(|_| Self {
            worker,
            _p: PhantomPinned,
        })
    }

    #[func]
    fn timeout(&mut self, call: Callable) {
        let call = SafeCallable::new(call);
        self.worker.blocking_write().wait_timeout(call);
    }

    #[func]
    fn connection_failed(&mut self, call: Callable) {
        let call = SafeCallable::new(call);
        self.worker.blocking_write().wait_connection_failed(call);
    }

    #[func]
    fn started(&mut self, call: Callable) {
        let call = SafeCallable::new(call);
        self.worker.blocking_write().wait_started(call);
    }

    #[func]
    fn exited(&mut self, call: Callable) {
        let call = SafeCallable::new(call);
        self.worker.blocking_write().wait_exited(call);
    }

    #[func]
    fn check_state(&self) -> GString {
        GString::from(self.worker.blocking_read().check_state().to_string())
    }

    #[func]
    fn scene_id(&self) -> i64 {
        self.worker.blocking_read().world_id() as i64
    }

    #[func]
    fn exit(&mut self) {
        self.worker.blocking_write().exit();
    }

    #[func]
    fn ping(&self) -> i64 {
        self.worker.blocking_read().ping()
    }

    #[func]
    fn delay(&self) -> i64 {
        self.worker.blocking_read().delay()
    }

    #[func]
    fn player_enter(&mut self, uuid: GString, name: GString) {
        self.worker.blocking_write().player_enter(
            u128::from_str_radix(&uuid.to_string(), 16).unwrap(),
            name.to_string(),
        );
    }

    #[func]
    /// worker.recv_player_enter(func (uuid: String, name: String, position: Array[int]):
    ///     ...
    /// )
    /// `position` 需要重新构造成Vector3
    /// `Array[int]` 仅为本文档类型提示，代码里只能写成 `Array`
    fn recv_player_enter(&mut self, call: Callable) {
        let call = SafeCallable::new(call);
        self.worker.blocking_write().recv_player_enter(call);
    }

    #[func]
    /// worker.recv_player_exit(func (uuid: String):
    ///     ...
    /// )
    fn recv_player_exit(&mut self, call: Callable) {
        let call = SafeCallable::new(call);
        self.worker.blocking_write().recv_player_exit(call);
    }

    #[func]
    /// worker.recv_player_list(func (ids: Array[String], names: Array[String]):
    ///     ...
    /// )
    fn recv_player_list(&mut self, call: Callable) {
        let call = SafeCallable::new(call);
        self.worker.blocking_write().recv_player_list(call);
    }

    #[func]
    fn scene_sync(&mut self, object: VariantArray) {
        let object = ObjectPack::from_variant(object);
        self.worker.blocking_write().scene_sync(object);
    }

    #[func]
    /// worker.recv_scene_sync(func (objs: Array[Object]):
    ///     ...
    /// )
    /// # 场景同步事件
    /// 敌人和玩家均为场景中的 `Object` ，客户端需要根据 `is_player` 参数选择更新玩家还是敌人。
    /// `Array[Object]` 仅为本文档类型提示，代码里只能写成 `Array`
    /// 其中 `Object` 类型为 `Array[Variant]` ，具体结构请看 `ObjectPack`
    /// 直接使用数组下标访问 `ObjectPack` 成员
    fn recv_scene_sync(&mut self, call: Callable) {
        let call: SafeCallable = SafeCallable::new(call);
        self.worker.blocking_write().recv_scene_sync(call);
    }

    #[func]
    /// worker.recv_enemy_spawn(func (uuid: String, position: Array[int], hp: float):
    ///     ...
    /// )
    /// `position` 需要重新构造成Vector3
    /// `Array[int]` 仅为本文档类型提示，代码里只能写成 `Array`
    fn recv_enemy_spawn(&mut self, call: Callable) {
        let call: SafeCallable = SafeCallable::new(call);
        self.worker.blocking_write().recv_enemy_spawn(call);
    }

    #[func]
    fn enemy_took_damage(&mut self, uuid: GString, damage: f64, source_uuid: GString, ulti: bool) {
        self.worker.blocking_write().enemy_took_damage(
            u128::from_str_radix(&uuid.to_string(), 16).unwrap(),
            damage,
            u128::from_str_radix(&source_uuid.to_string(), 16).unwrap(),
            ulti,
        );
    }

    #[func]
    fn recv_enemy_took_damage(&mut self, call: Callable) {
        let call: SafeCallable = SafeCallable::new(call);
        self.worker.blocking_write().recv_enemy_took_damage(call);
    }

    #[func]
    fn enemy_die(&mut self, uuid: GString) {
        self.worker
            .blocking_write()
            .enemy_die(u128::from_str_radix(&uuid.to_string(), 16).unwrap());
    }

    #[func]
    fn recv_enemy_die(&mut self, call: Callable) {
        let call: SafeCallable = SafeCallable::new(call);
        self.worker.blocking_write().recv_enemy_die(call);
    }
}
