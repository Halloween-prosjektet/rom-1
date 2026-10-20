extends Control
## Tittelskjerm: en mørk kjellergang som panorerer sakte bak tittelen.
## Lysrør flimrer, støv og tåke driver, og av og til skjer det noe i vinduene
## eller i døråpningen. Trykk hva som helst (tast, mus, berøring, gamepad) for å starte.
## Knappen nede til høyre slår berøringskontrollene (D-pad + !) av/på.
## Grafikken lages av tools/placeholder_art.gd (assets/ui/title_*.png). Lamper, vinduer
## og døråpningen er markører under Pano/Wall i scenen – flytt dem hvis grafikken byttes.

const NAME_SCENE := "res://scenes/name_entry.tscn"

## Hvor langt panoramaet panorerer (bredden på title_wall.png minus skjermbredden).
const PAN_RANGE := 400.0
## Sekunder for én tur fram og tilbake.
const PAN_PERIOD := 90.0
## Parallakse: hvor fort lagene flytter seg i forhold til veggen.
const SKY_FACTOR := 0.5
const FRONT_FACTOR := 1.6
## Størrelsen på hullet i hvert kjellervindu (markøren står i øvre venstre hjørne).
const WINDOW_SIZE := Vector2(30, 22)
## Bakken utenfor vinduene (der skyggen går).
const GROUND_Y := 47.0
const FLOOR_Y := 198.0
## Venter litt før input godtas, så et trykk fra forrige skjerm ikke starter spillet.
const INPUT_DELAY := 0.4
## Sekunder mellom hver skremmeeffekt (tilfeldig innenfor).
const SCARE_MIN := 14.0
const SCARE_MAX := 26.0
const GLITCH_CHARS := "#%&?/<>"

var _started := false
var _time := 0.0
var _pan := 0.0
var _lamps: Array[Lamp] = []
var _beams: Array[Polygon2D] = []
var _add_mat := CanvasItemMaterial.new()
var _title_text := ""
var _title_alpha := 0.0
var _sub_alpha := 0.0
var _prompt_alpha := 0.0
var _glitch_left := 0.0
var _next_glitch := 6.0
var _next_scare := 9.0
var _last_scare := -1
var _scare_busy := false
var _ghosts: Array[Label] = []
var _led: Sprite2D
var _exit_glow: Node2D

@onready var sky: Sprite2D = $Pano/Sky
@onready var wall: Node2D = $Pano/Wall
@onready var front: Sprite2D = $Pano/Front
@onready var shadow: Sprite2D = $Pano/Wall/Shadow
@onready var figure: Sprite2D = $Pano/Wall/Figure
@onready var glow_root: Node2D = $Pano/Wall/Glow
@onready var door_eyes: Marker2D = $Pano/Wall/DoorEyes
@onready var fog_back: Sprite2D = $FogBack
@onready var fog_front: Sprite2D = $FogFront
@onready var title: Label = $Title
@onready var subtitle: Label = $Subtitle
@onready var prompt: Label = $Prompt
@onready var touch_toggle: Button = $TouchToggle


func _ready() -> void:
	GameState.set_phase("title")
	_title_text = Text.t("title")
	title.text = _title_text
	subtitle.text = Text.t("title_sub")
	prompt.text = Text.t("press_start")
	Sfx.play_loop("ambience_drone", -14.0)
	Sfx.play_loop("hum", -26.0)
	_style_toggle()
	touch_toggle.pressed.connect(_on_touch_toggle)
	_update_touch_toggle()

	_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_build_lights()
	_build_ghosts()
	# Start et stykke inn i panoramaet, på vei mot høyre.
	_time = 0.0
	_update_layers()
	title.modulate.a = 0.0
	subtitle.modulate.a = 0.0
	prompt.modulate.a = 0.0
	_intro()


func _process(delta: float) -> void:
	_time += delta
	_update_layers()
	_update_title(delta)
	_update_props()
	if _started:
		return
	_next_glitch -= delta
	if _next_glitch <= 0.0:
		_next_glitch = randf_range(5.0, 11.0)
		_title_glitch(randf() < 0.35)
	_next_scare -= delta
	if _next_scare <= 0.0 and not _scare_busy:
		_next_scare = randf_range(SCARE_MIN, SCARE_MAX)
		_run_scare()


func _input(event: InputEvent) -> void:
	if _started or _time < INPUT_DELAY or not _is_press(event):
		return
	# Trykk på av/på-knappen skal ikke starte spillet.
	if (event is InputEventScreenTouch or event is InputEventMouseButton) \
			and touch_toggle.get_global_rect().grow(4).has_point(event.position):
		return
	_start()


## Alle tastetrykk, museklikk, berøringer og gamepad-knapper teller.
func _is_press(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventJoypadButton:
		return event.pressed
	return false


func _start() -> void:
	_started = true
	Sfx.play("blip", -6.0)
	Sfx.play("flicker", -10.0)
	# Lysene dør ut før neste skjerm.
	for lamp in _lamps:
		lamp.die()
	_title_glitch(true)
	await get_tree().create_timer(0.35).timeout
	Screen.change_scene(NAME_SCENE, 0.7)


# ----------------------------------------------------------------------
# Panorama og lys
# ----------------------------------------------------------------------

func _update_layers() -> void:
	# Kameraet driver sakte fram og tilbake (myk i endene).
	_pan = (1.0 - cos(TAU * (_time / PAN_PERIOD + 0.08))) * 0.5 * PAN_RANGE
	sky.position.x = -_pan * SKY_FACTOR
	wall.position.x = -_pan
	front.position.x = -_pan * FRONT_FACTOR
	# Tåka glir sakte av seg selv i tillegg til panoreringen.
	fog_back.region_rect.position.x = fposmod(_pan * 1.1 + _time * 4.0, 256.0)
	fog_front.region_rect.position.x = fposmod(_pan * 1.8 - _time * 6.0, 256.0)


## Er et punkt på veggen synlig på skjermen nå?
func _on_screen(wall_x: float, margin := 30.0) -> bool:
	var sx := wall_x - _pan
	return sx > margin and sx < size.x - margin


func _build_lights() -> void:
	for marker: Node2D in $Pano/Wall/Lamps.get_children():
		var lamp := Lamp.new()
		lamp.setup(_add_mat)
		lamp.position = marker.position
		lamp.base = marker.get_meta("energy", 0.9)
		lamp.flicker_rate = marker.get_meta("flicker_rate", 0.12)
		lamp.dead = marker.get_meta("dead", false)
		lamp.on_burst = _on_lamp_burst.bind(lamp)
		glow_root.add_child(lamp)
		_lamps.append(lamp)
	# Måneskinn som faller skrått inn gjennom vinduene.
	for marker: Node2D in $Pano/Wall/Windows.get_children():
		var p := marker.position
		var beam := Polygon2D.new()
		var slant := 60.0
		beam.polygon = PackedVector2Array([p + Vector2(0, WINDOW_SIZE.y), p + WINDOW_SIZE,
			Vector2(p.x + WINDOW_SIZE.x + slant, FLOOR_Y), Vector2(p.x + slant, FLOOR_Y)])
		var top := Color(0.55, 0.65, 1.0, 0.09)
		var bottom := Color(0.55, 0.65, 1.0, 0.0)
		beam.vertex_colors = PackedColorArray([top, top, bottom, bottom])
		beam.material = _add_mat
		glow_root.add_child(beam)
		glow_root.move_child(beam, 0)
		_beams.append(beam)
	# Feillampa på den gamle skriveren blinker rødt.
	_led = _glow_sprite($Pano/Wall/PrinterLed.position, Vector2(0.07, 0.07), Color(1.0, 0.15, 0.1, 0.9))
	glow_root.add_child(_led)
	# Grønt nødutgang-skilt.
	_exit_glow = Node2D.new()
	_exit_glow.position = $Pano/Wall/ExitSign.position
	var sign_face := Polygon2D.new()
	sign_face.polygon = PackedVector2Array([Vector2(-6, -3), Vector2(6, -3), Vector2(6, 3), Vector2(-6, 3)])
	sign_face.color = Color(0.25, 0.75, 0.45)
	sign_face.material = _add_mat
	_exit_glow.add_child(sign_face)
	_exit_glow.add_child(_glow_sprite(Vector2.ZERO, Vector2(0.25, 0.15), Color(0.3, 1.0, 0.5, 0.3)))
	glow_root.add_child(_exit_glow)


func _glow_sprite(pos: Vector2, scl: Vector2, col: Color) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = LightTex.radial()
	s.position = pos
	s.scale = scl
	s.modulate = col
	s.material = _add_mat
	return s


func _update_props() -> void:
	_led.visible = fmod(_time, 1.2) < 0.6
	# Nødutgang-skiltet sprekker av og til.
	_exit_glow.modulate.a = 0.15 if fmod(_time, 13.0) < 0.12 or (fmod(_time, 13.0) > 0.2 and fmod(_time, 13.0) < 0.27) else 1.0
	# Måneskinnet puster svakt (skyer som driver forbi).
	var moon := 0.75 + 0.25 * sin(_time * 0.3)
	for beam in _beams:
		beam.self_modulate.a = moon


func _on_lamp_burst(lamp: Lamp) -> void:
	if not _started and _on_screen(lamp.position.x, 0.0):
		Sfx.play("flicker", -20.0, randf_range(0.85, 1.1))


# ----------------------------------------------------------------------
# Tittel
# ----------------------------------------------------------------------

func _build_ghosts() -> void:
	# To fargede kopier bak tittelen, vises bare når den "glitcher".
	for col: Color in [Color(0.1, 0.85, 0.95), Color(1.0, 0.1, 0.25)]:
		var g: Label = title.duplicate()
		g.add_theme_color_override("font_color", col)
		g.add_theme_constant_override("outline_size", 0)
		g.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		g.visible = false
		add_child(g)
		move_child(g, title.get_index())
		_ghosts.append(g)


func _update_title(delta: float) -> void:
	# Hjerteslag: to raske pulser, så pause.
	var p := fmod(_time, 2.4)
	var beat := maxf(0.0, 1.0 - absf(p - 0.12) / 0.14) + 0.6 * maxf(0.0, 1.0 - absf(p - 0.42) / 0.14)
	var b := 0.82 + 0.3 * beat
	title.modulate = Color(b, b * 0.95, b * 0.95, _title_alpha)
	title.pivot_offset = title.size * 0.5
	title.scale = Vector2.ONE * (1.0 + 0.02 * beat)
	subtitle.modulate.a = _sub_alpha
	prompt.modulate.a = _prompt_alpha * (0.4 + 0.6 * absf(sin(_time * 1.6)))

	if _glitch_left > 0.0:
		_glitch_left -= delta
		var jitter := Vector2(randi_range(-3, 3), randi_range(-1, 1))
		title.position.x = jitter.x
		for i in _ghosts.size():
			var g := _ghosts[i]
			g.visible = randf() < 0.8
			g.position = Vector2(jitter.x + (3 if i == 0 else -3) + randi_range(-1, 1), title.position.y + randi_range(-1, 1))
			g.text = title.text
			g.modulate = Color(1, 1, 1, 0.6 * _title_alpha)
			g.scale = title.scale
			g.pivot_offset = title.pivot_offset
		title.text = _corrupt(_title_text) if randf() < 0.35 else _title_text
		if randf() < 0.15:
			title.modulate.a *= 0.3
		if _glitch_left <= 0.0:
			title.position.x = 0.0
			title.text = _title_text
			for g in _ghosts:
				g.visible = false


func _corrupt(s: String) -> String:
	if s.is_empty():
		return s
	var i := randi() % s.length()
	return s.substr(0, i) + GLITCH_CHARS[randi() % GLITCH_CHARS.length()] + s.substr(i + 1)


func _title_glitch(strong: bool) -> void:
	_glitch_left = randf_range(0.15, 0.35)
	if strong:
		Screen.glitch(0.3, 0.45)
		Sfx.play("static", -24.0)


## Lysene tennes ett og ett, så glitcher tittelen fram.
func _intro() -> void:
	await get_tree().create_timer(0.4).timeout
	for lamp in _lamps:
		if _started:
			return
		lamp.power_on()
		await get_tree().create_timer(0.22).timeout
	var tw := create_tween()
	tw.tween_callback(_title_glitch.bind(true))
	tw.tween_property(self, "_title_alpha", 1.0, 0.5)
	tw.tween_property(self, "_sub_alpha", 0.85, 0.6)
	tw.tween_property(self, "_prompt_alpha", 1.0, 0.6)


# ----------------------------------------------------------------------
# Skremmeeffekter (sjeldne og korte, bare der kameraet ser)
# ----------------------------------------------------------------------

func _run_scare() -> void:
	var order := [0, 1, 2, 3]
	order.shuffle()
	order.erase(_last_scare)
	order.append(_last_scare)  # samme effekt to ganger på rad bare hvis ingen andre passer
	for kind: int in order:
		if kind >= 0 and _try_scare(kind):
			_last_scare = kind
			return


func _try_scare(kind: int) -> bool:
	match kind:
		0:
			if _visible_windows().is_empty():
				return false
			_scare_walk()
		1:
			var wins := _visible_windows()
			if wins.is_empty():
				return false
			_scare_peek(wins.pick_random())
		2:
			if not _on_screen(door_eyes.position.x + 8.0, 40.0):
				return false
			_scare_eyes()
		3:
			var lamps := _lamps.filter(func(l: Lamp) -> bool: return not l.dead and l.energy > 0.5 and _on_screen(l.position.x, 50.0))
			if lamps.is_empty():
				return false
			_scare_lamp_figure(lamps.pick_random())
	return true


func _visible_windows() -> Array[Node2D]:
	var out: Array[Node2D] = []
	for w: Node2D in $Pano/Wall/Windows.get_children():
		if _on_screen(w.position.x + WINDOW_SIZE.x * 0.5, 20.0):
			out.append(w)
	return out


## Noen går forbi utenfor kjellervinduene – bare beina synes.
func _scare_walk() -> void:
	_scare_busy = true
	var dir := 1.0 if randf() < 0.5 else -1.0
	shadow.frame = 0
	shadow.flip_h = dir < 0.0
	shadow.position = Vector2(_pan - 24.0 if dir > 0.0 else _pan + size.x + 8.0, GROUND_Y - 32.0)
	shadow.visible = true
	var step := 0.0
	var t := 0.0
	while t < 40.0 and not _started:
		var d := get_process_delta_time()
		t += d
		step += d
		shadow.position.x += dir * 30.0 * d
		if step > 0.3:
			step = 0.0
			shadow.frame = 1 - shadow.frame
			if shadow.frame == 0 and _on_screen(shadow.position.x + 8.0, 0.0):
				Sfx.play("footstep", -24.0, 0.6)
		_shade_beams(shadow.position.x + 8.0)
		var sx := shadow.position.x - _pan
		if (dir > 0.0 and sx > size.x + 10.0) or (dir < 0.0 and sx < -26.0):
			break
		await get_tree().process_frame
	shadow.visible = false
	_shade_beams(-1000.0)
	_scare_busy = false


## Et hode dukker opp i et vindu, blir der litt og forsvinner.
func _scare_peek(win: Node2D) -> void:
	_scare_busy = true
	shadow.frame = 2
	shadow.flip_h = false
	var x := win.position.x + WINDOW_SIZE.x * 0.5 - 8.0
	shadow.position = Vector2(x, win.position.y + WINDOW_SIZE.y)
	shadow.visible = true
	_shade_beams(x + 8.0)
	var tw := create_tween()
	tw.tween_property(shadow, "position:y", win.position.y + 3.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(Sfx.play.bind("whisper", -24.0))
	tw.tween_interval(1.6)
	tw.tween_property(shadow, "position:y", win.position.y + WINDOW_SIZE.y, 0.15)
	await tw.finished
	shadow.visible = false
	_shade_beams(-1000.0)
	_scare_busy = false


## To lyse øyne i den mørke døråpningen. Blunker én gang og er borte.
func _scare_eyes() -> void:
	_scare_busy = true
	figure.position = door_eyes.position
	figure.modulate.a = 0.0
	figure.visible = true
	var tw := create_tween()
	tw.tween_property(figure, "modulate:a", 1.0, 1.5)
	tw.tween_interval(1.8)
	tw.tween_property(figure, "modulate:a", 0.0, 0.05)
	tw.tween_interval(0.12)
	tw.tween_property(figure, "modulate:a", 1.0, 0.05)
	tw.tween_interval(0.7)
	tw.tween_property(figure, "modulate:a", 0.0, 0.3)
	await tw.finished
	figure.visible = false
	_scare_busy = false


## Lyset blinker – i ett glimt står det noen under lampa.
func _scare_lamp_figure(lamp: Lamp) -> void:
	_scare_busy = true
	lamp.hold = true
	figure.position = Vector2(lamp.position.x - 8.0, FLOOR_Y - 40.0)
	figure.modulate.a = 1.0
	Sfx.play("flicker", -14.0)
	var tw := create_tween()
	tw.tween_property(lamp, "energy", 0.0, 0.04)
	tw.tween_interval(0.35)
	tw.tween_callback(figure.show)
	tw.tween_property(lamp, "energy", lamp.base, 0.03)
	tw.tween_interval(0.14)
	tw.tween_property(lamp, "energy", 0.0, 0.03)
	tw.tween_callback(figure.hide)
	tw.tween_interval(0.6)
	tw.tween_property(lamp, "energy", lamp.base * 0.6, 0.04)
	tw.tween_property(lamp, "energy", 0.1, 0.06)
	tw.tween_property(lamp, "energy", lamp.base, 0.08)
	await tw.finished
	lamp.hold = false
	_scare_busy = false


## Måneskinnet blir svakere når noe står foran vinduet.
func _shade_beams(x: float) -> void:
	var wins := $Pano/Wall/Windows.get_children()
	for i in _beams.size():
		var wx: float = wins[i].position.x
		_beams[i].modulate.a = 0.25 if x > wx - 4.0 and x < wx + WINDOW_SIZE.x + 4.0 else 1.0


# ----------------------------------------------------------------------
# Av/på-knapp for berøringskontroller
# ----------------------------------------------------------------------

func _on_touch_toggle() -> void:
	Config.set_touch_controls(not Config.touch_controls_enabled())
	Sfx.play("blip", -6.0)
	_update_touch_toggle()


func _update_touch_toggle() -> void:
	var on := Config.touch_controls_enabled()
	touch_toggle.text = Text.t("touch_on") if on else Text.t("touch_off")
	# Grønnaktig kant når på, grå når av.
	var border := Color(0.45, 0.75, 0.5) if on else Color(0.4, 0.4, 0.45)
	for state: String in ["normal", "hover", "pressed"]:
		var sb: StyleBoxFlat = touch_toggle.get_theme_stylebox(state)
		sb.border_color = border if state != "hover" else border.lightened(0.25)
	touch_toggle.add_theme_color_override("font_color", border.lightened(0.35))
	touch_toggle.add_theme_color_override("font_hover_color", border.lightened(0.5))
	touch_toggle.add_theme_color_override("font_pressed_color", border.lightened(0.5))


## Mørk, avrundet knapp med tynn kant som passer resten av menyen.
func _style_toggle() -> void:
	var make := func(bg: Color) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		return sb
	touch_toggle.add_theme_stylebox_override("normal", make.call(Color(0.06, 0.06, 0.08, 0.9)))
	touch_toggle.add_theme_stylebox_override("hover", make.call(Color(0.1, 0.1, 0.13, 0.95)))
	touch_toggle.add_theme_stylebox_override("pressed", make.call(Color(0.14, 0.14, 0.18, 1.0)))
	touch_toggle.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


# ----------------------------------------------------------------------

## Ett lysrør: selve røret, glorie, lyskjegle og lysflekk på gulvet.
## Alt tegnes additivt (ingen ekte 2D-lys), så det er billig på Pi-en.
class Lamp extends Node2D:
	var base := 0.9
	## Sjanse per sekund for at lampa begynner å blinke.
	var flicker_rate := 0.12
	## Nesten alltid av, men spraker til av og til.
	var dead := false
	## Settes mens en skremmeeffekt styrer lampa.
	var hold := false
	var on_burst: Callable
	var energy := 0.0:
		set(v):
			energy = v
			modulate.a = clampf(v, 0.0, 1.0)

	var _timer := 0.0
	var _tween: Tween
	var _running := false

	func setup(add_mat: Material) -> void:
		modulate.a = 0.0
		# Lyset på veggen bak lampa
		add_child(_sprite(Vector2(0, 50), Vector2(0.75, 0.55), Color(1.0, 0.9, 0.7, 0.16), add_mat))
		# Lyskjegle ned mot gulvet
		var cone := Polygon2D.new()
		cone.polygon = PackedVector2Array([Vector2(-11, 1), Vector2(11, 1), Vector2(58, 170), Vector2(-58, 170)])
		var top := Color(1.0, 0.95, 0.8, 0.14)
		var bottom := Color(1.0, 0.95, 0.8, 0.02)
		cone.vertex_colors = PackedColorArray([top, top, bottom, bottom])
		cone.material = add_mat
		add_child(cone)
		# Lysflekk på gulvet og glorie rundt røret
		add_child(_sprite(Vector2(0, 176), Vector2(0.55, 0.1), Color(1.0, 0.9, 0.7, 0.4), add_mat))
		add_child(_sprite(Vector2(0, 0), Vector2(0.4, 0.22), Color(1.0, 0.95, 0.8, 0.5), add_mat))
		# Selve lysrøret
		var tube := Polygon2D.new()
		tube.polygon = PackedVector2Array([Vector2(-11, 0), Vector2(11, 0), Vector2(11, 1), Vector2(-11, 1)])
		tube.color = Color(1.0, 0.98, 0.9)
		add_child(tube)

	func _sprite(pos: Vector2, scl: Vector2, col: Color, mat: Material) -> Sprite2D:
		var s := Sprite2D.new()
		s.texture = LightTex.radial()
		s.position = pos
		s.scale = scl
		s.modulate = col
		s.material = mat
		return s

	func _process(delta: float) -> void:
		if not _running or hold:
			return
		_timer -= delta
		if _timer <= 0.0:
			_timer = randf_range(1.0, 2.0 / maxf(flicker_rate, 0.01))
			burst()

	## Tennes med litt blinking (brukes i introen).
	func power_on() -> void:
		_running = true
		_timer = randf_range(2.0, 6.0)
		burst()

	func burst() -> void:
		if _tween:
			_tween.kill()
		if on_burst.is_valid():
			on_burst.call()
		_tween = create_tween()
		var target := base
		if dead:
			# Død lampe: et par svake gnister, så mørkt igjen.
			for i in randi_range(1, 3):
				_tween.tween_property(self, "energy", base * randf_range(0.3, 0.7), 0.03)
				_tween.tween_property(self, "energy", 0.0, randf_range(0.05, 0.15))
			return
		for i in randi_range(2, 6):
			_tween.tween_property(self, "energy", base * randf_range(0.0, 0.25), randf_range(0.03, 0.08))
			_tween.tween_property(self, "energy", base * randf_range(0.6, 1.0), randf_range(0.03, 0.1))
		if randf() < 0.25:
			_tween.tween_property(self, "energy", 0.0, 0.05)
			_tween.tween_interval(randf_range(0.4, 1.2))
		_tween.tween_property(self, "energy", target, 0.1)

	## Slukker med et siste blink (når spillet starter).
	func die() -> void:
		_running = false
		if _tween:
			_tween.kill()
		_tween = create_tween()
		_tween.tween_property(self, "energy", base * 0.3, 0.04)
		_tween.tween_property(self, "energy", base, 0.04)
		_tween.tween_property(self, "energy", 0.0, randf_range(0.05, 0.2))
