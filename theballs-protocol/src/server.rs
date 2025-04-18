use std::time::SystemTime;

use serde::{Deserialize, Serialize};

use crate::{FromTcpStream, ObjectPack, Pack};

#[derive(Debug, Serialize, Deserialize)]
pub struct ServerHead {
    pub state: StateCode,
    pub scene_id: u8,
    pub player_id: u128,
}

#[repr(u8)]
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
pub enum StateCode {
    Success = 0,
    ClientVerifyFailed = 1,
    NoSceneId = 2,
    NoPlayerId = 3,
    PlayerIdNotFoundInScene = 4,

    /// The inner states of client, never send by server.
    Timeout = 5,
    ConnectionFailed = 6,
    TryingToConnect = 7,
    NotStarted = 8,
    Exited = 9,
}

impl ToString for StateCode {
    fn to_string(&self) -> String {
        format!("{:?}", self)
    }
}

#[repr(u8)]
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum ServerPackage {
    None,
    /// For client to calculate the time deviation between client and server.
    ///
    /// Client send `ClientPackage::TimeDeviation` after record `SystemTime::now()`.
    /// Then server return `ServerPackage::TimeDeviation(SystemTime)`.
    /// Using the inner `SystemTime`, client can calculate the time deviation.
    ///
    /// The time deviation value will be used in any Package with `SystemTime`,
    /// to correct the time at client. Server do not deal with any time deviation.
    TimeDeviation(SystemTime),
    InnerError,
    Exit,
    SceneSync {
        objects: Vec<ObjectPack>,
    },
    PlayerList(Vec<(u128, String)>), // (uuid, name)
    PlayerEvent(PlayerEvent),
    EnemyEvent(EnemyEvent),
}

impl ServerPackage {
    pub fn discriminant(&self) -> u8 {
        unsafe { *(self as *const Self as *const u8) }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
/// 定义一个玩家事件枚举
pub enum PlayerEvent {
    Enter {
        uuid: u128,
        name: String,
        position: [i64; 3],
    },
    Exit(u128),
    None,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum EnemyEvent {
    Spawn {
        uuid: u128,
        position: [i64; 3],
        hp: f64,
        color: [f64; 3],
    },
    TookDamage {
        uuid: u128,
        damage: f64,
        source_uuid: u128,
        ulti: bool,
    },
    Die {
        uuid: u128,
    },
    None,

}

impl Default for ServerPackage {
    fn default() -> Self {
        Self::None
    }
}

impl Pack for ServerPackage {}

impl FromTcpStream for ServerPackage {}
