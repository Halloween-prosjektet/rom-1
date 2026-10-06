extends Node
## Alternativ måte å lage plassholdere på: kjør scenen tools/generate.tscn (F6).


func _ready() -> void:
	var written: Array[String] = preload("res://tools/placeholder_art.gd").run(false)
	print("Plassholdere laget: ", written.size())
	get_tree().quit()
