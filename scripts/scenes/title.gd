extends Control
## Tittelskjerm. Trykk hvor som helst for å starte.

const INTRO_SCENE := "res://scenes/intro/intro.tscn"

var _started := false

@onready var title: Label = $Title
@onready var subtitle: Label = $Subtitle
@onready var prompt: Label = $Prompt


func _ready() -> void:
	GameState.set_phase("title")
	title.text = Text.t("title")
	subtitle.text = Text.t("subtitle")
	prompt.text = Text.t("press_start")
	Sfx.play_loop("ambience_drone", -14.0)


func _process(_delta: float) -> void:
	prompt.modulate.a = 0.35 + 0.65 * absf(sin(Time.get_ticks_msec() / 700.0))
	# Tittelen "flimrer" av og til.
	title.modulate.a = 0.2 if randf() < 0.01 else 1.0


func _unhandled_input(event: InputEvent) -> void:
	if _started:
		return
	if event.is_action_pressed("interact") or (event is InputEventScreenTouch and event.pressed):
		_started = true
		Sfx.play("sting", -6.0)
		GameState.set_phase("intro")
		Screen.change_scene(INTRO_SCENE, 1.2)
