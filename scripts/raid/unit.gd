class_name Unit
extends Node3D
## Anything the defenses can hit: drones in the air, soldiers and tanks on the ground.
## The raid drives movement and attacks; this holds the shared health and status state.

signal crashed

var kind := ""
## Drones fly over the fence; ground units walk and need a way in.
var flying := true
var max_health := 100.0
var health := 100.0
var dead := false
var jammed := false
var net_timer := 0.0
## Demo/autoplay only: hits still show effects but never kill the unit.
var invulnerable := false
## Index into the raid's targets, or -1.
var target := -1
var velocity := Vector3.ZERO


func damage(amount: float) -> void:
	if dead:
		return
	health = maxf(1.0 if invulnerable else 0.0, health - amount)
	if health <= 0.0:
		dead = true
		crashed.emit()


func hit_net() -> void:
	Audio.play("net", -4.0)
	net_timer = 2.0
	damage(8.0)
