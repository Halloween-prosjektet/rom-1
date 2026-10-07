extends PointLight2D
## Lysrør i taket. flicker=true gir tilfeldig blinking med summelyd.

@export var flicker := true
@export var base_energy := 0.9
## Sjanse per sekund for at lyset begynner å blinke.
@export var flicker_rate := 0.35
@export var buzz_sound := "flicker"

var _timer := 0.0

@onready var buzz: AudioStreamPlayer2D = get_node_or_null("Buzz")


func _ready() -> void:
	add_to_group("level_light")
	texture = LightTex.radial()
	energy = base_energy
	_timer = randf_range(0.5, 3.0)
	if buzz and buzz_sound != "":
		buzz.stream = Sfx.get_stream(buzz_sound)


func _process(delta: float) -> void:
	if not flicker or not enabled:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(0.6, 1.0 / maxf(flicker_rate, 0.01) * 2.0)
		_flicker_burst()


func _flicker_burst() -> void:
	if buzz and buzz.stream and is_inside_tree():
		buzz.play()
	var tw := create_tween()
	for i in randi_range(2, 6):
		tw.tween_property(self, "energy", base_energy * randf_range(0.0, 0.25), randf_range(0.03, 0.08))
		tw.tween_property(self, "energy", base_energy * randf_range(0.6, 1.0), randf_range(0.03, 0.1))
	if randf() < 0.25:
		tw.tween_property(self, "energy", 0.0, 0.05)
		tw.tween_interval(randf_range(0.4, 1.2))
	tw.tween_property(self, "energy", base_energy, 0.1)


## Slår lyset av/på (brukes av mørke soner, f.eks. arkivet).
func set_dimmed(dimmed: bool) -> void:
	enabled = not dimmed
	if dimmed and buzz:
		buzz.stop()
