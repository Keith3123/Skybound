extends Node2D
## ============================================================
##  Game.gd  —  Main Gameplay Scene
##
##  Responsibilities:
##   • Procedurally spawns platforms, coins, and clouds
##   • Controls the camera (follows player upward only)
##   • Shows score / high-score labels
##   • Detects game-over when player falls off screen
##   • Scales difficulty as score increases
## ============================================================

# ── Preloaded Scenes ───────────────────────────────────────
const PLAYER_SCENE   := preload("res://scenes/player.tscn")
const PLATFORM_SCENE := preload("res://scenes/platform.tscn")
const COIN_SCENE     := preload("res://scenes/coin.tscn")
const CLOUD_SCENE    := preload("res://scenes/cloud.tscn")
const METEOR_SCENE   := preload("res://scenes/meteor.tscn")
const BIRD_SCENE     := preload("res://scenes/flying_bird.tscn")
const STAR_SCENE     := preload("res://scenes/falling_star.tscn")

# ── Screen / World Constants ───────────────────────────────
const SW: float = 480.0    # Screen width
const SH: float = 854.0    # Screen height

# Platform spawning distances
const SPAWN_AHEAD:  float = 700.0   # Pre-spawn this far above camera top
const DESPAWN_GAP:  float = 350.0   # Remove objects this far below camera bottom

# Gap between platforms at min/max difficulty
const GAP_MIN_EASY: float = 100.0
const GAP_MAX_EASY: float = 140.0
const GAP_MIN_HARD: float = 145.0
const GAP_MAX_HARD: float = 195.0

# ── Runtime Nodes (created in code) ───────────────────────
var player:      CharacterBody2D
var camera:      Camera2D
var score_label: Label
var hs_label:    Label
var coin_label:  Label

var _platforms:  Node2D   # Container for all platform nodes
var _coins:      Node2D   # Container for all coin nodes
var _clouds:     Node2D   # Container for cloud nodes
var _obstacles:  Node2D   # Container for obstacle nodes

# ── Game State ─────────────────────────────────────────────
var _active:          bool  = false
var _last_plat_y:     float = 0.0   # Y of highest spawned platform
var _last_plat_x: 	  float = 240.0 
var _bg_music:  	  AudioStreamPlayer
var _moving_platform: Platform  # Only one platform moves at a time

# ── Lifecycle ──────────────────────────────────────────────
func _ready() -> void:
	GameManager.reset()
	GameManager.score_updated.connect(_on_score_updated)
	GameManager.theme_changed.connect(_on_theme_changed)

	_build_background()
	_build_containers()
	_build_camera()
	_build_ui()
	_spawn_player()
	_build_initial_level()

	# Set camera so player appears in the lower portion of the screen
	camera.global_position = Vector2(
		SW / 2.0,
		player.global_position.y - SH * 0.14
	)
	
	_bg_music = AudioStreamPlayer.new()
	_bg_music.volume_db = -8.0
	_bg_music.stream = load("res://sounds/game.mp3")
	add_child(_bg_music)
	_change_music(GameManager.current_theme)
	_bg_music.play()

	_active = true

func _process(delta: float) -> void:
	if not _active:
		return
	_move_camera(delta)
	_tick_platform_spawner()
	_tick_cloud_spawner()
	_tick_obstacle_spawner()
	_ensure_moving_platform()  # Keep exactly 1 platform moving
	_despawn_old_objects()
	_check_game_over()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _active:
		_show_in_game_menu()
		
# ── Background ─────────────────────────────────────────────
var _bg_top: ColorRect    # Top half of background
var _bg_bot: ColorRect    # Bottom half of background
var _bg_layer: CanvasLayer  # Background layer reference

func _build_background() -> void:
	# CanvasLayer with layer = -10 means it's ALWAYS behind everything
	# and does NOT move with the game camera.
	_bg_layer = CanvasLayer.new()
	_bg_layer.layer = -10
	add_child(_bg_layer)

	# Top half
	_bg_top = ColorRect.new()
	_bg_top.size  = Vector2(SW, SH * 0.52)
	_bg_layer.add_child(_bg_top)

	# Bottom half
	_bg_bot = ColorRect.new()
	_bg_bot.size     = Vector2(SW, SH * 0.52)
	_bg_bot.position = Vector2(0, SH * 0.48)
	_bg_layer.add_child(_bg_bot)
	
	# Apply initial theme (theme 0)
	_apply_theme_colors(GameManager.current_theme)

# ── Scene Containers ───────────────────────────────────────
func _build_containers() -> void:
	_clouds = Node2D.new();    _clouds.name   = "Clouds";    _clouds.z_index    = -4
	_platforms = Node2D.new(); _platforms.name = "Platforms"; _platforms.z_index = 0
	_coins = Node2D.new();     _coins.name    = "Coins";     _coins.z_index     = 1
	_obstacles = Node2D.new();  _obstacles.name = "Obstacles"; _obstacles.z_index = 1
	add_child(_clouds)
	add_child(_platforms)
	add_child(_coins)
	add_child(_obstacles)

# ── Camera ─────────────────────────────────────────────────
func _build_camera() -> void:
	camera = Camera2D.new()
	camera.name = "Camera"
	add_child(camera)
	camera.make_current()
	# Start at a neutral position; adjusted after player spawns
	camera.global_position = Vector2(SW / 2.0, 0.0)

# ── HUD / UI ───────────────────────────────────────────────
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)

	# Score (top-left)
	score_label = _make_label("Score: 0", Vector2(14, 10), 28, Color.WHITE)
	score_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	score_label.add_theme_constant_override("shadow_offset_x", 2)
	score_label.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(score_label)

	# High score (top-right)
	hs_label = _make_label("Best: 0", Vector2(SW - 210, 10), 22, Color(1.0, 0.92, 0.25))
	hs_label.size = Vector2(196, 36)
	hs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hs_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	hs_label.add_theme_constant_override("shadow_offset_x", 2)
	hs_label.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(hs_label)

	# Coin counter (below score)
	coin_label = _make_label("🪙 0", Vector2(14, 44), 20, Color(1.0, 0.88, 0.2))
	layer.add_child(coin_label)
	
	# Menu button (right side, below score info) - small hamburger menu icon
	var menu_btn: Button = Button.new()
	menu_btn.text = "☰"
	menu_btn.position = Vector2(SW - 60, 65)
	menu_btn.custom_minimum_size = Vector2(50, 50)
	menu_btn.add_theme_font_size_override("font_size", 32)
	menu_btn.add_theme_color_override("font_color", Color.WHITE)
	var btn_style: StyleBoxFlat = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.2, 0.2, 0.6)
	btn_style.corner_radius_top_left = 8
	btn_style.corner_radius_top_right = 8
	btn_style.corner_radius_bottom_left = 8
	btn_style.corner_radius_bottom_right = 8
	menu_btn.add_theme_stylebox_override("normal", btn_style)
	menu_btn.pressed.connect(func():
		_show_in_game_menu())
	layer.add_child(menu_btn)

	_on_score_updated(0)   # Prime the labels with starting values

func _make_label(txt: String, pos: Vector2, fsize: int, col: Color) -> Label:
	var lbl := Label.new()
	lbl.text     = txt
	lbl.position = pos
	lbl.add_theme_font_size_override("font_size", fsize)
	lbl.add_theme_color_override("font_color", col)
	return lbl

# ── Player ─────────────────────────────────────────────────
func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	player.name    = "Player"
	player.z_index = 2
	add_child(player)
	# Start a short distance above the first platform (y = 0)
	player.global_position = Vector2(SW / 2.0, -90.0)

# ── Initial Level Layout ───────────────────────────────────
func _build_initial_level() -> void:
	# Wide solid platform directly under the player
	_place_platform(Vector2(SW / 2.0, 0.0), Platform.PlatformType.NORMAL, 130.0)
	_last_plat_y = 0.0
	_last_plat_x = SW / 2.0

	# Pre-generate enough platforms above to fill the spawn buffer
	for _i in 14:
		_spawn_next_platform()

	# A handful of decorative clouds at random positions
	for _i in 6:
		_spawn_cloud(Vector2(
			randf_range(0, SW),
			randf_range(-SH, SH * 0.25)
		))

# ── Platform Spawning ──────────────────────────────────────
func _tick_platform_spawner() -> void:
	# Keep generating platforms until we're SPAWN_AHEAD above camera top
	var target_y := (camera.global_position.y - SH / 2.0) - SPAWN_AHEAD
	while _last_plat_y > target_y:
		_spawn_next_platform()

func _spawn_next_platform() -> void:
	var gap   := _calc_gap()
	var width := randf_range(68.0, 108.0)
	var max_reach := 200.0 # max horizontal pixels player can travel per jump
	var min_x := clampf(_last_plat_x - max_reach, 60.0, SW - 60.0)
	var max_x := clampf(_last_plat_x + max_reach, 60.0, SW - 60.0)
	var x := randf_range(min_x, max_x)
	var y := _last_plat_y - gap
	var ptype := _pick_type()

	_place_platform(Vector2(x, y), ptype, width)
	_last_plat_y = y
	_last_plat_x = x

func _place_platform(pos: Vector2, ptype: int, width: float) -> void:
	var p := PLATFORM_SCENE.instantiate() as Platform
	_platforms.add_child(p)
	p.global_position = pos
	p.setup(ptype, width)
	
	# ~30 % chance to put a coin above this platform
	if randf() < 0.30:
		_spawn_coin(Vector2(pos.x + randf_range(-18.0, 18.0), pos.y - 40.0))

func _spawn_coin(pos: Vector2) -> void:
	var c := COIN_SCENE.instantiate()
	_coins.add_child(c)
	c.global_position = pos

# ── Cloud Spawning ─────────────────────────────────────────
func _tick_cloud_spawner() -> void:
	if _clouds.get_child_count() < 8:
		var top_y := camera.global_position.y - SH / 2.0
		_spawn_cloud(Vector2(
			randf_range(-50.0, SW + 50.0),
			top_y - randf_range(40.0, 260.0)
		))

func _spawn_cloud(pos: Vector2) -> void:
	var c := CLOUD_SCENE.instantiate()
	_clouds.add_child(c)
	c.global_position = pos

# ── Ensure One Moving Platform ─────────────────────────────
func _ensure_moving_platform() -> void:
	"""Ensure exactly 1 platform visible on screen is always moving."""
	# Check if current moving platform is still valid and visible
	if _moving_platform and is_instance_valid(_moving_platform):
		var dist_to_camera: float = abs(_moving_platform.global_position.y - camera.global_position.y)
		if dist_to_camera < SH * 0.6:  # Still on screen
			return  # Keep current one moving
		else:
			_moving_platform.is_moving = false  # Stop old one

	# Current platform is gone or off-screen, pick a new visible one
	var visible_platforms: Array = []
	for plat in _platforms.get_children():
		if is_instance_valid(plat):
			var dist: float = abs(plat.global_position.y - camera.global_position.y)
			if dist < SH * 0.6:  # On screen
				visible_platforms.append(plat)

	if visible_platforms.size() > 0:
		# Pick random visible platform and enable movement
		if _moving_platform:
			_moving_platform.is_moving = false  # Stop old one
		_moving_platform = visible_platforms[randi() % visible_platforms.size()]
		_moving_platform.enable_movement()

# ── Camera Movement ────────────────────────────────────────
func _move_camera(delta: float) -> void:
	# Target: player appears ~65 % down the screen
	# camera.y = player.y - SH * 0.14  keeps player at ~35 % from top → wait
	# Actually with camera centered: screen_y of player = player.y - cam.y + SH/2
	# For player at 65% from top: player.y - cam.y + SH/2 = 0.65 * SH
	# → cam.y = player.y - 0.15 * SH
	var target_y := player.global_position.y - SH * 0.15

	# Camera only moves UP (never chases the player downward)
	if target_y < camera.global_position.y:
		camera.global_position.y = lerp(
			camera.global_position.y, target_y, 7.0 * delta
		)

	# Always centered horizontally
	camera.global_position.x = SW / 2.0

# ── Despawn Off-Screen Objects ─────────────────────────────
func _despawn_old_objects() -> void:
	var limit_y := camera.global_position.y + SH / 2.0 + DESPAWN_GAP

	for node in _platforms.get_children():
		if node.global_position.y > limit_y:
			# Clear moving platform reference if it's being despawned
			if node == _moving_platform:
				_moving_platform = null
			node.queue_free()

	for node in _coins.get_children():
		if node.global_position.y > limit_y:
			node.queue_free()

	for node in _clouds.get_children():
		if node.global_position.y > limit_y + 150:
			node.queue_free()

	for node in _obstacles.get_children():
		if node.global_position.y > limit_y:
			node.queue_free()
func _check_game_over() -> void:
	var fall_limit := camera.global_position.y + SH / 2.0 + 80.0
	if player.global_position.y > fall_limit:
		_end_game()

func _end_game() -> void:
	if not _active:
		return
	_active = false
	_bg_music.stop()
	player.die()
	await get_tree().create_timer(0.9).timeout
	GameManager.go_to("res://scenes/game_over.tscn")

# ── Difficulty ─────────────────────────────────────────────
## Gap grows smoothly from easy values to hard values over 2500 score.
func _calc_gap() -> float:
	var t   := clampf(float(GameManager.score) / 2500.0, 0.0, 1.0)
	var min_g := lerpf(GAP_MIN_EASY, GAP_MIN_HARD, t)
	var max_g := lerpf(GAP_MAX_EASY, GAP_MAX_HARD, t)
	return randf_range(min_g, max_g)

## Platform type distribution shifts toward specials as score rises.
func _pick_type() -> int:
	var s := GameManager.score
	var r := randf()

	if s < 100:
		return Platform.PlatformType.NORMAL

	elif s < 350:
		return Platform.PlatformType.BOOST if r > 0.82 else Platform.PlatformType.NORMAL

	elif s < 750:
		if r < 0.45:   return Platform.PlatformType.NORMAL
		elif r < 0.65: return Platform.PlatformType.BOOST
		elif r < 0.82: return Platform.PlatformType.BREAKABLE
		else:          return Platform.PlatformType.SPEED

	else:   # Hard mode — all types
		if r < 0.40:   return Platform.PlatformType.NORMAL
		elif r < 0.60: return Platform.PlatformType.BOOST
		elif r < 0.78: return Platform.PlatformType.BREAKABLE
		else:          return Platform.PlatformType.SPEED

# ── Signal Handlers ────────────────────────────────────────
func _on_score_updated(new_score: int) -> void:
	if score_label:
		score_label.text = "Score: %d" % new_score
	if hs_label:
		hs_label.text = "Best: %d" % GameManager.high_score
	if coin_label:
		coin_label.text = "🪙 %d" % GameManager.coins_collected

func _on_theme_changed(theme: int) -> void:
	"""Called when the player advances to a new theme (every 5 coins)."""
	_apply_theme_colors(theme)
	_change_music(theme)

func _apply_theme_colors(theme: int) -> void:
	"""Update background colors based on theme number."""
	match theme:
		# Theme 0: Clear Sky — light blue with gradient
		0:
			_bg_top.color = Color(0.10, 0.32, 0.72)    # Deep blue
			_bg_bot.color = Color(0.40, 0.72, 0.98)    # Light sky blue
		
		# Theme 1: Sunset Sky — orange/purple gradient
		1:
			_bg_top.color = Color(0.72, 0.25, 0.55)    # Purple
			_bg_bot.color = Color(1.00, 0.65, 0.30)    # Orange
		
		# Theme 2: Night Sky — dark with blue tones
		2:
			_bg_top.color = Color(0.05, 0.08, 0.25)    # Very dark blue
			_bg_bot.color = Color(0.15, 0.15, 0.40)    # Dark blue
		
		# Theme 3: Space Sky — black with nebula
		3:
			_bg_top.color = Color(0.02, 0.01, 0.08)    # Almost black
			_bg_bot.color = Color(0.05, 0.02, 0.15)    # Dark purple

func _change_music(theme: int) -> void:
	"""Adjust music volume based on theme (no stream reload needed)."""
	if not _bg_music:
		return
	
	# Only adjust volume per theme — no need to reload the stream
	# since all themes currently use the same music file
	match theme:
		0:  # Clear Sky
			_bg_music.volume_db = -8.0
		1:  # Sunset
			_bg_music.volume_db = -8.5
		2:  # Night
			_bg_music.volume_db = -9.0
		3:  # Space
			_bg_music.volume_db = -8.0
# ── In-Game Menu Panel ────────────────────────────────────
func _show_in_game_menu() -> void:
	"""Display the in-game menu with retry, home, and music volume options."""
	if not _active:
		return
	
	_active = false  # Pause the game
	
	# Dark overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.65)
	overlay.size = Vector2(SW, SH)
	var hud_layer = get_node("HUD") as CanvasLayer
	hud_layer.add_child(overlay)
	
	# Menu card
	var card := PanelContainer.new()
	card.position = Vector2(60, 200)
	card.size = Vector2(360, 450)
	
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
	hud_layer.add_child(card)
	
	# Margin
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	card.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)
	
	# Title
	var title := Label.new()
	title.text = "MENU"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)
	
	# Music Volume Section
	var vol_label := Label.new()
	vol_label.text = "🔊  Music Volume"
	vol_label.add_theme_font_size_override("font_size", 18)
	vol_label.add_theme_color_override("font_color", Color(0.80, 0.90, 1.0))
	vbox.add_child(vol_label)
	
	# Music slider
	var slider := HSlider.new()
	slider.min_value = -40.0
	slider.max_value = 0.0
	slider.value = _bg_music.volume_db
	slider.custom_minimum_size = Vector2(320, 28)
	slider.value_changed.connect(func(val):
		_bg_music.volume_db = val)
	vbox.add_child(slider)
	
	var vol_value := Label.new()
	vol_value.text = "%.1f dB" % _bg_music.volume_db
	vol_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vol_value.add_theme_font_size_override("font_size", 14)
	vol_value.add_theme_color_override("font_color", Color(0.70, 0.80, 1.0))
	slider.value_changed.connect(func(val):
		vol_value.text = "%.1f dB" % val)
	vbox.add_child(vol_value)
	
	#SFX Volume Slider
	var sfx_label := Label.new()
	sfx_label.text = "🎵  SFX Volume"
	sfx_label.add_theme_font_size_override("font_size", 18)
	sfx_label.add_theme_color_override("font_color", Color(0.80, 0.90, 1.0))
	vbox.add_child(sfx_label)
	
	#SFX slider
	var sfx_slider := HSlider.new()
	sfx_slider.min_value = -40.0
	sfx_slider.max_value = 0.0
	sfx_slider.value = GameManager.sfx_volume
	sfx_slider.custom_minimum_size = Vector2(320, 28)
	sfx_slider.value_changed.connect(func(val: float) -> void:
		GameManager.sfx_volume = val)
	vbox.add_child(sfx_slider)
	
	var sfx_value := Label.new()
	sfx_value.text = "%.1f dB" % GameManager.sfx_volume
	sfx_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sfx_value.add_theme_font_size_override("font_size", 14)
	sfx_value.add_theme_color_override("font_color", Color(0.70, 0.80, 1.0))
	sfx_slider.value_changed.connect(func(val: float) -> void:
		sfx_value.text = "%.1f dB" % val)
	vbox.add_child(sfx_value)
	
	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	vbox.add_child(spacer)
	
	# Retry button
	var retry_btn := _make_menu_button("↻  RETRY")
	retry_btn.pressed.connect(func():
		overlay.queue_free()
		card.queue_free()
		GameManager.go_to("res://scenes/game.tscn"))
	vbox.add_child(retry_btn)
	
	# Home button
	var home_btn := _make_menu_button("⌂  HOME")
	home_btn.pressed.connect(func():
		overlay.queue_free()
		card.queue_free()
		_bg_music.stop()
		GameManager.go_to("res://scenes/main_menu.tscn"))
	vbox.add_child(home_btn)
	
	# Resume button
	var resume_btn := _make_menu_button("▶  RESUME")
	resume_btn.pressed.connect(func():
		overlay.queue_free()
		card.queue_free()
		_active = true)
	vbox.add_child(resume_btn)

func _make_menu_button(text: String) -> Button:
	"""Create a styled menu button for in-game menu."""
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(320, 54)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.35, 0.55, 0.85)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", style)
	
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.45, 0.65, 0.95)
	btn.add_theme_stylebox_override("hover", hover)
	
	var pressed := style.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.25, 0.45, 0.75)
	btn.add_theme_stylebox_override("pressed", pressed)
	
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color.WHITE)
	return btn

# ── Obstacle Spawner ───────────────────────────────────────
func _tick_obstacle_spawner() -> void:
	# Only spawn obstacles if score >= 3000
	if GameManager.score < 3000:
		return
	
	# Spawn obstacles more frequently as score increases
	var obstacle_chance := clampf(float(GameManager.score - 3000) / 3000.0, 0.0, 0.05)
	if randf() < obstacle_chance:
		if GameManager.current_theme == 1:
			# Birds spawn from both left and right sides
			var spawn_y = camera.global_position.y + randf_range(-SH * 0.3, SH * 0.3)
			# Left side bird
			_spawn_obstacle(Vector2(-30.0, spawn_y))
			# Right side bird
			_spawn_obstacle(Vector2(SW + 30.0, spawn_y))
		else:
			# Other obstacles spawn from above
			var top_y := camera.global_position.y - SH / 2.0 - 50.0
			_spawn_obstacle(Vector2(randf_range(50.0, SW - 50.0), top_y))

func _spawn_obstacle(pos: Vector2) -> void:
	var obstacle
	match GameManager.current_theme:
		0:
			obstacle = METEOR_SCENE.instantiate()
		1:
			obstacle = BIRD_SCENE.instantiate()
		2:
			obstacle = STAR_SCENE.instantiate()
		_:
			return

	_obstacles.add_child(obstacle)
	obstacle.global_position = pos
