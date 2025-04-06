use serde::{Deserialize, Serialize};

use crate::{server::PlayerEvent, FromTcpStream, ObjectPack, Pack};

#[derive(Default, Clone, Serialize, Deserialize)]
pub struct ClientHead {
    pub name_md5: u128,
    pub version: Version,
    pub scene_id: u8,
    pub player_id: u128,
}

#[derive(Default, Clone, Copy, Serialize, Deserialize)]
pub struct Version(pub u8, pub u8, pub u8);

impl ToString for Version {
    fn to_string(&self) -> String {
        format!("{}.{}.{}", self.0, self.1, self.2)
    }
}

impl From<&'static str> for Version {
    fn from(s: &'static str) -> Self {
        let mut iter = s.split('.');
        let major = iter.next().unwrap().parse().unwrap();
        let minor = iter.next().unwrap().parse().unwrap();
        let patch = iter.next().unwrap().parse().unwrap();
        Self(major, minor, patch)
    }
}

#[repr(u8)]
#[derive(Debug, Serialize, Deserialize, PartialEq)]
pub enum ClientPackage {
    None,
    /// The interval of heartbeat is defined at
    /// [`crate::HEARTBEAT_DURATION`](crate::HEARTBEAT_DURATION)
    ///
    /// This package will never get a reply.
    HeartBeat,
    /// For client to calculate the time deviation between client and server.
    ///
    /// Client send `ClientPackage::TimeDeviation` after record `SystemTime::now()`.
    /// Then server return `ServerPackage::TimeDeviation(SystemTime)`.
    /// Using the inner `SystemTime`, client can calculate the time deviation.
    ///
    /// The time deviation value will be used in any Package with `SystemTime`,
    /// to correct the time at client. Server do not deal with any time deviation.
    TimeDeviation,
    Exit,
    SceneSync {
        object: ObjectPack,
    },
    PlayerEvent(PlayerEvent),
}

impl Default for ClientPackage {
    fn default() -> Self {
        Self::None
    }
}

impl Pack for ClientPackage {}

impl FromTcpStream for ClientPackage {}
