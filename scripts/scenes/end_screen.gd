extends Control
## Sluttskjerm. Viser gruppenavn + tid. "Ny gruppe" (eller RESET fra
## kontrollskriptet, se StationLink) starter på nytt for neste gruppe.

@onready var title: Label = $Title
@onready var body: Label = $Body
@onready var result_label: Label = $Result
@onready var restart_button: Button = $RestartButton


func _ready() -> void:
	GameState.set_phase("done")
	title.text = Text.t("end_title")
	body.text = Text.t("end_text")
	result_label.text = Text.t("end_result")
	result_label.visible = GameState.player_name != ""
	restart_button.text = Text.t("restart")
	restart_button.pressed.connect(GameState.reset_game, CONNECT_ONE_SHOT)
	Sfx.play_loop("hum", -12.0)


func _process(_delta: float) -> void:
	title.modulate.a = 0.15 if randf() < 0.02 else 1.0
