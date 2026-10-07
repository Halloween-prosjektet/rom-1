class_name LevelMap
extends Node2D
## Bygger et rutenett-nivå fra en ASCII-fil (data/maps/*.txt) og holder styr på
## hvem som står hvor. Unike ting (NPC-er, dører, kasser med nøkler, triggere)
## legges som vanlige noder under Entities / Triggers i scenen.
##
## Tegnforklaring i kartfilen:
##   ' ' tomrom (svart)     '#' vegg            '.' gulv        ',' flekk/teppe på gulvet
##   '=' trapp (stengt)     'C' kasse (kan dyttes)              'S' hylle
##   'J' skrap (tilfeldig)  'D' pult            'K' skranke     'p' plante
##   'L' blinkende taklys   'l' stødig taklys

signal player_stepped(cell: Vector2i)

const TILE := 16

# Plassering i tile-atlaset (se assets/README.md)
const T_FLOOR := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
const T_FLOOR_SPECIAL := Vector2i(4, 0)
const T_STAIRS := Vector2i(5, 0)
const T_FLOOR_DARK := Vector2i(7, 0)
const T_WALL_TOP := Vector2i(0, 1)
const T_FACE_LOW := [Vector2i(1, 1), Vector2i(2, 1)]
const T_FACE_HIGH := [Vector2i(3, 1), Vector2i(4, 1)]
const ATLAS_SIZE := Vector2i(8, 2)

const PROP_SCENES := {
	"C": "res://scenes/props/crate.tscn",
	"S": "res://scenes/props/shelf.tscn",
	"J": "res://scenes/props/junk.tscn",
	"D": "res://scenes/props/desk.tscn",
	"K": "res://scenes/props/counter.tscn",
	"p": "res://scenes/props/plant.tscn",
	"L": "res://scenes/props/flicker_light.tscn",
	"l": "res://scenes/props/lamp_light.tscn",
}
const SOLID_TILES := "# ="

@export_file("*.txt") var map_file := ""
@export var tile_atlas: Texture2D
## Mørket over hele nivået (CanvasModulate). Lys legges oppå.
@export var ambient_color := Color(0.12, 0.12, 0.15)
@export var ambience_sound := ""
@export var ambience_volume_db := -6.0
## Nøkkel i "ui" i dialogue_no.json, vises nede til venstre ved start.
@export var location_key := ""
## Dialog når man undersøker trappa ('=').
@export var stairs_text_key := ""

var map_size := Vector2i.ZERO
var tile_layer: TileMapLayer
var player: Player

var _rows: PackedStringArray = []
var _occupants: Dictionary = {}  # Vector2i -> GridEntity
var _astar := AStarGrid2D.new()
var _inside_triggers: Dictionary = {}
var _canvas_modulate: CanvasModulate
var _ambient_tween: Tween
var _ambient_target := Color(-1, -1, -1)
var _lights_off := false

@onready var entities: Node2D = $Entities
@onready var triggers: Node2D = get_node_or_null("Triggers")


func _ready() -> void:
	add_to_group("level_map")
	_canvas_modulate = CanvasModulate.new()
	_canvas_modulate.color = ambient_color
	_ambient_target = ambient_color
	add_child(_canvas_modulate)

	_load_map()
	_build_tiles()
	_setup_astar()
	_spawn_props()
	for n in get_tree().get_nodes_in_group("grid_entity"):
		if is_ancestor_of(n):
			n.setup(self)
	player = get_tree().get_first_node_in_group("player")
	if player:
		player.stepped.connect(_on_player_stepped)
	for room in get_tree().get_nodes_in_group("puzzle_room"):
		room.setup(self)

	if ambience_sound != "":
		Sfx.play_loop(ambience_sound, ambience_volume_db)
	if location_key != "":
		Screen.show_location(Text.t(location_key))


# --- Kart ---------------------------------------------------------------

func _load_map() -> void:
	var raw := FileAccess.get_file_as_string(map_file)
	if raw == "":
		push_error("LevelMap: tomt eller manglende kart %s" % map_file)
	_rows = raw.replace("\r", "").split("\n")
	while _rows.size() > 0 and _rows[_rows.size() - 1].strip_edges() == "":
		_rows.remove_at(_rows.size() - 1)
	var w := 0
	for r in _rows:
		w = maxi(w, r.length())
	map_size = Vector2i(w, _rows.size())


func char_at(c: Vector2i) -> String:
	if c.y < 0 or c.y >= _rows.size() or c.x < 0:
		return " "
	var row := _rows[c.y]
	return row[c.x] if c.x < row.length() else " "


func _is_floorish(ch: String) -> bool:
	return ch != "#" and ch != " "


func _hash(c: Vector2i) -> int:
	return absi((c.x * 73856093) ^ (c.y * 19349663) ^ 0x5bd1e995) % 1000


func _tile_for(c: Vector2i) -> Vector2i:
	var ch := char_at(c)
	var h := _hash(c)
	match ch:
		" ":
			return Vector2i(-1, -1)
		"#":
			var below := char_at(c + Vector2i.DOWN)
			var below2 := char_at(c + Vector2i.DOWN * 2)
			if _is_floorish(below):
				return T_FACE_LOW[1] if h % 100 < 18 else T_FACE_LOW[0]
			if below == "#" and _is_floorish(below2):
				return T_FACE_HIGH[1] if h % 100 < 18 else T_FACE_HIGH[0]
			return T_WALL_TOP
		"=":
			return T_STAIRS
		",":
			return T_FLOOR_SPECIAL
		_:
			if h % 100 < 70:
				return T_FLOOR[0]
			if h % 100 < 97:
				return T_FLOOR[1 + h % 3]
			return T_FLOOR_DARK


func _build_tiles() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	var src := TileSetAtlasSource.new()
	src.texture = tile_atlas
	src.texture_region_size = Vector2i(TILE, TILE)
	for y in ATLAS_SIZE.y:
		for x in ATLAS_SIZE.x:
			src.create_tile(Vector2i(x, y))
	ts.add_source(src, 0)

	tile_layer = TileMapLayer.new()
	tile_layer.name = "Tiles"
	tile_layer.tile_set = ts
	tile_layer.z_index = -10
	add_child(tile_layer)
	move_child(tile_layer, 0)
	for y in map_size.y:
		for x in map_size.x:
			var atlas := _tile_for(Vector2i(x, y))
			if atlas.x >= 0:
				tile_layer.set_cell(Vector2i(x, y), 0, atlas)


func _spawn_props() -> void:
	var cache := {}
	for y in map_size.y:
		for x in map_size.x:
			var ch := char_at(Vector2i(x, y))
			if not PROP_SCENES.has(ch):
				continue
			if not cache.has(ch):
				cache[ch] = load(PROP_SCENES[ch])
			var node: Node2D = cache[ch].instantiate()
			node.global_position = cell_to_world(Vector2i(x, y))
			entities.add_child(node)


# --- Rutenett / pathfinding ---------------------------------------------

func _setup_astar() -> void:
	_astar.region = Rect2i(Vector2i.ZERO, map_size)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.update()
	for y in map_size.y:
		for x in map_size.x:
			var c := Vector2i(x, y)
			_astar.set_point_solid(c, is_tile_solid(c))


func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.y / TILE))


func cell_to_world(c: Vector2i) -> Vector2:
	return Vector2(c * TILE) + Vector2(TILE, TILE) * 0.5


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < map_size.x and c.y < map_size.y


func is_tile_solid(c: Vector2i) -> bool:
	return not in_bounds(c) or SOLID_TILES.contains(char_at(c))


func get_occupant(c: Vector2i) -> GridEntity:
	var e: GridEntity = _occupants.get(c)
	return e if is_instance_valid(e) else null


func is_free(c: Vector2i) -> bool:
	if is_tile_solid(c):
		return false
	var e := get_occupant(c)
	return e == null or not e.solid


func tile_text(c: Vector2i) -> String:
	if char_at(c) == "=" and stairs_text_key != "":
		return stairs_text_key
	return ""


func register(e: GridEntity) -> void:
	_occupants[e.cell] = e
	refresh_cell(e.cell)


func unregister(e: GridEntity) -> void:
	if _occupants.get(e.cell) == e:
		_occupants.erase(e.cell)
	refresh_cell(e.cell)


func move_occupant(e: GridEntity, from: Vector2i, to: Vector2i) -> void:
	if _occupants.get(from) == e:
		_occupants.erase(from)
	_occupants[to] = e
	refresh_cell(from)
	refresh_cell(to)


func refresh_cell(c: Vector2i) -> void:
	if in_bounds(c):
		_astar.set_point_solid(c, not is_free(c))


## Sti fra -> til (uten startcella). Tom liste hvis det ikke finnes vei.
func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if from == to or not in_bounds(to) or not is_free(to):
		return result
	var was_solid := _astar.is_point_solid(from)
	_astar.set_point_solid(from, false)
	var path := _astar.get_id_path(from, to)
	_astar.set_point_solid(from, was_solid)
	for i in range(1, path.size()):
		result.append(path[i])
	return result


# --- Triggere -----------------------------------------------------------

func _on_player_stepped(c: Vector2i) -> void:
	player_stepped.emit(c)
	if triggers == null:
		return
	var light_scale := 0.0
	var ambient := ambient_color
	var lights_off := false
	for t in triggers.get_children():
		if not t.has_method("contains"):
			continue
		var inside: bool = t.contains(c)
		if inside and t.light_scale > 0.0:
			light_scale = t.light_scale if light_scale == 0.0 else minf(light_scale, t.light_scale)
		if inside and t.use_ambient:
			ambient = t.ambient
		if inside and t.other_lights_off:
			lights_off = true
		if inside and not _inside_triggers.get(t, false):
			t.fire(player)
		_inside_triggers[t] = inside
	player.set_light_scale(light_scale)
	_set_ambient(ambient)
	if lights_off != _lights_off:
		_lights_off = lights_off
		for l in get_tree().get_nodes_in_group("level_light"):
			l.set_dimmed(lights_off)


func _set_ambient(color: Color) -> void:
	if _ambient_target.is_equal_approx(color):
		return
	_ambient_target = color
	if _ambient_tween:
		_ambient_tween.kill()
	_ambient_tween = create_tween()
	_ambient_tween.tween_property(_canvas_modulate, "color", color, 1.0)
