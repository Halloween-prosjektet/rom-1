extends Node
## Skriver ut feilkode-arket på en ekte skriver via CUPS (`lp`) på Raspberry Pi-en.
##   var ok: bool = await PrinterService.print_error_page()
## Innstillinger ligger i config/defaults.cfg (print_enabled, printer_name, print_args ...).

signal print_finished(success: bool)

const PAGE_FILE := "user://feilkode.txt"

var last_result := {}


func build_page() -> String:
	var code := Config.error_code
	var time := Time.get_datetime_string_from_system(false, true)
	return "\n".join([
		"",
		"==============================================",
		"   ELVEBAKKEN VGS  -  SKRIVER K-1 (KJELLER)",
		"==============================================",
		"",
		"   STATUS ........ FEIL",
		"   TIDSPUNKT ..... %s" % time,
		"",
		"   FEILKODE:",
		"",
		"          %s" % code,
		"",
		"   UTSKRIFTEN BLE AVBRUTT.",
		"   DOKUMENTET DITT ER IKKE HER.",
		"",
		"   FORTSETT TIL ETASJE -2.",
		"   TA MED DETTE ARKET.",
		"",
		"==============================================",
		"   (ikke snu)",
		"",
	])


## Skriver arket til fil og sender det til skriveren. Returnerer true ved suksess.
func print_error_page() -> bool:
	var page := build_page()
	var path := ProjectSettings.globalize_path(PAGE_FILE)
	var f := FileAccess.open(PAGE_FILE, FileAccess.WRITE)
	if f:
		f.store_string(page)
		f.close()
	print("PrinterService: side lagret i ", path)

	_run_error_hook()

	var success := false
	if not Config.get_value("station", "print_enabled", true):
		print("PrinterService: utskrift er slått av (print_enabled=false)")
	elif OS.get_name() != "Linux":
		print("PrinterService: ikke Linux (%s) - hopper over lp. Ville kjørt: %s" % [OS.get_name(), _command_preview(path)])
	else:
		success = await _run_lp(path)
	print_finished.emit(success)
	return success


func _lp_args(path: String) -> PackedStringArray:
	var args := PackedStringArray()
	var printer := str(Config.get_value("station", "printer_name", ""))
	if printer != "":
		args.append_array(["-d", printer])
	for a: Variant in Config.get_value("station", "print_args", []):
		args.append(str(a))
	args.append(path)
	return args


func _command_preview(path: String) -> String:
	return str(Config.get_value("station", "print_command", "lp")) + " " + " ".join(_lp_args(path))


func _run_lp(path: String) -> bool:
	var cmd := str(Config.get_value("station", "print_command", "lp"))
	var args := _lp_args(path)
	# Kjøres i egen tråd så spillet ikke fryser mens CUPS svarer.
	var thread := Thread.new()
	thread.start(func() -> Dictionary:
		var output: Array = []
		var code := OS.execute(cmd, args, output, true)
		return {"exit_code": code, "output": "\n".join(output)})
	while thread.is_alive():
		await get_tree().process_frame
	last_result = thread.wait_to_finish()
	print("PrinterService: ", cmd, " ", " ".join(args), " -> ", last_result)
	return last_result.get("exit_code", -1) == 0


func _run_error_hook() -> void:
	var hook: Array = Config.get_value("station", "on_error_command", [])
	if hook.is_empty():
		return
	var args := PackedStringArray()
	for i in range(1, hook.size()):
		args.append(str(hook[i]))
	var pid := OS.create_process(str(hook[0]), args)
	print("PrinterService: on_error_command startet (pid %d)" % pid)
