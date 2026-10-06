extends CanvasLayer
## Dialogboks med skrivemaskin-effekt. Trykk på skjermen / handlingsknapp for å gå videre.
##   await Dialogue.play("intro.teacher")      # linjer fra dialogue_no.json
##   await Dialogue.say("Fri tekst", "system")
## Boksen bruker assets/ui/dialogue_box.png (9-slice) og assets/ui/portraits/<who>.png hvis de finnes.

signal _advance

const BOX_TEXTURE := "res://assets/ui/dialogue_box.png"
const PORTRAIT_DIR := "res://assets/ui/portraits/"

var is_open := false

var _root: Control
var _box: NinePatchRect
var _name_label: Label
var _text_label: Label
var _portrait: TextureRect
var _arrow: Label
var _typing := false
var _cps := 40.0
var _last_press_ms := 0


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cps = float(Config.get_value("display", "text_speed", 40.0))
	_build()
	_root.visible = false


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_box = NinePatchRect.new()
	if ResourceLoader.exists(BOX_TEXTURE):
		_box.texture = load(BOX_TEXTURE)
		_box.patch_margin_left = 6
		_box.patch_margin_right = 6
		_box.patch_margin_top = 6
		_box.patch_margin_bottom = 6
	_box.position = Vector2(8, 240 - 66)
	_box.size = Vector2(400 - 16, 60)
	_root.add_child(_box)

	_portrait = TextureRect.new()
	_portrait.position = Vector2(8, 8)
	_portrait.size = Vector2(44, 44)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_box.add_child(_portrait)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 9)
	_name_label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.45))
	_name_label.position = Vector2(10, 4)
	_box.add_child(_name_label)

	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.add_theme_font_size_override("font_size", 10)
	_text_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.9))
	_text_label.position = Vector2(10, 16)
	_text_label.size = Vector2(_box.size.x - 20, 40)
	_box.add_child(_text_label)

	_arrow = Label.new()
	_arrow.text = "▼"
	_arrow.add_theme_font_size_override("font_size", 8)
	_arrow.position = Vector2(_box.size.x - 14, _box.size.y - 14)
	_box.add_child(_arrow)


func play(key: String) -> void:
	await play_lines(Text.lines(key))


func say(text: String, who := "system") -> void:
	await play_lines([{"who": who, "text": text}])


func play_lines(lines: Array) -> void:
	if lines.is_empty():
		return
	GameState.lock_input()
	is_open = true
	_root.visible = true
	for line: Dictionary in lines:
		await _show_line(str(line.get("who", "system")), Text.format(str(line.get("text", ""))))
	close()
	GameState.unlock_input()
	# Unngå at samme trykk også flytter spilleren.
	await get_tree().process_frame


func close() -> void:
	is_open = false
	if _root:
		_root.visible = false


func _show_line(who: String, text: String) -> void:
	var display_name := Text.name_of(who)
	_name_label.text = display_name
	_name_label.visible = display_name != ""
	var portrait_path := PORTRAIT_DIR + who + ".png"
	var has_portrait := ResourceLoader.exists(portrait_path)
	_portrait.visible = has_portrait
	var text_x := 56.0 if has_portrait else 10.0
	_text_label.position.x = text_x
	_text_label.size.x = _box.size.x - text_x - 10
	_name_label.position.x = text_x
	if has_portrait:
		_portrait.texture = load(portrait_path)
	_text_label.position.y = 16.0 if display_name != "" else 10.0

	_text_label.text = text
	_text_label.visible_ratio = 0.0
	_arrow.visible = false
	_typing = true
	var total := text.length()
	var shown := 0.0
	while _typing and shown < total:
		await get_tree().process_frame
		var before := int(shown)
		shown += _cps * get_process_delta_time()
		_text_label.visible_characters = int(shown)
		if int(shown) != before and int(shown) % 3 == 0:
			Sfx.play("blip", -14.0, randf_range(0.95, 1.05))
	_typing = false
	_text_label.visible_ratio = 1.0
	_arrow.visible = true
	await _advance


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	# Mus emuleres som berøring (project setting), så vi lytter bare på ScreenTouch.
	var pressed: bool = event.is_action_pressed("interact") \
		or (event is InputEventScreenTouch and event.pressed)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	# Ett trykk på berørings-knappen gir både touch og action: ignorer duplikater.
	var now := Time.get_ticks_msec()
	if now - _last_press_ms < 150:
		return
	_last_press_ms = now
	if _typing:
		_typing = false
	else:
		_advance.emit()


func _process(delta: float) -> void:
	if is_open and _arrow.visible:
		_arrow.modulate.a = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0)
