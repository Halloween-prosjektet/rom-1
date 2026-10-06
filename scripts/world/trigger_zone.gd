@tool
class_name TriggerZone
extends Node2D
## Område (i ruter) som utløser noe når spilleren går inn i det.
## Plasser noden på øverste venstre hjørne av en rute og sett size_cells.
## Vises som et oransje rektangel i editoren.

@export var size_cells := Vector2i(1, 1):
	set(v):
		size_cells = v
		queue_redraw()
@export var text_key := ""
@export var sound := ""
@export var sound_volume_db := 0.0
@export var shake := 0.0
@export var glitch := 0.0
@export var once := true
## > 0: spillerens lysradius mens man er inne i området (mørke soner).
@export var light_scale := 0.0

var fired := false


func contains(c: Vector2i) -> bool:
	var origin := Vector2i(floori(global_position.x / LevelMap.TILE), floori(global_position.y / LevelMap.TILE))
	return Rect2i(origin, size_cells).has_point(c)


func fire(_player: Node) -> void:
	if once and fired:
		return
	fired = true
	if sound != "":
		Sfx.play(sound, sound_volume_db)
	if shake > 0.0:
		Screen.shake(shake, 0.5)
	if glitch > 0.0:
		Screen.glitch(0.5, glitch)
	if text_key != "":
		await Dialogue.play(text_key)


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var r := Rect2(Vector2.ZERO, Vector2(size_cells * LevelMap.TILE))
	draw_rect(r, Color(1, 0.5, 0, 0.18))
	draw_rect(r, Color(1, 0.5, 0, 0.9), false, 1.0)
