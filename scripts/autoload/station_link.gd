extends Node
## Kobling mot kontrollskriptet som synkroniserer alle Pi-ene.
##
## 1) Status skrives til user://station_status.json hver gang fasen endres:
##      {"station": "rom-1", "phase": "level", "time": 1730000000}
##    (på Pi: ~/.local/share/godot/app_userdata/<prosjektnavn>/station_status.json)
## 2) Lytter på UDP-port (status_port i config, standard 4242):
##      "RESET"  -> spillet går tilbake til tittelskjermen
##      "STATUS" -> svarer avsenderen med JSON som over
##    Test fra en annen maskin:  echo -n RESET | nc -u -w1 <pi-ip> 4242

const STATUS_FILE := "user://station_status.json"

var _udp := PacketPeerUDP.new()
var _listening := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.phase_changed.connect(func(_p: String) -> void: _write_status())
	var port := int(Config.get_value("station", "status_port", 4242))
	if port > 0:
		var err := _udp.bind(port)
		_listening = err == OK
		if _listening:
			print("StationLink: lytter på UDP ", port)
		else:
			push_warning("StationLink: kunne ikke åpne UDP-port %d (%s)" % [port, err])
	_write_status()


func status() -> Dictionary:
	return {
		"station": Config.station_id,
		"phase": GameState.phase,
		"time": int(Time.get_unix_time_from_system()),
	}


func _write_status() -> void:
	var f := FileAccess.open(STATUS_FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(status()))


func _process(_delta: float) -> void:
	if not _listening:
		return
	while _udp.get_available_packet_count() > 0:
		var msg := _udp.get_packet().get_string_from_utf8().strip_edges().to_upper()
		var ip := _udp.get_packet_ip()
		var port := _udp.get_packet_port()
		print("StationLink: mottok '%s' fra %s:%d" % [msg, ip, port])
		match msg:
			"RESET":
				GameState.reset_game()
				_reply(ip, port, "OK")
			"STATUS":
				_reply(ip, port, JSON.stringify(status()))
			_:
				_reply(ip, port, "UKJENT")


func _reply(ip: String, port: int, text: String) -> void:
	_udp.set_dest_address(ip, port)
	_udp.put_packet(text.to_utf8_buffer())


func _exit_tree() -> void:
	_udp.close()
