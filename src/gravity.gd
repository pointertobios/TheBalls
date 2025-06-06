extends Object

class_name Gravity

var gravity: float
var ballradius: float
var max_charge: float
var charging: bool
var charging_keep: bool
var elas_coeff: float
var y: float
var v: float = 0
var yzoom: float = 1
var kinet_loss: float = 0.8
var velo_max: float = 12
var charge_acc: float = 10
var fast_jump: bool

func _init(
	g: float,
	ballradius_: float,
	max_charge_: float,
	elas_coeff_ = 0.8
) -> void:
	self.gravity = g
	self.ballradius = ballradius_
	self.max_charge = max_charge_
	self.elas_coeff = elas_coeff_
	self.y = ballradius

func set_velocity(vel: float) -> void:
	v = vel

func update(delta: float):
	var tv = v
	v -= gravity * delta
	y += v * delta
	v *= 0.9998
	if y > ballradius and tv * v < 0 and tv > 0:
		fast_jump = false

	if y <= ballradius:
		if not charging:
			var limr = elas_coeff * ballradius
			v += elas_coeff * 0.1
			if y <= limr:
				y = limr
				v = -v
			v *= kinet_loss
		else:
			var limr = (1 - max_charge) * ballradius
			if charging_keep:
				if y <= limr:
					y = limr
				if fast_jump:
					v -= 499 * gravity * delta
					if v < -velo_max * 50:
						v = - velo_max * 50
				else:
					if v < -velo_max:
						v = - velo_max
			elif y <= limr:
				y = limr
				v = -v
				if v > velo_max:
					v = velo_max
			if v > 0 and y > (1 - max_charge) * ballradius:
				charging = false
	elif charging:
		var t = v
		v -= charge_acc
		if t >= -velo_max * 2 and v < -velo_max * 2:
			v = - velo_max * 2

	yzoom = y / ballradius
	if yzoom > 1:
		yzoom = 1

func charge():
	charging_keep = true
	charging = true
	if at_floor():
		fast_jump = true

func release():
	charging_keep = false

func at() -> float:
	return y

func at_floor() -> bool:
	return y <= elas_coeff * ballradius

func touching_floor() -> bool:
	return y <= ballradius

func zoom() -> Vector3:
	var syz = log(sqrt(2 - yzoom)) / log(10) * 0.5 + 1
	return Vector3(syz, yzoom, syz)
