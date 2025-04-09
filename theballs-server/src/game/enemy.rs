use uuid::Uuid;

use super::object::{AsObject, Object};

pub struct Enemy {
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
}

impl Enemy {
    pub fn new() -> Self {
        let mut res = Self {
            game_obj: Object::default(),
        };
        res.game_obj.uuid = Uuid::new_v4().as_u128();
        res
    }
}
