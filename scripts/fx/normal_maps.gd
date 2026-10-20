class_name NormalMaps
## Lager normal maps automatisk fra vanlig pikselgrafikk, så 2D-lysene gir relieff
## (fuger, sprekker, kanter på kasser) og glans. Høyden er lysstyrken i bildet;
## gjennomsiktige piksler regnes som "lavt", så figurer får avrundede kanter.

static var _cache: Dictionary = {}


## CanvasTexture med generert normal map. cell > 0: hver rute (tile/ramme) behandles
## for seg, så kantene ikke blør over i naborutene.
static func lit(tex: Texture2D, strength := 2.5, specular := 0.35, shininess := 0.55, cell := Vector2i.ZERO) -> Texture2D:
	if tex == null or tex is CanvasTexture:
		return tex
	var key := "%s|%s|%s|%s|%s" % [tex.get_rid(), strength, specular, shininess, cell]
	if _cache.has(key):
		return _cache[key]
	var img := tex.get_image()
	if img == null:
		return tex
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var ct := CanvasTexture.new()
	ct.diffuse_texture = tex
	ct.normal_texture = ImageTexture.create_from_image(normal_image(img, strength, cell))
	ct.specular_color = Color(specular, specular, specular)
	ct.specular_shininess = shininess
	ct.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cache[key] = ct
	return ct


static func normal_image(img: Image, strength: float, cell := Vector2i.ZERO) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var heights := PackedFloat32Array()
	heights.resize(w * h)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			heights[y * w + x] = c.get_luminance() * c.a
	var out := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var a := img.get_pixel(x, y).a
			if a == 0.0:
				out.set_pixel(x, y, Color(0.5, 0.5, 1.0, 0.0))
				continue
			var x0 := x - 1
			var x1 := x + 1
			var y0 := y - 1
			var y1 := y + 1
			if cell.x > 0:
				# Hold oss innenfor ruta (ellers får kanten høyden fra nabo-tilen).
				var cx := (x / cell.x) * cell.x
				var cy := (y / cell.y) * cell.y
				x0 = maxi(x0, cx)
				x1 = mini(x1, cx + cell.x - 1)
				y0 = maxi(y0, cy)
				y1 = mini(y1, cy + cell.y - 1)
			x0 = clampi(x0, 0, w - 1)
			x1 = clampi(x1, 0, w - 1)
			y0 = clampi(y0, 0, h - 1)
			y1 = clampi(y1, 0, h - 1)
			var dx := heights[y * w + x1] - heights[y * w + x0]
			var dy := heights[y1 * w + x] - heights[y0 * w + x]
			# Godot vil ha OpenGL-retning (grønn = opp), bildet har y nedover.
			var n := Vector3(-dx * strength, dy * strength, 1.0).normalized()
			out.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5, 1.0))
	return out
