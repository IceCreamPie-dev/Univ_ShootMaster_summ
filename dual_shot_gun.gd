extends XRToolsPickable

# ::변수::
# 상탄, 하탄 장전 상태, 현재 컨트롤러
@export var upper_loaded: bool = true		# 상부 장전상태
@export var lower_loaded: bool = true		# 하부 장전상태
@export var used_shell: PackedScene			# 사용된 탄피 씬
@export var shell: PackedScene				# 새로운 탄피 씬
@export var bullet: PackedScene				# 총알 씬
@export var sfx_close: AudioStreamWAV		# 총오픈 소리
@export var sfx_open: AudioStreamWAV		# 총닫기 소리
@export var sfx_eject: AudioStreamWAV		# 탄피배출 소리
@export var sfx_shoot: AudioStreamWAV		# 총 발사 소리
@export var sfx_dryfire: AudioStreamWAV		# 총 공발사 소리

@export var auto_reset_position: bool = false  # 자동 리셋 활성화 여부
@export var reset_position: Node3D  # 리셋될 위치
@export var reset_duration: float = 1.0  # 리셋 애니메이션 시간

@onready var audio_player = $Shot			# SFX 플레이어 전방
@onready var upper_muzzle = $UpperMuzzle	# 총구 전방 상부
@onready var lower_muzzle = $LowerMuzzle	# 총구 전방 하부
@onready var eject_timer = $EjectTimer		# 탄배출 타이머
@onready var muzzle_flash = $MuzzleFlash	# VFX 플레이어 앞단 위치
@onready var muzzle_boom = $MuzzleFlashBoom # VFX 플레이어 앞단 위치
@onready var eject_smoke_upper = $하단부/EjectSmoke_upper		# VFX 플레이어 중간 위치
@onready var eject_smoke_lower = $하단부/EjectSmoke_lower		# VFX 플레이어 중간 위치
@onready var sfx_player = $SFX_eject		# SFX 플레이어 중간 위치
@onready var shell_point_up: Node3D = $하단부/shell_eject_up				# 탄피 나오는 부분 상
@onready var shell_point_down: Node3D = $하단부/shell_eject_down			# 탄피 나오는 부분 하
@onready var upper_shell: Node3D = $하단부/shell_eject_up/SkitShot
@onready var lower_shell: Node3D = $하단부/shell_eject_down/SkitShot


var is_open: bool = false				# 총의 개방 상태
var aniplayer: AnimationPlayer			# 애니메이션 플레이어
const THRESHOLD = 0.5					# 조이스틱 입력의 임계값
var upper_fired: bool = false			# 상단 총열에서 발사되었는지 여부
var lower_fired: bool = false			# 하단 총열에서 발사되었는지 여부

signal fired	# 사격시 시그널 (트리거 클릭)
signal opened	# 총오픈 시그널 (조이스틱 하)
signal closed	# 총닫기 시그널 (조이스틱 상)

func _ready():
	super._ready()
	#리소스 로드
	var preloader = ResourcePreloader.new()
	add_child(preloader)
	preloader.add_resource("bullet", load("res://Entities/Bullet/Bullet.tscn"))
	preloader.add_resource("shell", load("res://Entities/bulletPack/shotgun_shell.tscn"))
	connect("action_pressed", Callable(self, "_on_action_pressed"))
	connect("dropped", Callable(self, "_on_dropped"))
	aniplayer = $AnimationPlayer

func _on_action_pressed(pickable): 			# 컨트롤러 입력을 받고 발사처리
	if pickable == self:
		var controller = get_picked_up_by_controller()
		if controller and controller.get_is_active() and controller.is_button_pressed("trigger_click"):
			fire()

func _process(delta):
	if is_picked_up(): 						# 잡을시 프레임마다 입력을 인풋
		var controller = get_picked_up_by_controller()
		if controller:
			var joystick = controller.get_vector2("primary")
			if joystick.y < -THRESHOLD and not is_open:
				open()
			elif joystick.y > THRESHOLD and is_open:
				close()

func _on_dropped(pickable):
	if auto_reset_position and reset_position:
		# 리셋 위치로 부드럽게 이동
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.set_ease(Tween.EASE_OUT)
		
		# 위치와 회전 동시에 트윈
		tween.set_parallel(true)
		tween.tween_property(self, "global_position", reset_position.global_position, reset_duration)
		tween.tween_property(self, "global_rotation", reset_position.global_rotation, reset_duration)

# 발사 로직
func fire() -> void:
	emit_signal("fired")
	if !is_open:
		if upper_loaded:
			shoot_bullet(upper_muzzle)
			upper_loaded = false
			upper_fired = true
			trigger_haptic_feedback()
		elif lower_loaded:
			shoot_bullet(lower_muzzle)
			lower_loaded = false
			lower_fired = true
			trigger_haptic_feedback()
	else:
			sfx_player.stream = sfx_dryfire
			sfx_player.play()

# 총알을 나가게 하는 기능
func shoot_bullet(muzzle: Node3D) -> void:
	if bullet:
		audio_player.play()
		var new_bullet = bullet.instantiate()
		if new_bullet:
			get_tree().root.add_child(new_bullet)							# root에 총알 추가
			new_bullet.global_transform = muzzle.global_transform			# 총알 위치
			new_bullet.apply_impulse(muzzle.global_transform.basis.z * 100)	# 총알 속도++
		
		muzzle_flash.restart()												# VFX 재생
		muzzle_boom.restart()
		global_transform.origin -= self.global_transform.basis.z * 0.05

# 총 열기
func open() -> void:
	if !is_open:
		if not aniplayer.is_playing():
			aniplayer.play("open")
			is_open = true
			eject_timer.start(0.2)
			emit_signal("opened")
			if sfx_player and sfx_open:
				sfx_player.stream = sfx_open
				sfx_player.play()

# 총 닫기
func close() -> void:
	if is_open:
		if not aniplayer.is_playing():
			aniplayer.play_backwards("open")
			#is_open = false
			emit_signal("closed")
			if sfx_player and sfx_close:
				sfx_player.stream = sfx_close
				sfx_player.play()
				is_open = false
				upper_fired = false			# 테스트용 닫을시 자동 장전
				upper_loaded = true
				upper_shell.visible = true
				lower_fired = false
				lower_loaded = true
				lower_shell.visible = true
				

# 탄피 배출 로직
func eject_shells() -> void:
	if upper_fired:
		upper_shell.visible = false
		spawn_used_shell(shell_point_up)
		eject_smoke_upper.restart()
		upper_fired = false
		if sfx_player and sfx_eject:
			sfx_player.stream = sfx_eject
			sfx_player.play()
	if lower_fired:
		lower_shell.visible = false
		spawn_used_shell(shell_point_down)
		eject_smoke_lower.restart()
		lower_fired = false
		if sfx_player and sfx_eject:
			sfx_player.stream = sfx_eject
			sfx_player.play()

# 탄피 배출 기능
func spawn_used_shell(eject_point: Node3D) -> void:
	if used_shell:
		var new_shell = used_shell.instantiate()
		if new_shell:
			get_tree().root.add_child(new_shell)
			new_shell.global_transform = eject_point.global_transform
			
			# 탄피에 뒤쪽으로 힘++
			var ejection_force = -eject_point.global_transform.basis.y * 2  # 뒤쪽 방향
			ejection_force += Vector3(randf_range(-0.5, 0.5), randf_range(0.2, 0.5), 0)  # 약간의 랜덤성 추가
			new_shell.apply_impulse(ejection_force)



# 트리거 당길때 햅틱 주기
func trigger_haptic_feedback():
	var controller = get_picked_up_by_controller()
	if controller:
		controller.trigger_haptic_pulse("haptic", 0.0, 1.5, 0.5, 0.0)

func _on_eject_timer_timeout() -> void:
	eject_shells()
