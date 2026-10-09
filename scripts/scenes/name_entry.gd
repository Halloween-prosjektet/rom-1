extends Control
## Navneskjerm før spillet: gruppa skriver inn navnet sitt, slik at tiden
## kan knyttes til riktig gruppe på resultatlista.
## Har eget skjermtastatur (berøringsskjermen på Pi-en har ikke noe innebygd),
## men et vanlig tastatur virker også.

const INTRO_SCENE := "res://scenes/intro/intro.tscn"
const MAX_LENGTH := 16
const KEY_ROWS := ["1234567890", "QWERTYUIOPÅ", "ASDFGHJKLØÆ", "ZXCVBNM-"]
const KEY_SIZE := Vector2(30, 22)
const KEY_GAP := 3.0

var _started := false

@onready var title: Label = $Title
@onready var hint: Label = $Hint
@onready var name_edit: LineEdit = $NameEdit
@onready var keys: Control = $Keys
@onready var error_label: Label = $Error


func _ready() -> void:
	GameState.set_phase("name")
	title.text = Text.t("name_title")
	hint.text = Text.t("name_hint")
	name_edit.max_length = MAX_LENGTH
	name_edit.text_submitted.connect(func(_t: String) -> void: _start())
	name_edit.text_changed.connect(func(_t: String) -> void: error_label.text = "")
	_build_keyboard()
	name_edit.grab_focus()


func _build_keyboard() -> void:
	var y := 0.0
	for row: String in KEY_ROWS:
		var width := row.length() * KEY_SIZE.x + (row.length() - 1) * KEY_GAP
		var x := (400.0 - width) / 2.0
		for ch in row:
			_add_key(ch, Vector2(x, y), KEY_SIZE, _type.bind(ch))
			x += KEY_SIZE.x + KEY_GAP
		y += KEY_SIZE.y + KEY_GAP
	y += 3.0
	var bottom := [
		[Text.t("name_delete"), 70.0, _backspace],
		[Text.t("name_space"), 130.0, _type.bind(" ")],
		[Text.t("name_start"), 90.0, _start],
	]
	var total := 0.0
	for b: Array in bottom:
		total += b[1]
	total += KEY_GAP * 2 * (bottom.size() - 1)
	var bx := (400.0 - total) / 2.0
	for b: Array in bottom:
		var button := _add_key(b[0], Vector2(bx, y), Vector2(b[1], 26), b[2])
		if b[2] == _start:
			button.add_theme_color_override("font_color", Color(0.95, 0.8, 0.35))
		bx += b[1] + KEY_GAP * 2


func _add_key(label: String, pos: Vector2, size: Vector2, action: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.position = pos
	b.size = size
	b.focus_mode = Control.FOCUS_NONE  # LineEdit beholder fokus
	b.add_theme_font_size_override("font_size", 10)
	b.pressed.connect(func() -> void:
		Sfx.play("blip", -10.0)
		action.call())
	keys.add_child(b)
	return b


func _type(ch: String) -> void:
	var text := name_edit.text
	if text.length() >= MAX_LENGTH:
		return
	if ch == " " and (text == "" or text.ends_with(" ")):
		return
	# Stor forbokstav i hvert ord, ellers små bokstaver.
	if text != "" and not text.ends_with(" "):
		ch = ch.to_lower()
	name_edit.text = text + ch
	name_edit.caret_column = name_edit.text.length()
	error_label.text = ""


func _backspace() -> void:
	name_edit.text = name_edit.text.left(-1)
	name_edit.caret_column = name_edit.text.length()


func _start() -> void:
	if _started:
		return
	var group := name_edit.text.strip_edges()
	if group == "":
		error_label.text = Text.t("name_missing")
		Sfx.play("locked", -6.0)
		return
	_started = true
	GameState.player_name = group
	Sfx.play("sting", -6.0)
	GameState.set_phase("intro")
	Screen.change_scene(INTRO_SCENE, 1.2)
