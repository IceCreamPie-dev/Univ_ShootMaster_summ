#DialogManager.gd
extends Node

signal dialogue_started(dialogue_key)
signal dialogue_ended
signal dialogue_next(speaker, text)
signal actor_updated(actor_name, properties)

var current_dialogue: Dictionary  = {}
var dialogue_data: Dictionary = {}
var supported_languages: Array = ["en", "ko", "ja"]
var actors: Dictionary = {}
var current_section: String = ""
var base_path: String

func initialize_for_scene():
	load_dialogue_data()
	set_language(PlayerData.Lang)
	print("DialogueManager initialized")


func load_dialogue_data():
	for lang in supported_languages:
		dialogue_data[lang] = {}
		var dirs = DirAccess.get_directories_at("res://Assets/Dialouges/")
		for dir in dirs:
			_load_dialogues_in_directory("res://Assets/Dialouges/" + dir, lang)

func _load_dialogues_in_directory(path: String, lang: String):
	var files = DirAccess.get_files_at(path)
	for file in files:
		if file.ends_with("_%s.dialogue" % lang):
			var dialogue_key = file.split("_")[0]
			var file_path = path + "/" + file
			var content = FileAccess.get_file_as_string(file_path)
			dialogue_data[lang][dialogue_key] = parse_dialogue_file(content)

func parse_dialogue_file(content: String) -> Dictionary:
	var parsed_data = {}
	var current_dialogue = []
	var current_section = ""

	for line in content.split("\n"):
		line = line.strip_edges()
		if line.begins_with("~"):
			if current_section != "":
				parsed_data[current_section] = current_dialogue
			current_section = line.substr(1).strip_edges()
			current_dialogue = []
		elif line.begins_with("Actor"):
			var parts = line.split(" ", false, 2)
			if parts.size() >= 3:
				var actor_name = parts[1]
				var properties = parts[2].split(", ")
				current_dialogue.append({"type": "actor", "name": actor_name, "properties": properties})
		elif line.begins_with("[play_sfx="):
			var path = line.substr(10).trim_suffix("]")
			current_dialogue.append({"type": "sfx", "path": path})
		elif line.begins_with("[wait"):
			var duration = float(line.split("=")[1].trim_suffix("]"))
			current_dialogue.append({"type": "wait", "duration": duration})
		elif ":" in line:
			var parts = line.split(":", false, 1)
			current_dialogue.append({"type": "dialogue", "speaker": parts[0].strip_edges(), "text": parts[1].strip_edges()})
		elif line == "=> END":
			current_dialogue.append({"type": "end"})

	if current_section != "":
		parsed_data[current_section] = current_dialogue

	return parsed_data

func set_language(lang: String):
	if lang in supported_languages:
		PlayerData.Lang = lang
	else:
		push_warning("Unsupported language: %s. Falling back to default language." % lang)
		PlayerData.Lang = "ko"

func start_dialogue(dialogue_key: String, section: String = "start"):
	print("Starting dialogue: ", dialogue_key, " section: ", section)
	
	var parts = dialogue_key.split("/")
	var actual_key = parts[-1]
	if PlayerData.Lang in dialogue_data and actual_key in dialogue_data[PlayerData.Lang]:
		current_dialogue = dialogue_data[PlayerData.Lang][actual_key]
		current_section = section
		emit_signal("dialogue_started", dialogue_key)
		process_next_dialogue_item()
	else:
		push_warning("Dialogue key not found: %s in language: %s" % [actual_key, PlayerData.Lang])

func emit_custom_signal(node_path: String, signal_name: String):
	var node = get_node_or_null(node_path)
	if node:
		if node.has_signal(signal_name):
			node.emit_signal(signal_name)
		else:
			push_warning("Signal not found in node %s: %s" % [node_path, signal_name])
	else:
		push_warning("Node not found: %s" % node_path)
	process_next_dialogue_item()

func process_next_dialogue_item():
	if current_section not in current_dialogue or current_dialogue[current_section].is_empty():
		stop_dialogue()
		return

	var item = current_dialogue[current_section].pop_front()
	
	match item["type"]:
		"dialogue":
			show_dialogue(item["speaker"], item["text"])
			await get_tree().create_timer(1.0).timeout
			process_next_dialogue_item()
		"wait":
			await get_tree().create_timer(item["duration"]).timeout
			process_next_dialogue_item()
		"sfx":
			play_sfx(item["path"])
			process_next_dialogue_item()
		"actor":
			update_actor(item["name"], item["properties"])
			process_next_dialogue_item()
		"end":
			pass
		_:
			push_warning("Unknown dialogue item type: %s" % item["type"])
			process_next_dialogue_item()

func show_dialogue(speaker: String, text: String):
	emit_signal("dialogue_next", speaker, text)
	SubtitleSystem.show_subtitle(speaker, text, 3.0)  # 기본 지속 시간 3초

func play_sfx(sound_path: String, volume: float = 1.0):
	var audio_key = sound_path.get_file()
	var stream: AudioStream = null
	
	# 현재 씬의 ResourcePreloader에서 리소스 찾기
	var current_scene = get_tree().current_scene
	if current_scene.has_node("ResourcePreloader"):
		var preloader = current_scene.get_node("ResourcePreloader")
		if preloader.has_resource(audio_key):
			stream = preloader.get_resource(audio_key)
	
	# ResourcePreloader에 없으면 직접 로드
	if not stream:
		print("ResourcePreloader에 오디오를 없습니다 로드합니다.")
		stream = load(sound_path)
	
	if stream:
		var player = AudioStreamPlayer.new()
		add_child(player)
		player.stream = stream
		player.volume_db = linear_to_db(volume)
		player.play()
		player.connect("finished", Callable(player, "queue_free"))
	else:
		push_warning("Failed to load audio: " + sound_path)

func update_actor(actor_name: String, properties: Array):
	actors[actor_name] = properties
	emit_signal("actor_updated", actor_name, properties)
	process_next_dialogue_item()

func show_next_dialogue():
	if current_section not in current_dialogue or current_dialogue[current_section].is_empty():
		emit_signal("dialogue_ended")
		return

	var dialogue_entry = current_dialogue[current_section].pop_front()
	emit_signal("dialogue_next", dialogue_entry["speaker"], dialogue_entry["text"])
	
	# SubtitleSystem을 통해 대화 표시
	SubtitleSystem.show_subtitle(
		dialogue_entry["speaker"],
		dialogue_entry["text"],
		dialogue_entry.get("duration", 3.0)
	)

	# 대화 엔트리에 'do' 키가 있으면 해당 명령 실행
	if dialogue_entry.has("do"):
		execute_do_command(dialogue_entry["do"])

func execute_do_command(command: String):
	var parts = command.split(" ", false, 2)
	if parts.size() < 2:
		push_warning("Invalid 'do' command: %s" % command)
		return
	
	var method_name = parts[0]
	var args_string = parts[1]
	var args = parse_args(args_string)
	
	if method_name == "emit_custom_signal":
		if args.size() == 2:
			emit_custom_signal(args[0], args[1])
		else:
			push_warning("Invalid arguments for emit_custom_signal: %s" % args)
	elif has_method(method_name):
		callv(method_name, args)
	else:
		push_warning("Method not found: %s" % method_name)

func parse_args(args_string: String) -> Array:
	var args = []
	var regex = RegEx.new()
	regex.compile('(\\w+|"[^"]*")')
	for match in regex.search_all(args_string):
		var arg = match.get_string()
		if arg.begins_with('"') and arg.ends_with('"'):
			arg = arg.substr(1, arg.length() - 2)
		elif arg.is_valid_int():
			arg = arg.to_int()
		elif arg.is_valid_float():
			arg = arg.to_float()
		args.append(arg)
	return args

func stop_dialogue():
	# 현재 진행 중인 대화 중단
	current_dialogue.clear()
	current_section = ""
	
	# 모든 진행 중인 오디오 중지
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
	
	# 대화 종료 신호 발생
	emit_signal("dialogue_ended")
	
	print("Dialogue stopped")

func get_dialogue_keys() -> Array:
	return dialogue_data[PlayerData.Lang].keys()

func get_supported_languages() -> Array:
	return supported_languages

func translate_text(text_key: String) -> String:
	if PlayerData.Lang in dialogue_data and "translations" in dialogue_data[PlayerData.Lang]:
		return dialogue_data[PlayerData.Lang]["translations"].get(text_key, text_key)
	return text_key
