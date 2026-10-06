class_name LightTex
## Felles myk, rund lysteksur til PointLight2D (lages i kode, ingen fil trengs).

static var _radial: GradientTexture2D


static func radial() -> GradientTexture2D:
	if _radial == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
		_radial = GradientTexture2D.new()
		_radial.gradient = g
		_radial.width = 256
		_radial.height = 256
		_radial.fill = GradientTexture2D.FILL_RADIAL
		_radial.fill_from = Vector2(0.5, 0.5)
		_radial.fill_to = Vector2(1.0, 0.5)
	return _radial
