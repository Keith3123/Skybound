extends Node
## ============================================================
##  GameManager.gd  —  Autoload Singleton
##  Handles: score, high score, coin count, scene switching
## ============================================================

signal score_updated(new_score: int)

# ── Game Data ──────────────────────────────────────────────
var score: int = 0
var high_score: int = 0
var coins_collected: int = 0

const SAVE_PATH := "user://skybound_save.dat"

# ── Lifecycle ──────────────────────────────────────────────
func _ready() -> void:
	_load_data()

# ── Score Functions ────────────────────────────────────────
## Add points to the score. Automatically updates high score.
func add_score(points: int) -> void:
	if points <= 0:
		return
	score += points
	if score > high_score:
		high_score = score
		_save_data()
	score_updated.emit(score)

## Called when the player collects a coin (+50 pts).
func collect_coin() -> void:
	coins_collected += 1
	add_score(50)

## Reset score and coins for a new game session.
func reset() -> void:
	score = 0
	coins_collected = 0

# ── Scene Transitions ──────────────────────────────────────
## Switch to any scene by its file path.
func go_to(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)

# ── Save / Load ────────────────────────────────────────────
func _save_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_32(high_score)
		file.close()

func _load_data() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			high_score = file.get_32()
			file.close()
