mod client;
pub mod config;
mod game;
mod player;

use std::sync::{
    atomic::{AtomicBool, Ordering},
    Arc,
};

use anyhow::{Ok, Result};
use tokio::{
    net::TcpListener,
    select,
    signal::ctrl_c,
    sync::{broadcast, Mutex},
    task::{self, JoinHandle},
};
use tracing::{event, Level};

#[cfg(target_os = "linux")]
use tokio::signal::unix::{signal, SignalKind};

use client::handle;
use config::Config;

pub async fn run(config: Config) -> Result<()> {
    event!(Level::INFO, "Starting server...");

    let running = Arc::new(AtomicBool::new(true));
    let running_clone = Arc::clone(&running);

    let (ctrlc_tx, _) = broadcast::channel(1);
    let ctrlc_tx = Arc::new(Mutex::new(ctrlc_tx));
    let ctrlc_tx_clone = Arc::clone(&ctrlc_tx);

    task::spawn(async move {
        #[cfg(target_os = "linux")]
        {
            let mut sighup = signal(SignalKind::hangup())?;
            select! {
                _ = ctrl_c() => {
                    event!(Level::INFO, "\nCtrl+C received, wait a minutes...");
                }
                _ = sighup.recv() => {
                    event!(Level::ERROR, "\nSIGHUP received, wait a minutes...");
                }
            };
        }
        #[cfg(target_os = "windows")]
        {
            select! {
                _ = ctrl_c() => {
                    event!(Level::INFO, "\nCtrl+C received, wait a minutes...");
                }
            };
        }
        running_clone.store(false, Ordering::SeqCst);
        let _ = ctrlc_tx_clone.lock().await.send(());
        Ok(())
    });

    let server = TcpListener::bind(format!("{}:{}", config.name, config.port)).await?;
    event!(
        Level::INFO,
        "\nListening on tcp://{}:{}",
        config.name,
        config.port
    );
    event!(Level::INFO, "\nPress Ctrl+C to stop server.");

    let mut jh_list: Vec<JoinHandle<Result<()>>> = Vec::new();
    while running.load(Ordering::SeqCst) {
        let mut guard = ctrlc_tx.lock().await.subscribe();
        select! {
            peer = server.accept() => {
                let (stream, socket_addr) = peer?;
                let running = Arc::clone(&running);
                let rx = ctrlc_tx.lock().await.subscribe();
                let jh = task::spawn(async move {
                    handle(stream, socket_addr, running, rx).await
                });
                jh_list.push(jh);
            }
            _ = guard.recv() => running.store(false, Ordering::SeqCst),
        }

        // clean up here so that when waiting for clients' connection
        // we can clean disconneted links
        let mut i = 0;
        while i < jh_list.len() {
            if jh_list[i].is_finished() {
                jh_list.remove(i);
            } else {
                i += 1;
            }
        }
    }

    event!(Level::INFO, "\nServer exited.");
    Ok(())
}
