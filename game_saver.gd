extends Node

const save_path = "user://shot_master.cfg"

var instance = null

func _ready():
	if instance == null:
		instance = self
	else:
		queue_free()
		
# 세이브 
func save_game():
	var config = ConfigFile.new()
	var player_data = PlayerData.save_data()
	config.set_value("Player", "data", player_data)
	
	# 스테이지 데이터 저장
	
	# 기타 상태 저장
	
	# 저장
	var error = config.save(save_path)
	if error != OK:
		print("게임저장 중 오류발생: ", error)

# 로드
func load_game():
	var config = ConfigFile.new()
	var error = config.load(save_path)
	
	if error != OK:
		print("게음을 불러오는 중 오류 발생: ", error)
		return
		
	# 데이터 불러오기
	var player_data = config.get_value("Player", "data", {})
	PlayerData.load_data(player_data)
	
	# 스테이지 데이터 불러오기
	
	# 기타 상태 불러오기
