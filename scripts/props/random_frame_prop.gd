extends GridEntity
## Rekvisitt som velger en tilfeldig (men fast per rute) ramme fra spritearket,
## f.eks. assets/props/junk.png med 4 varianter ved siden av hverandre.

@onready var sprite: Sprite2D = $Sprite


func _on_setup() -> void:
	var frames := sprite.hframes * sprite.vframes
	sprite.frame = absi(cell.x * 31 + cell.y * 17) % frames
