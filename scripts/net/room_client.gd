extends "res://addons/control_room_client/control_room_client.gd"
## ControlRoomClient med det rom-1 trenger i tillegg: et signal når serveren har
## godtatt registreringen, og tidsstempel for hendelser som sendes senere.
## Lastes av ControlRoom-autoloaden.

signal player_registered


func event_handler(data: Dictionary) -> void:
	super(data)
	if data.get("event", null) in ["player_register_ok", "register_player_ok"]:
		player_registered.emit()


## Samme tidsformat som klienten selv bruker (UTC, ISO 8601).
func timestamp() -> String:
	return _get_timestamp()
