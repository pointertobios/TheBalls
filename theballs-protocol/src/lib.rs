pub mod client;
pub mod server;

use std::{fmt::Debug, future::Future, time::Duration};

use anyhow::Result;
use bincode::{deserialize, serialize};
use bytes::BytesMut;
use godot::prelude::*;
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

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ObjectPack {
    pub uuid: u128,
    pub is_player: bool,
    pub radius: f64,
    pub position: [f64; 3],
    pub velocity: [f64; 3],
    pub acceleration: [f64; 3],
    pub fast_falling: bool,
    pub charging: bool,
    pub charging_keep: bool,
}

impl ObjectPack {
    pub fn to_variant(&self) -> VariantArray {
        varray![
            format!("{:032x}", self.uuid).to_variant(),
            self.is_player,
            self.radius,
            self.position.to_variant(),
            self.velocity.to_variant(),
            self.acceleration.to_variant(),
            self.fast_falling,
            self.charging,
            self.charging_keep,
        ]
    }

    pub fn from_variant(v: VariantArray) -> Self {
        Self {
            uuid: u128::from_str_radix(&v.at(0).to::<String>(), 16).unwrap(),
            is_player: v.at(1).to::<bool>(),
            radius: v.at(2).to::<f64>(),
            position: v.at(3).to::<[f64; 3]>(),
            velocity: v.at(4).to::<[f64; 3]>(),
            acceleration: v.at(5).to::<[f64; 3]>(),
            fast_falling: v.at(6).to::<bool>(),
            charging: v.at(7).to::<bool>(),
            charging_keep: v.at(8).to::<bool>(),
        }
    }
}

pub trait PackObject: Sized {
    fn pack_object(&self) -> ObjectPack;
    fn pack_objects_iter(objects: impl Iterator<Item = Self>) -> Vec<ObjectPack> {
        objects.map(|o| o.pack_object()).collect()
    }

    fn unpack_object(pack: ObjectPack) -> Self;
}
