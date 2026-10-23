extends LevelMap
## Intro-cutscene i resepsjonen på Elvebakken. Eleven vil skrive ut en gave til
## læreren. Kameraet er zoomet inn mens eleven tenker, og et minne glir inn fra siden:
## i går feilet skriveren (IntroMemory). Så går eleven til resepsjonen, får vite om
## skriveren i kjelleren og går ned trappa.
## Rommet er tegnet av designgruppa (tools/intro_art.gd). Rutene (Vector2i) under
## refererer til data/maps/intro.txt.

const NEXT_SCENE := "res://scenes/level_minus1/level_minus1.tscn"
const THOUGHT_BUBBLE := preload("res://assets/intro/thought_bubble.png")
## Foran resepsjonisten, og nedenfor trappa.
const TALK_CELL := Vector2i(15, 5)
const STAIRS_CELL := Vector2i(18, 3)
const ZOOM_IN := Vector2(2, 2)
## Når minnet dekker høyre halvdel, flyttes kameraet så eleven står midt i venstre.
const SPLIT_OFFSET := 50.0

@onready var wall_art: Sprite2D = $Wall/WallArt

var _bubble: Sprite2D
var _bubble_tween: Tween


func _ready() -> void:
	super()
	player.controlled = false
	GameState.set_phase("intro")
	_pulse_wall_art()
	_run()


func _run() -> void:
	GameState.lock_input()
	var cam: Camera2D = player.camera
	cam.zoom = ZOOM_IN
	cam.reset_smoothing()
	player.face(Vector2i.DOWN)
	await _wait(1.4)

	_show_bubble()
	await _wait(1.0)
	await Dialogue.play("intro.think")

	# Skjermen deles: minnet glir inn fra høyre.
	var memory := IntroMemory.new()
	add_child(memory)
	_tween_offset(cam, SPLIT_OFFSET, IntroMemory.SLIDE_TIME)
	await memory.slide_in()
	await memory.play()
	_tween_offset(cam, 0.0, IntroMemory.SLIDE_TIME)
	await memory.slide_out()
	memory.queue_free()

	_hide_bubble()
	await Dialogue.play("intro.decide")
	var zoom := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	zoom.tween_property(cam, "zoom", Vector2.ONE, 1.2)
	await zoom.finished

	await player.walk_to(TALK_CELL)
	player.face(Vector2i.UP)
	await _wait(0.4)
	await Dialogue.play("intro.reception")
	Sfx.play("sting", -10.0)
	await _wait(0.8)

	await player.walk_to(STAIRS_CELL)
	player.face(Vector2i.UP)
	await _wait(0.3)
	await Dialogue.play("intro.stairs")
	await _descend()
	GameState.unlock_input()
	GameState.set_phase("level")
	Screen.change_scene(NEXT_SCENE, 1.5)


## Eleven går ned trappa: noen steg opp i trappeåpningen mens figuren blir borte.
func _descend() -> void:
	var sprite := player.sprite
	var up_row := 3 * sprite.hframes
	var tw := create_tween().set_parallel()
	tw.tween_property(player, "position:y", player.position.y - 14.0, 1.0)
	tw.tween_property(sprite, "modulate", Color(0.15, 0.15, 0.2, 0.0), 1.0).set_ease(Tween.EASE_IN)
	for i in 8:
		sprite.frame = up_row + player.walk_cols[i % player.walk_cols.size()]
		if i % 2 == 0:
			Sfx.play("footstep", -16.0 - i, randf_range(0.85, 1.0))
		await _wait(0.13)


# --- Tankeboble og pynt ----------------------------------------------------------

func _show_bubble() -> void:
	_bubble = Sprite2D.new()
	_bubble.texture = THOUGHT_BUBBLE
	_bubble.hframes = 3
	_bubble.position = Vector2(12, -36)
	player.add_child(_bubble)
	Sfx.play("blip", -14.0)
	# Prikkene kommer en og en, om og om igjen.
	_bubble_tween = create_tween().set_loops()
	for f in 3:
		_bubble_tween.tween_callback(func() -> void: _bubble.frame = f)
		_bubble_tween.tween_interval(0.45)


func _hide_bubble() -> void:
	if _bubble_tween:
		_bubble_tween.kill()
	if _bubble:
		_bubble.queue_free()


## "Hjernen" på veggen pulserer svakt.
func _pulse_wall_art() -> void:
	var tw := create_tween().set_loops()
	tw.tween_property(wall_art, "modulate", Color(1.25, 0.9, 0.95), 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(wall_art, "modulate", Color.WHITE, 1.6).set_trans(Tween.TRANS_SINE)


func _tween_offset(cam: Camera2D, x: float, time: float) -> void:
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(cam, "offset:x", x, time)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
