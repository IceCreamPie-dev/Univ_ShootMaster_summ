extends Node

var current_track: AudioStreamPlayer
var _volume_db: float = 0.0

signal volume_changed(new_volume_db)

func _ready():
	current_track = AudioStreamPlayer.new()
	add_child(current_track)
	current_track.volume_db = _volume_db

func play_bgm(stream: AudioStream, should_loop: bool = true):
	current_track.stream = stream
	current_track.play()

func stop_bgm():
	current_track.stop()

func pause_bgm():
	current_track.stream_paused = true

func resume_bgm():
	current_track.stream_paused = false

func set_volume_db(volume_db: float):
	_volume_db = volume_db
	current_track.volume_db = _volume_db
	emit_signal("volume_changed", _volume_db)

func get_volume_db() -> float:
	return _volume_db

func set_volume_linear(volume: float):
	set_volume_db(linear_to_db(clamp(volume, 0.0, 1.0)))

func get_volume_linear() -> float:
	return db_to_linear(_volume_db)
