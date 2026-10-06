extends Node
## All tekst ligger i res://data/dialogue_no.json. Bytt fil her for et annet språk.

const TEXT_PATH := "res://data/dialogue_no.json"

var _data: Dictionary = {}


func _ready() -> void:
	var raw := FileAccess.get_file_as_string(TEXT_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	if parsed is Dictionary:
		_data = parsed
	else:
		push_error("Text: kunne ikke lese %s" % TEXT_PATH)


## Enkel UI-tekst: Text.t("press_start")
func t(key: String) -> String:
	return _format(str(_data.get("ui", {}).get(key, key)))


## Dialoglinjer: [{who, text}, ...]. Ukjent nøkkel gir én linje med nøkkelen selv.
func lines(key: String) -> Array:
	var entry: Variant = _data.get("lines", {}).get(key)
	if entry == null:
		push_warning("Text: mangler dialog '%s'" % key)
		return [{"who": "system", "text": key}]
	if entry is String:
		return [{"who": "system", "text": entry}]
	return entry


func has_lines(key: String) -> bool:
	return _data.get("lines", {}).has(key)


func name_of(who: String) -> String:
	return str(_data.get("names", {}).get(who, ""))


func pool_random(pool: String) -> String:
	var items: Array = _data.get("pools", {}).get(pool, [])
	if items.is_empty():
		return ""
	return _format(str(items.pick_random()))


func _format(s: String) -> String:
	return s.replace("{code}", Config.error_code)


func format(s: String) -> String:
	return _format(s)
