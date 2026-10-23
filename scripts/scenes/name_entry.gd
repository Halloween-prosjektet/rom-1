extends Control
## Navneskjerm før spillet: gruppa skriver inn navnet sitt med tastaturet, slik at
## tiden kan knyttes til riktig gruppe på resultatlista. Enter starter.

const INTRO_SCENE := "res://scenes/intro/intro.tscn"
const MAX_LENGTH := 16

var _started := false
var _time := 0.0

@onready var title: Label = $Title
@onready var hint: Label = $Hint
@onready var name_edit: LineEdit = $NameEdit
@onready var prompt: Label = $Prompt
@onready var error_label: Label = $Error


func _ready() -> void:
	GameState.set_phase("name")
	title.text = Text.t("name_title")
	hint.text = Text.t("name_hint")
	prompt.text = Text.t("name_enter")
	name_edit.max_length = MAX_LENGTH
	name_edit.text_submitted.connect(func(_t: String) -> void: _start())
	name_edit.text_changed.connect(func(_t: String) -> void: error_label.text = "")
	name_edit.grab_focus()


func _process(delta: float) -> void:
	_time += delta
	prompt.modulate.a = 0.45 + 0.55 * absf(sin(_time * 2.0))
	# Tekstfeltet skal alltid ta imot tastetrykk, også etter et museklikk et annet sted.
	if not _started and not name_edit.has_focus():
		name_edit.grab_focus()


func _start() -> void:
	if _started:
		return
	var group := name_edit.text.strip_edges()
	if group == "":
		error_label.text = Text.t("name_missing")
		Sfx.play("locked", -6.0)
		return
	_started = true
	name_edit.editable = false
	GameState.player_name = group
	Sfx.play("sting", -6.0)
	GameState.set_phase("intro")
	Screen.change_scene(INTRO_SCENE, 1.2)
