extends Control
## Sluttskjerm. Viser gruppenavn + tid. "Ny gruppe" (eller RESET fra
## kontrollskriptet, se StationLink) starter på nytt for neste gruppe.

@onready var title: Label = $Title
@onready var body: Label = $Body
@onready var result_label: Label = $Result
@onready var restart_button: Button = $RestartButton
## Om gruppa skal vente eller gå videre (fra kontrollrommet, se ControlRoom).
@onready var room_status: Label = $RoomStatus


func _ready() -> void:
	GameState.set_phase("done")
	title.text = Text.t("end_title")
	body.text = Text.t("end_text")
	result_label.text = Text.t("end_result")
	result_label.visible = GameState.player_name != ""
	restart_button.text = Text.t("restart")
	restart_button.pressed.connect(GameState.reset_game, CONNECT_ONE_SHOT)
	Sfx.play_loop("hum", -12.0)
	ControlRoom.finish_status_changed.connect(_show_room_status)
	_show_room_status(ControlRoom.finish_status)


func _show_room_status(status: String) -> void:
	match status:
		"sending":
			room_status.text = Text.t("cr_sending")
		"waiting":
			room_status.text = Text.t("cr_waiting_until").replace("{wait}", ControlRoom.wait_until) \
				if ControlRoom.wait_until != "" else Text.t("cr_waiting")
		"go":
			room_status.text = Text.t("cr_go")
			Sfx.play("unlock")
		_:
			room_status.text = ""
	room_status.add_theme_color_override("font_color",
		Color(0.95, 0.65, 0.25) if status == "waiting" else Color(0.55, 0.85, 0.55))


func _process(_delta: float) -> void:
	title.modulate.a = 0.15 if randf() < 0.02 else 1.0
