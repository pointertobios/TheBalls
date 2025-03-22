use std::panic;

use anyhow::Result;
use clap::Parser;
use theballs_server::{config::Config, run};
use tracing::{event, Level};
use tracing_subscriber::{fmt::format::FmtSpan, FmtSubscriber};

#[tokio::main]
async fn main() -> Result<()> {
    let config = Config::parse();

    let subscriber = FmtSubscriber::builder()
        .with_ansi(true)
        .pretty()
        .with_span_events(FmtSpan::NEW | FmtSpan::CLOSE)
        .with_max_level(config.log)
        .with_thread_names(true)
        .with_thread_ids(true);
    #[cfg(not(debug_assertions))]
    let subscriber = subscriber.with_file(false).with_line_number(false);
    let subscriber = subscriber.finish();
    tracing::subscriber::set_global_default(subscriber).expect("Failed to set global subscriber");
    panic::set_hook(Box::new(|info| {
        event!(Level::ERROR, "\n{}", info);
    }));
    run(config).await?;
    Ok(())
}
