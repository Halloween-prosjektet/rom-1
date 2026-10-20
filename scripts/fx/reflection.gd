class_name Reflection
extends Sprite2D
## Speilbilde av en sprite i vått / blankt gulv. Ligger som søsken av sprite-en,
## speilvendt rundt føttene, og følger rammen (gange, retning) hver frame.
## Selve "hvor er gulvet vått" ligger i WetFloor-maska (se wet_floor.gd).

var source: Sprite2D


static func attach(src: Sprite2D) -> Reflection:
	if WetFloor.reflection_material == null or src == null:
		return null
	var r := Reflection.new()
	r.name = "Reflection"
	r.source = src
	r.material = WetFloor.reflection_material
	r.z_index = -8
	r.z_as_relative = false
	src.get_parent().add_child(r)
	r._sync()
	return r


func _process(_delta: float) -> void:
	if not is_instance_valid(source):
		queue_free()
		return
	_sync()


func _sync() -> void:
	texture = source.texture
	hframes = source.hframes
	vframes = source.vframes
	frame = source.frame
	flip_h = source.flip_h
	region_enabled = source.region_enabled
	region_rect = source.region_rect
	visible = source.is_visible_in_tree()
	modulate = source.modulate
	light_mask = source.light_mask
	# Speil rundt bunnen av sprite-en (føttene): noden står på speillinja, så
	# shaderen kan tone ut speilbildet jo lenger "ned" i gulvet det går.
	var frame_h := source.region_rect.size.y if source.region_enabled else 0.0
	if frame_h == 0.0 and source.texture:
		frame_h = source.texture.get_height() / float(source.vframes)
	var bottom := source.position.y + (source.offset.y + frame_h * 0.5) * source.scale.y
	position = Vector2(source.position.x, bottom)
	scale = Vector2(source.scale.x, -source.scale.y)
	offset = Vector2(source.offset.x, source.offset.y + (source.position.y - bottom) / source.scale.y)
