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

func _init(
	g: float,
	ballradius: float,
	max_charge: float,
	elas_coeff = 0.8
) -> void:
	self.gravity = g
	self.ballradius = ballradius
	self.max_charge = max_charge
	self.elas_coeff = elas_coeff
	self.y = ballradius

func set_velocity(v: float) -> void:
	self.v = v

func update(delta: float):
	v -= gravity * delta
	y += v * delta
	v *= 0.9998

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
				if v < -velo_max:
					v = -velo_max
			elif y <= limr:
				y = limr
				v = -v
				if v > velo_max:
					v = velo_max
			if v > 0 and y > (1 - max_charge) * ballradius:
				charging = false
	elif charging:
		var t = v
		v -= kinet_loss
		if t >= -velo_max and v < -velo_max:
			v = -velo_max

	yzoom = y / ballradius
	if yzoom > 1:
		yzoom = 1

func charge():
	charging_keep = true
	charging = true

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
