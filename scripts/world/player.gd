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
## Lommelykt (lyskjegle i gåretningen). Lages av enable_torch().
var torch: PointLight2D
var _torch_scale := 1.0
var _flicker_timer := 6.0
var _time := 0.0

static var _cone_tex: Texture2D

@onready var light: PointLight2D = $Light
@onready var camera: Camera2D = $Camera


func _ready() -> void:
	super()
	add_to_group("player")
	light.texture = LightTex.radial()
	light.texture_scale = light_scale
	Gfx.setup_player_light(light, 48.0, false)


func _on_setup() -> void:
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = map.map_size.x * LevelMap.TILE
	camera.limit_bottom = map.map_size.y * LevelMap.TILE
	camera.reset_smoothing()


func enable_torch() -> void:
	if torch:
		return
	torch = PointLight2D.new()
	torch.name = "Torch"
	torch.texture = _cone()
	torch.color = Color(1.0, 0.95, 0.85)
	torch.energy = 1.45
	torch.texture_scale = 0.8
	_torch_scale = torch.texture_scale
	torch.position = Vector2(0, -6)
	torch.rotation = Vector2(facing).angle()
	Gfx.setup_player_light(torch, 40.0, true)
	# Lommelykta lyser opp verden, ikke spilleren som holder den.
	sprite.light_mask = Gfx.LIT_PLAYER
	torch.range_item_cull_mask = Gfx.LIT_WORLD
	light.range_item_cull_mask = Gfx.LIT_WORLD | Gfx.LIT_PLAYER
	add_child(torch)
	# Nærlyset rundt spilleren dempes litt, så kjeglen synes.
	light.energy = 0.8


func _process(delta: float) -> void:
	_time += delta
	# Litt "håndholdt" kamera.
	camera.position = Vector2(sin(_time * 0.63) * 0.9, sin(_time * 0.81 + 1.3) * 0.7)
	if torch == null:
		return
	torch.rotation = lerp_angle(torch.rotation, Vector2(facing).angle(), minf(delta * 12.0, 1.0))
	# Av og til flimrer lommelykta (dårlig kontakt).
	_flicker_timer -= delta
	if _flicker_timer <= 0.0:
		_flicker_timer = randf_range(9.0, 22.0)
		var tw := create_tween()
		for i in randi_range(2, 4):
			tw.tween_property(torch, "energy", randf_range(0.1, 0.5), 0.04)
			tw.tween_property(torch, "energy", 1.45, 0.06)


## 0 = standard lysradius.
func set_light_scale(s: float) -> void:
	var target := light_scale if s <= 0.0 else s
	if is_equal_approx(light.texture_scale, target):
		return
	create_tween().tween_property(light, "texture_scale", target, 0.8)
	if torch:
		var k := target / light_scale
		create_tween().tween_property(torch, "texture_scale", _torch_scale * clampf(k * 1.4, 0.5, 1.0), 0.8)


## Lyskjegle som peker mot +x fra midten av teksturen (så lyset roterer rundt spilleren).
static func _cone() -> Texture2D:
	if _cone_tex:
		return _cone_tex
	var size := 256
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var half := deg_to_rad(26.0)
	for y in size:
		for x in size:
			var v := Vector2(x - size / 2.0, y - size / 2.0)
			var r := v.length() / (size / 2.0)
			var a := 0.0
			if v.x > 0.0 and r < 1.0:
				var ang := absf(v.angle())
				var edge := clampf((half - ang) / (half * 0.45), 0.0, 1.0)
				var hot := 1.0 + 0.6 * clampf(1.0 - ang / (half * 0.35), 0.0, 1.0)
				a = edge * pow(1.0 - r, 1.4) * hot
			# litt lys rundt hånda også
			a = maxf(a, clampf(1.0 - r * 9.0, 0.0, 1.0) * 0.12)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	_cone_tex = ImageTexture.create_from_image(img)
	return _cone_tex


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
