use nalgebra::Vector3;
use theballs_protocol::{ObjectPack, PackObject};

const G_ACC: f64 = 9.8;

pub struct Object {
    pub uuid: u128,
    pub radius: f64,
    pub position: Vector3<f64>,
    pub velocity: Vector3<f64>,
    pub acceleration: Vector3<f64>,

    max_charge: f64,

    elas_coeff: f64,
    kinet_loss: f64,
    velo_max: f64,
    charge_acc: f64,

    fast_falling: bool,
    charging: bool,
    charging_keep: bool,
}

impl Object {
    pub fn new(uuid: u128) -> Self {
        Self {
            uuid,
            ..Default::default()
        }
    }

    pub async fn gravity(&mut self, delta: f64) {
        let tv = self.velocity.y;
        self.velocity.y -= G_ACC * delta;
        self.position.y += self.velocity.y * delta;
        self.velocity.y *= 0.9998;

        if self.position.y > self.radius && tv * self.velocity.y < 0. && tv > 0. {
            self.fast_falling = false;
        }

        if self.position.y <= self.radius {
            if !self.charging {
                let limr = self.elas_coeff * self.radius;
                self.velocity.y += self.elas_coeff * 0.1;
                if self.position.y <= limr {
                    self.position.y = limr;
                    self.velocity.y *= -1.;
                }
                self.velocity.y *= self.kinet_loss;
            } else {
                let limr = (1. - self.max_charge) * self.radius;
                if self.charging_keep {
                    if self.position.y <= limr {
                        self.position.y = limr;
                    }
                    if self.fast_falling {
                        self.velocity.y -= 499. * G_ACC * delta;
                        if self.velocity.y < -self.velo_max * 50. {
                            self.velocity.y = -self.velo_max * 50.;
                        }
                    } else if self.velocity.y < -self.velo_max {
                        self.velocity.y = -self.velo_max;
                    }
                } else if self.position.y <= limr {
                    self.position.y = limr;
                    self.velocity.y *= -1.;
                    if self.velocity.y > self.velo_max {
                        self.velocity.y = self.velo_max;
                    }
                }
                if self.velocity.y > 0. && self.position.y > limr {
                    self.charging = false;
                }
            }
        } else if self.charging {
            let t = self.velocity.y;
            self.velocity.y -= self.charge_acc;
            if t >= -self.velo_max * 2. && self.velocity.y < -self.velo_max * 2. {
                self.velocity.y = -self.velo_max * 2.;
            }
        }
    }
}

impl PackObject for Object {
    fn pack_object(&self) -> ObjectPack {
        ObjectPack {
            uuid: self.uuid,
            radius: self.radius,
            position: [self.position.x, self.position.y, self.position.z],
            velocity: [self.velocity.x, self.velocity.y, self.velocity.z],
            acceleration: [
                self.acceleration.x,
                self.acceleration.y,
                self.acceleration.z,
            ],
            fast_falling: self.fast_falling,
            charging: self.charging,
            charging_keep: self.charging_keep,
        }
    }

    fn unpack_object(pack: ObjectPack) -> Self {
        Self {
            uuid: pack.uuid,
            radius: pack.radius,
            position: Vector3::new(pack.position[0], pack.position[1], pack.position[2]),
            velocity: Vector3::new(pack.velocity[0], pack.velocity[1], pack.velocity[2]),
            acceleration: Vector3::new(
                pack.acceleration[0],
                pack.acceleration[1],
                pack.acceleration[2],
            ),
            fast_falling: pack.fast_falling,
            charging: pack.charging,
            charging_keep: pack.charging_keep,
            ..Default::default()
        }
    }
}

impl Default for Object {
    fn default() -> Self {
        Self {
            uuid: 0,
            radius: 0.5,
            position: Vector3::new(0., 0.5, 0.),
            velocity: Vector3::new(0., 0., 0.),
            acceleration: Vector3::new(0., 0., 0.),
            max_charge: 0.5,
            elas_coeff: 0.8,
            kinet_loss: 0.8,
            velo_max: 12.,
            charge_acc: 10.,
            fast_falling: false,
            charging: false,
            charging_keep: false,
        }
    }
}

impl Clone for Object {
    fn clone(&self) -> Self {
        Self {
            uuid: self.uuid,
            radius: self.radius,
            position: self.position.clone(),
            velocity: self.velocity.clone(),
            acceleration: self.acceleration.clone(),
            max_charge: self.max_charge,
            elas_coeff: self.elas_coeff,
            kinet_loss: self.kinet_loss,
            velo_max: self.velo_max,
            charge_acc: self.charge_acc,
            fast_falling: self.fast_falling,
            charging: self.charging,
            charging_keep: self.charging_keep,
        }
    }
}

pub trait AsObject: Send + Sync {
    fn as_object(&self) -> &Object;
    fn as_object_mut(&mut self) -> &mut Object;

    fn is_player(&self) -> bool;
}
