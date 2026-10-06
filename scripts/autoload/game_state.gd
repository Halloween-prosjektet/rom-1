extends Node
## Global spilltilstand: fase, gjenstander, flagg og input-låsing.

signal phase_changed(phase: String)
signal items_changed

const TITLE_SCENE := "res://scenes/title.tscn"

## title | intro | level | printing | done
var phase := "title"
var items: Dictionary = {}
var flags: Dictionary = {}

## Antall ting (dialog, cutscene ...) som blokkerer spillerens bevegelse.
var _locks := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()


func set_phase(p: String) -> void:
	if p == phase:
		return
	phase = p
	phase_changed.emit(p)


func add_item(id: String) -> void:
	items[id] = true
	items_changed.emit()


func has_item(id: String) -> bool:
	return items.has(id)


func lock_input() -> void:
	_locks += 1


func unlock_input() -> void:
	_locks = maxi(_locks - 1, 0)


func can_move() -> bool:
	return _locks == 0


## Kalles av kontrollskriptet (via StationLink) for å starte på nytt.
func reset_game() -> void:
	items.clear()
	flags.clear()
	_locks = 0
	Dialogue.close()
	Screen.change_scene(TITLE_SCENE)
	set_phase("title")


# Input defineres her i kode slik at alt er samlet ett sted.
# Legg til flere taster / knapper her (f.eks. en fysisk arkadeknapp).
func _setup_input() -> void:
	var keys := {
		"move_up": [KEY_UP, KEY_W],
		"move_down": [KEY_DOWN, KEY_S],
		"move_left": [KEY_LEFT, KEY_A],
		"move_right": [KEY_RIGHT, KEY_D],
		"interact": [KEY_E, KEY_SPACE, KEY_ENTER],
	}
	var buttons := {
		"move_up": [JOY_BUTTON_DPAD_UP],
		"move_down": [JOY_BUTTON_DPAD_DOWN],
		"move_left": [JOY_BUTTON_DPAD_LEFT],
		"move_right": [JOY_BUTTON_DPAD_RIGHT],
		"interact": [JOY_BUTTON_A, JOY_BUTTON_B],
	}
	for action: String in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.4)
		for code: int in keys[action]:
			var k := InputEventKey.new()
			k.physical_keycode = code as Key
			InputMap.action_add_event(action, k)
		for code: int in buttons[action]:
			var jb := InputEventJoypadButton.new()
			jb.button_index = code as JoyButton
			InputMap.action_add_event(action, jb)
	# Venstre analog-stikke
	var axes := {"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
		"move_up": [JOY_AXIS_LEFT_Y, -1.0], "move_down": [JOY_AXIS_LEFT_Y, 1.0]}
	for action: String in axes:
		var m := InputEventJoypadMotion.new()
		m.axis = axes[action][0]
		m.axis_value = axes[action][1]
		InputMap.action_add_event(action, m)
