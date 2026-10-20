class_name LampFx
extends Node2D
## Synlig lampe i taket: selve lysrøret, en myk glorie (bloom), støv som danser i
## lyset og en lysstripe i vått gulv under. Følger lysets styrke, så alt blinker
## sammen når lysrøret flimrer.

var light: PointLight2D
var _base := 1.0
var _tube: Sprite2D
var _halo: Sprite2D
var _streak: Sprite2D
var _dust: CPUParticles2D

static var _tube_tex: Texture2D
static var _streak_tex: Texture2D


static func attach(l: PointLight2D, with_particles: bool) -> LampFx:
	var fx := LampFx.new()
	fx.name = "LampFx"
	fx.light = l
	l.add_child(fx)
	fx._build(with_particles)
	return fx


func _build(with_particles: bool) -> void:
	_base = maxf(light.get("base_energy") if light.get("base_energy") != null else light.energy, 0.01)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED

	# Glorie: stor, svak og additiv. Glorie og lysrør sorteres sammen med figurene
	# (lampa står i Entities), så en figur foran lampa tegnes over den.
	_halo = Sprite2D.new()
	_halo.texture = LightTex.radial()
	_halo.scale = Vector2.ONE * 0.42 * light.texture_scale
	_halo.material = add
	add_child(_halo)

	_tube = Sprite2D.new()
	_tube.texture = _make_tube()
	_tube.material = unshaded
	_tube.position = Vector2(0, -6)
	add_child(_tube)

	# Lysstripe i vått gulv rett under lampa.
	if WetFloor.reflection_material:
		_streak = Sprite2D.new()
		_streak.texture = _make_streak()
		_streak.material = WetFloor.reflection_material
		_streak.z_index = -8
		_streak.z_as_relative = false
		_streak.position = Vector2(0, 4)
		_streak.offset = Vector2(0, 14)
		add_child(_streak)

	if with_particles:
		_dust = CPUParticles2D.new()
		_dust.amount = 18
		_dust.lifetime = 6.0
		_dust.preprocess = 6.0
		_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		_dust.emission_sphere_radius = 30.0
		_dust.gravity = Vector2(0, 1.5)
		_dust.direction = Vector2(0, -1)
		_dust.spread = 180.0
		_dust.initial_velocity_min = 0.5
		_dust.initial_velocity_max = 3.0
		_dust.scale_amount_min = 1.0
		_dust.scale_amount_max = 1.0
		var ramp := Gradient.new()
		ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
		ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 0.97, 0.9, 0.5), Color(1, 0.97, 0.9, 0.5), Color(1, 1, 1, 0)])
		_dust.color_ramp = ramp
		_dust.z_index = 54
		_dust.z_as_relative = false
		add_child(_dust)


func _process(_delta: float) -> void:
	var k := clampf(light.energy / _base, 0.0, 1.4) if light.enabled else 0.0
	var tint := light.color
	_halo.modulate = Color(tint.r, tint.g, tint.b, 0.16 * k)
	_tube.modulate = Color(lerpf(0.25, 1.0, k), lerpf(0.25, 1.0, k), lerpf(0.28, 1.0, k))
	if _streak:
		_streak.modulate = Color(tint.r, tint.g, tint.b, 0.55 * k)
	if _dust:
		_dust.modulate.a = k


static func _make_tube() -> Texture2D:
	if _tube_tex == null:
		var img := Image.create_empty(14, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color8(40, 42, 46))
		for x in range(1, 13):
			img.set_pixel(x, 1, Color8(250, 252, 240))
			img.set_pixel(x, 2, Color8(214, 228, 220))
		_tube_tex = ImageTexture.create_from_image(img)
	return _tube_tex


## Smal, loddrett glød (lysrøret speilet i vann).
static func _make_streak() -> Texture2D:
	if _streak_tex == null:
		var img := Image.create_empty(10, 30, false, Image.FORMAT_RGBA8)
		for y in 30:
			for x in 10:
				var fx := 1.0 - absf(x - 4.5) / 5.0
				var fy := 1.0 - y / 30.0
				img.set_pixel(x, y, Color(1, 1, 1, clampf(fx * fx * fy, 0.0, 1.0)))
		_streak_tex = ImageTexture.create_from_image(img)
	return _streak_tex
