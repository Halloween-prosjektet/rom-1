class_name WetFloor
extends Sprite2D
## Vått / blankt gulv over hele nivået. Lager en maske (R = vanndammer, G = glans)
## ut fra kartet, tegner dammene med animerte krusninger som lyset glitrer i, og
## gir speilbildene (Reflection) beskjed om hvor gulvet speiler.

## Maska har én piksel per MASK_SCALE spillpiksler.
const MASK_SCALE := 2

const SURFACE_SHADER := """
shader_type canvas_item;
render_mode blend_mix;
uniform sampler2D mask : filter_linear;
uniform float time_scale = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	// Maska har 2 spillpiksler per piksel. Les den myk, men i hele spillpiksler,
	// så kanten på dammen blir glatt og fortsatt "pikselskarp".
	vec2 game_px = floor(UV / TEXTURE_PIXEL_SIZE * 2.0) + 0.5;
	vec4 m = texture(mask, game_px * 0.5 * TEXTURE_PIXEL_SIZE);
	float puddle = smoothstep(0.25, 0.6, m.r);
	if (puddle < 0.02) {
		discard;
	}
	vec2 px = UV / TEXTURE_PIXEL_SIZE;
	float t = TIME * time_scale;
	// Små bølger + ringer fra dråper som treffer på faste steder.
	vec2 grad = vec2(sin(px.y * 0.9 + t * 1.7), cos(px.x * 0.7 - t * 1.3)) * 0.18;
	vec2 cellp = floor(px / 24.0);
	vec2 drop = (cellp + vec2(hash(cellp), hash(cellp + 3.1))) * 24.0;
	float phase = fract(t * 0.35 + hash(cellp + 7.0));
	float d = length(px - drop);
	float ring = sin((d - phase * 26.0) * 1.6) * smoothstep(8.0, 0.0, abs(d - phase * 26.0)) * (1.0 - phase);
	grad += normalize(px - drop + 0.001) * ring * 0.9;
	NORMAL_MAP = normalize(vec3(-grad.x, grad.y, 1.0)) * 0.5 + 0.5;
	// Vannet gjør betongen mørkere og litt blå, med en mørkere våt kant.
	float rim = puddle * (1.0 - smoothstep(0.6, 1.0, m.r));
	COLOR = vec4(0.05, 0.08, 0.11, 0.34 * puddle + 0.18 * rim);
}
"""

## Delt materiale for alle speilbilder (Reflection) i nivået.
const REFLECTION_SHADER := """
shader_type canvas_item;
uniform sampler2D mask : filter_linear;
uniform vec2 mask_world_size = vec2(1.0);
uniform float strength = 1.0;
uniform float fade_px = 26.0;
varying vec2 world;
varying float depth;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	vec2 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
	depth = world.y - origin.y;
}

void fragment() {
	vec4 m = texture(mask, (floor(world) + 0.5) / mask_world_size);
	float wet = max(smoothstep(0.25, 0.6, m.r) * 0.8, m.g * 0.6);
	if (wet < 0.01) {
		discard;
	}
	float wobble = sin(world.y * 0.8 + TIME * 2.2) * m.r * 0.6;
	vec4 src = texture(TEXTURE, UV + vec2(wobble * TEXTURE_PIXEL_SIZE.x, 0.0));
	float fade = clamp(1.0 - depth / fade_px, 0.0, 1.0);
	COLOR = vec4(src.rgb * vec3(0.75, 0.82, 0.95), src.a * wet * fade * strength * COLOR.a);
}
"""

static var reflection_material: ShaderMaterial = null
static var current: WetFloor = null

var _mask: Image
var _map: LevelMap


## gloss: blank gulv overalt (0..1). puddles: omtrent antall dammer per 100 gulvruter.
func setup(map: LevelMap, gloss: float, puddles: float) -> void:
	_map = map
	current = self
	z_index = -9
	z_as_relative = false
	centered = false
	var size := map.map_size * LevelMap.TILE / MASK_SCALE
	_mask = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	_paint_mask(gloss, puddles)
	var tex := ImageTexture.create_from_image(_mask)

	# Selve sprite-en er bare et lerret på størrelse med kartet. Glansen (speilende
	# høylys fra lampene) kommer fra CanvasTexture; krusningene lager shaderen.
	var blank := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	blank.fill(Color.WHITE)
	var flat := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	flat.fill(Color(0.5, 0.5, 1.0))
	var ct := CanvasTexture.new()
	ct.diffuse_texture = ImageTexture.create_from_image(blank)
	ct.normal_texture = ImageTexture.create_from_image(flat)
	ct.specular_color = Color(1, 1, 1)
	ct.specular_shininess = 0.85
	texture = ct
	scale = Vector2(MASK_SCALE, MASK_SCALE)
	var mat := ShaderMaterial.new()
	mat.shader = _shader(SURFACE_SHADER)
	mat.set_shader_parameter("mask", tex)
	material = mat

	reflection_material = ShaderMaterial.new()
	reflection_material.shader = _shader(REFLECTION_SHADER)
	reflection_material.set_shader_parameter("mask", tex)
	reflection_material.set_shader_parameter("mask_world_size", Vector2(map.map_size * LevelMap.TILE))


func _exit_tree() -> void:
	if current == self:
		current = null
		reflection_material = null


## Står man i en vanndam? (brukes til plaskelyd i fottrinn)
func is_wet(cell: Vector2i) -> bool:
	var p := (Vector2(cell) + Vector2(0.5, 0.5)) * LevelMap.TILE / MASK_SCALE
	var x := clampi(int(p.x), 0, _mask.get_width() - 1)
	var y := clampi(int(p.y), 0, _mask.get_height() - 1)
	return _mask.get_pixel(x, y).r > 0.4


func _paint_mask(gloss: float, puddles: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_map.map_file)
	var floor_cells: Array[Vector2i] = []
	var spots: Array[Vector2i] = []
	for y in _map.map_size.y:
		for x in _map.map_size.x:
			var c := Vector2i(x, y)
			var ch := _map.char_at(c)
			if ch == "#" or ch == " ":
				continue
			floor_cells.append(c)
			if ch == ",":
				spots.append(c)
	var extra := int(floor_cells.size() * puddles / 100.0)
	for i in extra:
		spots.append(floor_cells[rng.randi() % floor_cells.size()])

	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.09
	var cells_px := LevelMap.TILE / MASK_SCALE
	# Glans på alt gulv (ikke vegger, trapp eller tomrom).
	for c in floor_cells:
		if _map.char_at(c) == "=":
			continue
		for y in range(c.y * cells_px, (c.y + 1) * cells_px):
			for x in range(c.x * cells_px, (c.x + 1) * cells_px):
				var g := gloss * (0.75 + 0.25 * noise.get_noise_2d(x * 0.5 + 99.0, y * 0.5))
				_mask.set_pixel(x, y, Color(0.0, clampf(g, 0.0, 1.0), 0.0, 1.0))
	if puddles <= 0.0:
		return
	# Dammene males bare innenfor sin egen boks.
	for s in spots:
		var center := (Vector2(s) + Vector2(rng.randf(), rng.randf())) * cells_px
		var radius := rng.randf_range(4.0, 11.0)
		var stretch := Vector2(rng.randf_range(1.0, 1.8), 1.0)
		var reach := Vector2(radius * 1.4, radius * 1.4) * stretch
		for y in range(int(center.y - reach.y), int(center.y + reach.y) + 1):
			for x in range(int(center.x - reach.x), int(center.x + reach.x) + 1):
				if x < 0 or y < 0 or x >= _mask.get_width() or y >= _mask.get_height():
					continue
				var m := _mask.get_pixel(x, y)
				if m.a == 0.0:
					continue  # vegg
				var d := ((Vector2(x, y) - center) / stretch).length()
				var r := radius * (0.8 + 0.5 * noise.get_noise_2d(x, y))
				if d < r:
					m.r = maxf(m.r, clampf((r - d) / 2.5, 0.0, 1.0))
					_mask.set_pixel(x, y, m)


static func _shader(code: String) -> Shader:
	var s := Shader.new()
	s.code = code
	return s
