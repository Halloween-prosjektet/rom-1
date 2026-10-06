extends GridEntity
## Låst dør. Åpnes hvis spilleren har required_item.
## Ramme 0 = lukket, ramme 1 = åpen (assets/props/door.png).

@export var required_item := "key"
@export var locked_text_key := "l1.door_locked"
@export var unlock_text_key := "l1.door_unlock"

var is_open := false

@onready var sprite: Sprite2D = $Sprite


func can_interact() -> bool:
	return not is_open


func interact(_player: Node) -> void:
	if is_open:
		return
	if required_item == "" or GameState.has_item(required_item):
		Sfx.play("unlock")
		await Dialogue.play(unlock_text_key)
		open()
	else:
		Sfx.play("locked")
		await Dialogue.play(locked_text_key)


func open() -> void:
	is_open = true
	sprite.frame = 1
	Sfx.play("door")
	set_solid(false)
