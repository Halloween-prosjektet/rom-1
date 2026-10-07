extends RefCounted
## Genererer alle plassholder-bilder og -lyder i res://assets/.
## Kjør fra editoren: åpne tools/run_placeholder_generator.gd og velg File > Run.
## NB: overskriver filene i assets/ - ikke kjør etter at ekte grafikk er lagt inn
## (eller sett OVERWRITE = false for kun å lage filer som mangler).

const OVERWRITE := false
const ROOT := "res://assets/"
const OUTLINE := Color8(14, 12, 16)

static var rng := RandomNumberGenerator.new()


static func run(overwrite := OVERWRITE) -> Array[String]:
	rng.seed = 1337
	var written: Array[String] = []
	var images := {
		"tiles/basement.png": _tiles_basement,
		"tiles/school.png": _tiles_school,
		"characters/student.png": func() -> Image: return _character(Color8(22, 20, 28), Color8(232, 200, 175), Color8(40, 52, 88), Color8(50, 58, 80), "student"),
		"characters/teacher.png": func() -> Image: return _character(Color8(150, 150, 150), Color8(225, 190, 160), Color8(105, 75, 50), Color8(45, 42, 40), "teacher"),
		"characters/receptionist.png": func() -> Image: return _character(Color8(110, 35, 30), Color8(235, 205, 180), Color8(90, 60, 110), Color8(40, 35, 45), "receptionist"),
		"props/crate.png": _crate,
		"props/shelf.png": _shelf,
		"props/junk.png": _junk,
		"props/desk.png": _desk,
		"props/counter.png": _counter,
		"props/plant.png": _plant,
		"props/box.png": _box,
		"props/door.png": _door,
		"props/printer_broken.png": _printer_office,
		"props/printer.png": _printer_old,
		"ui/dialogue_box.png": _dialogue_box,
		"ui/arrow.png": _arrow,
		"ui/action.png": _action,
	}
	for rel: String in images:
		var path: String = ROOT + rel
		if not overwrite and FileAccess.file_exists(path):
			continue
		var img: Image = images[rel].call()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
		img.save_png(path)
		written.append(path)

	var sounds := {
		"footstep": _snd_footstep, "push": _snd_push, "bump": _snd_bump, "hum": _snd_hum,
		"ambience_drone": _snd_drone, "flicker": _snd_flicker, "door": _snd_door,
		"door_slam": _snd_slam, "unlock": _snd_unlock, "locked": _snd_locked,
		"printer": _snd_printer, "error": _snd_error, "sting": _snd_sting, "thud": _snd_thud,
		"blip": _snd_blip, "item": _snd_item, "rummage": _snd_rummage, "static": _snd_static,
		"whisper": _snd_whisper,
	}
	for sname: String in sounds:
		var path := ROOT + "audio/" + sname + ".wav"
		if not overwrite and FileAccess.file_exists(path):
			continue
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
		var samples: PackedFloat32Array = sounds[sname].call()
		_save_wav(samples, path)
		written.append(path)
	return written


# ======================================================================
# Hjelpere
# ======================================================================

static func _img(w: int, h: int) -> Image:
	return Image.create_empty(w, h, false, Image.FORMAT_RGBA8)


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		if c.a < 1.0:
			c = img.get_pixel(x, y).blend(c)
		img.set_pixel(x, y, c)


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(img, xx, yy, c)


static func _noise(img: Image, x: int, y: int, w: int, h: int, amount: float) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			var c := img.get_pixel(xx, yy)
			if c.a == 0.0:
				continue
			var n := rng.randf_range(-amount, amount)
			img.set_pixel(xx, yy, Color(clampf(c.r + n, 0, 1), clampf(c.g + n, 0, 1), clampf(c.b + n, 0, 1), c.a))


static func _outline(img: Image, region: Rect2i, col := OUTLINE) -> void:
	var to_set: Array[Vector2i] = []
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			if img.get_pixel(x, y).a > 0.0:
				continue
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n := Vector2i(x, y) + d
				if region.has_point(n) and img.get_pixel(n.x, n.y).a > 0.5 and img.get_pixel(n.x, n.y) != col:
					to_set.append(Vector2i(x, y))
					break
	for p in to_set:
		img.set_pixel(p.x, p.y, col)


static func _shade(c: Color, f: float) -> Color:
	return Color(clampf(c.r * f, 0, 1), clampf(c.g * f, 0, 1), clampf(c.b * f, 0, 1), c.a)


# ======================================================================
# Tiles (8 x 2 ruter à 16 px = 128 x 32) - se assets/README.md for oppsett
# ======================================================================

static func _tiles_basement() -> Image:
	var img := _img(128, 32)
	var floor_c := Color8(56, 58, 60)
	# (0..3,0) betonggulv + varianter
	for i in 4:
		var ox := i * 16
		_rect(img, ox, 0, 16, 16, floor_c)
		_noise(img, ox, 0, 16, 16, 0.025)
		_rect(img, ox, 0, 16, 1, _shade(floor_c, 0.8))
		_rect(img, ox, 0, 1, 16, _shade(floor_c, 0.85))
		if i == 1:  # sprekk
			var x := ox + 3
			for y in range(2, 14):
				_px(img, x, y, _shade(floor_c, 0.55))
				x += rng.randi_range(-1, 1) if x > ox + 2 and x < ox + 13 else 0
		elif i == 2:  # flekk
			for y in range(4, 13):
				for x in range(ox + 4, ox + 13):
					if Vector2(x - ox - 8, (y - 8) * 1.3).length() < 4.5 + rng.randf() * 0.8:
						_px(img, x, y, Color(0.15, 0.2, 0.12, 0.35))
		elif i == 3:  # småstein / skitt
			for k in 6:
				_px(img, ox + rng.randi_range(2, 13), rng.randi_range(2, 13), _shade(floor_c, 0.6))
	# (4,0) våt flekk
	_rect(img, 64, 0, 16, 16, _shade(floor_c, 0.75))
	_noise(img, 64, 0, 16, 16, 0.03)
	for y in 16:
		for x in range(64, 80):
			if Vector2(x - 72, y - 8).length() < 6.0:
				_px(img, x, y, Color(0.1, 0.16, 0.12, 0.45))
	# (5,0) trapp
	for s in 4:
		var c := _shade(Color8(80, 80, 82), 1.15 - s * 0.12)
		_rect(img, 80, s * 4, 16, 4, c)
		_rect(img, 80, s * 4 + 3, 16, 1, _shade(c, 0.6))
	_rect(img, 80, 0, 1, 16, Color8(40, 40, 42))
	_rect(img, 95, 0, 1, 16, Color8(40, 40, 42))
	# (6,0) svart
	_rect(img, 96, 0, 16, 16, Color.BLACK)
	# (7,0) mørkt, fuktig gulv med rist
	_rect(img, 112, 0, 16, 16, _shade(floor_c, 0.7))
	_noise(img, 112, 0, 16, 16, 0.03)
	for k in range(4, 12, 2):
		_rect(img, 116, k, 8, 1, Color8(22, 22, 24))

	# (0,1) toppen av vegg (mørk)
	_rect(img, 0, 16, 16, 16, Color8(18, 18, 21))
	_noise(img, 0, 16, 16, 16, 0.01)
	# (1,1)/(2,1) nedre vegg: betongblokker
	for v in 2:
		var ox := 16 + v * 16
		_block_wall(img, ox, 16, Color8(74, 76, 74), 1.0)
		_rect(img, ox, 29, 16, 3, Color8(30, 30, 32))
		if v == 1:  # rør
			_rect(img, ox + 10, 16, 3, 13, Color8(96, 62, 42))
			_rect(img, ox + 10, 16, 1, 13, Color8(130, 90, 60))
			_rect(img, ox + 9, 22, 5, 2, Color8(70, 45, 30))
	# (3,1)/(4,1) øvre vegg
	for v in 2:
		var ox := 48 + v * 16
		_block_wall(img, ox, 16, Color8(66, 68, 66), 0.75)
		if v == 1:
			_rect(img, ox, 20, 16, 3, Color8(60, 64, 70))
			_rect(img, ox, 20, 16, 1, Color8(95, 100, 108))
	return img


static func _block_wall(img: Image, ox: int, oy: int, base: Color, top_dark: float) -> void:
	for y in 16:
		var f := lerpf(top_dark, 1.0, y / 15.0)
		for x in 16:
			_px(img, ox + x, oy + y, _shade(base, f))
	_noise(img, ox, oy, 16, 16, 0.02)
	var mortar := _shade(base, 0.7)
	for row in 4:
		var y := oy + row * 4 + 3
		_rect(img, ox, y, 16, 1, mortar)
		var shift := 0 if row % 2 == 0 else 4
		for x in range(shift, 16, 8):
			_rect(img, ox + x, y - 3, 1, 3, mortar)


static func _tiles_school() -> Image:
	var img := _img(128, 32)
	var lino := Color8(118, 122, 112)
	for i in 4:
		var ox := i * 16
		var c := lino if i != 3 else _shade(lino, 0.93)
		_rect(img, ox, 0, 16, 16, c)
		_noise(img, ox, 0, 16, 16, 0.015)
		_rect(img, ox, 0, 16, 1, _shade(c, 0.85))
		_rect(img, ox, 0, 1, 16, _shade(c, 0.85))
		_rect(img, ox + 7, 7, 2, 2, _shade(c, 0.8))
		if i == 1:
			for k in 5:
				_px(img, ox + 3 + k * 2, 11 + (k % 2), _shade(c, 0.75))
		elif i == 2:
			_rect(img, ox + 2, 3, 3, 1, _shade(c, 0.8))
	# (4,0) rødt teppe
	var red := Color8(110, 26, 32)
	_rect(img, 64, 0, 16, 16, red)
	_noise(img, 64, 0, 16, 16, 0.03)
	for k in range(0, 16, 4):
		_px(img, 64 + k + 1, 1, Color8(170, 130, 60))
		_px(img, 64 + k + 1, 14, Color8(170, 130, 60))
	# (5,0) trapp
	for s in 4:
		var c := _shade(Color8(120, 110, 95), 1.1 - s * 0.12)
		_rect(img, 80, s * 4, 16, 4, c)
		_rect(img, 80, s * 4 + 3, 16, 1, _shade(c, 0.6))
	_rect(img, 96, 0, 16, 16, Color.BLACK)
	_rect(img, 112, 0, 16, 16, _shade(lino, 0.85))
	_noise(img, 112, 0, 16, 16, 0.02)

	_rect(img, 0, 16, 16, 16, Color8(28, 24, 22))
	# nedre vegg: brunt panel
	for v in 2:
		var ox := 16 + v * 16
		var wood := Color8(92, 62, 42)
		_rect(img, ox, 16, 16, 16, wood)
		_noise(img, ox, 16, 16, 16, 0.02)
		_rect(img, ox, 16, 16, 2, Color8(130, 95, 60))
		_rect(img, ox + 1, 20, 6, 8, _shade(wood, 0.85))
		_rect(img, ox + 9, 20, 6, 8, _shade(wood, 0.85))
		_rect(img, ox, 29, 16, 3, Color8(40, 28, 20))
		if v == 1:  # radiator
			_rect(img, ox + 2, 19, 12, 9, Color8(170, 170, 160))
			for k in range(3, 14, 2):
				_rect(img, ox + k, 19, 1, 9, Color8(130, 130, 122))
	# øvre vegg: tapet med striper
	for v in 2:
		var ox := 48 + v * 16
		var paper := Color8(108, 112, 78)
		_rect(img, ox, 16, 16, 16, paper)
		for x in range(0, 16, 4):
			_rect(img, ox + x, 16, 1, 16, _shade(paper, 0.85))
		_noise(img, ox, 16, 16, 16, 0.015)
		if v == 1:  # oppslagstavle
			_rect(img, ox + 2, 19, 12, 10, Color8(140, 100, 60))
			_rect(img, ox + 4, 21, 4, 5, Color8(220, 220, 210))
			_rect(img, ox + 9, 20, 3, 4, Color8(230, 210, 120))
			_outline(img, Rect2i(ox, 16, 16, 16), Color8(60, 40, 25))
	return img


# ======================================================================
# Personer: 48 x 96 (3 kolonner x 4 rader à 16 x 24)
# Rader: 0 ned, 1 venstre, 2 høyre, 3 opp. Kolonner: steg A, stå, steg B.
# ======================================================================

static func _character(hair: Color, skin: Color, shirt: Color, pants: Color, kind: String) -> Image:
	var img := _img(48, 96)
	for row in 4:
		for col in 3:
			var ox := col * 16
			var oy := row * 24
			var stepping := col - 1  # -1, 0, 1
			_draw_person(img, ox, oy, row, stepping, hair, skin, shirt, pants, kind)
			_outline(img, Rect2i(ox, oy, 16, 24))
	return img


static func _draw_person(img: Image, ox: int, oy: int, dir: int, st: int, hair: Color, skin: Color, shirt: Color, pants: Color, kind: String) -> void:
	var shoes := Color8(30, 26, 26)
	var bob := 1 if st != 0 else 0
	var side := dir == 1 or dir == 2
	var flip := dir == 2
	var y0 := oy + bob

	# Bein
	if side:
		var a := 2 * st
		_rect(img, ox + 6 + a, y0 + 18, 2, 4, pants)
		_rect(img, ox + 8 - a, y0 + 18, 2, 4, _shade(pants, 0.8))
		_rect(img, ox + 6 + a, y0 + 22, 3, 1, shoes)
		_rect(img, ox + 8 - a, y0 + 22, 3, 1, shoes)
	else:
		var l_len := 4 + (1 if st < 0 else 0) - (1 if st > 0 else 0)
		var r_len := 4 + (1 if st > 0 else 0) - (1 if st < 0 else 0)
		_rect(img, ox + 5, y0 + 18, 3, l_len, pants)
		_rect(img, ox + 8, y0 + 18, 3, r_len, pants)
		_rect(img, ox + 5, y0 + 18 + l_len, 3, 1, shoes)
		_rect(img, ox + 8, y0 + 18 + r_len, 3, 1, shoes)
		if kind == "receptionist":
			_rect(img, ox + 4, y0 + 17, 8, 3, pants)

	# Kropp
	var bw := 6 if side else 8
	var bx := ox + (5 if side else 4)
	_rect(img, bx, y0 + 11, bw, 7, shirt)
	_rect(img, bx, y0 + 11, bw, 1, _shade(shirt, 1.2))
	if kind == "student" and dir == 0:  # hettegenser-snorer
		_px(img, ox + 6, y0 + 12, Color8(200, 200, 210))
		_px(img, ox + 9, y0 + 12, Color8(200, 200, 210))
	if kind == "teacher" and dir == 0:  # skjorte under jakke
		_rect(img, ox + 7, y0 + 11, 2, 5, Color8(200, 205, 215))
	# Armer
	if side:
		var arm_x := ox + 7 - st
		_rect(img, arm_x, y0 + 12, 2, 5, _shade(shirt, 0.85))
		_px(img, arm_x, y0 + 17, skin)
	else:
		_rect(img, ox + 3, y0 + 12 + maxi(st, 0), 1, 5, _shade(shirt, 0.85))
		_rect(img, ox + 12, y0 + 12 + maxi(-st, 0), 1, 5, _shade(shirt, 0.85))
		_px(img, ox + 3, y0 + 17 + maxi(st, 0), skin)
		_px(img, ox + 12, y0 + 17 + maxi(-st, 0), skin)

	# Hode
	var hx := ox + (5 if side else 4)
	var hw := 6 if side else 8
	_rect(img, hx, y0 + 2, hw, 9, skin)
	match dir:
		0:  # ned
			_rect(img, hx, y0 + 1, hw, 4, hair)
			_rect(img, hx - 1, y0 + 2, 1, 6, hair)
			_rect(img, hx + hw, y0 + 2, 1, 6, hair)
			_px(img, ox + 6, y0 + 7, Color8(20, 20, 30))
			_px(img, ox + 9, y0 + 7, Color8(20, 20, 30))
			_px(img, ox + 7, y0 + 9, _shade(skin, 0.8))
			_px(img, ox + 8, y0 + 9, _shade(skin, 0.8))
		3:  # opp
			_rect(img, hx - 1, y0 + 1, hw + 2, 10, hair)
		_:  # side
			_rect(img, hx, y0 + 1, hw, 4, hair)
			var back := hx + hw - 2 if not flip else hx
			_rect(img, back, y0 + 2, 2, 7, hair)
			var eye := hx + 1 if not flip else hx + hw - 2
			_px(img, eye, y0 + 7, Color8(20, 20, 30))
	if kind == "teacher" and dir != 3:  # briller
		if dir == 0:
			_rect(img, ox + 5, y0 + 7, 6, 1, Color8(40, 40, 40))
		else:
			var gx := hx if not flip else hx + hw - 3
			_rect(img, gx, y0 + 7, 3, 1, Color8(40, 40, 40))
	if kind == "receptionist":  # langt hår
		if dir == 3:
			_rect(img, hx - 1, y0 + 1, hw + 2, 14, hair)
		elif dir == 0:
			_rect(img, hx - 1, y0 + 2, 1, 11, hair)
			_rect(img, hx + hw, y0 + 2, 1, 11, hair)
		else:
			var back2 := hx + hw - 2 if not flip else hx
			_rect(img, back2, y0 + 2, 2, 11, hair)


# ======================================================================
# Rekvisitter
# ======================================================================

static func _crate() -> Image:
	var img := _img(16, 16)
	var wood := Color8(112, 78, 44)
	_rect(img, 1, 2, 14, 13, wood)
	_rect(img, 1, 2, 14, 4, _shade(wood, 1.25))  # topp
	for y in [8, 11]:
		_rect(img, 1, y, 14, 1, _shade(wood, 0.7))
	_rect(img, 1, 6, 14, 1, _shade(wood, 0.6))
	for i in 8:
		_px(img, 2 + i + i / 2, 13 - i, _shade(wood, 0.75))
	_noise(img, 1, 2, 14, 13, 0.03)
	_outline(img, Rect2i(0, 0, 16, 16))
	return img


static func _shelf() -> Image:
	var img := _img(16, 24)
	var metal := Color8(78, 84, 90)
	_rect(img, 1, 2, 14, 21, Color8(28, 28, 32))
	_rect(img, 1, 2, 1, 21, metal)
	_rect(img, 14, 2, 1, 21, metal)
	var colors := [Color8(120, 40, 40), Color8(45, 60, 110), Color8(150, 130, 90), Color8(60, 90, 60), Color8(110, 110, 100)]
	for s in 3:
		var y := 2 + s * 7
		_rect(img, 1, y + 6, 14, 1, _shade(metal, 1.2))
		var x := 2
		while x < 13:
			var w := rng.randi_range(1, 3)
			var h := rng.randi_range(3, 5)
			var c: Color = colors[rng.randi_range(0, colors.size() - 1)]
			_rect(img, x, y + 6 - h, mini(w, 14 - x), h, _shade(c, rng.randf_range(0.6, 0.9)))
			x += w + (1 if rng.randf() < 0.3 else 0)
	_rect(img, 1, 1, 14, 2, _shade(metal, 1.3))
	_outline(img, Rect2i(0, 0, 16, 24))
	return img


static func _junk() -> Image:
	var img := _img(64, 16)
	# 0: CRT-skjerm
	_rect(img, 2, 3, 12, 11, Color8(170, 160, 135))
	_rect(img, 4, 5, 8, 6, Color8(25, 35, 30))
	_px(img, 5, 6, Color8(70, 90, 80))
	_rect(img, 2, 3, 12, 1, Color8(200, 190, 165))
	_rect(img, 5, 14, 6, 1, Color8(120, 112, 95))
	# 1: PC-kabinett
	_rect(img, 20, 2, 8, 13, Color8(160, 155, 140))
	_rect(img, 21, 4, 6, 2, Color8(80, 80, 80))
	_rect(img, 21, 7, 6, 1, Color8(80, 80, 80))
	_px(img, 26, 12, Color8(60, 150, 60))
	_rect(img, 28, 10, 3, 5, Color8(30, 30, 30))
	# 2: knekt stol
	_rect(img, 35, 3, 7, 6, Color8(40, 50, 90))
	_rect(img, 36, 9, 8, 2, Color8(40, 50, 90))
	_rect(img, 39, 11, 1, 3, Color8(60, 60, 60))
	_rect(img, 37, 14, 6, 1, Color8(60, 60, 60))
	_rect(img, 43, 6, 1, 4, Color8(60, 60, 60))
	# 3: kabler og bokser
	_rect(img, 49, 7, 10, 8, Color8(140, 110, 70))
	_rect(img, 49, 7, 10, 2, Color8(170, 135, 90))
	for i in 12:
		_px(img, 50 + i, 4 + int(2 * sin(i)), Color8(25, 25, 25))
		_px(img, 50 + i, 13 + int(1.5 * cos(i * 1.3)), Color8(35, 35, 35))
	_noise(img, 0, 0, 64, 16, 0.025)
	for f in 4:
		_outline(img, Rect2i(f * 16, 0, 16, 16))
	return img


static func _desk() -> Image:
	var img := _img(16, 16)
	_rect(img, 0, 2, 16, 8, Color8(150, 110, 70))
	_rect(img, 0, 2, 16, 1, Color8(185, 145, 100))
	_rect(img, 0, 10, 16, 2, Color8(100, 70, 45))
	_rect(img, 1, 12, 2, 4, Color8(60, 60, 60))
	_rect(img, 13, 12, 2, 4, Color8(60, 60, 60))
	_noise(img, 0, 2, 16, 10, 0.02)
	return img


static func _counter() -> Image:
	var img := _img(16, 16)
	_rect(img, 0, 1, 16, 4, Color8(170, 130, 90))
	_rect(img, 0, 5, 16, 11, Color8(90, 55, 35))
	_rect(img, 0, 1, 16, 1, Color8(200, 160, 120))
	_rect(img, 2, 7, 12, 7, Color8(75, 45, 28))
	_noise(img, 0, 1, 16, 15, 0.02)
	return img


static func _plant() -> Image:
	var img := _img(16, 24)
	_rect(img, 5, 16, 6, 7, Color8(120, 70, 40))
	_rect(img, 4, 16, 8, 2, Color8(150, 90, 50))
	for i in 40:
		var a := rng.randf() * TAU
		var r := rng.randf() * 6.0
		_px(img, 8 + int(cos(a) * r), 10 + int(sin(a) * r * 1.2), Color8(40, 90 + rng.randi_range(0, 40), 45))
	_outline(img, Rect2i(0, 0, 16, 24))
	return img


static func _box() -> Image:
	var img := _img(32, 16)
	for f in 2:
		var ox := f * 16
		var card := Color8(150, 115, 70)
		_rect(img, ox + 2, 5, 12, 10, card)
		_rect(img, ox + 2, 5, 12, 3, _shade(card, 1.2))
		if f == 0:
			_rect(img, ox + 7, 5, 2, 3, Color8(200, 190, 150))
			_rect(img, ox + 4, 10, 5, 2, Color8(230, 230, 220))  # etikett
		else:
			_rect(img, ox + 3, 6, 10, 3, Color8(30, 22, 15))
			_rect(img, ox + 1, 3, 4, 3, _shade(card, 1.1))
			_rect(img, ox + 11, 3, 4, 3, _shade(card, 1.1))
		_noise(img, ox, 0, 16, 16, 0.02)
		_outline(img, Rect2i(ox, 0, 16, 16))
	return img


static func _door() -> Image:
	var img := _img(32, 32)
	for f in 2:
		var ox := f * 16
		_rect(img, ox, 0, 16, 32, Color8(40, 40, 42))
		if f == 0:
			var metal := Color8(70, 85, 78)
			_rect(img, ox + 2, 2, 12, 30, metal)
			_rect(img, ox + 3, 4, 10, 10, _shade(metal, 0.85))
			_rect(img, ox + 3, 17, 10, 12, _shade(metal, 0.85))
			_rect(img, ox + 11, 17, 2, 2, Color8(180, 170, 110))
			_rect(img, ox + 4, 6, 8, 3, Color8(200, 195, 170))  # skilt
		else:
			_rect(img, ox + 2, 2, 12, 30, Color8(6, 6, 8))
			_rect(img, ox + 2, 2, 2, 30, Color8(70, 85, 78))
		_noise(img, ox, 0, 16, 32, 0.02)
	return img


static func _printer_office() -> Image:
	var img := _img(32, 16)
	for f in 2:
		var ox := f * 16
		_rect(img, ox + 1, 4, 14, 11, Color8(185, 185, 180))
		_rect(img, ox + 1, 4, 14, 3, Color8(215, 215, 210))
		_rect(img, ox + 3, 8, 10, 2, Color8(60, 60, 60))
		_rect(img, ox + 3, 12, 10, 2, Color8(150, 150, 145))
		_rect(img, ox + 10, 5, 3, 1, Color8(50, 90, 50) if f == 0 else Color8(240, 40, 30))
		if f == 1:
			_px(img, ox + 12, 5, Color8(255, 200, 200))
		_noise(img, ox, 0, 16, 16, 0.015)
		_outline(img, Rect2i(ox, 0, 16, 16))
	return img


static func _printer_old() -> Image:
	var img := _img(32, 24)
	for f in 2:
		var ox := f * 16
		_rect(img, ox + 3, 14, 10, 9, Color8(60, 50, 40))  # bord
		_rect(img, ox + 1, 4, 14, 10, Color8(150, 145, 125))
		_rect(img, ox + 1, 4, 14, 3, Color8(175, 170, 150))
		_rect(img, ox + 3, 1, 10, 4, Color8(230, 230, 225))  # papir
		_rect(img, ox + 3, 9, 6, 3, Color8(20, 40, 25) if f == 0 else Color8(60, 10, 10))
		_rect(img, ox + 4, 10, 3, 1, Color8(80, 200, 100) if f == 0 else Color8(255, 60, 40))
		_rect(img, ox + 11, 10, 2, 2, Color8(60, 160, 60) if f == 0 else Color8(255, 40, 30))
		_noise(img, ox, 0, 16, 24, 0.02)
		_outline(img, Rect2i(ox, 0, 16, 24))
	return img


# ======================================================================
# UI
# ======================================================================

static func _dialogue_box() -> Image:
	var img := _img(24, 24)
	_rect(img, 0, 0, 24, 24, Color(0.05, 0.05, 0.07, 0.92))
	for i in 24:
		_px(img, i, 0, Color8(150, 150, 150))
		_px(img, i, 23, Color8(150, 150, 150))
		_px(img, 0, i, Color8(150, 150, 150))
		_px(img, 23, i, Color8(150, 150, 150))
		_px(img, i, 2, Color8(60, 60, 64))
		_px(img, 2, i, Color8(60, 60, 64))
		_px(img, i, 21, Color8(60, 60, 64))
		_px(img, 21, i, Color8(60, 60, 64))
	return img


static func _arrow() -> Image:
	var img := _img(24, 24)
	for y in 24:
		for x in 24:
			if Vector2(x - 11.5, y - 11.5).length() < 11.5:
				_px(img, x, y, Color(0, 0, 0, 0.45))
	for i in 6:
		_rect(img, 12 - i, 7 + i, i * 2, 1, Color(1, 1, 1, 0.75))
	_rect(img, 10, 13, 4, 5, Color(1, 1, 1, 0.75))
	return img


static func _action() -> Image:
	var img := _img(36, 36)
	for y in 36:
		for x in 36:
			var d := Vector2(x - 17.5, y - 17.5).length()
			if d < 17.5:
				_px(img, x, y, Color(0, 0, 0, 0.45))
			if d > 15.5 and d < 17.5:
				_px(img, x, y, Color(1, 1, 1, 0.5))
	_rect(img, 16, 9, 4, 12, Color(1, 1, 1, 0.8))
	_rect(img, 16, 24, 4, 4, Color(1, 1, 1, 0.8))
	return img


# ======================================================================
# Lyd (mono, 22050 Hz)
# ======================================================================

const RATE := 22050


static func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


static func _save_wav(samples: PackedFloat32Array, path: String) -> void:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	wav.save_to_wav(path)


static func _lowpass(b: PackedFloat32Array, k: float) -> PackedFloat32Array:
	var y := 0.0
	for i in b.size():
		y += (b[i] - y) * k
		b[i] = y
	return b


static func _env(i: int, n: int, attack := 0.01, power := 2.0) -> float:
	var t := float(i) / n
	var a := minf(t / maxf(attack, 0.0001), 1.0)
	return a * pow(1.0 - t, power)


static func _snd_footstep() -> PackedFloat32Array:
	var b := _buf(0.09)
	for i in b.size():
		b[i] = rng.randf_range(-1, 1) * _env(i, b.size(), 0.02, 3.0) * 0.6
	return _lowpass(b, 0.25)


static func _snd_push() -> PackedFloat32Array:
	var b := _buf(0.3)
	for i in b.size():
		b[i] = rng.randf_range(-1, 1) * _env(i, b.size(), 0.1, 1.0) * (0.6 + 0.4 * sin(i * 0.01))
	return _lowpass(b, 0.08)


static func _snd_bump() -> PackedFloat32Array:
	var b := _buf(0.12)
	for i in b.size():
		b[i] = sin(TAU * 70.0 * i / RATE) * _env(i, b.size(), 0.01, 3.0) * 0.8
	return b


static func _snd_hum() -> PackedFloat32Array:
	var b := _buf(2.0)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = (sin(TAU * 50.0 * t) * 0.25 + sin(TAU * 100.0 * t) * 0.12 + sin(TAU * 150.0 * t) * 0.05)
	return b


static func _snd_drone() -> PackedFloat32Array:
	var b := _buf(8.0)
	var noise := 0.0
	for i in b.size():
		var t := float(i) / RATE
		noise += (rng.randf_range(-1, 1) - noise) * 0.01
		var swell := 0.75 + 0.25 * sin(TAU * t / 8.0)
		b[i] = (sin(TAU * 55.0 * t) * 0.22 + sin(TAU * 58.25 * t) * 0.18 + sin(TAU * 82.5 * t) * 0.06 + noise * 0.8) * swell
	return b


static func _snd_flicker() -> PackedFloat32Array:
	var b := _buf(0.35)
	for i in b.size():
		var t := float(i) / RATE
		var on := 1.0 if rng.randf() < 0.85 else 0.0
		b[i] = (signf(sin(TAU * 120.0 * t)) * 0.15 + rng.randf_range(-0.2, 0.2)) * on * _env(i, b.size(), 0.01, 0.6)
	return b


static func _snd_door() -> PackedFloat32Array:
	var b := _buf(1.0)
	var phase := 0.0
	for i in b.size():
		var t := float(i) / b.size()
		phase += TAU * (180.0 + 220.0 * t + 30.0 * sin(t * 40.0)) / RATE
		b[i] = (sin(phase) * 0.25 + signf(sin(phase * 0.5)) * 0.08) * sin(PI * t) * (0.6 + 0.4 * rng.randf())
	return _lowpass(b, 0.4)


static func _snd_slam() -> PackedFloat32Array:
	var b := _buf(1.2)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = (rng.randf_range(-1, 1) * 0.7 + sin(TAU * 45.0 * t)) * _env(i, b.size(), 0.002, 4.0)
	return _lowpass(b, 0.12)


static func _snd_unlock() -> PackedFloat32Array:
	var b := _buf(0.4)
	for i in b.size():
		var t := float(i) / RATE
		var click := 0.0
		for c in [0.02, 0.18]:
			if t > c and t < c + 0.03:
				click += rng.randf_range(-1, 1) * (1.0 - (t - c) / 0.03)
		b[i] = click * 0.7
	return b


static func _snd_locked() -> PackedFloat32Array:
	var b := _buf(0.35)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = rng.randf_range(-1, 1) * 0.5 * (1.0 if fmod(t, 0.09) < 0.03 else 0.0) * _env(i, b.size(), 0.01, 1.0)
	return _lowpass(b, 0.3)


static func _snd_printer() -> PackedFloat32Array:
	var b := _buf(1.8)
	for i in b.size():
		var t := float(i) / RATE
		var motor := sin(TAU * 220.0 * t) * 0.08 + sin(TAU * 330.0 * t) * 0.04
		var chunk := rng.randf_range(-1, 1) * 0.3 * (1.0 if fmod(t, 0.25) < 0.08 else 0.15)
		b[i] = (motor + chunk) * minf(1.0, (1.8 - t) * 4.0)
	return _lowpass(b, 0.35)


static func _snd_error() -> PackedFloat32Array:
	var b := _buf(0.9)
	for i in b.size():
		var t := float(i) / RATE
		var f := 880.0 if fmod(t, 0.3) < 0.15 else 622.0
		b[i] = signf(sin(TAU * f * t)) * 0.18 * (1.0 if fmod(t, 0.15) < 0.12 else 0.0)
	return b


static func _snd_sting() -> PackedFloat32Array:
	var b := _buf(2.5)
	for i in b.size():
		var t := float(i) / RATE
		var e := minf(t / 1.2, 1.0) * clampf((2.5 - t) / 0.6, 0.0, 1.0)
		b[i] = (sin(TAU * 220.0 * t) + sin(TAU * 233.1 * t) + sin(TAU * 311.1 * t) * 0.7 + rng.randf_range(-0.3, 0.3)) * 0.12 * e
	return b


static func _snd_thud() -> PackedFloat32Array:
	var b := _buf(0.8)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = (sin(TAU * 60.0 * t) * 0.8 + rng.randf_range(-0.4, 0.4)) * _env(i, b.size(), 0.005, 5.0)
	return _lowpass(b, 0.1)


static func _snd_blip() -> PackedFloat32Array:
	var b := _buf(0.025)
	for i in b.size():
		b[i] = signf(sin(TAU * 600.0 * i / RATE)) * 0.15 * (1.0 - float(i) / b.size())
	return b


static func _snd_item() -> PackedFloat32Array:
	var b := _buf(0.6)
	for i in b.size():
		var t := float(i) / RATE
		var f := 523.0 if t < 0.15 else (659.0 if t < 0.3 else 784.0)
		b[i] = sin(TAU * f * t) * 0.25 * _env(i, b.size(), 0.01, 1.5)
	return b


static func _snd_rummage() -> PackedFloat32Array:
	var b := _buf(0.5)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = rng.randf_range(-1, 1) * 0.4 * absf(sin(t * 40.0)) * _env(i, b.size(), 0.05, 1.0)
	return _lowpass(b, 0.5)


static func _snd_static() -> PackedFloat32Array:
	var b := _buf(0.6)
	for i in b.size():
		b[i] = rng.randf_range(-1, 1) * 0.3 * _env(i, b.size(), 0.01, 0.8)
	return b


static func _snd_whisper() -> PackedFloat32Array:
	var b := _buf(2.0)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = rng.randf_range(-1, 1) * 0.25 * maxf(0.0, sin(t * 9.0) * sin(t * 2.3)) * sin(PI * t / 2.0)
	return _lowpass(b, 0.6)
