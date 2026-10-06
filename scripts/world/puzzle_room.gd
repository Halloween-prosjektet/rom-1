@tool
extends Node2D
## Dytte-gåte: husker startplassen til alle kasser innenfor området og kan
## tilbakestille dem. Viser "Tilbakestill rommet"-knappen i HUD-en mens
## spilleren er inne i rommet. Plasser på øverste venstre rute.

@export var size_cells := Vector2i(1, 1):
	set(v):
		size_cells = v
		queue_redraw()
## Hvor spilleren settes ved tilbakestilling (rute, absolutte koordinater).
@export var player_reset_cell := Vector2i.ZERO

var map: LevelMap
var _crates: Array = []  # [[entity, start_cell], ...]


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group("puzzle_room")


func setup(m: LevelMap) -> void:
	map = m
	for e in get_tree().get_nodes_in_group("grid_entity"):
		if e.pushable and _rect().has_point(e.cell):
			_crates.append([e, e.cell])
	m.player_stepped.connect(_on_player_stepped)


func _rect() -> Rect2i:
	var origin := Vector2i(floori(global_position.x / LevelMap.TILE), floori(global_position.y / LevelMap.TILE))
	return Rect2i(origin, size_cells)


func _on_player_stepped(c: Vector2i) -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.set_reset_target(self if _rect().has_point(c) else null)


func reset_room() -> void:
	Sfx.play("thud", -4.0)
	await Screen.fade_out(0.3)
	for pair in _crates:
		map.unregister(pair[0])
	for pair in _crates:
		var e: GridEntity = pair[0]
		e.cell = pair[1]
		e.global_position = map.cell_to_world(pair[1])
		map.register(e)
	if map.player and map.is_free(player_reset_cell):
		map.player.place_at(player_reset_cell)
		map.player.camera.reset_smoothing()
	await Screen.fade_in(0.3)


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var r := Rect2(Vector2.ZERO, Vector2(size_cells * LevelMap.TILE))
	draw_rect(r, Color(0.3, 0.6, 1, 0.12))
	draw_rect(r, Color(0.3, 0.6, 1, 0.9), false, 1.0)
