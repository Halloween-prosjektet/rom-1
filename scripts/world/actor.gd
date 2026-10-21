class_name Actor
extends GridEntity
## En person som går i rutenettet (spiller eller NPC).
## Spriteark: 4 rader (ned, venstre, høyre, opp). Antall kolonner = hframes på Sprite.
## Standard (NPC-er): 3 kolonner (steg, stå, steg). Spilleren har flere, se player.tscn.

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

@export_group("Spriteark")
## Kolonnen der figuren står stille.
@export var stand_col := 1
## Gangsyklusen. 2 kolonner = én tegning per steg, 4 = to per steg osv.
@export var walk_cols: Array[int] = [0, 2]
## Kolonne med blunk som vises av og til når figuren står stille (-1 = ingen).
@export var blink_col := -1

var facing := Vector2i.DOWN
var _walk_i := 0
var _blink_in := 0.0

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	super()
	if sheet:
		sprite.texture = sheet
	face(start_facing)
	_blink_in = randf_range(2.0, 4.0)
	set_process(blink_col >= 0)


func _process(delta: float) -> void:
	if is_moving:
		return
	_blink_in -= delta
	if _blink_in > 0.0:
		return
	_blink_in = randf_range(2.5, 5.0)
	_set_frame(blink_col)
	await get_tree().create_timer(0.12).timeout
	if not is_moving and sprite.frame == _frame_index(blink_col):
		_set_frame(stand_col)


func face(dir: Vector2i) -> void:
	if dir == Vector2i.ZERO:
		return
	facing = dir
	_set_frame(stand_col)


func face_towards(target: Vector2i) -> void:
	var d := target - cell
	if absi(d.x) > absi(d.y):
		face(Vector2i(signi(d.x), 0))
	elif d.y != 0:
		face(Vector2i(0, signi(d.y)))


func _set_frame(col: int) -> void:
	sprite.frame = _frame_index(col)


func _frame_index(col: int) -> int:
	return DIR_ROW.get(facing, 0) * sprite.hframes + col


func _next_walk_frame() -> void:
	_set_frame(walk_cols[_walk_i % walk_cols.size()])
	_walk_i += 1


## Prøver å gå én rute. Returnerer false hvis veien er blokkert.
func step(dir: Vector2i) -> bool:
	if is_moving:
		return false
	face(dir)
	var target := cell + dir
	if not map.is_free(target):
		return false
	# Hvert steg viser halve gangsyklusen (minst én tegning).
	var per_step := maxi(1, walk_cols.size() / 2)
	_next_walk_frame()
	if footstep_volume_db > -100.0:
		Sfx.play("footstep", footstep_volume_db, randf_range(0.85, 1.15))
	if per_step == 1:
		get_tree().create_timer(step_time * 0.55).timeout.connect(func() -> void:
			if is_moving: _set_frame(stand_col))
	for j in range(1, per_step):
		get_tree().create_timer(step_time * j / per_step).timeout.connect(func() -> void:
			if is_moving: _next_walk_frame())
	await move_to_cell(target, step_time)
	_set_frame(stand_col)
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
