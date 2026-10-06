extends GridEntity
## Kasse som kan dyttes én rute av gangen (hvis ruta bak er ledig).


func try_push(dir: Vector2i) -> bool:
	if is_moving:
		return false
	var target := cell + dir
	if not map.is_free(target):
		Sfx.play("bump", -6.0)
		return false
	Sfx.play("push", -2.0, randf_range(0.9, 1.1))
	move_to_cell(target, 0.22)
	return true
