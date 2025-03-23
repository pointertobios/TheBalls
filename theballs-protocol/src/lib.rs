pub mod client;
pub mod server;

use std::{fmt::Debug, future::Future, time::Duration};

use anyhow::Result;
use bincode::{deserialize, serialize};
use bytes::BytesMut;
use serde::{Deserialize, Serialize};
use tokio::{io::AsyncReadExt, net::TcpStream};
use tracing::{event, Level};

pub const HEARTBEAT_DURATION: Duration = Duration::from_secs(5);

pub trait Pack
where
    Self: Serialize,
{
    fn pack(&self) -> Result<Vec<u8>> {
        let mut body = serialize(self)?;
        let mut len = (body.len() as u32).to_le_bytes().to_vec();
        len.append(&mut body);
        Ok(len)
    }
}

pub trait FromTcpStream {
    fn from_tcp_stream(
        stream: &mut TcpStream,
        buf: &mut BytesMut,
    ) -> impl Future<Output = Result<Option<Self>>> + Send
    where
        Self: Sized + Debug + for<'de> Deserialize<'de>,
    {
        async move {
            while buf.len() < 4 {
                let len = stream.read_buf(buf).await?;
                if len == 0 {
                    return Ok(None);
                }
            }
            let pack_len = u32::from_le_bytes(buf.split_to(4).as_ref().try_into()?) as usize;
            event!(Level::TRACE, "pack_len: {}", pack_len);
            while buf.len() < pack_len {
                let len = stream.read_buf(buf).await?;
                if len == 0 {
                    return Ok(None);
                }
            }
            let pack = buf.split_to(pack_len);
            let pkg: Self = deserialize(&pack)?;
            event!(Level::TRACE, "\nReceived pack: {:?}", pkg);
            Ok(Some(pkg))
        }
    }
}
