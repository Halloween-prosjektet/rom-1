extends LevelMap
## Intro-cutscene på Elvebakken: læreren ber deg skrive ut noe, alle skriverne
## er ødelagte, resepsjonen sender deg til kjelleren.
## Rutene (Vector2i) under refererer til data/maps/intro.txt.

const NEXT_SCENE := "res://scenes/level_minus1/level_minus1.tscn"

@onready var teacher: Actor = $Entities/Teacher
@onready var receptionist: Actor = $Entities/Receptionist
@onready var printer1: GridEntity = $Entities/Printer1
@onready var printer2: GridEntity = $Entities/Printer2
@onready var printer3: GridEntity = $Entities/Printer3
@onready var basement_door: GridEntity = $Entities/BasementDoor


func _ready() -> void:
	super()
	player.controlled = false
	GameState.set_phase("intro")
	_run()


func _run() -> void:
	GameState.lock_input()
	await _wait(1.5)
	player.face(Vector2i.UP)
	await _wait(0.6)
	await Dialogue.play("intro.teacher")

	await player.walk_to(Vector2i(6, 12))
	await _check_printer(printer1, "intro.printer1")
	await _check_printer(printer2, "intro.printer2")

	await player.walk_to(printer3.cell + Vector2i.DOWN)
	player.face(Vector2i.UP)
	printer3.get_node("Sprite").frame = 1
	Sfx.play("static", -4.0)
	await Screen.glitch(0.5, 0.5)
	await Dialogue.play("intro.printer3")
	printer3.get_node("Sprite").frame = 0

	await player.walk_to(receptionist.cell + Vector2i.DOWN * 2)
	player.face(Vector2i.UP)
	await _wait(0.4)
	await Dialogue.play("intro.reception")
	Sfx.play("sting", -10.0)
	await _wait(0.8)

	await player.walk_to(basement_door.cell + Vector2i.LEFT)
	player.face(Vector2i.RIGHT)
	# Resepsjonisten har snudd seg og ser etter deg.
	receptionist.face(Vector2i.RIGHT)
	await Dialogue.play("intro.basement_door")
	basement_door.get_node("Sprite").frame = 1
	basement_door.set_solid(false)
	Sfx.play("door")
	await _wait(0.4)
	await player.step(Vector2i.RIGHT)
	GameState.unlock_input()
	GameState.set_phase("level")
	Screen.change_scene(NEXT_SCENE, 1.5)


func _check_printer(printer: GridEntity, text_key: String) -> void:
	await player.walk_to(printer.cell + Vector2i.DOWN)
	player.face(Vector2i.UP)
	await _wait(0.3)
	printer.get_node("Sprite").frame = 1
	Sfx.play("error", -8.0)
	await Dialogue.play(text_key)
	printer.get_node("Sprite").frame = 0


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
