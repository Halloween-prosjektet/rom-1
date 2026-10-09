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
	touch_toggle.text = Text.t("touch_on") if Config.touch_controls_enabled() else Text.t("touch_off")
