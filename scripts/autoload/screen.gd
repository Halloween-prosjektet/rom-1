extends Node
## Skjermeffekter: fade, scenebytte, risting, glitch, vignett og stedsnavn.
## Setter også felles UI-tema (font hentes fra assets/fonts/main.ttf hvis den finnes).

const FONT_PATHS := ["res://assets/fonts/main.ttf", "res://assets/fonts/main.otf"]

const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform float strength = 0.65;
uniform float grain = 0.035;
float rand(vec2 co) { return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 uv = UV - 0.5;
	float v = smoothstep(0.3, 0.8, length(uv * vec2(1.25, 1.0)));
	float n = rand(floor(UV * vec2(400.0, 240.0)) + fract(TIME * 7.13) * 100.0);
	COLOR = vec4(vec3(n * 0.35) * (1.0 - v), clamp(v * strength + grain * n, 0.0, 1.0));
}
"""

const GLITCH_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float amount = 0.0;
float rand(vec2 co) { return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 uv = SCREEN_UV;
	float t = floor(TIME * 18.0);
	float band = floor(uv.y * 30.0);
	if (rand(vec2(band, t)) < amount * 0.6) {
		uv.x += (rand(vec2(t, band)) - 0.5) * 0.12 * amount;
	}
	float split = 0.008 * amount;
	vec3 col;
	col.r = texture(screen_tex, uv + vec2(split, 0.0)).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - vec2(split, 0.0)).b;
	float scan = 0.85 + 0.15 * step(0.5, fract(SCREEN_UV.y * 120.0));
	COLOR = vec4(col * mix(1.0, scan, amount), 1.0);
}
"""

var theme := Theme.new()

var _effects_layer: CanvasLayer
var _vignette: ColorRect
var _glitch: ColorRect
var _fade_layer: CanvasLayer
var _fade: ColorRect
var _location: Label
var _location_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_theme()

	_effects_layer = CanvasLayer.new()
	_effects_layer.layer = 70
	add_child(_effects_layer)
	_vignette = _full_rect(_effects_layer, VIGNETTE_SHADER)
	_vignette.visible = Config.get_value("display", "screen_effects", true)

	var glitch_layer := CanvasLayer.new()
	glitch_layer.layer = 90
	add_child(glitch_layer)
	_glitch = _full_rect(glitch_layer, GLITCH_SHADER)
	_glitch.visible = false

	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	add_child(_fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	_fade_layer.add_child(_fade)

	_location = Label.new()
	_location.theme = theme
	_location.add_theme_font_size_override("font_size", 9)
	_location.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	_location.add_theme_color_override("font_outline_color", Color.BLACK)
	_location.add_theme_constant_override("outline_size", 3)
	_location.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_location.position = Vector2(8, 240 - 34)
	_location.modulate.a = 0.0
	_fade_layer.add_child(_location)


func _setup_theme() -> void:
	theme.default_font_size = 10
	for path: String in FONT_PATHS:
		if ResourceLoader.exists(path):
			theme.default_font = load(path)
			break
	get_tree().root.theme = theme
	RenderingServer.set_default_clear_color(Color.BLACK)


func _full_rect(parent: Node, shader_code: String) -> ColorRect:
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = shader_code
	var mat := ShaderMaterial.new()
	mat.shader = shader
	rect.material = mat
	parent.add_child(rect)
	return rect


func fade_out(duration := 0.6) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, duration)
	await tw.finished


func fade_in(duration := 0.6) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 0.0, duration)
	await tw.finished


func change_scene(path: String, fade := 0.6) -> void:
	GameState.lock_input()
	await fade_out(fade)
	Sfx.stop_all_loops()
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	GameState.unlock_input()
	await fade_in(fade)


func shake(strength := 3.0, duration := 0.4) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var tw := create_tween()
	var steps := int(duration / 0.04)
	for i in steps:
		var falloff := 1.0 - float(i) / steps
		tw.tween_property(cam, "offset", Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * falloff, 0.04)
	tw.tween_property(cam, "offset", Vector2.ZERO, 0.04)
	await tw.finished


func glitch(duration := 0.6, amount := 1.0) -> void:
	_glitch.visible = true
	var mat: ShaderMaterial = _glitch.material
	var tw := create_tween()
	mat.set_shader_parameter("amount", amount)
	tw.tween_interval(duration * 0.7)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("amount", v), amount, 0.0, duration * 0.3)
	await tw.finished
	_glitch.visible = false


func show_location(text: String, hold := 3.0) -> void:
	_location.text = text
	if _location_tween:
		_location_tween.kill()
	_location_tween = create_tween()
	_location_tween.tween_property(_location, "modulate:a", 1.0, 0.8)
	_location_tween.tween_interval(hold)
	_location_tween.tween_property(_location, "modulate:a", 0.0, 1.2)
