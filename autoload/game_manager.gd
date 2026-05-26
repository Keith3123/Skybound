extends Node
## ============================================================
##  GameManager.gd  —  Autoload Singleton
##  Handles: score, high score, coin count, scene switching, theme progression
## ============================================================

signal score_updated(new_score: int)
signal theme_changed(theme: int)

# ── Game Data ──────────────────────────────────────────────
var score: int = 0
var high_score: int = 0
var coins_collected: int = 0
var sfx_enabled: bool = true
var sfx_volume: float = 5.0
var music_volume: float = 0.8
var current_theme: int = 0   # 0=Clear, 1=Sunset, 2=Night, 3=Space

const SAVE_PATH := "user://skybound_save.dat"

# ── Lifecycle ──────────────────────────────────────────────
func _ready() -> void:
	_load_data()

# ── Score Functions ────────────────────────────────────────
## Add points to the score. Automatically updates high score.
func add_score(points: int) -> void:
	if points <= 0:
		return
	var old_score = score
	score += points
	if score > high_score:
		high_score = score
		_save_data()
	score_updated.emit(score)
	
	# Check if we crossed a 120-point threshold (theme progression)
	var old_theme = old_score / 120
	var new_theme = score / 120
	if new_theme > old_theme:
		_advance_theme()

## Called when the player collects a coin (+5 pts).
func collect_coin() -> void:
	coins_collected += 1
	add_score(5)

## Reset score, coins, and theme for a new game session.
func reset() -> void:
	score = 0
	coins_collected = 0
	if current_theme != 0:
		current_theme = 0
		theme_changed.emit(current_theme)

## Advance to the next theme (cycles through 4 themes: 0→1→2→3→0...)
func _advance_theme() -> void:
	current_theme = (current_theme + 1) % 4
	theme_changed.emit(current_theme)

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
