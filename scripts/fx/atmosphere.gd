class_name Atmosphere
extends Node2D
## Støv i lufta og tåke som driver langs gulvet. Begge påvirkes av 2D-lysene, så de
## synes nesten bare i lyskjeglene og rundt lampene (som "volumetrisk" lys).
## Følger kameraet, men tåka ligger fast i verden (den glir ikke med skjermen).

const FOG_SHADER := """
shader_type canvas_item;
uniform sampler2D noise : repeat_enable, filter_linear;
uniform vec4 tint : source_color = vec4(0.55, 0.6, 0.7, 1.0);
uniform float density = 0.22;
varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 p = world / 220.0;
	float a = texture(noise, p + vec2(TIME * 0.012, TIME * 0.004)).r;
	float b = texture(noise, p * 1.9 - vec2(TIME * 0.02, -TIME * 0.007)).r;
	float f = smoothstep(0.35, 0.95, a * 0.6 + b * 0.5);
	COLOR = vec4(tint.rgb, f * density);
}
"""

## Hvor tett tåka er (0 = ingen).
var density := 0.22

var _fog: Sprite2D
var _dust: CPUParticles2D


func _ready() -> void:
	z_index = 50
	z_as_relative = false

	var noise := FastNoiseLite.new()
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	var ntex := NoiseTexture2D.new()
	ntex.width = 256
	ntex.height = 256
	ntex.seamless = true
	ntex.noise = noise

	_fog = Sprite2D.new()
	var blank := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	blank.fill(Color.WHITE)
	_fog.texture = ImageTexture.create_from_image(blank)
	_fog.scale = Vector2(560, 400) / 4.0
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = FOG_SHADER
	mat.shader = shader
	mat.set_shader_parameter("noise", ntex)
	mat.set_shader_parameter("density", density)
	_fog.material = mat
	add_child(_fog)

	_dust = CPUParticles2D.new()
	_dust.amount = 70
	_dust.lifetime = 9.0
	_dust.preprocess = 9.0
	_dust.local_coords = false
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust.emission_rect_extents = Vector2(240, 150)
	_dust.gravity = Vector2(0, 0.6)
	_dust.direction = Vector2(1, -0.3)
	_dust.spread = 180.0
	_dust.initial_velocity_min = 0.6
	_dust.initial_velocity_max = 2.4
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(0.95, 0.95, 0.9, 0.55), Color(0.95, 0.95, 0.9, 0.55), Color(1, 1, 1, 0)])
	_dust.color_ramp = ramp
	add_child(_dust)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam:
		global_position = cam.get_screen_center_position()
