use std::{marker::PhantomPinned, ptr::addr_of, sync::Arc, time::Duration};

use anyhow::Result;
use godot::prelude::*;
use theballs_protocol::{
    client::ClientPackage,
    server::{PlayerEvent, ServerPackage, StateCode},
};
use tokio::{
    runtime::{self, Runtime},
    sync::{
        mpsc::{self, Receiver, Sender},
        RwLock,
    },
    task::JoinHandle,
    time,
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
    jh: JoinHandle<Result<()>>,

    pub(crate) world_id: u8,
    pub(crate) player_uuid: u128,

    pub(crate) state_code: StateCode,

    pub(crate) ping: Duration,
    pub(crate) delay: Duration,

    pub(crate) signal_rx: APISignalsReceiver,

    sync_recv_rx: RwLock<Receiver<ServerPackage>>,
    api_recv_buffer: Vec<ServerPackage>,

    _tokio_rt: Runtime,

    _p: PhantomPinned,
}

impl APIWorker {
    pub fn connect(host: String, player_id: u128, world_id: u8) -> Arc<RwLock<Self>> {
        logging_init();
        let (client_tx, client_rx) = mpsc::channel(PIPE_BUFFER_SIZE);
        let (worker_self_tx, worker_self_rx) = mpsc::channel(1);
        let (sync_recv_tx, sync_recv_rx) = mpsc::channel(PIPE_BUFFER_SIZE);
        let (signal_tx, signal_rx) = api_signal_channel(PIPE_BUFFER_SIZE);
        let tokio_rt = runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .unwrap();
        let jh = tokio_rt.spawn(async move {
            worker(
                worker_self_rx,
                host,
                player_id,
                world_id,
                client_rx,
                sync_recv_tx,
                signal_tx,
            )
            .await
        });
        let res = Arc::new(RwLock::new(Self {
            client_tx,
            jh,
            world_id: 0,
            player_uuid: 0,
            state_code: StateCode::NotStarted,
            ping: Duration::from_secs(0),
            delay: Duration::from_secs(0),
            signal_rx,
            sync_recv_rx: RwLock::new(sync_recv_rx),
            api_recv_buffer: Vec::new(),
            _tokio_rt: tokio_rt,
            _p: PhantomPinned,
        }));
        let res_ref = Arc::clone(&res);
        let _ = res
            .blocking_read()
            ._tokio_rt
            .spawn(async move { worker_self_tx.send(res_ref).await });
        while res.blocking_read().state_code == StateCode::NotStarted {}
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
    }

    #[inline]
    pub fn ping(&self) -> i64 {
        self.ping.as_millis() as i64
    }

    #[inline]
    pub fn delay(&self) -> i64 {
        self.delay.as_millis() as i64
    }

    pub fn get_pkg_from_buffer(&mut self, type_id: u8) -> Option<ServerPackage> {
        for i in 0..self.api_recv_buffer.len() {
            if self.api_recv_buffer[i].discriminant() == type_id {
                return Some(self.api_recv_buffer.remove(i));
            }
        }
        None
    }

    pub async fn pkg_recv(&mut self, type_id: u8) -> Option<ServerPackage> {
        if let Some(pkg) = self.get_pkg_from_buffer(type_id) {
            return Some(pkg);
        }
        loop {
            if let Some(res) = {
                let mut rx_g = unsafe { &*addr_of!(self.sync_recv_rx) }.write().await;
                let res = if let Some(pkg) = self.get_pkg_from_buffer(type_id) {
                    Some(pkg)
                } else {
                    if let Some(pkg) = rx_g.recv().await {
                        if pkg.discriminant() == type_id {
                            event!(Level::INFO, "Found package: {:?}", pkg);
                            Some(pkg)
                        } else {
                            self.api_recv_buffer.push(pkg);
                            None
                        }
                    } else {
                        return None;
                    }
                };
                res
            } {
                return Some(res);
            } else {
                time::sleep(Duration::from_millis(1)).await;
            }
        }
    }

    pub fn player_enter(&mut self, name: String) {
        self.send(ClientPackage::PlayerEvent(PlayerEvent::Enter(name)));
    }

    pub fn recv_player_enter(&mut self, call: SafeCallable) {
        let selfp = SafePointer(self as *mut APIWorker);
        self._tokio_rt.spawn(async move {
            let mut selfp = selfp;
            loop {
                match selfp
                    .pkg_recv(ServerPackage::PlayerEvent(PlayerEvent::None).discriminant())
                    .await
                {
                    Some(ServerPackage::PlayerEvent(PlayerEvent::Enter(name))) => {
                        call.call(&[name.to_variant()]);
                    }
                    Some(pkg) => selfp.api_recv_buffer.push(pkg),
                    None => break,
                }
            }
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
                    .map(|id| GString::from(id.to_string()))
                    .collect();
                let names: Array<GString> =
                    names.into_iter().map(|name| GString::from(name)).collect();
                call.call(&[ids.to_variant(), names.to_variant()]);
            }
        });
    }
}

#[derive(GodotClass)]
#[class(no_init)]
struct TheBallsWorker {
    worker: Arc<RwLock<APIWorker>>,

    _p: PhantomPinned,
}

#[godot_api]
impl TheBallsWorker {
    #[func]
    fn connect(host: GString, player_id: GString) -> Gd<Self> {
        let player_id = u128::from_str_radix(player_id.to_string().as_str(), 16).unwrap();
        let worker = APIWorker::connect(host.to_string(), player_id, 0);
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
    fn player_enter(&mut self, name: GString) {
        self.worker.blocking_write().player_enter(name.to_string());
    }

    #[func]
    fn recv_player_enter(&mut self, call: Callable) {
        let call = SafeCallable::new(call);
        self.worker.blocking_write().recv_player_enter(call);
    }

    #[func]
    fn recv_player_list(&mut self, call: Callable) {
        let call = SafeCallable::new(call);
        self.worker.blocking_write().recv_player_list(call);
    }
}
