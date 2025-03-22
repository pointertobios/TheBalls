use clap::Parser;
use tracing::Level;

#[derive(Debug, Parser)]
#[command(author, version, about, long_about = None)]
pub struct Config {
    #[clap(short, long, default_value = "0.0.0.0")]
    /// 监听的地址，通常是0.0.0.0
    pub name: String,
    #[clap(long, default_value = "3000")]
    /// 监听的端口
    pub port: u16,
    #[clap(short, long, default_value = "debug")]
    /// 日志等级 <trace|debug|info|warning|error>
    pub log: Level,
}
