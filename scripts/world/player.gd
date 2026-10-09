class_name Player
extends Actor
## Spilleren. Styres med tastatur/gamepad/berørings-D-pad, eller ved å trykke
## på en rute på skjermen (går dit) / på en ting (går bort og undersøker).

## false under cutscener.
@export var controlled := true
@export var light_scale := 0.95

var _path: Array[Vector2i] = []
var _pending_target := Vector2i.ZERO
var _has_pending := false
var _busy := false

@onready var light: PointLight2D = $Light
@onready var camera: Camera2D = $Camera


func _ready() -> void:
	super()
	add_to_group("player")
	light.texture = LightTex.radial()
	light.texture_scale = light_scale


func _on_setup() -> void:
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = map.map_size.x * LevelMap.TILE
	camera.limit_bottom = map.map_size.y * LevelMap.TILE
	camera.reset_smoothing()


## 0 = standard lysradius.
func set_light_scale(s: float) -> void:
	var target := light_scale if s <= 0.0 else s
	if is_equal_approx(light.texture_scale, target):
		return
	create_tween().tween_property(light, "texture_scale", target, 0.8)


func _can_act() -> bool:
	return controlled and not _busy and GameState.can_move() and map != null


func _physics_process(_delta: float) -> void:
	if is_moving or not _can_act():
		return
	var dir := _input_dir()
	if dir != Vector2i.ZERO:
		_path.clear()
		_has_pending = false
		_try_move(dir)
		return
	if not _path.is_empty():
		var next: Vector2i = _path.pop_front()
		if map.is_free(next):
			step(next - cell)
		else:
			_path.clear()
		return
	if _has_pending:
		_has_pending = false
		if _manhattan(_pending_target, cell) == 1:
			face_towards(_pending_target)
			var occ := map.get_occupant(_pending_target)
			if occ == null or not occ.pushable:
				_interact_cell(_pending_target)


func _input_dir() -> Vector2i:
	if Input.is_action_pressed("move_up"):
		return Vector2i.UP
	if Input.is_action_pressed("move_down"):
		return Vector2i.DOWN
	if Input.is_action_pressed("move_left"):
		return Vector2i.LEFT
	if Input.is_action_pressed("move_right"):
		return Vector2i.RIGHT
	return Vector2i.ZERO


func _try_move(dir: Vector2i) -> void:
	var target := cell + dir
	var occ := map.get_occupant(target)
	if occ and occ.solid and occ.pushable:
		face(dir)
		if occ.try_push(dir):
			step(dir)
		return
	step(dir)


func _unhandled_input(event: InputEvent) -> void:
	if not _can_act():
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if not is_moving:
			interact_front()
	elif event is InputEventScreenTouch and event.pressed:
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.blocks_tap(event.position):
			return
		var world: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * event.position
		_on_tap(map.world_to_cell(world))


func interact_front() -> void:
	_interact_cell(cell + facing)


func _interact_cell(c: Vector2i) -> void:
	var occ := map.get_occupant(c)
	_busy = true
	if occ and occ.can_interact():
		await occ.interact(self)
	elif map.tile_text(c) != "":
		await Dialogue.play(map.tile_text(c))
	_busy = false


func _is_interesting(c: Vector2i) -> bool:
	var occ := map.get_occupant(c)
	if occ and (occ.pushable or occ.can_interact()):
		return true
	return map.tile_text(c) != ""


func _on_tap(target: Vector2i) -> void:
	if target == cell:
		return
	_has_pending = false
	_path.clear()
	if _is_interesting(target):
		if _manhattan(target, cell) == 1:
			var occ := map.get_occupant(target)
			if occ and occ.pushable:
				_try_move(target - cell)
			else:
				face_towards(target)
				_interact_cell(target)
			return
		var best: Array[Vector2i] = []
		for d: Vector2i in DIR_ROW.keys():
			var n := target + d
			if not map.is_free(n):
				continue
			var p := map.find_path(cell, n)
			if not p.is_empty() and (best.is_empty() or p.size() < best.size()):
				best = p
		if not best.is_empty():
			_path = best
			_pending_target = target
			_has_pending = true
	elif map.is_free(target):
		_path = map.find_path(cell, target)


static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
