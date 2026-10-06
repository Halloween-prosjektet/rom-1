class_name GridEntity
extends Node2D
## Alt som står i en rute: rekvisitter, kasser, dører, personer.
## Plasser noden hvor som helst i ruta - den snappes til midten når nivået starter.

## Blokkerer ruta.
@export var solid := true
## Kan dyttes av spilleren (kasser).
@export var pushable := false
## Dialog-nøkkel (lines) som vises når man undersøker.
@export var text_key := ""
## Alternativt: tilfeldig replikk fra en "pool" i dialogue_no.json.
@export var text_pool := ""

var map: LevelMap
var cell := Vector2i.ZERO
var is_moving := false


func _ready() -> void:
	add_to_group("grid_entity")


func setup(m: LevelMap) -> void:
	if map != null:
		return
	map = m
	cell = m.world_to_cell(global_position)
	global_position = m.cell_to_world(cell)
	m.register(self)
	_on_setup()


## Overstyr i subklasser.
func _on_setup() -> void:
	pass


func can_interact() -> bool:
	return text_key != "" or text_pool != ""


func interact(_player: Node) -> void:
	if text_key != "":
		await Dialogue.play(text_key)
	elif text_pool != "":
		await Dialogue.say(Text.pool_random(text_pool))


func set_solid(value: bool) -> void:
	solid = value
	if map:
		map.refresh_cell(cell)


## Flytter til en ny rute med en kort animasjon.
func move_to_cell(target: Vector2i, duration := 0.2) -> void:
	var from := cell
	cell = target
	map.move_occupant(self, from, target)
	is_moving = true
	var tw := create_tween()
	tw.tween_property(self, "global_position", map.cell_to_world(target), duration)
	await tw.finished
	is_moving = false


## Teleporterer uten animasjon.
func place_at(target: Vector2i) -> void:
	var from := cell
	cell = target
	map.move_occupant(self, from, target)
	global_position = map.cell_to_world(target)


## Overstyres av kasser.
func try_push(_dir: Vector2i) -> bool:
	return false
