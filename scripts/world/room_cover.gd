@tool
class_name RoomCover
extends Node2D
## Svart "tak" over et rom slik at det ikke kan ses (eller lyse opp) fra andre
## steder i nivået. Forsvinner gradvis når spilleren går inn i rommet.
##
## Plasser noden på øverste venstre rute av området som skal skjules og sett
## size_cells. reveal_* bestemmer hvor spilleren må stå for at rommet vises
## (tom størrelse = samme område som dekket). Vises som lilla rektangel i editoren.

@export var size_cells := Vector2i(1, 1):
	set(v):
		size_cells = v
		queue_redraw()
## Øverste venstre rute (absolutte koordinater) for området som avslører rommet.
@export var reveal_origin := Vector2i.ZERO
@export var reveal_size := Vector2i.ZERO
@export var fade_time := 0.4

var _tween: Tween
var _revealed := false


func _ready() -> void:
	z_index = 100
	if Engine.is_editor_hint():
		return
	await get_tree().process_frame
	var map: LevelMap = get_tree().get_first_node_in_group("level_map")
	if map:
		map.player_stepped.connect(_on_player_stepped)
		if map.player:
			_set_revealed(_reveal_rect().has_point(map.player.cell), true)


func _reveal_rect() -> Rect2i:
	if reveal_size != Vector2i.ZERO:
		return Rect2i(reveal_origin, reveal_size)
	var origin := Vector2i(floori(global_position.x / LevelMap.TILE), floori(global_position.y / LevelMap.TILE))
	return Rect2i(origin, size_cells)


func _on_player_stepped(c: Vector2i) -> void:
	_set_revealed(_reveal_rect().has_point(c))


func _set_revealed(value: bool, instant := false) -> void:
	if value == _revealed and not instant:
		return
	_revealed = value
	if _tween:
		_tween.kill()
	var target := 0.0 if value else 1.0
	if instant:
		modulate.a = target
		return
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", target, fade_time)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, Vector2(size_cells * LevelMap.TILE))
	if Engine.is_editor_hint():
		draw_rect(r, Color(0.6, 0.3, 0.9, 0.15))
		draw_rect(r, Color(0.6, 0.3, 0.9, 0.9), false, 1.0)
	else:
		draw_rect(r, Color.BLACK)
