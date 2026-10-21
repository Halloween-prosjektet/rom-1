extends SceneTree
## Lager spillerens spriteark (assets/characters/student.png) fra animasjonene
## designgruppa leverte (assets/characters/student_src/).
##
## Kjør fra prosjektmappa:
##   godot --headless --path . --script res://tools/student_sprite.gd
## Valgfritt: legg til  -- --preview=C:/sti/preview.png  for et forstørret kontrollbilde.
##
## Kildefilene: hver rute er 240x135, tegnet i 3x størrelse (80x45 ekte piksler).
##   PlayerWalkDown/Left/Up.png  16 ruter, hver tegning vist 2 ruter -> 4 gangtegninger
##   PlayerIdleAnim.png          12 ruter: står forfra, rute 6 er et blunk
##   PlayerIdleLeft/Up.png       1 rute
## Høyre finnes ikke - den speiles fra venstre.
##
## Ark: 6 kolonner x 4 rader (ned, venstre, høyre, opp). Hver rute er 24x36.
##   kolonne 0: står   1: blunk   2-5: gangsyklus
## Kolonnene brukes av Player-scenen (stand_col, blink_col, walk_cols på Actor).

const SRC := "res://assets/characters/student_src/"
const OUT := "res://assets/characters/student.png"
const SRC_W := 240
const SRC_H := 135
const SCALE := 3
## Utsnittet av 80x45-tegningen som blir én rute: figuren er 20x36 og står med
## føttene på rad 39, så rutene får samme størrelse og plassering som før.
const CROP := Rect2i(28, 4, 24, 36)
const FW := 24
const FH := 36
const COLS := 6


func _initialize() -> void:
	var walk_down := _frames("PlayerWalkDown.png")
	var walk_left := _frames("PlayerWalkLeft.png")
	var walk_up := _frames("PlayerWalkUp.png")
	var idle := _frames("PlayerIdleAnim.png")
	var idle_left: Image = _frames("PlayerIdleLeft.png")[0]
	var idle_up: Image = _frames("PlayerIdleUp.png")[0]

	# Hver gangtegning er vist i 2 ruter etter hverandre: ta annenhver av de 8 første.
	var rows := [
		[idle[0], idle[6]] + _cycle(walk_down),
		[idle_left, idle_left] + _cycle(walk_left),
		[],
		[idle_up, idle_up] + _cycle(walk_up),
	]
	for img: Image in rows[1]:
		var m := img.duplicate() as Image
		m.flip_x()
		rows[2].append(m)

	var sheet := Image.create_empty(FW * COLS, FH * 4, false, Image.FORMAT_RGBA8)
	for r in 4:
		for c in COLS:
			sheet.blit_rect(rows[r][c], Rect2i(0, 0, FW, FH), Vector2i(c * FW, r * FH))
	var err := sheet.save_png(OUT)
	print("student_sprite: lagret %s (%dx%d) - %s" % [OUT, sheet.get_width(), sheet.get_height(), error_string(err)])

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--preview="):
			var big := sheet.duplicate() as Image
			big.resize(sheet.get_width() * 4, sheet.get_height() * 4, Image.INTERPOLATE_NEAREST)
			big.save_png(arg.get_slice("=", 1))
	quit()


## Deler et kildeark i ruter, skalerer ned 3x og skjærer ut CROP.
func _frames(file: String) -> Array:
	var src := Image.load_from_file(ProjectSettings.globalize_path(SRC + file))
	src.convert(Image.FORMAT_RGBA8)
	var out := []
	for i in src.get_width() / SRC_W:
		var frame := Image.create_empty(FW, FH, false, Image.FORMAT_RGBA8)
		for y in FH:
			for x in FW:
				# Midten av hver 3x3-blokk.
				var sx := i * SRC_W + (CROP.position.x + x) * SCALE + 1
				var sy := (CROP.position.y + y) * SCALE + 1
				frame.set_pixel(x, y, src.get_pixel(sx, sy))
		out.append(frame)
	_check_outside_crop(src, file)
	return out


## Advarer hvis noe av tegningen havner utenfor utsnittet.
func _check_outside_crop(src: Image, file: String) -> void:
	for i in src.get_width() / SRC_W:
		var used := src.get_region(Rect2i(i * SRC_W, 0, SRC_W, SRC_H)).get_used_rect()
		var crop_px := Rect2i(CROP.position * SCALE, CROP.size * SCALE)
		if not crop_px.encloses(used):
			push_warning("student_sprite: %s rute %d går utenfor utsnittet (%s)" % [file, i, used])


func _cycle(frames: Array) -> Array:
	return [frames[0], frames[2], frames[4], frames[6]]
