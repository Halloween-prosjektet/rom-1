extends Control
## Tittelskjerm. Trykk hvor som helst for å starte.
## Knappen nede til høyre slår berøringskontrollene (D-pad + !) av/på.

const NAME_SCENE := "res://scenes/name_entry.tscn"

var _started := false

@onready var title: Label = $Title
@onready var prompt: Label = $Prompt
@onready var touch_toggle: Button = $TouchToggle


func _ready() -> void:
	GameState.set_phase("title")
	title.text = Text.t("title")
	prompt.text = Text.t("press_start")
	Sfx.play_loop("ambience_drone", -14.0)
	_style_toggle()
	touch_toggle.pressed.connect(_on_touch_toggle)
	_update_touch_toggle()


func _process(_delta: float) -> void:
	prompt.modulate.a = 0.35 + 0.65 * absf(sin(Time.get_ticks_msec() / 700.0))
	# Tittelen "flimrer" av og til.
	title.modulate.a = 0.2 if randf() < 0.01 else 1.0


func _input(event: InputEvent) -> void:
	if _started:
		return
	if event is InputEventScreenTouch and touch_toggle.get_global_rect().grow(4).has_point(event.position):
		return  # trykk på av/på-knappen skal ikke starte spillet
	if event.is_action_pressed("interact") or (event is InputEventScreenTouch and event.pressed):
		_started = true
		Sfx.play("blip", -6.0)
		Screen.change_scene(NAME_SCENE, 0.6)


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
