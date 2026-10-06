class_name Actor
extends GridEntity
## En person som går i rutenettet (spiller eller NPC).
## Spriteark: 3 kolonner (steg, stå, steg) x 4 rader (ned, venstre, høyre, opp).

signal stepped(cell: Vector2i)

const DIR_ROW := {
	Vector2i.DOWN: 0,
	Vector2i.LEFT: 1,
	Vector2i.RIGHT: 2,
	Vector2i.UP: 3,
}

## Bytt figur uten å lage ny scene.
@export var sheet: Texture2D
@export var step_time := 0.22
@export var start_facing := Vector2i.DOWN
## Snur seg mot spilleren når man snakker med den.
@export var face_player_on_talk := true
@export var footstep_volume_db := -999.0

var facing := Vector2i.DOWN
var _parity := false

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	super()
	if sheet:
		sprite.texture = sheet
	face(start_facing)


func face(dir: Vector2i) -> void:
	if dir == Vector2i.ZERO:
		return
	facing = dir
	_set_frame(1)


func face_towards(target: Vector2i) -> void:
	var d := target - cell
	if absi(d.x) > absi(d.y):
		face(Vector2i(signi(d.x), 0))
	elif d.y != 0:
		face(Vector2i(0, signi(d.y)))


func _set_frame(col: int) -> void:
	sprite.frame = DIR_ROW.get(facing, 0) * 3 + col


## Prøver å gå én rute. Returnerer false hvis veien er blokkert.
func step(dir: Vector2i) -> bool:
	if is_moving:
		return false
	face(dir)
	var target := cell + dir
	if not map.is_free(target):
		return false
	_parity = not _parity
	_set_frame(0 if _parity else 2)
	if footstep_volume_db > -100.0:
		Sfx.play("footstep", footstep_volume_db, randf_range(0.85, 1.15))
	get_tree().create_timer(step_time * 0.55).timeout.connect(func() -> void:
		if is_moving: _set_frame(1))
	await move_to_cell(target, step_time)
	_set_frame(1)
	stepped.emit(cell)
	return true


func walk_path(path: Array[Vector2i]) -> bool:
	for c in path:
		var d := c - cell
		if absi(d.x) + absi(d.y) != 1:
			return false
		if not await step(d):
			return false
	return true


## Går til en rute med pathfinding (brukes i cutscener).
func walk_to(target: Vector2i) -> bool:
	if target == cell:
		return true
	var path := map.find_path(cell, target)
	if path.is_empty():
		push_warning("%s: finner ikke vei til %s" % [name, target])
		return false
	return await walk_path(path)


func interact(player: Node) -> void:
	if face_player_on_talk and player is GridEntity:
		face_towards(player.cell)
	await super(player)
