extends GridEntity
## Skriveren på slutten av etasje -1. Feiler i spillet og skriver ut
## feilkoden på den ekte skriveren (PrinterService), deretter sluttskjerm.

const END_SCENE := "res://scenes/end_screen.tscn"

var used := false

@onready var sprite: Sprite2D = $Sprite


func can_interact() -> bool:
	return true


func interact(_player: Node) -> void:
	if used:
		await Dialogue.play("l1.printer_done")
		return
	used = true
	GameState.lock_input()
	GameState.set_phase("printing")
	await Dialogue.play("l1.printer_use")

	Sfx.play("printer")
	await _blink(1.8)
	Sfx.play("error")
	sprite.frame = 1
	Screen.shake(2.5, 0.5)
	await Screen.glitch(0.9, 1.0)

	var result := {"done": false, "ok": false}
	PrinterService.print_finished.connect(func(ok: bool) -> void:
		result.done = true
		result.ok = ok, CONNECT_ONE_SHOT)
	PrinterService.print_error_page()

	await Dialogue.play("l1.printer_error")
	while not result.done:
		await get_tree().process_frame
	GameState.flags["print_ok"] = result.ok
	GameState.set_phase("done")
	GameState.unlock_input()
	Screen.change_scene(END_SCENE, 1.5)


func _blink(duration: float) -> void:
	var t := 0.0
	while t < duration:
		sprite.frame = 1 - sprite.frame
		await get_tree().create_timer(0.15).timeout
		t += 0.15
	sprite.frame = 0
