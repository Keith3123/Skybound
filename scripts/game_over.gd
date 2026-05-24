extends Control
## ============================================================
##  GameOver.gd  —  Game Over / Results Screen
##  Fixed for Godot 4.6.2 — no set_anchor_preset() calls
## ============================================================
var _gameover_sfx: AudioStreamPlayer
var _btn_sfx: AudioStreamPlayer
# ── Lifecycle ──────────────────────────────────────────────
func _ready() -> void:
	# NOTE: Anchors are already set in game_over.tscn — no call needed here
	_gameover_sfx = AudioStreamPlayer.new()
	_btn_sfx = AudioStreamPlayer.new()
	_gameover_sfx.stream = load("res://sounds/412168__poligonstudio__arcade-game-over.wav")
	_btn_sfx.stream = load("res://sounds/172204__leszek_szary__menu-button.wav")
	_gameover_sfx.volume_db = 0.0
	add_child(_btn_sfx)
	add_child(_gameover_sfx)
	_gameover_sfx.play()
	_build_background()
	_build_ui()

# ── Dark overlay background ────────────────────────────────
func _build_background() -> void:
	var bg := ColorRect.new()
	# Manual full-screen size instead of set_anchor_preset
	bg.position = Vector2(0, 0)
	bg.size     = Vector2(480, 854)
	bg.color    = Color(0.04, 0.06, 0.20, 0.90)
	add_child(bg)

# ── UI Layout ──────────────────────────────────────────────
func _build_ui() -> void:
	# ── Central card — manually centered: x=(480-360)/2=60, y=(854-500)/2=177 ──
	var card := PanelContainer.new()
	card.position = Vector2(60, 150)
	card.size     = Vector2(360, 520)

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.08, 0.12, 0.32, 0.92)
	card_style.corner_radius_top_left     = 22
	card_style.corner_radius_top_right    = 22
	card_style.corner_radius_bottom_left  = 22
	card_style.corner_radius_bottom_right = 22
	card_style.border_width_left   = 2
	card_style.border_width_right  = 2
	card_style.border_width_top    = 2
	card_style.border_width_bottom = 2
	card_style.border_color = Color(0.30, 0.55, 1.0, 0.45)
	card.add_theme_stylebox_override("panel", card_style)
	add_child(card)

	# Margin padding inside the card
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   28)
	margin.add_theme_constant_override("margin_right",  28)
	margin.add_theme_constant_override("margin_top",    28)
	margin.add_theme_constant_override("margin_bottom", 28)
	card.add_child(margin)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 16)
	margin.add_child(inner)

	# ── GAME OVER title ────────────────────────────────────
	var title := Label.new()
	title.text = "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(1.0, 0.28, 0.28))
	title.add_theme_color_override("font_shadow_color", Color(0.6, 0.0, 0.0, 0.7))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	inner.add_child(title)

	# ── Score Section ──────────────────────────────────────
	var score_sec := VBoxContainer.new()
	score_sec.add_theme_constant_override("separation", 8)
	inner.add_child(score_sec)

	_add_stat(score_sec, "Score",   "%d" % GameManager.score,            Color.WHITE,              36)
	_add_stat(score_sec, "🪙 Coins", "%d" % GameManager.coins_collected, Color(1.0, 0.88, 0.22),  24)

	# High score — show NEW RECORD if the player beat it
	var is_record := (GameManager.score > 0) and (GameManager.score >= GameManager.high_score)
	if is_record:
		var rec := Label.new()
		rec.text = "🏆  NEW RECORD!"
		rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rec.add_theme_font_size_override("font_size", 26)
		rec.add_theme_color_override("font_color", Color(1.0, 0.90, 0.15))
		score_sec.add_child(rec)
	else:
		_add_stat(score_sec, "⭐ Best", "%d" % GameManager.high_score, Color(1.0, 0.88, 0.22), 22)

	# Spacer
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 8)
	inner.add_child(sp)

	# ── Buttons ────────────────────────────────────────────
	var retry := _make_btn("↺   RETRY",      Color(0.14, 0.68, 0.26))
	retry.pressed.connect(func(): 
		_btn_sfx.play()
		await _btn_sfx.finished
		GameManager.go_to("res://scenes/game.tscn"))
	inner.add_child(retry)

	var menu := _make_btn("⌂   MAIN MENU", Color(0.22, 0.40, 0.82))
	menu.pressed.connect(func(): 
		_btn_sfx.play()
		await _btn_sfx.finished
		GameManager.go_to("res://scenes/main_menu.tscn"))
	inner.add_child(menu)

# ── Helper: Stat row ───────────────────────────────────────
func _add_stat(parent: Control, lbl_text: String, val_text: String, col: Color, fsize: int) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(row)

	var key := Label.new()
	key.text = lbl_text + ":  "
	key.add_theme_font_size_override("font_size", fsize)
	key.add_theme_color_override("font_color", Color(0.75, 0.82, 1.0))
	row.add_child(key)

	var val := Label.new()
	val.text = val_text
	val.add_theme_font_size_override("font_size", fsize)
	val.add_theme_color_override("font_color", col)
	row.add_child(val)

# ── Helper: Styled Button ──────────────────────────────────
func _make_btn(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(290, 60)

	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left     = 14
	s.corner_radius_top_right    = 14
	s.corner_radius_bottom_left  = 14
	s.corner_radius_bottom_right = 14
	s.content_margin_left   = 20
	s.content_margin_right  = 20
	s.content_margin_top    = 10
	s.content_margin_bottom = 10
	b.add_theme_stylebox_override("normal", s)

	var sh := s.duplicate() as StyleBoxFlat
	sh.bg_color = color.lightened(0.20)
	b.add_theme_stylebox_override("hover", sh)

	var sp := s.duplicate() as StyleBoxFlat
	sp.bg_color = color.darkened(0.22)
	b.add_theme_stylebox_override("pressed", sp)

	var sf := StyleBoxFlat.new()
	sf.bg_color = Color.TRANSPARENT
	b.add_theme_stylebox_override("focus", sf)

	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", Color.WHITE)
	return b
