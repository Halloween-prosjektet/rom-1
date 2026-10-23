extends SceneTree
## Lager grafikken til intro-scenen (resepsjonen og trappa ned til kjelleren) fra
## illustrasjonen designgruppa laget: assets/intro/source/reception_illustration.webp.
##
## Kjør fra prosjektmappa:
##   godot --headless --path . --script res://tools/intro_art.gd
##
## Illustrasjonen er tegnet i 240x135 og skalert opp ~3.5x (og lagret som webp, som gir
## litt støy). Skriptet finner de ekte pikslene igjen (midten av hver blokk + fast palett),
## skjærer ut delene og bygger rommet (400x240) rundt dem:
##
##   reception_bg.png   vegg, gulvfliser og teppe for hele rommet (illustrasjonen står
##                      80 px inn fra venstre, resten er forlenget med de samme mønstrene)
##   reception.png      resepsjonsvinduet (uten resepsjonisten)
##   receptionist.png   resepsjonisten
##   stairs.png         trappa ned til kjelleren
##   plant_pot.png      potten med ansikt
##   wall_art.png       "hjernen" på veggen
##   cabinet.png        glassmonteren (tegnet her, etter bildet av resepsjonen)
##   thought_bubble.png tankeboble, 3 ruter (. .. ...)
##
## Plasseringene står i OFS + R_* under, og må stemme med scenes/intro/intro.tscn.

const SRC := "res://assets/intro/source/reception_illustration.webp"
const NATIVE_OUT := "res://assets/intro/source/reception_native.png"
const OUT := "res://assets/intro/"
const W := 240
const H := 135
const ROOM := Vector2i(400, 240)
## Der illustrasjonen står i rommet.
const OFS := Vector2i(80, 0)

# Utsnitt i illustrasjonen (blir egne sprites i scenen).
const R_RECEPTION := Rect2i(94, 0, 92, 80)
const R_STAIRS := Rect2i(185, 0, 55, 50)
const R_PLANT := Rect2i(0, 33, 22, 27)
const R_ART := Rect2i(30, 9, 38, 43)
const R_RECEPTIONIST := Rect2i(167, 36, 14, 23)
## Ren veggsøyle (ingen pynt) i venstre del. Veggen der går fra y 0 til 59.
const WALL_REF_X := 80
const WALL_H := 60
## Gulvmønsteret gjentar seg hver 28. piksel.
const PERIOD := 28
## Teppekant og fliser nederst i rommet (etter bildene fra inngangen).
const BOTTOM_EDGE_Y := 208

const BEIGE := Color8(216, 160, 96)
const CARPET := Color8(56, 56, 56)
const EDGE := Color8(32, 32, 48)
const BLACK := Color8(0, 0, 0)
const WHITE := Color8(248, 248, 248)


func _initialize() -> void:
	var native := _native()
	native.save_png(ProjectSettings.globalize_path(NATIVE_OUT))
	var wall := _wall_column(native)

	# Resepsjonisten skilles fra vinduet: alt som ikke er den beige bakveggen.
	var reception := native.get_region(R_RECEPTION)
	var receptionist := Image.create_empty(R_RECEPTIONIST.size.x, R_RECEPTIONIST.size.y, false, Image.FORMAT_RGBA8)
	for y in R_RECEPTIONIST.size.y:
		for x in R_RECEPTIONIST.size.x:
			var p := R_RECEPTIONIST.position + Vector2i(x, y)
			var c := native.get_pixelv(p)
			if _dist(c, BEIGE) > 0.15 and c != WHITE:
				receptionist.set_pixel(x, y, c)
				reception.set_pixelv(p - R_RECEPTION.position, BEIGE)
	_save(reception, "reception.png")
	_save(receptionist, "receptionist.png")
	_save(native.get_region(R_STAIRS), "stairs.png")
	_save(_cut_from_wall(native, wall, R_PLANT), "plant_pot.png")
	_save(_cut_from_wall(native, wall, R_ART), "wall_art.png")
	_save(_cabinet(), "cabinet.png")
	_save(_thought_bubble(), "thought_bubble.png")
	_save(_background(native, wall), "reception_bg.png")
	quit()


# --- Illustrasjonen ----------------------------------------------------------

## Finner 240x135-tegningen igjen: median av 3x3 midt i hver blokk, så fast palett.
func _native() -> Image:
	var src := Image.load_from_file(ProjectSettings.globalize_path(SRC))
	src.convert(Image.FORMAT_RGBA8)
	var sx := float(src.get_width()) / W
	var sy := float(src.get_height()) / H
	var img := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	var counts := {}
	for y in H:
		for x in W:
			var cx := int((x + 0.5) * sx)
			var cy := int((y + 0.5) * sy)
			var rs: Array[float] = []
			var gs: Array[float] = []
			var bs: Array[float] = []
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var s := src.get_pixel(clampi(cx + dx, 0, src.get_width() - 1), clampi(cy + dy, 0, src.get_height() - 1))
					rs.append(s.r)
					gs.append(s.g)
					bs.append(s.b)
			rs.sort()
			gs.sort()
			bs.sort()
			var c := Color(rs[4], gs[4], bs[4])
			img.set_pixel(x, y, c)
			var key := Color8(c.r8 / 8 * 8, c.g8 / 8 * 8, c.b8 / 8 * 8)
			counts[key] = int(counts.get(key, 0)) + 1
	var keys := counts.keys()
	keys.sort_custom(func(a: Color, b: Color) -> bool: return counts[a] > counts[b])
	var pal: Array[Color] = []
	for k: Color in keys:
		if int(counts[k]) < 3:
			continue
		var near := false
		for p in pal:
			if _dist(p, k) < 0.06:
				near = true
				break
		if not near:
			pal.append(k)
	for y in H:
		for x in W:
			var c := img.get_pixel(x, y)
			var best := pal[0]
			var bd := 99.0
			for p in pal:
				var d := _dist(p, c)
				if d < bd:
					bd = d
					best = p
			img.set_pixel(x, y, best)
	print("intro_art: illustrasjonen gjenskapt (%d farger)" % pal.size())
	return img


## Én ren veggsøyle (y 0..59). Advarer hvis søylene rundt ikke er like (pynt i veien).
func _wall_column(native: Image) -> Array[Color]:
	var col: Array[Color] = []
	for y in WALL_H:
		col.append(native.get_pixel(WALL_REF_X, y))
	for x in range(WALL_REF_X - 4, WALL_REF_X + 5):
		for y in WALL_H:
			if _dist(native.get_pixel(x, y), col[y]) > 0.1:
				push_warning("intro_art: veggsøyla x=%d er ikke ren (y=%d)" % [x, y])
				return col
	return col


## Alt i utsnittet som skiller seg fra veggen bak.
func _cut_from_wall(native: Image, wall: Array[Color], r: Rect2i) -> Image:
	var out := Image.create_empty(r.size.x, r.size.y, false, Image.FORMAT_RGBA8)
	for y in r.size.y:
		for x in r.size.x:
			var c := native.get_pixel(r.position.x + x, r.position.y + y)
			if _dist(c, wall[r.position.y + y]) > 0.1:
				out.set_pixel(x, y, c)
	return out


# --- Rommet ------------------------------------------------------------------

func _background(native: Image, wall: Array[Color]) -> Image:
	var bg := Image.create_empty(ROOM.x, ROOM.y, false, Image.FORMAT_RGBA8)
	bg.fill(CARPET)
	for x in ROOM.x:
		var nx := x - OFS.x
		if nx < R_STAIRS.position.x:
			# Gul vegg (venstre forlengelse og venstre del av illustrasjonen). Pynten og
			# resepsjonen er egne sprites, så her er veggen bar.
			for y in WALL_H:
				bg.set_pixel(x, y, wall[y])
			# Gulvet under: fra illustrasjonen, eller gjentatt mønster til venstre for den
			# (hentet fra x 28..55, der potten ikke står i veien).
			var sx := nx if nx >= 0 else PERIOD + posmod(nx, PERIOD)
			for y in range(WALL_H, H):
				bg.set_pixel(x, y, native.get_pixel(sx, y))
		elif nx < W:
			for y in range(R_STAIRS.end.y, H):
				bg.set_pixel(x, y, native.get_pixel(nx, y))
		else:
			# Til høyre for trappa: hvit vegg (gangen på bildene), gulv som under trappa.
			var sx := R_STAIRS.end.x - PERIOD + posmod(nx - (R_STAIRS.end.x - PERIOD), PERIOD)
			for y in range(R_STAIRS.end.y, H):
				bg.set_pixel(x, y, native.get_pixel(sx, y))
	# Under resepsjonen er det bare teppekant og teppe (resepsjonen dekker resten).
	_white_wall(bg, OFS.x + W, ROOM.x)
	_doorway(bg, Rect2i(344, 8, 32, 41))
	_bottom_tiles(bg)
	return bg


func _white_wall(bg: Image, from_x: int, to_x: int) -> void:
	var h := R_STAIRS.end.y
	for x in range(from_x, to_x):
		for y in h:
			var c := Color8(224, 216, 224)
			if y < 5:
				c = Color8(152, 144, 152)
			elif y == h - 5:
				c = Color8(80, 72, 56)
			elif y >= h - 4 and y < h - 1:
				c = Color8(72, 72, 72)
			elif y == h - 1:
				c = BLACK
			bg.set_pixel(x, y, c)
	for y in h:
		bg.set_pixel(from_x, y, BLACK)


## Mørk gang innover (som på bildene), med nødutgangsskilt over.
func _doorway(bg: Image, r: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var t := float(y - r.position.y) / r.size.y
			var c := Color8(24, 24, 16).lerp(Color8(48, 48, 48), t)
			# Gulvet i gangen smalner innover.
			var floor_y := r.end.y - 9
			var inset := int((r.end.y - y) * 1.2)
			if y >= floor_y and x > r.position.x + inset - 8 and x < r.end.x - inset + 8:
				c = Color8(72, 72, 72)
			if x == r.position.x or x == r.end.x - 1 or y == r.position.y:
				c = BLACK
			bg.set_pixel(x, y, c)
	# lys helt innerst i gangen
	_rect(bg, Rect2i(r.get_center().x - 3, r.position.y + 10, 6, 14), Color8(88, 88, 96))
	_rect(bg, Rect2i(r.get_center().x - 2, r.position.y + 12, 4, 10), Color8(112, 112, 120))
	# nødutgangsskilt
	var sign_r := Rect2i(r.get_center().x - 6, 0, 12, 5)
	_rect(bg, sign_r, Color8(32, 128, 64))
	_rect(bg, Rect2i(sign_r.position.x + 2, 2, 5, 1), WHITE)
	bg.set_pixel(sign_r.position.x + 3, 1, WHITE)
	bg.set_pixel(sign_r.position.x + 3, 3, WHITE)
	_rect(bg, Rect2i(sign_r.position.x + 8, 1, 2, 3), WHITE)


## Teppet slutter, grå fliser ved inngangen nederst.
func _bottom_tiles(bg: Image) -> void:
	_rect(bg, Rect2i(0, BOTTOM_EDGE_Y, ROOM.x, 4), EDGE)
	for y in range(BOTTOM_EDGE_Y + 4, ROOM.y):
		for x in ROOM.x:
			var c := Color8(88, 88, 96)
			if x % 16 == 15 or (y - BOTTOM_EDGE_Y - 4) % 16 == 15:
				c = Color8(64, 64, 72)
			elif x % 16 == 0 or (y - BOTTOM_EDGE_Y - 4) % 16 == 0:
				c = Color8(104, 104, 112)
			bg.set_pixel(x, y, c)


# --- Tegnet her ----------------------------------------------------------------

## Glassmonter med hvite keramikkvaser (som på bildet av resepsjonen). 24x46.
func _cabinet() -> Image:
	var img := Image.create_empty(24, 46, false, Image.FORMAT_RGBA8)
	var frame := Color8(192, 192, 192)
	var glass := Color8(152, 168, 176)
	var shine := Color8(200, 212, 216)
	_rect(img, Rect2i(0, 0, 24, 42), BLACK)
	_rect(img, Rect2i(1, 1, 22, 40), frame)
	_rect(img, Rect2i(2, 3, 20, 37), glass)
	_rect(img, Rect2i(11, 3, 1, 37), frame)  # midtstolpe
	for sy in [13, 23, 33]:
		_rect(img, Rect2i(2, sy, 20, 1), frame)
	# vaser
	var vases := [[4, 9, 3, 4], [8, 10, 2, 3], [14, 8, 3, 5], [18, 10, 2, 3],
		[5, 19, 2, 4], [14, 18, 4, 5], [4, 29, 4, 4], [15, 29, 3, 4], [19, 30, 2, 3]]
	for v: Array in vases:
		_rect(img, Rect2i(v[0], v[1], v[2], v[3]), WHITE)
		_rect(img, Rect2i(v[0] + v[2] - 1, v[1] + 1, 1, v[3] - 1), frame)
	# glans på glasset
	for i in 8:
		img.set_pixel(3 + i, 30 - i * 3, shine)
		img.set_pixel(13 + i / 2, 16 - i, shine)
	# sokkel
	_rect(img, Rect2i(0, 41, 24, 5), BLACK)
	_rect(img, Rect2i(1, 42, 22, 3), Color8(168, 168, 176))
	return img


## Tankeboble, 3 ruter à 20x16: ett, to og tre prikker.
func _thought_bubble() -> Image:
	var img := Image.create_empty(60, 16, false, Image.FORMAT_RGBA8)
	for f in 3:
		var o := f * 20
		_rect(img, Rect2i(o + 4, 0, 16, 11), BLACK)
		_rect(img, Rect2i(o + 5, 1, 14, 9), WHITE)
		for corner in [Vector2i(4, 0), Vector2i(19, 0), Vector2i(4, 10), Vector2i(19, 10)]:
			img.set_pixel(o + corner.x, corner.y, Color(0, 0, 0, 0))
		_rect(img, Rect2i(o + 2, 11, 3, 3), BLACK)
		img.set_pixel(o + 3, 12, WHITE)
		img.set_pixel(o + 0, 15, BLACK)
		for d in f + 1:
			_rect(img, Rect2i(o + 7 + d * 4, 5, 2, 2), BLACK)
	return img


# --- Hjelpere ------------------------------------------------------------------

func _rect(img: Image, r: Rect2i, c: Color) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, c)


func _dist(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)


func _save(img: Image, file: String) -> void:
	var err := img.save_png(OUT + file)
	print("intro_art: %s (%dx%d) %s" % [file, img.get_width(), img.get_height(), error_string(err)])
