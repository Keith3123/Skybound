extends Control
## ============================================================
##  MainMenu.gd  —  Title / Start Screen
##  Fixed for Godot 4.6.2 — no set_anchor_preset() calls
## ============================================================

const SW := 480.0
const SH := 854.0
var _btn_sfx: AudioStreamPlayer
var _bg_music: AudioStreamPlayer
var _settings_panel: Control  # Reference to settings overlay
var _hover_sfx: AudioStreamPlayer

# ── Lifecycle ──────────────────────────────────────────────
func _ready() -> void:
	# NOTE: Anchors are already set in main_menu.tscn — no call needed here
	_btn_sfx = AudioStreamPlayer.new()
	_bg_music = AudioStreamPlayer.new()
	_hover_sfx = AudioStreamPlayer.new()
	_btn_sfx.stream = load("res://sounds/172204__leszek_szary__menu-button.wav")
	_bg_music.stream = load("res://sounds/game.mp3")
	_hover_sfx.stream = load("res://sounds/hover.mp3")
	_btn_sfx.volume_db = GameManager.vol_to_db(GameManager.sfx_volume)
	_bg_music.volume_db = GameManager.vol_to_db(GameManager.music_volume)
	_hover_sfx.volume_db = GameManager.vol_to_db(GameManager.sfx_volume)
	add_child(_btn_sfx)
	add_child(_bg_music)
	add_child(_hover_sfx)
	
	if _bg_music.stream is AudioStreamMP3:
		(_bg_music.stream as AudioStreamMP3).loop = true
		
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
	_draw_cloud(Vector2(190, 215), 95)
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
	sub.add_theme_font_size_override("font_size", 18)
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
		#_btn_sfx.volume_db = GameManager.sfx_volume
		_btn_sfx.stop()
		_btn_sfx.play()
		_bg_music.stop()
		await _btn_sfx.finished
		GameManager.go_to("res://scenes/game.tscn"))
	vbox.add_child(play)

	var settings := _make_btn("⚙   SETTINGS", Color(0.35, 0.55, 0.85))
	settings.pressed.connect(func():
		_btn_sfx.stop()
		_btn_sfx.play()
		_show_settings())
	vbox.add_child(settings)

	var exit_btn := _make_btn("✕   EXIT", Color(0.72, 0.18, 0.18))
	exit_btn.pressed.connect(func(): 
		_btn_sfx.stop()
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
	
	b.mouse_entered.connect(func():
		if _hover_sfx:
			_hover_sfx.stop()
			_hover_sfx.volume_db = GameManager.vol_to_db(GameManager.sfx_volume)
			_hover_sfx.play()
	)
	return b

# ── Settings Panel ────────────────────────────────────────
func _show_settings() -> void:
	"""Display the settings overlay with music volume and controls."""
	# Dark overlay background
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.65)
	overlay.size = Vector2(SW, SH)
	add_child(overlay)
	
	# Settings card
	var card := PanelContainer.new()
	card.position = Vector2(45, 50)
	card.size = Vector2(390, 700)
	
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.08, 0.12, 0.32, 0.95)
	card_style.corner_radius_top_left = 20
	card_style.corner_radius_top_right = 20
	card_style.corner_radius_bottom_left = 20
	card_style.corner_radius_bottom_right = 20
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.border_color = Color(0.30, 0.55, 1.0, 0.45)
	card.add_theme_stylebox_override("panel", card_style)
	add_child(card)
	
	# Margin inside card
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	card.add_child(margin)
	
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(340, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(340, 0)
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)  

	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)

	_add_vol_card(vbox,
		"🔊", Color(0.16, 0.58, 0.40),
		"Music Volume", "Background tracks",
		GameManager.music_volume,
		func(val: float) -> void:
			GameManager.music_volume = val
			_bg_music.volume_db = GameManager.vol_to_db(val))

	_add_vol_card(vbox,
		"🎵", Color(0.26, 0.42, 0.80),
		"SFX Volume", "Sound effects",
		GameManager.sfx_volume,
		func(val: float) -> void:
			GameManager.sfx_volume = val
			_btn_sfx.volume_db = GameManager.vol_to_db(val))

	_add_controls_card(vbox)

	#var sp := Control.new()
	#sp.custom_minimum_size = Vector2(0, 6)
	#vbox.add_child(sp)

	var close_btn := _make_btn("✕  CLOSE", Color(0.55, 0.35, 0.55))
	close_btn.pressed.connect(func():
		_btn_sfx.stop(); _btn_sfx.play()
		overlay.queue_free(); card.queue_free())
	vbox.add_child(close_btn)

	_settings_panel = overlay
	
func _add_vol_card(parent: Control, icon: String, icon_col: Color,
		title: String, subtitle: String,
		init_val: float, on_change: Callable) -> void:

	var card := PanelContainer.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.12, 0.17, 0.36, 0.90)
	cs.corner_radius_top_left = 12; cs.corner_radius_top_right = 12
	cs.corner_radius_bottom_left = 12; cs.corner_radius_bottom_right = 12
	card.add_theme_stylebox_override("panel", cs)
	parent.add_child(card)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left",   14)
	m.add_theme_constant_override("margin_right",  14)
	m.add_theme_constant_override("margin_top",    12)
	m.add_theme_constant_override("margin_bottom", 12)
	card.add_child(m)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	m.add_child(col)

	# Top row: icon badge + title/subtitle + value badge
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	col.add_child(top)

	var ibx := PanelContainer.new()
	var is_ := StyleBoxFlat.new()
	is_.bg_color = icon_col
	is_.corner_radius_top_left = 10; is_.corner_radius_top_right = 10
	is_.corner_radius_bottom_left = 10; is_.corner_radius_bottom_right = 10
	is_.content_margin_left = 10; is_.content_margin_right = 10
	is_.content_margin_top = 8;  is_.content_margin_bottom = 8
	ibx.add_theme_stylebox_override("panel", is_)
	var ilbl := Label.new()
	ilbl.text = icon
	ilbl.add_theme_font_size_override("font_size", 20)
	ilbl.add_theme_color_override("font_color", Color.WHITE)
	ibx.add_child(ilbl)
	top.add_child(ibx)

	var tc := VBoxContainer.new()
	tc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tc)

	var tl := Label.new()
	tl.text = title
	tl.add_theme_font_size_override("font_size", 17)
	tl.add_theme_color_override("font_color", Color.WHITE)
	tc.add_child(tl)

	var sl := Label.new()
	sl.text = subtitle
	sl.add_theme_font_size_override("font_size", 12)
	sl.add_theme_color_override("font_color", Color(0.60, 0.68, 0.85))
	tc.add_child(sl)

	# Value badge
	var bbx := PanelContainer.new()
	var bs_ := StyleBoxFlat.new()
	bs_.bg_color = icon_col.darkened(0.28)
	bs_.corner_radius_top_left = 14; bs_.corner_radius_top_right = 14
	bs_.corner_radius_bottom_left = 14; bs_.corner_radius_bottom_right = 14
	bs_.content_margin_left = 10; bs_.content_margin_right = 10
	bs_.content_margin_top = 4;   bs_.content_margin_bottom = 4
	bbx.add_theme_stylebox_override("panel", bs_)
	var blbl := Label.new()
	blbl.text = "%d" % int(init_val)
	blbl.add_theme_font_size_override("font_size", 15)
	blbl.add_theme_color_override("font_color", Color.WHITE)
	bbx.add_child(blbl)
	top.add_child(bbx)

	# Slider row
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 6)
	col.add_child(srow)

	var mn := Label.new(); mn.text = "0"
	mn.add_theme_font_size_override("font_size", 12)
	mn.add_theme_color_override("font_color", Color(0.50, 0.58, 0.75))
	srow.add_child(mn)

	var slider := HSlider.new()
	slider.min_value = 0; slider.max_value = 100; slider.step = 1
	slider.value = init_val
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0, 28)
	slider.value_changed.connect(func(val: float) -> void:
		blbl.text = "%d" % int(val)
		on_change.call(val))
	srow.add_child(slider)

	var mx := Label.new(); mx.text = "100"
	mx.add_theme_font_size_override("font_size", 12)
	mx.add_theme_color_override("font_color", Color(0.50, 0.58, 0.75))
	srow.add_child(mx)


func _add_controls_card(parent: Control) -> void:
	var card := PanelContainer.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.12, 0.17, 0.36, 0.90)
	cs.corner_radius_top_left = 12; cs.corner_radius_top_right = 12
	cs.corner_radius_bottom_left = 12; cs.corner_radius_bottom_right = 12
	card.add_theme_stylebox_override("panel", cs)
	parent.add_child(card)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left",   14)
	m.add_theme_constant_override("margin_right",  14)
	m.add_theme_constant_override("margin_top",    12)
	m.add_theme_constant_override("margin_bottom", 12)
	card.add_child(m)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	m.add_child(col)

	# Header row
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 10)
	col.add_child(hdr)

	var ibx := PanelContainer.new()
	var is_ := StyleBoxFlat.new()
	is_.bg_color = Color(0.52, 0.36, 0.12)
	is_.corner_radius_top_left = 10; is_.corner_radius_top_right = 10
	is_.corner_radius_bottom_left = 10; is_.corner_radius_bottom_right = 10
	is_.content_margin_left = 10; is_.content_margin_right = 10
	is_.content_margin_top = 7;   is_.content_margin_bottom = 7
	ibx.add_theme_stylebox_override("panel", is_)
	var ilbl := Label.new(); ilbl.text = "🎮"
	ilbl.add_theme_font_size_override("font_size", 18)
	ibx.add_child(ilbl)
	hdr.add_child(ibx)

	var htl := Label.new(); htl.text = "Controls"
	htl.add_theme_font_size_override("font_size", 18)
	htl.add_theme_color_override("font_color", Color.WHITE)
	htl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hdr.add_child(htl)

	col.add_child(HSeparator.new())

	_add_ctrl_row(col, ["←", "→"], "Arrow Keys",      "Move left or right")
	_add_ctrl_row(col, ["↑"],       "Up Arrow (hold)", "Shield up — block falling hazards")
	_add_ctrl_row(col, ["Space", "Ctrl"], "Hold",      "Shield sides — block birds")


func _add_ctrl_row(parent: Control, keys: Array,
	label: String, sublabel: String) -> void:

	# ── Wrap row in its own card ───────────────────────────
	var card := PanelContainer.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.16, 0.22, 0.42, 0.85)
	cs.corner_radius_top_left = 8; cs.corner_radius_top_right = 8
	cs.corner_radius_bottom_left = 8; cs.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", cs)
	parent.add_child(card)

	var cm := MarginContainer.new()
	cm.add_theme_constant_override("margin_left",   10)
	cm.add_theme_constant_override("margin_right",  10)
	cm.add_theme_constant_override("margin_top",     8)
	cm.add_theme_constant_override("margin_bottom",  8)
	card.add_child(cm)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	cm.add_child(row)

	var krow := HBoxContainer.new()
	krow.add_theme_constant_override("separation", 4)
	krow.custom_minimum_size = Vector2(76, 0)
	row.add_child(krow)

	for k in keys:
		var bx := PanelContainer.new()
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color(0.18, 0.24, 0.44)
		bs.border_color = Color(0.42, 0.52, 0.76, 0.85)
		bs.border_width_left = 1; bs.border_width_right  = 1
		bs.border_width_top  = 1; bs.border_width_bottom = 1
		bs.corner_radius_top_left = 7; bs.corner_radius_top_right = 7
		bs.corner_radius_bottom_left = 7; bs.corner_radius_bottom_right = 7
		bs.content_margin_left = 8; bs.content_margin_right  = 8
		bs.content_margin_top  = 5; bs.content_margin_bottom = 5
		bx.add_theme_stylebox_override("panel", bs)
		var lbl := Label.new(); lbl.text = k
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.85, 0.90, 1.0))
		bx.add_child(lbl)
		krow.add_child(bx)

	var tc := VBoxContainer.new()
	tc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(tc)

	var ml := Label.new(); ml.text = label
	ml.add_theme_font_size_override("font_size", 14)
	ml.add_theme_color_override("font_color", Color.WHITE)
	tc.add_child(ml)

	var sl := Label.new(); sl.text = sublabel
	sl.add_theme_font_size_override("font_size", 12)
	sl.add_theme_color_override("font_color", Color(0.56, 0.64, 0.84))
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tc.add_child(sl)
