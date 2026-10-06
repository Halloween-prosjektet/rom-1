@tool
extends EditorScript
## Åpne denne filen i skripteditoren og velg File > Run (Ctrl+Shift+X)
## for å lage plassholder-grafikk/lyd som mangler i assets/.


func _run() -> void:
	var written: Array[String] = preload("res://tools/placeholder_art.gd").run(false)
	print("Plassholdere laget: ", written.size())
	for p in written:
		print("  ", p)
	EditorInterface.get_resource_filesystem().scan()
