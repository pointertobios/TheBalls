use nalgebra::Vector3;
use rand::Rng;
use uuid::Uuid;

use crate::player::Player;

use super::object::{AsObject, Object};

pub struct Enemy {
    pub speed: f64,
    pub target_radius: f64,
    pub color: [f64; 3],

    pub game_obj: Object,
}

impl AsObject for Enemy {
    fn as_object(&self) -> &Object {
        &self.game_obj
    }
    fn as_object_mut(&mut self) -> &mut Object {
        &mut self.game_obj
    }

    fn is_player(&self) -> bool {
        false
    }

    fn as_player(&self) -> Option<&Player> {
        None
    }

    fn as_player_mut(&mut self) -> Option<&mut Player> {
        None
    }

    fn as_enemy(&self) -> Option<&Enemy> {
        Some(self)
    }

    fn as_enemy_mut(&mut self) -> Option<&mut Enemy> {
        Some(self)
    }
}

impl Enemy {
    pub fn new() -> Self {
        let mut rng = rand::rng();
        let p = rng.random::<u64>() % 101;
        let (speed, hp_max, target_radius) = if p > 90 && p <= 100 {
            (15., 200., 2.)
        } else if p > 80 && p <= 90 {
            (12., 150., 1.5)
        } else if p > 70 && p <= 80 {
            (10., 120., 1.)
        } else if p > 60 && p <= 70 {
            (8., 100., 0.8)
        } else {
            (3., 50., 0.5)
        };
        let mut res = Self {
            speed,
            target_radius,
            color: [
                (rng.random::<u64>() % 255) as f64 / 255.,
                (rng.random::<u64>() % 255) as f64 / 255.,
                (rng.random::<u64>() % 255) as f64 / 255.,
            ],
            game_obj: Object::default(),
        };
        res.game_obj.hp_max = hp_max;
        res.game_obj.hp = hp_max;
        res.game_obj.radius = 0.;
        res.game_obj.uuid = Uuid::new_v4().as_u128();
        res
    }

    pub fn spawning_zoom(&mut self, delta: f64) -> bool {
        if self.game_obj.radius < self.target_radius {
            self.game_obj.radius += delta;
            self.game_obj.position.y = self.game_obj.radius;
            self.game_obj.radius < self.target_radius
        } else {
            self.game_obj.radius = self.target_radius;
            false
        }
    }

    pub fn follow(&mut self, pos: Vector3<f64>, delta: f64) {
        let selfpos = self.game_obj.position;
        let mut direction = (pos - selfpos).normalize();
        direction.y = 0.;
        let vel = direction * self.speed * delta * 50.;
        self.game_obj.velocity = vel;
    }
}
