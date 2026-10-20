extends Node
## Leser innstillinger fra res://config/defaults.cfg og overstyrer med
## station.cfg ved siden av spillfilen (eller i user://). Bruk: Config.get_value("station", "error_code")

const DEFAULTS_PATH := "res://config/defaults.cfg"
const OVERRIDE_NAME := "station.cfg"
## Serverdetaljer (kontrollrommet) ligger i .env, se .env.example. Bruk: Config.env("CONTROL_ROOM_URL")
const ENV_NAME := ".env"

var _cfg := ConfigFile.new()
var _env: Dictionary = {}


func _ready() -> void:
	var err := _cfg.load(DEFAULTS_PATH)
	if err != OK:
		push_error("Config: kunne ikke lese %s (%s)" % [DEFAULTS_PATH, err])
	for path in _override_paths():
		_merge(path)
	_load_env()
	_apply_display()


func _override_paths() -> Array[String]:
	var paths: Array[String] = []
	if not OS.has_feature("editor"):
		paths.append(OS.get_executable_path().get_base_dir().path_join(OVERRIDE_NAME))
	paths.append("user://" + OVERRIDE_NAME)
	return paths


## Verdi fra en ekte miljøvariabel, ellers fra .env-fila, ellers `default`.
func env(key: String, default: String = "") -> String:
	var value := OS.get_environment(key)
	if value != "":
		return value
	return str(_env.get(key, default))


## .env leses fra (første som har nøkkelen vinner): ved siden av spillfila (Pi-en),
## prosjektmappa (editoren), user://.
func _load_env() -> void:
	var paths: Array[String] = []
	if not OS.has_feature("editor"):
		paths.append(OS.get_executable_path().get_base_dir().path_join(ENV_NAME))
	paths.append("res://" + ENV_NAME)
	paths.append("user://" + ENV_NAME)
	for path in paths:
		if not FileAccess.file_exists(path):
			continue
		for line in FileAccess.get_file_as_string(path).split("\n"):
			var entry := _parse_env_line(line)
			if not entry.is_empty() and not _env.has(entry[0]):
				_env[entry[0]] = entry[1]
		print("Config: lastet ", path)


## 'KEY=verdi', 'export KEY="verdi"', '# kommentar' -> [key, verdi] eller []
static func _parse_env_line(line: String) -> Array:
	line = line.strip_edges()
	if line == "" or line.begins_with("#") or not "=" in line:
		return []
	if line.begins_with("export "):
		line = line.substr(7)
	var key := line.get_slice("=", 0).strip_edges()
	var value := line.substr(line.find("=") + 1).strip_edges()
	if value.length() >= 2 and value[0] in ["\"", "'"] and value.ends_with(value[0]):
		value = value.substr(1, value.length() - 2)
	elif " #" in value:
		value = value.get_slice(" #", 0).strip_edges()
	return [key, value]


func _merge(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var extra := ConfigFile.new()
	if extra.load(path) != OK:
		push_warning("Config: ugyldig fil %s" % path)
		return
	for section in extra.get_sections():
		for key in extra.get_section_keys(section):
			_cfg.set_value(section, key, extra.get_value(section, key))
	print("Config: lastet overstyringer fra ", path)


func _apply_display() -> void:
	if OS.has_feature("editor"):
		return
	if get_value("display", "fullscreen", true):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func get_value(section: String, key: String, default: Variant = null) -> Variant:
	return _cfg.get_value(section, key, default)


var error_code: String:
	get: return str(get_value("station", "error_code", "E-0000"))

var station_id: String:
	get: return str(get_value("station", "station_id", "rom-1"))


## Skal D-pad/handlingsknapp vises? ("on", "off" eller "auto" i [display] touch_controls)
func touch_controls_enabled() -> bool:
	var mode := str(get_value("display", "touch_controls", "auto"))
	return mode == "on" or (mode == "auto" and DisplayServer.is_touchscreen_available())


## Brukes av knappen på tittelskjermen. Lagres i user://station.cfg så valget
## huskes etter omstart (overstyrer defaults.cfg og station.cfg ved spillfila).
func set_touch_controls(enabled: bool) -> void:
	var mode := "on" if enabled else "off"
	_cfg.set_value("display", "touch_controls", mode)
	var user_cfg := ConfigFile.new()
	user_cfg.load("user://" + OVERRIDE_NAME)
	user_cfg.set_value("display", "touch_controls", mode)
	user_cfg.save("user://" + OVERRIDE_NAME)
