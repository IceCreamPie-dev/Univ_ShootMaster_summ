extends Node3D

class_name SubtitleSystem

class Subtitle:
	var name: String
	var text: String
	var duration: float
	var start_time: float
	var name_label: Label3D
	var text_label: Label3D
	var name_color: Color
	var text_color: Color

	func _init(n: String, t: String, d: float, nc: Color, tc: Color):
		name = n
		text = t
		duration = d
		start_time = 0.0
		name_color = nc
		text_color = tc

@onready var staging = $"/root/Main"

var subtitles: Array[Subtitle] = []
var subtitle_container: Node3D = null
var max_width: float = 1.0  # 최대 너비 (미터 단위)
var sfx_player: AudioStreamPlayer3D = null

static var instance: SubtitleSystem = null

var default_name_color: Color = Color(1, 0.5, 0, 1)  # 주황색
var default_text_color: Color = Color(1, 1, 1, 1)  # 흰색
var background_color: Color = Color(0, 0, 0)
var fade_duration: float = 0.4
var max_subtitles: int = 3  # 화면에 표시할 최대 자막 수
var subtitle_spacing: float = 0.4  # 자막 간 간격
var translations = {}

func _init():
	if instance == null:
		instance = self
	else:
		push_warning("SubtitleSystem already exists. Use SubtitleSystem.instance to access it.")

func _ready():
	staging.connect("scene_loaded", Callable(self, "_on_scene_loaded"))
	staging.connect("scene_visible", Callable(self, "_on_scene_visible"))

func _on_scene_visible(scene, user_data):
	create_subtitle_container()

func _process(delta):
	if subtitles.is_empty():
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	var subtitle = subtitles[0]
	
	if current_time - subtitle.start_time > subtitle.duration:
		fade_out_subtitle(subtitle)
		subtitles.clear()

func create_subtitle_container():
	print("new container")
	if subtitle_container != null:
		return

	subtitle_container = Node3D.new()
	subtitle_container.name = "SubtitleContainer"
	add_child(subtitle_container)
	sfx_player = AudioStreamPlayer3D.new()
	subtitle_container.add_child(sfx_player)
	
	var xr_camera = get_node("../XRCamera3D")
	if xr_camera:
		subtitle_container.global_transform = xr_camera.global_transform
		subtitle_container.translate(Vector3(-0.3, -0.5, -2))
	else:
		push_warning("XRCamera3D not found. Placing subtitle container at default position.")
		subtitle_container.transform.origin = Vector3(0.1, -0.05, -2)
	
	print("Subtitle container and sfx player created and initialized.")

func create_subtitle_labels(subtitle: Subtitle):
	if subtitle_container == null:
		create_subtitle_container()
	
	if subtitle_container == null:
		push_error("Failed to create subtitle container")
		return

	var name_label = Label3D.new()
	var text_label = Label3D.new()
	
	for label in [name_label, text_label]:
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.pixel_size = 0.001
		label.outline_size = 18
		label.outline_modulate = background_color
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		label.width = max_width / label.pixel_size
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.render_priority = 4
		label.outline_render_priority = 3
	
	name_label.text = subtitle.name
	name_label.modulate = subtitle.name_color
	name_label.font_size = 60
	
	text_label.text = subtitle.text
	text_label.modulate = subtitle.text_color
	text_label.font_size = 90
	
	subtitle_container.add_child(name_label)
	subtitle_container.add_child(text_label)
	
	subtitle.name_label = name_label
	subtitle.text_label = text_label
	
	# 위치 조정은 reposition_subtitles에서 처리합니다.

func reposition_subtitles():
	if subtitles.is_empty():
		return
	
	var subtitle = subtitles[0]
	var text_height = subtitle.text_label.get_aabb().size.y * subtitle.text_label.pixel_size 
	var name_height = subtitle.name_label.get_aabb().size.y * subtitle.name_label.pixel_size + -0.49
	var total_height = text_height + name_height + subtitle_spacing
	
	var base_y = -0.8  # 화면 하단에서 시작하는 기준점
	
	# 새 자막을 화면 아래에서 시작하여 올라오게 함
	var start_y = base_y - 0.25
	subtitle.name_label.position = Vector3(-max_width/2, start_y, 0)
	subtitle.text_label.position = Vector3(-max_width/2, start_y + name_height + subtitle_spacing, 0)
	
	var tween = create_tween()
	tween.tween_property(subtitle.name_label, "position:y", base_y, 0.3)
	tween.parallel().tween_property(subtitle.text_label, "position:y", base_y + name_height + subtitle_spacing, 0.3)

func fade_out_subtitle(subtitle: Subtitle):
	var tween = create_tween()
	var start_y_name = subtitle.name_label.position.y
	var start_y_text = subtitle.text_label.position.y
	var end_y_name = start_y_name + 0.2  # 위로 올라가는 거리
	var end_y_text = start_y_text + 0.2  # 위로 올라가는 거리

	# 위로 올라가면서 투명해지는 애니메이션
	tween.parallel().tween_property(subtitle.name_label, "position:y", end_y_name, fade_duration)
	tween.parallel().tween_property(subtitle.text_label, "position:y", end_y_text, fade_duration)
	tween.parallel().tween_property(subtitle.name_label, "modulate:a", 0, fade_duration)
	tween.parallel().tween_property(subtitle.text_label, "modulate:a", 0, fade_duration)
	
	tween.tween_callback(func(): remove_subtitle(subtitle))

static func show_subtitle(name: String, text: String, duration: float, name_color: Color = Color(), text_color: Color = Color()):
	if is_instance_valid(instance):
		instance.add_subtitle(name, text, duration, name_color, text_color)
	else:
		push_warning("SubtitleSystem instance not found or invalid. Creating a new instance.")
		var scene = Engine.get_main_loop().current_scene
		instance = SubtitleSystem.new()
		scene.add_child(instance)
		instance.add_subtitle(name, text, duration, name_color, text_color)

static func clear_subtitle():
	if instance:
		instance._clear_subtitle()
	else:
		push_warning("SubtitleSystem instance not found. Cannot clear subtitle.")

func _clear_subtitle():
	for subtitle in subtitles:
		remove_subtitle(subtitle)
	subtitles.clear()

func add_subtitle(name: String, text: String, duration: float, name_color: Color = Color(), text_color: Color = Color()):
	var nc = name_color if name_color != Color() else default_name_color
	var tc = text_color if text_color != Color() else default_text_color
	
	# 기존 자막이 있으면 위로 올리면서 페이드 아웃
	if not subtitles.is_empty():
		fade_out_subtitle(subtitles[0])
	
	var new_subtitle = Subtitle.new(name, text, duration, nc, tc)
	create_subtitle_labels(new_subtitle)
	
	# 새 자막을 리스트에 추가
	subtitles.clear()  # 기존 자막 제거
	subtitles.push_back(new_subtitle)
	
	# 자막 위치 재조정
	reposition_subtitles()
	
	new_subtitle.start_time = Time.get_ticks_msec() / 1000.0

func remove_subtitle(subtitle: Subtitle):
	if subtitle.name_label:
		subtitle_container.remove_child(subtitle.name_label)
	if subtitle.text_label:
		subtitle_container.remove_child(subtitle.text_label)

static func set_default_name_color(color: Color):
	if instance:
		instance.default_name_color = color

static func set_default_text_color(color: Color):
	if instance:
		instance.default_text_color = color

static func set_background_color(color: Color):
	if instance:
		instance.background_color = color
		instance.update_all_backgrounds()

static func sfx(address: String, volume: float = 0.0):
	if instance:
		instance._play_sfx(address, volume)
	else:
		push_warning("SubtitleSystem instance not found. Cannot play SFX.")

func _play_sfx(address: String, volume: float = 0.0):
	if sfx_player:
		var audio_stream = load(address)
		if audio_stream is AudioStream:
			sfx_player.stream = audio_stream
			sfx_player.volume_db = volume
			sfx_player.play()
		else:
			push_warning("Failed to load audio file: " + address)
	else:
		push_warning("SFX player not initialized.")

func update_all_backgrounds():
	for subtitle in subtitles:
		subtitle.name_label.outline_modulate = background_color
		subtitle.text_label.outline_modulate = background_color
