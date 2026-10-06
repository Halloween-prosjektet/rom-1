extends Node
## Leser innstillinger fra res://config/defaults.cfg og overstyrer med
## station.cfg ved siden av spillfilen (eller i user://). Bruk: Config.get_value("station", "error_code")

const DEFAULTS_PATH := "res://config/defaults.cfg"
const OVERRIDE_NAME := "station.cfg"

var _cfg := ConfigFile.new()


func _ready() -> void:
	var err := _cfg.load(DEFAULTS_PATH)
	if err != OK:
		push_error("Config: kunne ikke lese %s (%s)" % [DEFAULTS_PATH, err])
	for path in _override_paths():
		_merge(path)
	_apply_display()


func _override_paths() -> Array[String]:
	var paths: Array[String] = []
	if not OS.has_feature("editor"):
		paths.append(OS.get_executable_path().get_base_dir().path_join(OVERRIDE_NAME))
	paths.append("user://" + OVERRIDE_NAME)
	return paths


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
