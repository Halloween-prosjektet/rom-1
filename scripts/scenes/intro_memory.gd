class_name IntroMemory
extends CanvasLayer
## Minnet i introen: et panel glir inn fra høyre over halve skjermen og viser
## eleven ved en skriver i går, som feiler. Tegnes i sepia i sin egen SubViewport,
## i 2x størrelse som resten av introen mens kameraet er zoomet inn.
##
##   var memory := IntroMemory.new()
##   add_child(memory)
##   await memory.slide_in()
##   await memory.play()
##   await memory.slide_out()

const SCHOOL_TILES := preload("res://assets/tiles/school.png")
const PRINTER := preload("res://assets/props/printer_broken.png")
const STUDENT := preload("res://assets/characters/student.png")

const PANEL_W := 200.0
const SLIDE_TIME := 0.7
const T := LevelMap.TILE
## Kolonnene og radene i student.png (se player.tscn).
const STUDENT_COLS := 6
const ROW_LEFT := 1
const ROW_UP := 3
const WALK_COLS := [2, 3, 4, 5]
## Eleven står ved siden av skriveren og ser mot den (står man rett foran, skjuler
## figuren skriveren).
const PRINTER_POS := Vector2(3 * T + T / 2.0, 3 * T + T / 2.0)
const STUDENT_POS := PRINTER_POS + Vector2(18, 6)

const SEPIA_SHADER := """
shader_type canvas_item;
uniform float amount : hint_range(0.0, 1.0) = 0.85;
uniform float flash = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 sepia = vec3(g * 1.08, g * 0.9, g * 0.68);
	vec3 col = mix(c.rgb, sepia, amount);
	// mørkere kanter, som et gammelt fotografi
	vec2 d = UV - 0.5;
	col *= 1.0 - dot(d, d) * 1.2;
	COLOR = vec4(col + flash, c.a);
}
"""

var _panel: Control
var _container: SubViewportContainer
var _printer: Sprite2D
var _student: Sprite2D


func _init() -> void:
	layer = 60
	_build()


func slide_in() -> void:
	Sfx.play("whisper", -14.0)
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel, "position:x", 400.0 - PANEL_W, SLIDE_TIME)
	await tw.finished


func slide_out() -> void:
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_panel, "position:x", 400.0 + 4.0, SLIDE_TIME)
	await tw.finished


## Eleven går bort til skriveren, den feiler, og så skjer det noe rart.
func play() -> void:
	await _walk_to_printer()
	await Dialogue.play("intro.memory1")

	_printer.frame = 1
	Sfx.play("error", -8.0)
	await _wait(0.4)
	await Dialogue.play("intro.memory2")

	# Prøver igjen: skriveren blinker, støyer og sier noe den ikke burde.
	_student.position.x -= 2
	Sfx.play("bump", -10.0)
	await _wait(0.15)
	_student.position.x += 2
	for i in 6:
		_printer.frame = i % 2
		await _wait(0.12)
	Sfx.play("static", -4.0)
	_flash()
	await Screen.glitch(0.5, 0.6)
	_printer.frame = 1
	await Dialogue.play("intro.memory3")
	_printer.frame = 0
	Sfx.play("thud", -12.0)
	await _wait(0.5)


## Går opp nedenfra og snur seg mot skriveren.
func _walk_to_printer() -> void:
	_student.position = STUDENT_POS + Vector2(0, T * 4)
	for s in 4:
		for col: int in [WALK_COLS[(s * 2) % 4], WALK_COLS[(s * 2 + 1) % 4]]:
			_student.frame = ROW_UP * STUDENT_COLS + col
			var tw := create_tween()
			tw.tween_property(_student, "position:y", _student.position.y - T / 2.0, 0.11)
			await tw.finished
		Sfx.play("footstep", -20.0, randf_range(0.85, 1.15))
	_student.position = STUDENT_POS
	_student.frame = ROW_UP * STUDENT_COLS
	await _wait(0.25)
	_student.frame = ROW_LEFT * STUDENT_COLS
	await _wait(0.3)


func _flash() -> void:
	var mat: ShaderMaterial = _container.material
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("flash", v), 0.5, 0.0, 0.4)


# --- Oppbygging ----------------------------------------------------------------

func _build() -> void:
	_panel = Control.new()
	_panel.position = Vector2(400.0 + 4.0, 0)
	_panel.size = Vector2(PANEL_W, 240)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	# Skillelinje mellom nå og minnet.
	var edge := ColorRect.new()
	edge.color = Color.BLACK
	edge.position = Vector2(-4, 0)
	edge.size = Vector2(4, 240)
	_panel.add_child(edge)
	var light := ColorRect.new()
	light.color = Color(0.95, 0.88, 0.7)
	light.position = Vector2(-2, 0)
	light.size = Vector2(1, 240)
	_panel.add_child(light)

	_container = SubViewportContainer.new()
	_container.stretch = true
	_container.stretch_shrink = 2
	_container.size = Vector2(PANEL_W, 240)
	_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SEPIA_SHADER
	mat.shader = shader
	_container.material = mat
	_panel.add_child(_container)

	var vp := SubViewport.new()
	vp.transparent_bg = false
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_container.add_child(vp)
	_build_world(vp)

	var label := Label.new()
	label.text = Text.t("memory_label")
	label.position = Vector2(8, 6)
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.7))
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	_panel.add_child(label)


## Et hjørne av skolen: vegg øverst, gulv, skriveren mot veggen, eleven foran.
func _build_world(vp: SubViewport) -> void:
	var world := Node2D.new()
	world.position = Vector2(-16, -8)  # skriveren og eleven midt i bildet
	vp.add_child(world)

	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	var src := TileSetAtlasSource.new()
	src.texture = SCHOOL_TILES
	src.texture_region_size = Vector2i(T, T)
	for y in LevelMap.ATLAS_SIZE.y:
		for x in LevelMap.ATLAS_SIZE.x:
			src.create_tile(Vector2i(x, y))
	ts.add_source(src, 0)
	var tiles := TileMapLayer.new()
	tiles.tile_set = ts
	world.add_child(tiles)
	for x in 8:
		tiles.set_cell(Vector2i(x, 0), 0, LevelMap.T_WALL_TOP)
		tiles.set_cell(Vector2i(x, 1), 0, LevelMap.T_FACE_HIGH[1 if x % 3 == 1 else 0])
		tiles.set_cell(Vector2i(x, 2), 0, LevelMap.T_FACE_LOW[1 if x % 4 == 2 else 0])
		for y in range(3, 9):
			var h := (x * 7 + y * 13) % 10
			tiles.set_cell(Vector2i(x, y), 0, LevelMap.T_FLOOR[0] if h < 7 else LevelMap.T_FLOOR[1 + h % 3])

	_printer = Sprite2D.new()
	_printer.texture = PRINTER
	_printer.hframes = 2
	_printer.position = PRINTER_POS
	world.add_child(_printer)

	_student = Sprite2D.new()
	_student.texture = STUDENT
	_student.hframes = STUDENT_COLS
	_student.vframes = 4
	_student.offset = Vector2(0, -10)
	_student.frame = ROW_UP * STUDENT_COLS
	_student.position = STUDENT_POS + Vector2(0, T * 4)
	world.add_child(_student)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
