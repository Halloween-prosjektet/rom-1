extends Node
## Lyd. Sfx.play("footstep") laster res://assets/audio/footstep.(ogg|wav|mp3).
## Bytt lyd ved å legge en fil med samme navn i assets/audio/.

const AUDIO_DIR := "res://assets/audio/"
const EXTENSIONS := ["ogg", "wav", "mp3"]
const POOL_SIZE := 8

var _cache: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _loops: Dictionary = {}  # name -> AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)


func get_stream(sound: String) -> AudioStream:
	if _cache.has(sound):
		return _cache[sound]
	var stream: AudioStream = null
	for ext: String in EXTENSIONS:
		var path := AUDIO_DIR + sound + "." + ext
		if ResourceLoader.exists(path):
			stream = load(path)
			break
	if stream == null:
		push_warning("Sfx: fant ikke lyd '%s'" % sound)
	_cache[sound] = stream
	return stream


func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	var stream := get_stream(sound)
	if stream == null:
		return
	var player: AudioStreamPlayer = null
	for p in _pool:
		if not p.playing:
			player = p
			break
	if player == null:
		player = _pool[0]
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


## Starter en lyd som går i loop (ambience, summing). Kall stop_loop for å stoppe.
func play_loop(sound: String, volume_db := 0.0) -> void:
	if _loops.has(sound):
		return
	var stream := get_stream(sound)
	if stream == null:
		return
	stream = make_looping(stream)
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	add_child(p)
	p.play()
	_loops[sound] = p


func stop_loop(sound: String, fade := 0.5) -> void:
	var p: AudioStreamPlayer = _loops.get(sound)
	if p == null:
		return
	_loops.erase(sound)
	var tw := create_tween()
	tw.tween_property(p, "volume_db", -60.0, fade)
	tw.tween_callback(p.queue_free)


func stop_all_loops() -> void:
	for sound: String in _loops.keys():
		stop_loop(sound, 0.3)


static func make_looping(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamWAV:
		var wav: AudioStreamWAV = stream.duplicate()
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
		return wav
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		var s: AudioStream = stream.duplicate()
		s.set("loop", true)
		return s
	return stream
