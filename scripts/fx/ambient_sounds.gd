class_name AmbientSounds
extends Node2D
## Tilfeldige lyder et sted rundt spilleren (drypp, rørbank, knirk, fottrinn langt
## unna ...). Spilles posisjonelt, så de kommer fra venstre/høyre og nær/fjern.

var pool: PackedStringArray = []
var min_delay := 4.0
var max_delay := 11.0

var _timer := 3.0
var _last := ""


func _process(delta: float) -> void:
	if pool.is_empty():
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = randf_range(min_delay, max_delay)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var sound := pool[randi() % pool.size()]
	if sound == _last and pool.size() > 1:
		sound = pool[(pool.find(sound) + 1) % pool.size()]
	_last = sound
	var angle := randf() * TAU
	var dist := randf_range(70.0, 190.0)
	var at := player.global_position + Vector2.from_angle(angle) * dist
	Sfx.play_at(sound, at, randf_range(-14.0, -6.0), randf_range(0.85, 1.12), self)
