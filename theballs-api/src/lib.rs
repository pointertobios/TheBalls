#![allow(static_mut_refs)]

use std::{
    ops::{Deref, DerefMut},
    panic,
};

use anyhow::Result;
use godot::prelude::*;
use tokio::sync::mpsc::{channel, Receiver, Sender};
use tracing::{event, Level};

pub mod api;
pub mod worker;

struct TheballsAPI;

#[gdextension]
unsafe impl ExtensionLibrary for TheballsAPI {}

pub struct SafeCallable {
    call: Callable,
}

impl SafeCallable {
    pub fn new(call: Callable) -> Self {
        Self { call }
    }

    pub fn call(&self, args: &[Variant]) {
        self.call.call_deferred(args)
    }
}

unsafe impl Send for SafeCallable {}
unsafe impl Sync for SafeCallable {}

pub struct SafePointer<T>(*mut T);

impl<T> Deref for SafePointer<T> {
    type Target = T;

    fn deref(&self) -> &Self::Target {
        unsafe { &*self.0 }
    }
}

impl<T> DerefMut for SafePointer<T> {
    fn deref_mut(&mut self) -> &mut Self::Target {
        unsafe { &mut *self.0 }
    }
}

unsafe impl<T> Send for SafePointer<T> {}
unsafe impl<T> Sync for SafePointer<T> {}

pub struct APISignalsReceiver {
    pub(crate) timeout: Receiver<bool>,
    pub(crate) connection_failed: Receiver<Option<String>>,
    pub(crate) setup: Receiver<bool>,
    pub(crate) exited: Receiver<bool>,
}

pub struct APISignalsSender {
    pub(crate) timeout: Sender<bool>,
    pub(crate) connection_failed: Sender<Option<String>>,
    pub(crate) setup: Sender<bool>,
    pub(crate) exited: Sender<bool>,
}

impl APISignalsSender {
    pub async fn send_timeout(&self) -> Result<()> {
        self.timeout.send(true).await?;
        self.connection_failed.send(None).await?;
        self.setup.send(false).await?;
        Ok(())
    }

    pub async fn send_connection_failed(&self, reason: String) -> Result<()> {
        self.connection_failed.send(Some(reason)).await?;
        self.timeout.send(false).await?;
        self.setup.send(false).await?;
        Ok(())
    }

    pub async fn send_setup(&self) -> Result<()> {
        self.setup.send(true).await?;
        self.timeout.send(false).await?;
        self.connection_failed.send(None).await?;
        Ok(())
    }

    pub async fn send_exited(&self) -> Result<()> {
        self.exited.send(true).await?;
        Ok(())
    }
}

pub(crate) fn api_signal_channel(buffer: usize) -> (APISignalsSender, APISignalsReceiver) {
    let (timeout_tx, timeout_rx) = channel(buffer);
    let (connection_failed_tx, connection_failed_rx) = channel(buffer);
    let (setup_tx, setup_rx) = channel(buffer);
    let (exited_tx, exited_rx) = channel(buffer);
    (
        APISignalsSender {
            timeout: timeout_tx,
            connection_failed: connection_failed_tx,
            setup: setup_tx,
            exited: exited_tx,
        },
        APISignalsReceiver {
            timeout: timeout_rx,
            connection_failed: connection_failed_rx,
            setup: setup_rx,
            exited: exited_rx,
        },
    )
}

fn logging_init() {
    let subscriber = tracing_subscriber::fmt()
        .with_max_level(Level::DEBUG)
        .pretty()
        .with_ansi(true)
        .with_thread_names(true)
        .with_thread_ids(true)
        .finish();
    tracing::subscriber::set_global_default(subscriber).expect("Failed to set global subscriber");
    panic::set_hook(Box::new(|info| {
        event!(Level::ERROR, "{}", info);
    }));
}
