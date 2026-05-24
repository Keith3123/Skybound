extends Control
## ============================================================
##  MainMenu.gd  —  Title / Start Screen
##  Fixed for Godot 4.6.2 — no set_anchor_preset() calls
## ============================================================

const SW := 480.0
const SH := 854.0
var _btn_sfx: AudioStreamPlayer
var _bg_music: AudioStreamPlayer

# ── Lifecycle ──────────────────────────────────────────────
func _ready() -> void:
	# NOTE: Anchors are already set in main_menu.tscn — no call needed here
	_btn_sfx = AudioStreamPlayer.new()
	_bg_music = AudioStreamPlayer.new()
	_btn_sfx.stream = load("res://sounds/172204__leszek_szary__menu-button.wav")
	_bg_music.stream = load("res://sounds/game.mp3")
	_btn_sfx.volume_db = 0.0
	_bg_music.volume_db = -8.0
	add_child(_btn_sfx)
	add_child(_bg_music)
	_bg_music.play()
	_build_ui()
	

# ── Background (drawn via _draw) ───────────────────────────
func _draw() -> void:
	# Gradient sky: bands from deep blue → light blue
	var top_c := Color(0.08, 0.28, 0.68)
	var bot_c := Color(0.38, 0.70, 0.98)
	var steps  := 24
	for i in steps:
		var t := float(i) / float(steps)
		draw_rect(
			Rect2(0, t * SH, SW, SH / float(steps) + 1.5),
			top_c.lerp(bot_c, t), true
		)

	# Static decorative clouds
	_draw_cloud(Vector2(55,  140), 85)
	_draw_cloud(Vector2(340,  85), 68)
	_draw_cloud(Vector2(190, 230), 95)
	_draw_cloud(Vector2(415, 270), 55)
	_draw_cloud(Vector2(20,  310), 70)

	# Ground strip at the bottom
	draw_rect(Rect2(0, SH - 60, SW, 60), Color(0.18, 0.60, 0.22), true)
	draw_rect(Rect2(0, SH - 65, SW,  8), Color(0.28, 0.78, 0.30), true)

func _draw_cloud(pos: Vector2, w: float) -> void:
	var c := Color(1, 1, 1, 0.65)
	draw_circle(pos,                              w * 0.22, c)
	draw_circle(pos + Vector2(w*0.22, -w*0.10),  w * 0.29, c)
	draw_circle(pos + Vector2(w*0.50, -w*0.06),  w * 0.26, c)
	draw_circle(pos + Vector2(w*0.75,  0),        w * 0.21, c)
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-w*0.05,  0),
		pos + Vector2( w*0.88,  0),
		pos + Vector2( w*0.88,  w*0.18),
		pos + Vector2(-w*0.05,  w*0.18),
	]), c)

# ── UI Buttons ─────────────────────────────────────────────
func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	# Manual center positioning: x=(480-320)/2=80, y adjusted for visual balance
	vbox.position = Vector2(80, 130)
	vbox.size = Vector2(320, 560)
	vbox.add_theme_constant_override("separation", 16)
	add_child(vbox)

	# ── Title ──────────────────────────────────────────────
	var title := Label.new()
	title.text = "SKYBOUND"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_shadow_color", Color(0, 0.1, 0.4, 0.7))
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 4)
	vbox.add_child(title)

	# Subtitle
	var sub := Label.new()
	sub.text = "Endless Vertical Platformer"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 17)
	sub.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0, 0.80))
	vbox.add_child(sub)

	# Spacer
	var sp1 := Control.new()
	sp1.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(sp1)

	# ── High Score display ─────────────────────────────────
	var hs := Label.new()
	hs.text = "⭐  Best:  %d" % GameManager.high_score
	hs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hs.add_theme_font_size_override("font_size", 24)
	hs.add_theme_color_override("font_color", Color(1.0, 0.90, 0.22))
	hs.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	hs.add_theme_constant_override("shadow_offset_x", 2)
	hs.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(hs)

	# Spacer
	var sp2 := Control.new()
	sp2.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(sp2)

	# ── Buttons ────────────────────────────────────────────
	var play := _make_btn("▶   PLAY", Color(0.16, 0.72, 0.28))
	play.pressed.connect(func(): 
		_btn_sfx.play()
		_bg_music.stop()
		await _btn_sfx.finished
		GameManager.go_to("res://scenes/game.tscn"))
	vbox.add_child(play)

	# Controls hint
	var hint := Label.new()
	hint.text = "← →  Arrow Keys  /  A D  to Move"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.78, 0.88, 1.0, 0.72))
	vbox.add_child(hint)

	var exit_btn := _make_btn("✕   EXIT", Color(0.72, 0.18, 0.18))
	exit_btn.pressed.connect(func(): 
		_btn_sfx.play()
		_bg_music.stop()
		await _btn_sfx.finished
		get_tree().quit())
	vbox.add_child(exit_btn)

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
