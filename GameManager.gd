# GameManager.gd
extends Node

# 점수 관련 변수
var current_score: int = 0
var high_score: int = 0
var targets_hit: int = 0
var total_shots: int = 0
var totla_target: int = 0
var accuracy: float = 0.0
var is_game_active: bool = true
var xr_interface: XRInterface
# 시그널 정의
signal score_updated(new_score)
signal accuracy_updated(new_accuracy)
signal hit_registered(total_hits)
signal game_paused
signal game_resumed
signal game_over
signal game_start

var game_diff: int = 1 # 난이도 0 쉬움, 1 보통, 2 어려움

func _ready():
	load_high_score() # 게임 시작시 최고 점수 로드
	reset_stats()
		# OpenXR 인터페이스 가져오기
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		# OpenXR 시그널 연결
		xr_interface.session_begun.connect(_on_openxr_session_begun)
		xr_interface.session_visible.connect(_on_openxr_visible_state)
		xr_interface.session_focussed.connect(_on_openxr_focused_state)
		xr_interface.session_stopping.connect(_on_openxr_stopping)

func start_game():
	emit_signal("game_start")

# OpenXR 세션이 시작될 때
func _on_openxr_session_begun():
	print("OpenXR session begun")

# OpenXR visible 상태 변경 시 (헤드셋을 벗었을 때)
func _on_openxr_visible_state():
	if is_game_active:
		print("OpenXR lost focus (visible_state)")
		pause_game()

# OpenXR focus 상태 변경 시
func _on_openxr_focused_state():
	if !is_game_active:
		print("OpenXR gained focus")
		resume_game()

# OpenXR 세션이 종료될 때
func _on_openxr_stopping():
	print("OpenXR session stopping")
	pause_game()

func toggle_pause():
	if is_game_active:
		pause_game()
	else:
		resume_game()

func pause_game():
	if is_game_active:
		is_game_active = false
		get_tree().paused = true
		emit_signal("game_paused")
		# 오디오 음소거
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)

func resume_game():
	if !is_game_active:
		is_game_active = true
		get_tree().paused = false
		emit_signal("game_resumed")
		# 오디오 음소거 해제
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), false)

func failed():
	emit_signal("game_over")

# 자동 일시정지를 위한 VR 인터페이스 체크
func _process(_delta):
	if XRServer.primary_interface:
		var vr_interface = XRServer.primary_interface
		if !vr_interface.get_play_area_mode():
			if is_game_active:
				pause_game()

# 기본 스탯 초기화
func reset_stats() -> void:
	current_score = 0
	targets_hit = 0
	total_shots = 0
	accuracy = 0.0
	emit_signal("score_updated", current_score)
	emit_signal("accuracy_updated", accuracy)
	emit_signal("hit_registered", targets_hit)

# 점수 추가
func add_score(points: int) -> void:
	current_score += points
	emit_signal("score_updated", current_score)
	
	if current_score > high_score:
		high_score = current_score
		save_high_score()

# 명중 처리
func register_hit() -> void:
	targets_hit += 1
	update_accuracy()
	emit_signal("hit_registered", targets_hit)

# 발사 처리
func register_shot() -> void:
	total_shots += 1
	update_accuracy()

# 정확도 계산
func update_accuracy() -> void:
	if total_shots > 0:
		accuracy = float(targets_hit) / float(total_shots) * 100.0
		emit_signal("accuracy_updated", accuracy)

# 최고 점수 저장
func save_high_score() -> void:
	var save_file = FileAccess.open("user://highscore.save", FileAccess.WRITE)
	save_file.store_var(high_score)

# 최고 점수 로드
func load_high_score() -> void:
	if FileAccess.file_exists("user://highscore.save"):
		var save_file = FileAccess.open("user://highscore.save", FileAccess.READ)
		high_score = save_file.get_var()

# 현재 스탯 가져오기
func get_current_stats() -> Dictionary:
	return {
		"score": current_score,
		"high_score": high_score,
		"hits": targets_hit,
		"shots": total_shots,
		"accuracy": accuracy
	}
