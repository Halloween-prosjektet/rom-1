extends GridEntity
## Eske man kan lete i. Kan gi en gjenstand (item_id), f.eks. nøkkelen.
## Ramme 0 = lukket, ramme 1 = åpnet (assets/props/box.png).

@export var item_id := ""
@export var empty_text_key := "l1.box_empty"

var opened := false

@onready var sprite: Sprite2D = $Sprite


func can_interact() -> bool:
	return true


func interact(_player: Node) -> void:
	if opened:
		await Dialogue.play(empty_text_key)
		return
	opened = true
	sprite.frame = 1
	Sfx.play("rummage")
	await get_tree().create_timer(0.35).timeout
	if item_id != "":
		GameState.add_item(item_id)
		Sfx.play("item")
	await Dialogue.play(text_key)
