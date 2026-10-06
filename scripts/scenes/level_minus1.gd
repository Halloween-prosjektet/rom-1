extends LevelMap
## Etasje -1: lageret. Selve innholdet (kasser, nøkkel, dør, skriver, triggere)
## ligger som noder i scenen og i data/maps/level_minus1.txt.


func _ready() -> void:
	super()
	GameState.set_phase("level")
	_arrive()


func _arrive() -> void:
	GameState.lock_input()
	await get_tree().create_timer(1.2).timeout
	Sfx.play("door_slam")
	Screen.shake(3.0, 0.5)
	await get_tree().create_timer(0.6).timeout
	GameState.unlock_input()
	await Dialogue.play("l1.arrive")
