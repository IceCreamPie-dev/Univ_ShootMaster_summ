extends Node3D

# 클레이 피젼 설정
@export var clay_pigeon: PackedScene
@export_range(0, 90) var launch_angle: float = 45.0
@export_range(0, 100) var spread_angle: float = 27.0
@export var canon: Node3D
@export var clay_spawn_point: Node3D

# 오디오 플레이어
@export var gear_noise: AudioStreamPlayer3D
@export var shoot_noise: AudioStreamPlayer3D
@export var reload_noise: AudioStreamPlayer3D
@export var beep_sfx: AudioStreamPlayer3D

const DEFAULT_VELOCITY: float = 28.0
var is_rotating: bool = false
var target_rotation: float = 0.0
var rotation_speed: float = 2.0

func _ready():
	set_process_input(true)
	var preloader = ResourcePreloader.new() # preload clay
	add_child(preloader)
	preloader.add_resource("clay", load("res://Entities/Clay/clay.tscn"))
	if !canon:
		push_warning("Canon node not found!")
	if !clay_spawn_point:
		push_warning("Clay spawn point not found!")

func _process(delta):
	if is_rotating and canon:
		var current_rotation = canon.rotation.x
		var new_rotation = lerp_angle(current_rotation, target_rotation, rotation_speed * delta)
		canon.rotation.x = new_rotation
		
		if abs(new_rotation - target_rotation) < 0.01:
			is_rotating = false
			if gear_noise:
				gear_noise.stop()

func rotate_canon() -> void:
	if canon:
		target_rotation = deg_to_rad(launch_angle)
		is_rotating = true
		if gear_noise and !gear_noise.playing:
			gear_noise.play()

func shoot(velocity: float = DEFAULT_VELOCITY) -> void:
	if beep_sfx:
		beep_sfx.play()
	await get_tree().create_timer(0.5).timeout
	
	rotate_canon()
	await get_tree().create_timer(1.0).timeout
	
	if clay_pigeon and clay_spawn_point:
		var new_pigeon = clay_pigeon.instantiate()
		if new_pigeon:
			GameManager.register_shot()
			get_tree().root.add_child(new_pigeon)
			new_pigeon.global_transform = clay_spawn_point.global_transform
			
			# Canon의 방향을 기준으로 발사 방향 계산
			var random_spread = randf_range(-spread_angle/2, spread_angle/2)
			
			# Canon의 기본 방향(-Z)을 기준으로 회전
			var base_direction = -clay_spawn_point.global_transform.basis.z
			
			# 좌우 랜덤 회전
			var spread_rotation = Transform3D().rotated(Vector3.UP, deg_to_rad(random_spread))
			var direction = spread_rotation * base_direction
			
			# 발사 각도 적용 (X축 회전)
			var angle_rotation = Transform3D().rotated(Vector3.RIGHT, deg_to_rad(launch_angle))
			direction = angle_rotation * direction
			
			if new_pigeon is RigidBody3D:
				new_pigeon.linear_velocity = direction.normalized() * velocity
				new_pigeon.angular_velocity = Vector3.ZERO
				
				if shoot_noise:
					shoot_noise.play()
				await get_tree().create_timer(1.0).timeout
				if reload_noise:
					reload_noise.play()
