extends Node
## Global spilltilstand: fase, gjenstander, flagg og input-låsing.

signal phase_changed(phase: String)
signal items_changed
signal timer_stopped(ms: int)

const TITLE_SCENE := "res://scenes/title.tscn"
## Alle resultater (gruppenavn + tid) legges til her, én linje per gruppe.
const RESULTS_FILE := "user://resultater.csv"

## title | name | intro | level | printing | done
var phase := "title"
var items: Dictionary = {}
var flags: Dictionary = {}
## Gruppenavnet fra navneskjermen.
var player_name := ""

var _timer_start_ms := -1
var _timer_end_ms := -1

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


## Kalles av kontrollskriptet (via StationLink) eller "Ny gruppe"-knappen.
func reset_game() -> void:
	items.clear()
	flags.clear()
	player_name = ""
	_timer_start_ms = -1
	_timer_end_ms = -1
	_locks = 0
	Dialogue.close()
	Screen.change_scene(TITLE_SCENE)
	set_phase("title")


# --- Tidtaking --------------------------------------------------------------

## Startes når introen er ferdig (spilleren kommer ned i kjelleren).
func start_timer() -> void:
	_timer_start_ms = Time.get_ticks_msec()
	_timer_end_ms = -1


## Stoppes når spilleren bruker skriveren. Lagrer resultatet i RESULTS_FILE.
func stop_timer() -> void:
	if not timer_running():
		return
	_timer_end_ms = Time.get_ticks_msec()
	_save_result()
	timer_stopped.emit(elapsed_ms())


func timer_running() -> bool:
	return _timer_start_ms >= 0 and _timer_end_ms < 0


func timer_started() -> bool:
	return _timer_start_ms >= 0


func elapsed_ms() -> int:
	if _timer_start_ms < 0:
		return 0
	var end := _timer_end_ms if _timer_end_ms >= 0 else Time.get_ticks_msec()
	return end - _timer_start_ms


## 83456 -> "01:23.4"
static func format_time(ms: int) -> String:
	var tenths := ms / 100
	return "%02d:%02d.%d" % [tenths / 600, (tenths / 10) % 60, tenths % 10]


func _save_result() -> void:
	var is_new := not FileAccess.file_exists(RESULTS_FILE)
	var f := FileAccess.open(RESULTS_FILE, FileAccess.READ_WRITE if not is_new else FileAccess.WRITE)
	if f == null:
		push_warning("GameState: kunne ikke skrive %s" % RESULTS_FILE)
		return
	f.seek_end()
	if is_new:
		f.store_line("tidspunkt,stasjon,gruppe,millisekunder,tid")
	var safe_name := player_name.replace('"', "'")
	f.store_line('%s,%s,"%s",%d,%s' % [Time.get_datetime_string_from_system(false, true),
		Config.station_id, safe_name, elapsed_ms(), format_time(elapsed_ms())])
	print("GameState: resultat lagret - %s %s" % [player_name, format_time(elapsed_ms())])


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
