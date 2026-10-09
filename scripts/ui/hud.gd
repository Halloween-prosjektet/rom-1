extends CanvasLayer
## HUD i nivåene: berørings-D-pad, handlingsknapp og "Tilbakestill rommet".
## Knappene sender vanlige input-actions (move_up, interact ...), så de virker
## likt som tastatur / fysiske knapper.

@onready var touch: Node2D = $Touch
@onready var dpad: Node2D = $Touch/DPad
@onready var action_button: TouchScreenButton = $Touch/Action
@onready var reset_button: Button = $ResetButton
@onready var item_label: Label = $ItemLabel
## Klokke oppe til høyre: går fra man kommer ned i kjelleren til man når skriveren.
@onready var timer_label: Label = $TimerLabel

var _reset_target: Node = null


func _ready() -> void:
	layer = 60
	add_to_group("hud")
	var mode := str(Config.get_value("display", "touch_controls", "auto"))
	touch.visible = mode == "on" or (mode == "auto" and DisplayServer.is_touchscreen_available())
	reset_button.text = Text.t("reset_room")
	reset_button.visible = false
	reset_button.pressed.connect(func() -> void:
		if _reset_target and GameState.can_move():
			_reset_target.reset_room())
	GameState.items_changed.connect(_update_items)
	_update_items()


func _process(_delta: float) -> void:
	# Skjul kontrollene mens dialog vises.
	var show := not Dialogue.is_open
	dpad.modulate.a = 1.0 if show else 0.0
	action_button.modulate.a = 1.0 if show else 0.0
	timer_label.visible = GameState.timer_started()
	timer_label.text = GameState.format_time(GameState.elapsed_ms())
	if not GameState.timer_running():
		timer_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.35))


func set_reset_target(room: Node) -> void:
	_reset_target = room
	reset_button.visible = room != null


## Skal et trykk på denne posisjonen ignoreres av spilleren (traff en knapp)?
func blocks_tap(pos: Vector2) -> bool:
	if touch.visible:
		if pos.distance_to(dpad.global_position) < 44.0:
			return true
		if pos.distance_to(action_button.global_position + Vector2(18, 18)) < 26.0:
			return true
	if reset_button.visible and reset_button.get_global_rect().grow(4).has_point(pos):
		return true
	return false


func _update_items() -> void:
	item_label.text = ("[ " + Text.t("item_key") + " ]") if GameState.has_item("key") else ""
