#PlayerData
extends Node

var CP: int = 0
var XP: int = 0
var Score_EndlessShot: int = 0
var Score_lv1: int = 0
var Score_lv2: int = 0
var Score_lv3: int = 0
var Score_lv4: int = 0
var Score_lv5: int = 0
var Lang: String = "ko"
var DoneTutorial: bool = false
var current_score = 0 # 씬의 로컬 점수

const RANKS = {
	0: "ROOKIE",
	10000: "HUNTER",
	20000: "HIGH HUNTER",
	30000: "EXPERT HUNTER",
	40000: "MASTER HUNTER",
	50000: "SHOT MASTER"
}

signal level_up(new_level: int)
signal cp_changed(new_cp: int)
signal xp_changed(new_xp: int)
signal rank_changed(new_rank: String)

func save_data() -> Dictionary:
	return {
		"CP": CP,
		"XP": XP,
		"Lang": Lang,
		"Score_EndlessShot": Score_EndlessShot,
		"Score_lv1": Score_lv1,
		"Score_lv2": Score_lv2,
		"Score_lv3": Score_lv3,
		"Score_lv4": Score_lv4,
		"Score_lv5": Score_lv5,
		"DoneTutorial": DoneTutorial
	}

func load_data(data: Dictionary) -> void:
	CP = data.get("CP", 0)
	XP = data.get("XP", 0)
	Lang = data.get("Lang", "en")
	Score_EndlessShot = data.get("Score_EndlessShot", 0)
	Score_lv1 = data.get("Score_lv1", 0)
	Score_lv2 = data.get("Score_lv2", 0)
	Score_lv3 = data.get("Score_lv3", 0)
	Score_lv4 = data.get("Score_lv4", 0)
	Score_lv5 = data.get("Score_lv5", 0)
	DoneTutorial = data.get("DoneTutorial", false)

func add_scene_rewards(CP_PER_SCENE, XP_PER_SCENE) -> void:
	add_cp(CP_PER_SCENE)
	add_xp(XP_PER_SCENE)

func add_cp(amount: int) -> void:
	CP += amount
	emit_signal("cp_changed", CP)

func add_xp(amount: int) -> void:
	var old_rank = get_current_rank()
	XP += amount
	emit_signal("xp_changed", XP)
	
	var new_rank = get_current_rank()
	if old_rank != new_rank:
		emit_signal("rank_changed", new_rank)

func get_current_rank() -> String:
	var current_rank = "ROOKIE"
	for threshold in RANKS.keys():
		if XP >= threshold:
			current_rank = RANKS[threshold]
		else:
			break
	return current_rank

func get_xp_to_next_rank() -> Dictionary:
	var current_rank = get_current_rank()
	var next_threshold = 0
	var next_rank = ""
	
	# 현재 랭크의 다음 랭크 찾기
	var found_current = false
	for threshold in RANKS.keys():
		if found_current:
			next_threshold = threshold
			next_rank = RANKS[threshold]
			break
		if RANKS[threshold] == current_rank:
			found_current = true
	
	return {
		"next_rank": next_rank,
		"xp_needed": next_threshold - XP if next_threshold > 0 else 0
	}

func get_rank_progress() -> float:
	var current_xp = XP
	var current_threshold = 0
	var next_threshold = 1000  # 기본값
	
	for threshold in RANKS.keys():
		if current_xp >= threshold:
			current_threshold = threshold
		else:
			next_threshold = threshold
			break
	
	var progress = float(current_xp - current_threshold) / float(next_threshold - current_threshold)
	return clamp(progress, 0.0, 1.0)

func is_max_rank() -> bool:
	return get_current_rank() == "SHOT MASTER"
