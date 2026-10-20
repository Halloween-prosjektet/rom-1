extends Node
## Grafikkeffekter for nivåene. LevelMap kaller decorate_level() når kartet er bygd:
##   - normal maps på tiles, figurer og rekvisitter (relieff og glans i lyset)
##   - skygger fra vegger og møbler
##   - synlige lamper med glorie, støv og lysstriper i vått gulv
##   - vått / blankt gulv med speilbilder
##   - tåke og støv i lufta, romklang og tilfeldige lyder
##
## Kvalitet: [display] graphics = "high" (alt) eller "low" (uten skygger, speilbilder,
## tåke, partikler og etterbehandling) i config, for svakere maskiner.

var high := true

## Skyggelag: vegger kaster skygge for alle lys, møbler bare for lamper og
## lommelykta (ikke for nærlyset rundt spilleren, ellers blir det umulig å se
## hylleradene i arkivet).
const SHADOW_WALLS := 1
const SHADOW_PROPS := 2
## Lyslag for hva som blir opplyst: spilleren ligger på eget lag, så lommelykta
## (som starter i hånda) ikke lyser opp spilleren selv.
const LIT_WORLD := 1
const LIT_PLAYER := 2
## Bare høye ting kaster skygge (ikke skrap og små esker – det blir rotete).
const SHADOW_CASTERS := ["shelf", "crate", "desk", "counter", "printer", "door"]


func _ready() -> void:
	high = str(Config.get_value("display", "graphics", "high")) != "low"
	print("Gfx: grafikk ", "høy" if high else "lav")


func decorate_level(map: LevelMap) -> void:
	_tiles(map)
	if high and (map.floor_gloss > 0.0 or map.puddles > 0.0):
		var wet := WetFloor.new()
		wet.name = "WetFloor"
		map.add_child(wet)
		wet.setup(map, map.floor_gloss, map.puddles)
	for e in map.entities.get_children():
		_entity(e)
	for l in get_tree().get_nodes_in_group("level_light"):
		if map.is_ancestor_of(l):
			_lamp(l)
	if high and map.fog_density > 0.0:
		var atmo := Atmosphere.new()
		atmo.name = "Atmosphere"
		atmo.density = map.fog_density
		map.add_child(atmo)
	Sfx.set_room(map.reverb_room, map.reverb_wet)
	if not map.ambient_pool.is_empty():
		var amb := AmbientSounds.new()
		amb.name = "AmbientSounds"
		amb.pool = map.ambient_pool
		map.add_child(amb)


## Normal maps på tile-atlaset og skyggekastere på toppen av veggene.
func _tiles(map: LevelMap) -> void:
	var ts := map.tile_layer.tile_set
	var src := ts.get_source(0) as TileSetAtlasSource
	src.texture = NormalMaps.lit(src.texture, 3.0, 0.28, 0.5, Vector2i(LevelMap.TILE, LevelMap.TILE))
	if not high:
		return
	ts.add_occlusion_layer()
	ts.set_occlusion_layer_light_mask(0, SHADOW_WALLS)
	var poly := OccluderPolygon2D.new()
	var h := LevelMap.TILE * 0.5
	poly.polygon = PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	var td := src.get_tile_data(LevelMap.T_WALL_TOP, 0)
	td.set_occluder_polygons_count(0, 1)
	td.set_occluder_polygon(0, 0, poly)


func _entity(e: Node) -> void:
	var sprite := e.get_node_or_null("Sprite") as Sprite2D
	if sprite == null or sprite.texture == null:
		return
	var frame := Vector2i(sprite.texture.get_width() / sprite.hframes, sprite.texture.get_height() / sprite.vframes)
	var person := e is Actor
	sprite.texture = NormalMaps.lit(sprite.texture, 2.2, 0.12 if person else 0.32, 0.45, frame)
	if not high:
		return
	if WetFloor.current:
		Reflection.attach(sprite)
	# Møbler kaster skygge. Skyggekasteren ligger i den bakre halvdelen av ruta,
	# så siden som vender mot lyset fortsatt blir opplyst.
	var kind := e.scene_file_path.get_file()
	if e is GridEntity and e.solid and not person and SHADOW_CASTERS.any(func(k: String) -> bool: return k in kind):
		var occ := LightOccluder2D.new()
		occ.name = "Shadow"
		occ.occluder_light_mask = SHADOW_PROPS
		var poly := OccluderPolygon2D.new()
		poly.polygon = PackedVector2Array([Vector2(-6, -6), Vector2(6, -6), Vector2(6, 1), Vector2(-6, 1)])
		occ.occluder = poly
		e.add_child(occ)


func _lamp(l: PointLight2D) -> void:
	# Høyt i taket: lyset når langt ut på gulvet, men relieffet synes fortsatt.
	l.height = 64.0
	l.range_item_cull_mask = LIT_WORLD | LIT_PLAYER
	# Normal maps sprer lyset litt mindre, så lampene får litt mer kraft.
	if "base_energy" in l:
		l.base_energy *= 1.15
		l.energy = l.base_energy
	if high:
		l.shadow_enabled = true
		l.shadow_filter = Light2D.SHADOW_FILTER_PCF5
		l.shadow_filter_smooth = 1.5
		l.shadow_color = Color(0, 0, 0, 0.85)
		l.shadow_item_cull_mask = SHADOW_WALLS | SHADOW_PROPS
	LampFx.attach(l, high)


## Felles oppsett for lys som følger spilleren. casts_prop_shadows: lommelykta ja,
## nærlyset nei.
func setup_player_light(l: PointLight2D, height: float, casts_prop_shadows: bool) -> void:
	l.height = height
	if high:
		l.shadow_enabled = true
		l.shadow_filter = Light2D.SHADOW_FILTER_PCF5
		l.shadow_filter_smooth = 2.0
		l.shadow_color = Color(0, 0, 0, 0.9)
		l.shadow_item_cull_mask = SHADOW_WALLS | (SHADOW_PROPS if casts_prop_shadows else 0)
