class_name RaidRules
extends RefCounted
## Pure game rules, kept free of nodes so they can be unit tested headless.


## 0 stars: crashed or brought nothing home. 1: some loot. 2: the vault. 3: vault and every crate.
static func stars(banked_loot: int, vault_taken: bool, all_crates_taken: bool, survived: bool) -> int:
	if not survived or banked_loot <= 0:
		return 0
	if not vault_taken:
		return 1
	return 3 if all_crates_taken else 2


## Body tilt for a multirotor: nose dips with speed and forward acceleration,
## and the drone banks into turns. Returns Vector2(pitch, roll) in radians.
## Forward is local +Z; yaw is the heading around +Y.
static func bank_angles(accel: Vector3, velocity: Vector3, yaw: float) -> Vector2:
	var forward := Vector3(sin(yaw), 0.0, cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var a_forward := accel.dot(forward)
	var a_right := accel.dot(right)
	var speed := Vector2(velocity.x, velocity.z).length()
	var pitch := clampf(speed * 0.03 + a_forward * 0.05, -0.35, 0.45)
	var roll := clampf(-a_right * 0.06, -0.5, 0.5)
	return Vector2(pitch, roll)
