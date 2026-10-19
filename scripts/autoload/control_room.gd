extends Node
## Kobling mot kontrollrom-serveren (https://github.com/halloween-prosjektet/control-room).
## Bruker ControlRoomClient fra addons/control_room_client (git submodule) og
## rapporterer hva som skjer i spillet:
##
##   navneskjerm ferdig     -> register_player(gruppenavn)
##   kommer ned i kjelleren -> start_game()       (samtidig som klokka starter)
##   bruker skriveren       -> finish_game()      (samtidig som klokka stopper)
##                             share("group_name", "Gruppe 7")
##                             share("finish_time", "01:00.7")
##                             share("finish_time_ms", 60742)
##   "Ny gruppe" / RESET    -> leave_player()
##
## Adresse og rom-nummer settes i [control_room] i config (defaults.cfg / station.cfg).
## Er serveren nede, legges meldingene i kø og sendes når den kommer tilbake.

const CLIENT_SCRIPT := "res://addons/control_room_client/control_room_client.gd"
## Klienten gir opp etter ~10 forsøk. Da prøver vi på nytt etter så mange sekunder.
const RESTART_DELAY := 30.0

var _client: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var uri := str(Config.get_value("control_room", "uri", ""))
	if uri == "":
		print("ControlRoom: av (ingen uri i [control_room])")
		return
	# Lastes dynamisk så spillet fortsatt starter hvis submodulen mangler.
	if not ResourceLoader.exists(CLIENT_SCRIPT):
		push_warning("ControlRoom: fant ikke %s - kjør 'git submodule update --init'" % CLIENT_SCRIPT)
		return
	var pi_id := int(Config.get_value("control_room", "pi_id", 1))
	_client = load(CLIENT_SCRIPT).new(uri, pi_id)
	_client.name = "Client"
	add_child(_client)
	_client.authenticated.connect(func() -> void: print("ControlRoom: koblet til ", uri))
	_client.gave_up.connect(_on_gave_up)

	GameState.phase_changed.connect(_on_phase_changed)
	GameState.timer_began.connect(_on_timer_began)
	GameState.timer_stopped.connect(_on_timer_stopped)

	print("ControlRoom: kobler til %s som pi %d" % [uri, pi_id])
	_client.run()


func is_connected_to_server() -> bool:
	return _client != null and _client.is_authenticated


func _on_phase_changed(phase: String) -> void:
	match phase:
		"intro":
			# Navneskjermen er ferdig, gruppenavnet er satt.
			if GameState.player_name != "":
				_client.register_player(GameState.player_name)
		"title":
			# Spillet er nullstilt for neste gruppe.
			if not _client.current_player.is_empty():
				_client.leave_player()


func _on_timer_began() -> void:
	_client.start_game()


func _on_timer_stopped(ms: int) -> void:
	_client.finish_game()
	_client.share("group_name", GameState.player_name)
	_client.share("finish_time", GameState.format_time(ms))
	_client.share("finish_time_ms", ms)
	print("ControlRoom: ferdig - %s %s" % [GameState.player_name, GameState.format_time(ms)])


func _on_gave_up() -> void:
	push_warning("ControlRoom: fikk ikke kontakt, prøver igjen om %d s" % RESTART_DELAY)
	await get_tree().create_timer(RESTART_DELAY).timeout
	_client.run()
