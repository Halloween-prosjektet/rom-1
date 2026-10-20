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
		# characters/student.png er ekte grafikk nå – lages av tools/student_sprite.gd.
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
		# Tittelskjermen (panorama). Har egne frø, så rekkefølgen over påvirkes ikke.
		"ui/title_sky.png": _pano_sky,
		"ui/title_wall.png": _pano_wall,
		"ui/title_front.png": _pano_front,
		"ui/title_shadow.png": _pano_shadow,
		"ui/title_figure.png": _pano_figure,
		"ui/title_fog.png": _pano_fog,
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
		# Stemningslyder (spilles tilfeldig rundt spilleren, se scripts/fx/ambient_sounds.gd)
		"drip": _snd_drip, "pipe_knock": _snd_pipe_knock, "creak": _snd_creak,
		"distant_steps": _snd_distant_steps, "rat": _snd_rat, "vent": _snd_vent,
		"footstep_wet": _snd_footstep_wet,
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

## Deterministisk "tilfeldig" tall 0..1 for et punkt (samme hver gang).
static func _h(x: int, y: int, s: int) -> float:
	var n := (x * 374761393 + y * 668265263 + s * 2246822519) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float(n & 0xffff) / 65535.0


## Myk verdistøy 0..1 (bilineær mellom gitterpunkter).
static func _vn(x: float, y: float, s: int) -> float:
	var ix := floori(x)
	var iy := floori(y)
	var fx := x - ix
	var fy := y - iy
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := lerpf(_h(ix, iy, s), _h(ix + 1, iy, s), fx)
	var b := lerpf(_h(ix, iy + 1, s), _h(ix + 1, iy + 1, s), fx)
	return lerpf(a, b, fy)


static func _fbm(x: float, y: float, s: int) -> float:
	return _vn(x, y, s) * 0.55 + _vn(x * 2.1, y * 2.1, s + 7) * 0.3 + _vn(x * 4.3, y * 4.3, s + 13) * 0.15


## Betongplate med fas i kantene, tilslag (prikker) og flekkete overflate.
static func _concrete(img: Image, ox: int, oy: int, base: Color, s: int) -> void:
	for y in 16:
		for x in 16:
			var f := 0.86 + 0.22 * _fbm(x / 6.0 + ox, y / 6.0, s)
			var h := _h(x + ox, y, s + 99)
			if h < 0.05:
				f += 0.1
			elif h < 0.09:
				f -= 0.09
			var c := _shade(base, f)
			# Fasen: mørk fuge oppe/venstre, lys kant nede/høyre.
			if y == 0 or x == 0:
				c = _shade(base, 0.52)
			elif y == 1 or x == 1:
				c = _shade(c, 0.88)
			elif y == 15 or x == 15:
				c = _shade(c, 1.1)
			img.set_pixel(ox + x, oy + y, c)


## Sprekk (tilfeldig gange) med lys kant ved siden av, så den ser dyp ut i lyset.
static func _crack(img: Image, ox: int, oy: int, s: int, base: Color) -> void:
	var x := ox + 4 + int(_h(1, 2, s) * 6)
	for y in range(oy + 2, oy + 15):
		_px(img, x, y, _shade(base, 0.38))
		_px(img, x + 1, y, _shade(base, 1.18))
		if _h(x, y, s) < 0.35:
			x += 1 if _h(y, x, s) < 0.5 else -1
			x = clampi(x, ox + 2, ox + 12)
			_px(img, x, y, _shade(base, 0.45))
	# en liten gren
	var bx := ox + 9
	for y in range(oy + 6, oy + 10):
		_px(img, bx, y, _shade(base, 0.5))
		bx += 1


static func _blob(img: Image, ox: int, oy: int, cx: float, cy: float, r: float, s: int, col: Color, rim := Color(0, 0, 0, 0)) -> void:
	for y in 16:
		for x in 16:
			var d := Vector2(x - cx, (y - cy) * 1.25).length()
			var edge := r * (0.75 + 0.45 * _vn(x / 3.0, y / 3.0, s))
			if d < edge:
				_px(img, ox + x, oy + y, col)
			elif rim.a > 0.0 and d < edge + 1.0:
				_px(img, ox + x, oy + y, rim)


static func _tiles_basement() -> Image:
	var img := _img(128, 32)
	var floor_c := Color8(62, 63, 64)
	# (0..3,0) betonggulv + varianter
	for i in 4:
		var ox := i * 16
		_concrete(img, ox, 0, floor_c, 11 + i)
		match i:
			1:
				_crack(img, ox, 0, 5, floor_c)
			2:  # oljeflekk med regnbuekant
				_blob(img, ox, 0, 8.0, 8.5, 5.0, 21, Color(0.08, 0.08, 0.1, 0.5), Color(0.35, 0.25, 0.45, 0.25))
				_blob(img, ox, 0, 7.0, 8.0, 2.5, 22, Color(0.04, 0.04, 0.06, 0.4))
			3:  # grus, papirbit og en sigarettstump
				for k in 9:
					var px := ox + 2 + int(_h(k, 1, 31) * 12)
					var py := 2 + int(_h(k, 2, 31) * 12)
					_px(img, px, py, _shade(floor_c, 0.5 if k % 2 else 1.35))
				_rect(img, ox + 9, 4, 3, 2, Color8(150, 146, 132))
				_px(img, ox + 11, 5, Color8(110, 106, 96))
				_rect(img, ox + 3, 11, 3, 1, Color8(200, 196, 180))
				_px(img, ox + 6, 11, Color8(170, 110, 60))
	# (4,0) fuktig flekk: mørkere, blålig, med glans
	_concrete(img, 64, 0, _shade(floor_c, 0.82), 41)
	_blob(img, 64, 0, 8.0, 8.0, 6.0, 42, Color(0.05, 0.1, 0.14, 0.5), Color(0.1, 0.14, 0.16, 0.25))
	for p: Vector2i in [Vector2i(70, 6), Vector2i(71, 6), Vector2i(74, 10)]:
		_px(img, p.x, p.y, Color(0.75, 0.82, 0.9, 0.55))
	# (5,0) trapp med metallkant på hvert trinn
	for st in 4:
		var y := st * 4
		var tread := _shade(Color8(84, 84, 86), 1.18 - st * 0.13)
		_rect(img, 80, y, 16, 3, tread)
		_noise(img, 80, y, 16, 3, 0.02)
		_rect(img, 80, y, 16, 1, Color8(150, 152, 158))
		_rect(img, 80, y + 3, 16, 1, _shade(tread, 0.45))
	_rect(img, 80, 0, 2, 16, Color8(34, 34, 37))
	_rect(img, 94, 0, 2, 16, Color8(34, 34, 37))
	# (6,0) svart
	_rect(img, 96, 0, 16, 16, Color.BLACK)
	# (7,0) sluk med rist og rustring
	_concrete(img, 112, 0, _shade(floor_c, 0.8), 71)
	_rect(img, 114, 2, 12, 12, Color8(92, 58, 38))
	_rect(img, 115, 3, 10, 10, Color8(48, 46, 46))
	for k in range(3, 13, 2):
		_rect(img, 115, k, 10, 1, Color8(10, 10, 12))
	_rect(img, 115, 3, 10, 1, Color8(110, 108, 106))
	_rect(img, 115, 3, 1, 10, Color8(80, 78, 76))

	# (0,1) toppen av vegg: nesten svart betong med lys leppe nederst
	for y in 16:
		for x in 16:
			img.set_pixel(x, 16 + y, _shade(Color8(20, 20, 23), 0.85 + 0.3 * _fbm(x / 4.0, y / 4.0, 81)))
	_rect(img, 0, 31, 16, 1, Color8(40, 40, 44))
	# (1,1)/(2,1) nedre vegg, (3,1)/(4,1) øvre vegg: murstein
	for v in 2:
		_bricks(img, 16 + v * 16, 16, Color8(86, 84, 80), 0.88, 1.0, 101 + v)
		_grime(img, 16 + v * 16, 16, 103 + v)
		_rect(img, 16 + v * 16, 29, 16, 3, Color8(26, 26, 28))
		_rect(img, 16 + v * 16, 29, 16, 1, Color8(48, 48, 50))
	# rør med brakett og rustrenner
	_rect(img, 42, 16, 3, 13, Color8(104, 66, 42))
	_rect(img, 42, 16, 1, 13, Color8(150, 104, 70))
	_rect(img, 44, 16, 1, 13, Color8(66, 40, 26))
	_rect(img, 41, 21, 5, 2, Color8(60, 58, 58))
	_px(img, 43, 21, Color8(140, 140, 140))
	for y in range(23, 29):
		_px(img, 43, y, Color(0.45, 0.25, 0.12, 0.35 * (29 - y) / 6.0))
	for v in 2:
		_bricks(img, 48 + v * 16, 16, Color8(76, 75, 72), 0.55, 0.9, 111 + v)
		_grime(img, 48 + v * 16, 16, 113 + v)
	# to rør på tvers
	for py: int in [19, 24]:
		_rect(img, 64, py, 16, 3, Color8(70, 76, 84))
		_rect(img, 64, py, 16, 1, Color8(128, 136, 148))
		_rect(img, 64, py + 2, 16, 1, Color8(36, 38, 44))
	_rect(img, 70, 18, 2, 10, Color8(46, 46, 48))
	_px(img, 70, 20, Color8(150, 150, 150))
	_px(img, 70, 25, Color8(150, 150, 150))
	return img


## Murstein 8x4 med fuger, ulik farge per stein og skygge mot taket.
static func _bricks(img: Image, ox: int, oy: int, base: Color, top: float, bottom: float, s: int) -> void:
	for y in 16:
		var row := y / 4
		var shift := 0 if row % 2 == 0 else 4
		var light := lerpf(top, bottom, y / 15.0)
		for x in 16:
			var bx := (x + shift) / 8
			var tone := 0.84 + 0.3 * _h(bx + ox, row, s)
			var warm := _h(bx + ox, row, s + 1)
			var c := Color(base.r * (1.0 + (warm - 0.5) * 0.12), base.g, base.b * (1.0 - (warm - 0.5) * 0.1))
			c = _shade(c, tone * light * (0.93 + 0.12 * _vn(x / 2.0 + ox, y / 2.0, s + 5)))
			var mortar_row := y % 4 == 3
			var mortar_col := (x + shift) % 8 == 7
			if mortar_row or mortar_col:
				c = _shade(base, 0.48 * light)
			elif y % 4 == 0:
				c = _shade(c, 1.12)  # lys overkant på steinen
			img.set_pixel(ox + x, oy + y, c)


## Fuktstriper som renner nedover veggen.
static func _grime(img: Image, ox: int, oy: int, s: int) -> void:
	for k in 2:
		var x := ox + 2 + int(_h(k, 0, s) * 12)
		var length := 5 + int(_h(k, 1, s) * 9)
		for y in length:
			_px(img, x, oy + y, Color(0.05, 0.09, 0.05, 0.28 * (1.0 - float(y) / length)))


static func _tiles_school() -> Image:
	var img := _img(128, 32)
	var lino := Color8(126, 130, 120)
	for i in 4:
		var ox := i * 16
		for y in 16:
			for x in 16:
				var checker := 1.0 if ((x / 8 + y / 8) % 2 == 0) else 0.94
				var f := checker * (0.95 + 0.08 * _fbm(x / 5.0 + ox, y / 5.0, 201 + i))
				if _h(x + ox, y, 205) < 0.06:
					f += 0.07 if _h(y, x + ox, 206) < 0.5 else -0.08
				# glans: litt lysere mot øvre venstre
				f += 0.04 * (1.0 - (x + y) / 30.0)
				img.set_pixel(ox + x, y, _shade(lino, f))
		_rect(img, ox, 0, 16, 1, _shade(lino, 0.72))
		_rect(img, ox, 0, 1, 16, _shade(lino, 0.78))
		match i:
			1:  # skuremerker
				for k in 6:
					_px(img, ox + 3 + k * 2, 10 + (k % 2), Color8(60, 58, 56))
			2:  # tyggis
				_rect(img, ox + 4, 4, 2, 2, Color8(150, 140, 150))
				_px(img, ox + 4, 4, Color8(190, 180, 190))
			3:
				_blob(img, ox, 0, 10.0, 6.0, 3.0, 211, Color(0.3, 0.28, 0.2, 0.2))
	# (4,0) rødt teppe med gullmønster
	var red := Color8(116, 28, 34)
	for y in 16:
		for x in 16:
			img.set_pixel(64 + x, y, _shade(red, 0.85 + 0.25 * _h(x, y, 221)))
	for k in range(0, 16, 4):
		_px(img, 64 + k + 1, 1, Color8(180, 140, 66))
		_px(img, 64 + k + 1, 14, Color8(180, 140, 66))
		_px(img, 64 + k + 3, 8, Color8(140, 40, 46))
	# (5,0) trapp
	for st in 4:
		var c := _shade(Color8(126, 114, 98), 1.12 - st * 0.12)
		_rect(img, 80, st * 4, 16, 4, c)
		_rect(img, 80, st * 4, 16, 1, Color8(170, 170, 160))
		_rect(img, 80, st * 4 + 3, 16, 1, _shade(c, 0.55))
	_rect(img, 96, 0, 16, 16, Color.BLACK)
	for y in 16:
		for x in 16:
			img.set_pixel(112 + x, y, _shade(lino, 0.82 + 0.08 * _fbm(x / 4.0, y / 4.0, 231)))

	for y in 16:
		for x in 16:
			img.set_pixel(x, 16 + y, _shade(Color8(30, 26, 24), 0.85 + 0.3 * _fbm(x / 4.0, y / 4.0, 241)))
	_rect(img, 0, 31, 16, 1, Color8(52, 44, 38))
	# nedre vegg: brunt panel med treverk
	for v in 2:
		var ox := 16 + v * 16
		var wood := Color8(96, 64, 42)
		for y in 16:
			for x in 16:
				var grain := 0.88 + 0.2 * _vn(x / 1.5 + ox, y / 7.0, 251 + v)
				img.set_pixel(ox + x, 16 + y, _shade(wood, grain))
		_rect(img, ox, 16, 16, 2, Color8(140, 102, 64))
		_rect(img, ox, 17, 16, 1, Color8(84, 56, 36))
		for px: int in [1, 9]:
			_rect(img, ox + px, 20, 6, 8, _shade(wood, 0.86))
			_rect(img, ox + px, 20, 6, 1, _shade(wood, 0.62))
			_rect(img, ox + px, 20, 1, 8, _shade(wood, 0.7))
			_rect(img, ox + px, 27, 6, 1, _shade(wood, 1.15))
		_rect(img, ox, 29, 16, 3, Color8(40, 28, 20))
		if v == 1:  # radiator
			_rect(img, ox + 2, 19, 12, 9, Color8(176, 176, 166))
			for k in range(3, 14, 2):
				_rect(img, ox + k, 19, 1, 9, Color8(126, 126, 118))
			_rect(img, ox + 2, 19, 12, 1, Color8(210, 210, 200))
	# øvre vegg: tapet med striper og flekker
	for v in 2:
		var ox := 48 + v * 16
		var paper := Color8(112, 116, 82)
		for y in 16:
			for x in 16:
				var f := 0.95 + 0.07 * _fbm(x / 4.0 + ox, y / 4.0, 261)
				if x % 4 == 0:
					f *= 0.86
				f *= lerpf(0.82, 1.0, y / 15.0)
				img.set_pixel(ox + x, 16 + y, _shade(paper, f))
		if v == 1:  # oppslagstavle
			_rect(img, ox + 2, 19, 12, 10, Color8(146, 104, 62))
			_noise(img, ox + 2, 19, 12, 10, 0.03)
			_rect(img, ox + 4, 21, 4, 5, Color8(226, 224, 214))
			_rect(img, ox + 9, 20, 3, 4, Color8(232, 212, 120))
			_px(img, ox + 5, 21, Color8(200, 40, 40))
			_px(img, ox + 10, 20, Color8(40, 90, 200))
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
# Tittelskjerm – panorama av kjellergangen sett fra siden (scenes/title.tscn)
# ======================================================================
# Lagene bakfra: title_sky (ses bare gjennom vinduene) -> title_wall -> title_front.
# Vinduer, lamper og dører i title_wall må stå der markørene i title.tscn står.

const PANO_WINDOWS := [40, 250, 430, 640]  # venstre kant, hullet er 30×22 ved y = 30
const PANO_LAMPS := [120, 335, 545, 735]   # midten av lysrøret, y = 28
const PANO_DOORS := [172, 482, 690]        # venstre kant, 26×52 ved y = 136 (nr. 2 står på gløtt)
const PANO_FLOOR := 188                    # der gulvet begynner


static func _ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
		for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
			if Vector2((x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry).length_squared() <= 1.0:
				_px(img, x, y, c)


static func _line(img: Image, a: Vector2, b: Vector2, w: int, c: Color) -> void:
	var steps := int(maxf(absf(b.x - a.x), absf(b.y - a.y))) + 1
	for i in steps + 1:
		var p := a.lerp(b, float(i) / steps)
		_rect(img, int(p.x - w / 2.0), int(p.y), w, 1, c)


static func _pano_box(img: Image, x: int, y: int, w: int, h: int) -> void:
	var c := _shade(Color8(120, 92, 58), rng.randf_range(0.55, 0.85))
	_rect(img, x, y, w, h, c)
	_rect(img, x, y, w, 1, _shade(c, 1.3))
	_rect(img, x + w / 2, y, 1, h / 2, _shade(c, 1.45))  # teip
	_rect(img, x + w - 1, y, 1, h, _shade(c, 0.65))


static func _pano_crate(img: Image, x: int, y: int, w: int, h: int) -> void:
	var wood := _shade(Color8(88, 64, 38), rng.randf_range(0.75, 0.95))
	_rect(img, x, y, w, h, wood)
	_rect(img, x, y, w, 2, _shade(wood, 1.25))
	_rect(img, x, y + h / 2, w, 1, _shade(wood, 0.65))
	_line(img, Vector2(x + 2, y + h - 2), Vector2(x + w - 3, y + 2), 1, _shade(wood, 0.72))
	_rect(img, x, y, 1, h, _shade(wood, 0.55))
	_rect(img, x + w - 1, y, 1, h, _shade(wood, 0.55))
	_rect(img, x, y + h - 1, w, 1, _shade(wood, 0.5))


## Natthimmel og bakke utenfor kjellervinduene (600×64, ses bare gjennom vinduene).
static func _pano_sky() -> Image:
	rng.seed = 501
	var img := _img(600, 64)
	var top := Color8(9, 12, 24)
	var low := Color8(42, 52, 76)
	for y in 64:
		_rect(img, 0, y, 600, 1, top.lerp(low, clampf(y / 46.0, 0.0, 1.0)))
	for i in 40:  # stjerner
		_px(img, rng.randi_range(0, 599), rng.randi_range(0, 36), Color8(110, 120, 150))
	for i in 7:  # skyer
		var cx := rng.randi_range(0, 599)
		var cy := rng.randi_range(8, 34)
		for k in 5:
			_ellipse(img, cx + k * 9 + rng.randi_range(-3, 3), cy + rng.randi_range(-2, 2),
				rng.randf_range(8, 14), rng.randf_range(2, 3.5), Color(0.06, 0.08, 0.13, 0.5))
	# måne med glorie
	_ellipse(img, 300, 30, 16, 16, Color(0.55, 0.65, 0.85, 0.08))
	_ellipse(img, 300, 30, 10, 10, Color(0.6, 0.7, 0.9, 0.1))
	_ellipse(img, 300, 30, 5, 5, Color8(205, 210, 195))
	_ellipse(img, 298, 29, 1.5, 1.5, Color8(170, 175, 165))
	_px(img, 302, 32, Color8(175, 180, 168))
	# gatelykter langt unna
	for lx: int in [110, 470]:
		_rect(img, lx, 22, 1, 25, Color8(14, 16, 22))
		_rect(img, lx - 2, 21, 4, 1, Color8(14, 16, 22))
		_ellipse(img, lx, 23, 9, 7, Color(1.0, 0.6, 0.25, 0.1))
		_rect(img, lx - 1, 22, 2, 1, Color8(230, 170, 90))
	# bakken utenfor (vinduene ligger i bakkehøyde) med gresstrå
	var ground := Color8(7, 9, 9)
	_rect(img, 0, 47, 600, 17, ground)
	for x in 600:
		if rng.randf() < 0.6:
			var h := rng.randi_range(1, 3)
			_rect(img, x, 47 - h, 1, h, ground)
	return img


## Selve kjellergangen (800×240): vegg, rør, vinduer, lamper, dører og rot.
static func _pano_wall() -> Image:
	rng.seed = 502
	var w := 800
	var fl := PANO_FLOOR
	var img := _img(w, 240)
	# tak
	_rect(img, 0, 0, w, 12, Color8(17, 18, 21))
	_rect(img, 0, 11, w, 1, Color8(27, 28, 31))
	# lettbetongblokker, malt mørkegrønn nederst og mørkere opp mot taket
	for y in range(12, fl):
		var row := (y - 12) / 8
		var shift := 8 if row % 2 == 1 else 0
		var base := Color8(46, 50, 52) if y < 128 else Color8(33, 43, 41)
		var light := lerpf(0.68, 1.0, clampf((y - 12) / 90.0, 0.0, 1.0))
		for x in w:
			var block_id := (x + shift) / 16 * 7 + row * 13
			var f := light * (0.94 + 0.03 * ((block_id * 37) % 4))
			if (x + shift) % 16 == 0 or (y - 12) % 8 == 0:
				f *= 0.8
			img.set_pixel(x, y, _shade(base, f))
	_noise(img, 0, 12, w, fl - 12, 0.015)
	_rect(img, 0, 125, w, 1, Color8(96, 40, 34))  # rød stripe
	_rect(img, 0, 126, w, 2, Color8(70, 26, 24))
	for i in 7:  # sprekker
		var x := rng.randi_range(20, w - 20)
		var y := rng.randi_range(40, 160)
		for k in rng.randi_range(8, 20):
			_px(img, x, y, Color(0, 0, 0, 0.45))
			x += rng.randi_range(-1, 1)
			y += 1
	# rør langs taket
	_rect(img, 0, 14, w, 6, Color8(58, 60, 58))
	_rect(img, 0, 14, w, 1, Color8(84, 86, 80))
	_rect(img, 0, 19, w, 1, Color8(32, 33, 32))
	for x in range(20, w, 64):
		_rect(img, x, 12, 3, 9, Color8(28, 28, 31))
		_rect(img, x + 32, 13, 3, 8, Color8(72, 74, 70))
	_rect(img, 0, 22, w, 3, Color8(78, 52, 38))
	_rect(img, 0, 22, w, 1, Color8(104, 72, 52))
	_rect(img, 0, 24, w, 1, Color8(44, 30, 24))
	for i in 14:  # rustrenner
		_rect(img, rng.randi_range(0, w - 2), 25, rng.randi_range(1, 2), rng.randi_range(10, 70), Color(0.12, 0.07, 0.03, 0.3))

	# kjellervinduer (hull – himmelen bak synes gjennom)
	for wx: int in PANO_WINDOWS:
		_rect(img, wx - 3, 27, 36, 28, Color8(24, 25, 28))
		_rect(img, wx - 3, 27, 36, 1, Color8(40, 41, 44))
		img.fill_rect(Rect2i(wx, 30, 30, 22), Color(0, 0, 0, 0))
		for i in 18:  # skitt på glasset
			_px(img, wx + rng.randi_range(0, 29), 30 + rng.randi_range(0, 21), Color(0.1, 0.11, 0.09, 0.5))
		for bx: int in [wx + 9, wx + 20]:
			_rect(img, bx, 30, 1, 22, Color8(30, 31, 35))
		_rect(img, wx, 40, 30, 1, Color8(30, 31, 35))
		_rect(img, wx - 4, 53, 38, 2, Color8(66, 68, 70))
		_rect(img, wx - 4, 55, 38, 1, Color8(22, 23, 25))

	# lysrør i kjetting (selve lyset tegnes i scenen)
	for lx: int in PANO_LAMPS:
		for cx: int in [lx - 9, lx + 9]:
			for y in range(12, 25, 2):
				_px(img, cx, y, Color8(44, 44, 48))
		_rect(img, lx - 13, 25, 26, 3, Color8(48, 50, 54))
		_rect(img, lx - 13, 25, 26, 1, Color8(64, 66, 70))
		_rect(img, lx - 11, 28, 22, 1, Color8(84, 86, 82))

	# oppslagstavle med lapper (og en savnet-plakat)
	_rect(img, 58, 82, 56, 36, Color8(46, 36, 26))
	_rect(img, 60, 84, 52, 32, Color8(86, 64, 44))
	_noise(img, 60, 84, 52, 32, 0.03)
	for i in 9:
		var nx := 62 + rng.randi_range(0, 38)
		var ny := 86 + rng.randi_range(0, 17)
		var pc := Color8(170, 168, 150) if rng.randf() < 0.8 else Color8(150, 60, 50)
		_rect(img, nx, ny, rng.randi_range(6, 10), rng.randi_range(7, 11), _shade(pc, rng.randf_range(0.6, 0.85)))
		_px(img, nx + 3, ny, Color8(160, 30, 30))
	_rect(img, 98, 88, 10, 13, Color8(150, 148, 132))
	_ellipse(img, 103, 93, 2.5, 3, Color8(40, 38, 36))
	_rect(img, 100, 98, 6, 1, Color8(90, 88, 80))

	# dører
	var metal := Color8(52, 64, 60)
	for i in PANO_DOORS.size():
		var dx: int = PANO_DOORS[i]
		_rect(img, dx - 3, 133, 32, fl - 133, Color8(24, 25, 28))
		_rect(img, dx - 3, 133, 32, 1, Color8(44, 45, 48))
		if i == 1:  # står på gløtt – helt mørkt bak
			_rect(img, dx, 136, 26, fl - 136, Color8(4, 4, 6))
			_rect(img, dx, 136, 7, fl - 136, _shade(metal, 0.7))
			_rect(img, dx + 6, 136, 1, fl - 136, _shade(metal, 0.45))
			_rect(img, dx + 3, 162, 2, 3, Color8(120, 112, 76))
			continue
		_rect(img, dx, 136, 26, fl - 136, metal)
		_rect(img, dx, 136, 26, 1, _shade(metal, 1.3))
		_rect(img, dx + 25, 136, 1, fl - 136, _shade(metal, 0.7))
		_rect(img, dx + 7, 142, 12, 16, Color8(12, 15, 17))  # trådglass
		for yy in range(142, 158):
			for xx in range(dx + 7, dx + 19):
				if (xx + yy) % 4 == 0 or (xx - yy) % 4 == 0:
					_px(img, xx, yy, Color8(34, 40, 40))
		_rect(img, dx + 19, 165, 4, 2, Color8(150, 140, 92))
		_rect(img, dx + 1, 177, 24, 10, _shade(metal, 1.12))
		_rect(img, dx + 9, 129, 8, 3, Color8(160, 156, 132))
		_noise(img, dx, 136, 26, fl - 136, 0.02)
	# nødutgang-skilt over den siste døra (lyset tegnes i scenen)
	var ex: int = PANO_DOORS[2] + 6
	_rect(img, ex, 116, 14, 8, Color8(18, 70, 36))
	_rect(img, ex + 1, 117, 12, 6, Color8(34, 120, 62))
	_rect(img, ex + 3, 119, 6, 2, Color8(150, 220, 170))
	_px(img, ex + 9, 118, Color8(150, 220, 170))
	_px(img, ex + 9, 121, Color8(150, 220, 170))
	_rect(img, ex + 10, 119, 1, 2, Color8(150, 220, 170))
	# håndavtrykk ved den åpne døra
	var hx: int = PANO_DOORS[1] + 32
	var blood := Color(0.3, 0.04, 0.03, 0.55)
	_rect(img, hx, 146, 6, 5, blood)
	_rect(img, hx, 142, 1, 4, blood)
	_rect(img, hx + 2, 141, 1, 5, blood)
	_rect(img, hx + 4, 142, 1, 4, blood)
	_rect(img, hx + 6, 145, 1, 3, blood)
	_rect(img, hx + 1, 151, 1, 9, blood)
	_rect(img, hx + 4, 151, 1, 14, blood)

	# garderobeskap (ett står åpent)
	var lock_c := Color8(50, 62, 78)
	for i in 6:
		var lx := 222 + i * 12
		_rect(img, lx, 118, 11, fl - 118, lock_c)
		_rect(img, lx, 118, 11, 1, _shade(lock_c, 1.3))
		_rect(img, lx + 11, 118, 1, fl - 118, Color8(18, 20, 24))
		for v in 3:
			_rect(img, lx + 3, 123 + v * 2, 5, 1, _shade(lock_c, 0.6))
		_rect(img, lx + 8, 148, 1, 4, Color8(140, 140, 130))
		if i == 3:
			_rect(img, lx, 119, 11, fl - 119, Color8(10, 10, 12))
			_rect(img, lx + 1, 128, 9, 1, Color8(30, 30, 34))
			_rect(img, lx + 11, 117, 3, fl - 116, _shade(lock_c, 1.1))
	_noise(img, 222, 118, 74, fl - 118, 0.02)
	_pano_box(img, 226, 108, 16, 10)
	_pano_box(img, 262, 112, 12, 6)

	# brannalarm og brannslukker
	_rect(img, 316, 98, 10, 10, Color8(120, 24, 22))
	_rect(img, 316, 98, 10, 1, Color8(160, 40, 34))
	_rect(img, 320, 102, 2, 2, Color8(200, 190, 180))
	_rect(img, 315, 146, 12, 2, Color8(60, 60, 64))
	_rect(img, 319, 148, 3, 4, Color8(40, 40, 42))
	_rect(img, 317, 152, 8, 18, Color8(140, 28, 24))
	_rect(img, 317, 152, 2, 18, Color8(170, 50, 40))
	_rect(img, 316, 156, 1, 8, Color8(30, 30, 30))
	_rect(img, 319, 158, 4, 5, Color8(180, 175, 160))

	# hylle med esker
	var steel := Color8(72, 76, 82)
	_rect(img, 372, 104, 56, fl - 104, Color(0, 0, 0, 0.35))
	for sy: int in [118, 140, 162, 185]:
		var x := 375
		while x < 420:
			var bw := rng.randi_range(7, 15)
			var bh := rng.randi_range(6, 13)
			if x + bw > 425:
				break
			if rng.randf() < 0.25:  # permer
				for k in rng.randi_range(2, 4):
					_rect(img, x + k * 2, sy - 11, 2, 11, _shade([Color8(110, 40, 40), Color8(40, 60, 110), Color8(60, 90, 60)][k % 3], 0.7))
				x += 9
			else:
				_pano_box(img, x, sy - bh, bw, bh)
				x += bw + rng.randi_range(0, 3)
		_rect(img, 372, sy, 56, 2, steel)
		_rect(img, 372, sy, 56, 1, _shade(steel, 1.3))
	_rect(img, 372, 104, 2, fl - 104, steel)
	_rect(img, 426, 104, 2, fl - 104, steel)

	# sikringsskap med varseltrekant
	_rect(img, 448, 24, 2, 68, Color8(48, 50, 50))
	_rect(img, 440, 92, 18, 24, Color8(66, 70, 68))
	_rect(img, 440, 92, 18, 1, Color8(90, 94, 90))
	_rect(img, 457, 92, 1, 24, Color8(40, 42, 42))
	_rect(img, 440, 115, 18, 1, Color8(40, 42, 42))
	for i in 5:
		_rect(img, 449 - i, 99 + i, i * 2 + 1, 1, Color8(180, 150, 40))
	_px(img, 449, 101, Color8(20, 20, 20))
	_px(img, 449, 103, Color8(20, 20, 20))

	# pult med en gammel skriver (feillampa blinker i scenen)
	_rect(img, 560, 162, 52, 3, Color8(92, 68, 46))
	_rect(img, 560, 162, 52, 1, Color8(120, 92, 64))
	_rect(img, 562, 165, 2, fl - 165, Color8(50, 40, 30))
	_rect(img, 608, 165, 2, fl - 165, Color8(50, 40, 30))
	_rect(img, 588, 165, 20, 16, Color8(74, 54, 36))
	_rect(img, 588, 172, 20, 1, Color8(50, 36, 24))
	_rect(img, 570, 144, 20, 4, Color8(196, 194, 184))
	_rect(img, 566, 148, 28, 14, Color8(132, 128, 114))
	_rect(img, 566, 148, 28, 2, Color8(156, 152, 136))
	_rect(img, 570, 156, 20, 2, Color8(40, 40, 40))
	_rect(img, 589, 151, 2, 1, Color8(110, 30, 26))
	_noise(img, 566, 144, 28, 18, 0.02)

	# rør ned langs veggen med ventilratt
	_rect(img, 622, 24, 6, fl - 24, Color8(56, 58, 56))
	_rect(img, 622, 24, 1, fl - 24, Color8(78, 80, 76))
	_rect(img, 627, 24, 1, fl - 24, Color8(30, 31, 30))
	for fy: int in [60, 170]:
		_rect(img, 620, fy, 10, 2, Color8(70, 72, 68))
	for i in 24:
		var a := i / 24.0 * TAU
		_px(img, 625 + roundi(cos(a) * 5), 120 + roundi(sin(a) * 5), Color8(120, 30, 28))
	_rect(img, 620, 120, 11, 1, Color8(100, 26, 24))
	_rect(img, 625, 115, 1, 11, Color8(100, 26, 24))

	# kasser stablet i enden
	_pano_crate(img, 740, 170, 24, 18)
	_pano_crate(img, 765, 170, 26, 18)
	_pano_crate(img, 750, 152, 24, 18)

	# gulv med fuger i perspektiv
	var floor_c := Color8(30, 31, 34)
	for y in range(fl, 240):
		_rect(img, 0, y, w, 1, _shade(floor_c, lerpf(0.8, 1.15, float(y - fl) / (240 - fl))))
	_noise(img, 0, fl, w, 240 - fl, 0.018)
	for y: int in [195, 204, 217, 235]:
		_rect(img, 0, y, w, 1, _shade(floor_c, 0.75))
	for x0 in range(-200, w + 200, 40):
		for y in range(fl, 240):
			_px(img, x0 + int((x0 - w / 2) * (y - fl) / 140.0), y, _shade(floor_c, 0.75))
	_rect(img, 0, fl - 2, w, 2, Color8(20, 20, 23))
	_rect(img, 0, fl, w, 3, Color(0, 0, 0, 0.35))
	# vanndammer som speiler lyset
	for p: Array in [[335, 210, 26.0, 3.5], [618, 224, 30.0, 4.0], [90, 230, 18.0, 3.0]]:
		_ellipse(img, p[0], p[1], p[2], p[3], Color8(20, 24, 30))
		_rect(img, int(p[0] - p[2] * 0.5), p[1] - 1, int(p[2] * 0.6), 1, Color8(58, 64, 74))
	# ark og rusk
	for i in 10:
		_rect(img, rng.randi_range(540, 640), rng.randi_range(192, 230), rng.randi_range(3, 5), 2,
			_shade(Color8(160, 158, 146), rng.randf_range(0.5, 0.8)))
	for i in 80:
		_px(img, rng.randi_range(0, w - 1), rng.randi_range(fl, 239), Color(0, 0, 0, 0.4))
	return img


## Forgrunn (1040×240, nesten svarte silhuetter) som glir fortere forbi enn veggen.
static func _pano_front() -> Image:
	rng.seed = 503
	var w := 1040
	var img := _img(w, 240)
	var col := Color8(9, 8, 11)
	var rim := Color8(30, 30, 37)
	# rør øverst
	_rect(img, 0, 0, w, 5, col)
	for x in range(40, w, 130):
		_rect(img, x, 0, 5, 8, col)
	# søyler
	for px: int in [180, 600, 930]:
		_rect(img, px - 4, 0, 30, 12, col)
		_rect(img, px, 0, 22, 240, col)
		_rect(img, px - 3, 224, 28, 16, col)
		_rect(img, px, 12, 1, 212, rim)
		_rect(img, px + 21, 12, 1, 212, _shade(rim, 0.7))
	# kabler som henger ned
	for c: Array in [[300, 470, 26.0], [700, 860, 18.0], [40, 140, 14.0]]:
		for x in range(c[0], c[1] + 1):
			var t: float = float(x - c[0]) / (c[1] - c[0]) * 2.0 - 1.0
			_rect(img, x, 4 + int(c[2] * (1.0 - t * t)), 1, 2, col)
	# spindelvev ved en søyle
	var web := Color(0.55, 0.55, 0.6, 0.22)
	var o := Vector2(622, 12)
	for i in 5:
		var a := deg_to_rad(i * 22.5)
		for r in 20:
			_px(img, int(o.x + cos(a) * r), int(o.y + sin(a) * r), web)
	for r: int in [6, 11, 16]:
		for k in r * 2:
			var a := k / (r * 2.0) * PI * 0.5
			_px(img, int(o.x + cos(a) * r), int(o.y + sin(a) * r), web)
	# kasser, stol og esker nederst
	_rect(img, 0, 196, 46, 44, col)
	_rect(img, 40, 210, 48, 30, col)
	_rect(img, 8, 178, 30, 18, col)
	_rect(img, 8, 178, 30, 1, rim)
	_rect(img, 46, 210, 42, 1, rim)
	_rect(img, 440, 213, 26, 3, col)
	_rect(img, 462, 186, 3, 30, col)
	_rect(img, 456, 188, 10, 12, col)
	_rect(img, 442, 216, 2, 24, col)
	_rect(img, 461, 216, 2, 24, col)
	_rect(img, 972, 204, 44, 36, col)
	_rect(img, 996, 186, 30, 18, col)
	_rect(img, 996, 186, 30, 1, rim)
	return img


## Skygge utenfor vinduet: 3 ruter à 16×32 – bein i steg A, steg B og et hode som titter inn.
static func _pano_shadow() -> Image:
	var img := _img(48, 32)
	var c := Color8(5, 5, 7)
	_line(img, Vector2(7, 0), Vector2(4, 29), 3, c)
	_line(img, Vector2(9, 0), Vector2(12, 29), 3, c)
	_rect(img, 2, 29, 5, 3, c)
	_rect(img, 11, 29, 5, 3, c)
	_rect(img, 21, 0, 3, 29, c)
	_rect(img, 24, 0, 3, 29, c)
	_rect(img, 21, 29, 8, 3, c)
	_ellipse(img, 40, 9, 4.5, 5.5, c)
	_rect(img, 38, 14, 4, 3, c)
	_ellipse(img, 40, 25, 8, 7, c)
	_rect(img, 32, 25, 16, 7, c)
	_px(img, 38, 9, Color8(120, 122, 112))
	_px(img, 42, 9, Color8(120, 122, 112))
	return img


## Høy, tynn skikkelse (16×40) som dukker opp i døråpningen eller når lyset blinker.
static func _pano_figure() -> Image:
	var img := _img(16, 40)
	var c := Color8(6, 6, 8)
	_ellipse(img, 8, 6, 3.5, 4.5, c)
	_rect(img, 7, 10, 2, 2, c)
	for y in range(12, 27):
		var half := 5 - (y - 12) / 6
		_rect(img, 8 - half, y, half * 2, 1, c)
	_rect(img, 2, 13, 2, 18, c)  # lange armer
	_rect(img, 12, 13, 2, 18, c)
	_rect(img, 4, 27, 3, 13, c)
	_rect(img, 9, 27, 3, 13, c)
	_px(img, 6, 6, Color8(225, 220, 205))
	_px(img, 10, 6, Color8(225, 220, 205))
	return img


## Tåke som kan flislegges sidelengs (256×48), tettest nederst.
static func _pano_fog() -> Image:
	var img := _img(256, 48)
	var noise := FastNoiseLite.new()
	noise.seed = 504
	noise.frequency = 0.035
	noise.fractal_octaves = 3
	var r := 256.0 / TAU
	for y in 48:
		for x in 256:
			var a := x / 256.0 * TAU
			var n := noise.get_noise_3d(cos(a) * r, sin(a) * r, y * 1.6) * 0.5 + 0.5
			var f := clampf((n - 0.3) * 1.6, 0.0, 1.0) * smoothstep(0.0, 1.0, y / 40.0)
			f = floorf(f * 5.0) / 5.0
			if f > 0.0:
				img.set_pixel(x, y, Color(0.62, 0.66, 0.74, f * 0.45))
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


## Skosåle på betong: et hælklikk, et dunk og litt skrap etterpå.
static func _snd_footstep() -> PackedFloat32Array:
	var b := _buf(0.22)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var click := rng.randf_range(-1, 1) * exp(-t * 260.0) * 0.9
		var thump := sin(TAU * 95.0 * t * (1.0 - t * 2.0)) * exp(-t * 45.0) * 0.55
		lp += (rng.randf_range(-1, 1) - lp) * 0.18
		var scuff := lp * exp(-maxf(t - 0.03, 0.0) * 28.0) * 0.5 * (1.0 if t > 0.02 else 0.0)
		b[i] = click + thump + scuff
	return _lowpass(b, 0.55)


## Fottrinn i vann: plask med høye dråper.
static func _snd_footstep_wet() -> PackedFloat32Array:
	var b := _snd_footstep()
	var n := b.size()
	for k in 6:
		var start := int(rng.randf_range(0.01, 0.12) * RATE)
		var f := rng.randf_range(1400.0, 3200.0)
		for i in range(start, mini(start + int(0.05 * RATE), n)):
			var t := float(i - start) / RATE
			b[i] += sin(TAU * f * t * (1.0 + t * 6.0)) * exp(-t * 70.0) * 0.12
	for i in n:
		var t := float(i) / RATE
		b[i] += rng.randf_range(-1, 1) * exp(-t * 18.0) * 0.25
	return b


## Én vanndråpe som treffer en dam: "plink" som glir ned i tone.
static func _snd_drip() -> PackedFloat32Array:
	var b := _buf(0.6)
	var phase := 0.0
	for i in b.size():
		var t := float(i) / RATE
		phase += TAU * (1900.0 * exp(-t * 9.0) + 700.0) / RATE
		b[i] = sin(phase) * exp(-t * 14.0) * 0.45 + rng.randf_range(-1, 1) * exp(-t * 400.0) * 0.2
	return b


## Metallisk bank i rørene (uharmoniske overtoner som ringer ut), 2-3 slag.
static func _snd_pipe_knock() -> PackedFloat32Array:
	var b := _buf(2.2)
	var hits := [0.0, 0.32, 0.55] if rng.randf() < 0.5 else [0.0, 0.41]
	for h: float in hits:
		var start := int(h * RATE)
		var amp := rng.randf_range(0.5, 0.8)
		for i in range(start, b.size()):
			var t := float(i - start) / RATE
			var ring := sin(TAU * 310.0 * t) * 0.5 + sin(TAU * 731.0 * t) * 0.3 + sin(TAU * 1187.0 * t) * 0.18 + sin(TAU * 1720.0 * t) * 0.1
			b[i] += (ring * exp(-t * 5.5) + rng.randf_range(-1, 1) * exp(-t * 300.0)) * amp * 0.35
	return _lowpass(b, 0.5)


## Knirk: treg sagtann med ujevn friksjon (gamle hyller / dør langt unna).
static func _snd_creak() -> PackedFloat32Array:
	var b := _buf(1.6)
	var phase := 0.0
	var jitter := 0.0
	for i in b.size():
		var t := float(i) / b.size()
		jitter += (rng.randf_range(-1, 1) - jitter) * 0.002
		var f := 95.0 + 60.0 * sin(t * PI) + jitter * 400.0
		phase += f / RATE
		var saw := fmod(phase, 1.0) * 2.0 - 1.0
		var grip := 0.5 + 0.5 * signf(sin(phase * TAU * 0.25))
		b[i] = saw * grip * sin(PI * t) * 0.35
	return _lowpass(_lowpass(b, 0.25), 0.4)


## Dempede fottrinn et sted i bygget (noen andre går der).
static func _snd_distant_steps() -> PackedFloat32Array:
	var b := _buf(3.0)
	var t0 := 0.15
	for k in 5:
		var start := int(t0 * RATE)
		for i in range(start, mini(start + int(0.18 * RATE), b.size())):
			var t := float(i - start) / RATE
			b[i] += (sin(TAU * 70.0 * t) * 0.8 + rng.randf_range(-0.5, 0.5)) * exp(-t * 30.0) * (0.5 + k * 0.08)
		t0 += rng.randf_range(0.45, 0.6)
	return _lowpass(_lowpass(b, 0.06), 0.1)


## Rotte: rask skraping med klør og et lite pip.
static func _snd_rat() -> PackedFloat32Array:
	var b := _buf(1.1)
	for i in b.size():
		var t := float(i) / RATE
		var claws := rng.randf_range(-1, 1) * (1.0 if fmod(t, 0.045) < 0.012 else 0.0) * 0.4 * sin(PI * minf(t / 0.7, 1.0))
		b[i] = claws
	var start := int(0.8 * RATE)
	for i in range(start, b.size()):
		var t := float(i - start) / RATE
		b[i] += sin(TAU * (3200.0 + 900.0 * sin(t * 60.0)) * t) * 0.12 * sin(PI * minf(t / 0.12, 1.0))
	return _lowpass(b, 0.6)


## Trekk gjennom ventilasjonen: filtrert sus som sveller opp og ned.
static func _snd_vent() -> PackedFloat32Array:
	var b := _buf(4.0)
	var lp := 0.0
	var lp2 := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (rng.randf_range(-1, 1) - lp) * (0.04 + 0.03 * sin(t * 2.1))
		lp2 += (lp - lp2) * 0.3
		b[i] = lp2 * 2.2 * sin(PI * t / 4.0) * (0.7 + 0.3 * sin(t * 5.3))
	return b


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


## Kjellerens grunntone: to svevende basstoner, rumling, sus fra ventilasjonen og en
## fjern metallisk klang. Slutten blandes inn i starten så loopen ikke klikker.
static func _snd_drone() -> PackedFloat32Array:
	var seconds := 12.0
	var b := _buf(seconds)
	var n := b.size()
	var rumble := 0.0
	var air := 0.0
	var air2 := 0.0
	for i in n:
		var t := float(i) / RATE
		rumble += (rng.randf_range(-1, 1) - rumble) * 0.004
		air += (rng.randf_range(-1, 1) - air) * 0.05
		air2 += (air - air2) * 0.2
		var swell := 0.7 + 0.3 * sin(TAU * t / seconds)
		var tones := sin(TAU * 55.0 * t) * 0.2 + sin(TAU * 58.25 * t) * 0.15 \
			+ sin(TAU * 82.5 * t) * 0.05 + sin(TAU * 27.5 * t) * 0.14
		var clang := sin(TAU * 412.0 * t) * 0.025 * maxf(0.0, sin(TAU * t / seconds * 2.0)) ** 6
		b[i] = (tones * swell + rumble * 1.6 + air2 * 0.22 * (0.6 + 0.4 * sin(TAU * t / 6.0)) + clang)
	# Myk skjøt: bland slutten inn i starten.
	var fade := int(0.5 * RATE)
	for i in fade:
		var k := float(i) / fade
		b[i] = b[i] * k + b[n - fade + i] * (1.0 - k)
	b.resize(n - fade)
	return b


## Lysrør som blinker: 100 Hz brumming med overtoner, sprak og korte utfall.
static func _snd_flicker() -> PackedFloat32Array:
	var b := _buf(0.5)
	var on := 1.0
	for i in b.size():
		var t := float(i) / RATE
		if i % 220 == 0:
			on = 1.0 if rng.randf() < 0.75 else 0.0
		var buzz := signf(sin(TAU * 100.0 * t)) * 0.08 + sin(TAU * 200.0 * t) * 0.08 + sin(TAU * 300.0 * t) * 0.04
		var crackle := rng.randf_range(-1, 1) * (0.5 if rng.randf() < 0.01 else 0.06)
		b[i] = (buzz + crackle) * on * _env(i, b.size(), 0.01, 0.5)
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
