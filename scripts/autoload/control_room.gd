extends Node
## Kobling mot kontrollrom-serveren (https://github.com/halloween-prosjektet/control-room).
## Serveren styrer flyten gjennom de fem rommene og lager resultatlista ut fra
## tidsstemplene i game_start / game_finish. Vi er rom 1, så vi registrerer gruppene.
##
##   navneskjerm ferdig     -> register_player(gruppenavn)
##   kommer ned i kjelleren -> game_start          (samtidig som klokka starter)
##   bruker skriveren       -> game_finish         (samtidig som klokka stopper)
##   "Ny gruppe" / RESET    -> player_leave, men BARE hvis gruppa ikke ble ferdig
##                             (ellers ville serveren slettet løpet fra resultatlista)
##
## Gruppenavnet følger med som brukernavn, og tiden regner serveren ut selv, så vi
## deler ingenting med share.
##
## Rom 1 kan bare registrere en ny gruppe når rommet er tomt. Svarer serveren
## "room_busy" (forrige gruppe venter fortsatt på rom 2), prøver vi igjen, og holder
## game_start / game_finish tilbake til registreringen er godtatt. De sendes
## da med sine opprinnelige tidsstempler, så tiden på resultatlista blir riktig.
##
## Gruppa som spiller lagres i STATE_FILE. Går strømmen midt i et spill, sier vi
## fra at den gruppa gikk når spillet starter igjen, ellers ville rom 1 vært opptatt.
##
## Adresse og rom-nummer: CONTROL_ROOM_URL og CONTROL_ROOM_PI_ID i .env.

## Endres når gruppa er ferdig: "" -> "sending" -> "waiting" (neste rom opptatt) -> "go".
signal finish_status_changed(status: String)

const CLIENT_SCRIPT := "res://addons/control_room_client/control_room_client.gd"
const ROOM_CLIENT_SCRIPT := "res://scripts/net/room_client.gd"
## Klienten gir opp etter ~10 forsøk. Da prøver vi på nytt etter så mange sekunder.
const RESTART_DELAY := 30.0
## Ventetid før vi prøver å registrere på nytt når rom 1 er opptatt.
const REGISTER_RETRY_DELAY := 5.0
const STATE_FILE := "user://control_room.json"

var finish_status := ""
## Klokkeslett (TT:MM) serveren regner med at neste rom er ledig, ved "waiting".
var wait_until := ""

var _client: Node = null
## Gruppa som spiller nå ("" = ingen).
var _group := ""
var _registered := false
var _finished := false
## Hendelser som venter på at registreringen blir godtatt.
var _pending: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var url := Config.env("CONTROL_ROOM_URL").strip_edges()
	if url == "":
		print("ControlRoom: av (CONTROL_ROOM_URL mangler, se .env.example)")
		return
	# Lastes dynamisk så spillet fortsatt starter hvis submodulen mangler.
	if not ResourceLoader.exists(CLIENT_SCRIPT):
		push_warning("ControlRoom: fant ikke %s - kjør 'git submodule update --init'" % CLIENT_SCRIPT)
		return
	var pi_id := int(Config.env("CONTROL_ROOM_PI_ID", "1"))
	_client = load(ROOM_CLIENT_SCRIPT).new(url, pi_id)
	_client.name = "Client"
	add_child(_client)
	_client.authenticated.connect(func() -> void: print("ControlRoom: koblet til ", url))
	_client.gave_up.connect(_on_gave_up)
	_client.player_registered.connect(_on_registered)
	_client.server_error.connect(_on_server_error)
	_client.game_finish_wait.connect(_on_finish_wait)
	_client.game_finish_ok.connect(_on_finish_ok)

	GameState.phase_changed.connect(_on_phase_changed)
	GameState.timer_began.connect(_on_timer_began)
	GameState.timer_stopped.connect(_on_timer_stopped)

	print("ControlRoom: kobler til %s som rom %d" % [url, pi_id])
	_recover_after_restart()
	_client.run()


func is_enabled() -> bool:
	return _client != null


func is_connected_to_server() -> bool:
	return _client != null and _client.is_authenticated


# --- Spillet -----------------------------------------------------------------

func _on_phase_changed(phase: String) -> void:
	match phase:
		"intro":
			# Navneskjermen er ferdig, gruppenavnet er satt.
			if GameState.player_name != "":
				_begin_group(GameState.player_name)
		"title":
			_end_group()


func _begin_group(group: String) -> void:
	_end_group()
	_group = group
	_registered = false
	_finished = false
	_pending.clear()
	_set_finish_status("")
	_client.register_player(group)
	_save_state()


## Spillet er nullstilt for neste gruppe.
func _end_group() -> void:
	if _group == "":
		return
	if not _finished and _registered:
		# Gruppa ga opp underveis: fjern den fra rom 1 så neste gruppe kan starte.
		_client.leave_player()
	# En ferdig gruppe beholdes hos serveren (den er på vei til rom 2). Vi glemmer
	# den bare her, så neste gruppes hendelser ikke får feil brukernavn.
	_client.current_player = {}
	_group = ""
	_registered = false
	_finished = false
	_pending.clear()
	_set_finish_status("")
	_save_state()


func _on_timer_began() -> void:
	if _group != "":
		_send_game_event({"event": "game_start"})


func _on_timer_stopped(ms: int) -> void:
	if _group == "":
		return
	_send_game_event({"event": "game_finish"})
	_finished = true
	_set_finish_status("sending")
	_save_state()
	print("ControlRoom: ferdig - %s %s" % [_group, GameState.format_time(ms)])


## Lager hendelsen med tidsstempel nå, men sender den først når gruppa er registrert.
func _send_game_event(payload: Dictionary) -> void:
	payload["timestamp"] = _client.timestamp()
	payload["username"] = _group
	if _registered:
		_client.send_event(payload)
	else:
		_pending.append(payload)


# --- Serveren ----------------------------------------------------------------

func _on_registered() -> void:
	if _group == "":
		# Svar på en registrering for en gruppe som allerede er nullstilt.
		_client.leave_player()
		return
	if _registered:
		return
	_registered = true
	print("ControlRoom: %s registrert" % _group)
	for payload in _pending:
		_client.send_event(payload)
	_pending.clear()


func _on_server_error(code: String, message: String, event: String) -> void:
	push_warning("ControlRoom: serveren avviste %s (%s: %s)" % [event, code, message])
	if event == "player_register" and code == "room_busy" and _group != "" and not _registered:
		# Forrige gruppe venter fortsatt i rom 1 på at rom 2 blir ledig.
		var group := _group
		await get_tree().create_timer(REGISTER_RETRY_DELAY).timeout
		if _group == group and not _registered:
			_client.register_player(group)


func _on_finish_wait(max_wait: String) -> void:
	if not _finished:
		return
	# "2026-10-31T18:42:10+01:00" -> "18:42"
	wait_until = max_wait.substr(11, 5) if max_wait.length() >= 16 else ""
	_set_finish_status("waiting")


func _on_finish_ok() -> void:
	if _finished:
		_set_finish_status("go")


func _set_finish_status(status: String) -> void:
	if status == finish_status:
		return
	finish_status = status
	finish_status_changed.emit(status)


## Lagrer gruppa som spiller nå, så vi kan rydde opp etter et strømbrudd.
func _save_state() -> void:
	var f := FileAccess.open(STATE_FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"group": _group, "finished": _finished}))


func _recover_after_restart() -> void:
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(STATE_FILE)) \
		if FileAccess.file_exists(STATE_FILE) else null
	if not saved is Dictionary:
		return
	var group := str(saved.get("group", ""))
	if group != "" and not saved.get("finished", false):
		print("ControlRoom: %s ble ikke ferdig før omstart - sier fra at gruppa gikk" % group)
		_client.current_player = {"username": group}
		_client.leave_player()
	_save_state()


func _on_gave_up() -> void:
	push_warning("ControlRoom: fikk ikke kontakt, prøver igjen om %d s" % RESTART_DELAY)
	await get_tree().create_timer(RESTART_DELAY).timeout
	_client.run()
