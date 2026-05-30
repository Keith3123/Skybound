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
const TWINKLE_SCENE  := preload("res://scenes/star.tscn")
const PLANET_SCENE   := preload("res://scenes/planet.tscn")
const METEOR_SCENE   := preload("res://scenes/meteor.tscn")
const BIRD_SCENE     := preload("res://scenes/flying_bird.tscn")
const STAR_SCENE     := preload("res://scenes/falling_star.tscn")
const MOON_SCENE     := preload("res://scenes/moon.tscn")

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
const GAP_MAX_HARD: float = 150.0

# ── Runtime Nodes (created in code) ───────────────────────
var player:      CharacterBody2D
var camera:      Camera2D
var score_label: Label
var hs_label:    Label
var coin_label:  Label

var _platforms:  Node2D   # Container for all platform nodes
var _coins:      Node2D   # Container for all coin nodes
var _decorations:     Node2D   # Container for cloud nodes
var _obstacles:  Node2D   # Container for obstacle nodes
var _moon_spawned := false
var _moon_phase := 0
var _last_planet_type := -1

# ── Game State ─────────────────────────────────────────────
var _active:          bool  = false
var _last_plat_y:     float = 0.0   # Y of highest spawned platform
var _last_plat_x: 	  float = 240.0 
var _bg_music:  	  AudioStreamPlayer
var _hover_sfx: 	  AudioStreamPlayer
var _fall_sfx: AudioStreamPlayer
var _obstacle_timer: float = 2.5 # first obstacle spawns after 2.5 seconds
var _menu_open: bool = false
var _pause_overlay: ColorRect = null
var _pause_card: PanelContainer = null
var _jump_sfx: AudioStreamPlayer

# ── Lifecycle ──────────────────────────────────────────────
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	_fall_sfx = AudioStreamPlayer.new()
	_hover_sfx = AudioStreamPlayer.new()
	_jump_sfx = AudioStreamPlayer.new()
	_bg_music.volume_db = GameManager.vol_to_db(GameManager.music_volume)
	_hover_sfx.volume_db = GameManager.vol_to_db(GameManager.sfx_volume)
	_jump_sfx.stream = load("res://sounds/369515__lefty_studios__jumping-sfx.wav")
	_bg_music.stream = load("res://sounds/game.mp3")
	_fall_sfx.stream = load("res://sounds/412168__poligonstudio__arcade-game-over.wav")
	_hover_sfx.stream = load("res://sounds/hover.mp3")
	add_child(_jump_sfx)
	add_child(_bg_music)
	add_child(_fall_sfx)
	add_child(_hover_sfx)
	#
	if _bg_music.stream is AudioStreamMP3:
		(_bg_music.stream as AudioStreamMP3).loop = true
	_bg_music.play()

	_active = true

func _process(delta: float) -> void:
	if not _active:
		return
	_move_camera(delta)
	_tick_platform_spawner()
	_tick_decoration_spawner()
	_tick_obstacle_spawner(delta)
	#_ensure_moving_platform()  # Keep exactly 1 platform moving
	_despawn_old_objects()
	_check_game_over()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if get_tree().paused:
			_resume_game()
		else:
			_show_in_game_menu()
		
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			get_tree().paused = false
			GameManager.go_to("res://scenes/game.tscn")
		
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
	_decorations = Node2D.new();    _decorations.name   = "Decorations";    _decorations.z_index = -4
	_platforms = Node2D.new(); _platforms.name = "Platforms"; _platforms.z_index = 0
	_coins = Node2D.new();     _coins.name    = "Coins";     _coins.z_index     = 1
	_obstacles = Node2D.new();  _obstacles.name = "Obstacles"; _obstacles.z_index = 1
	add_child(_decorations)
	add_child(_platforms)
	add_child(_coins)
	add_child(_obstacles)

func _resume_game() -> void:
	if _pause_overlay:
		_pause_overlay.queue_free()
		_pause_overlay = null

	if _pause_card:
		_pause_card.queue_free()
		_pause_card = null

	get_tree().paused = false
	_menu_open = false
	_active = true
	_bg_music.stream_paused = false
	_hover_sfx.stream_paused = false
	_jump_sfx.stream_paused = false
	_fall_sfx.stream_paused = false
	player.set_physics_process(true)
	player.set_process(true)
	for p in _platforms.get_children():
		p.set_process(true)
		p.set_physics_process(true)

	for d in _decorations.get_children():
		d.set_process(true)
		d.set_physics_process(true)

	for o in _obstacles.get_children():
		o.set_process(true)
		o.set_physics_process(true)
	
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

	## Coin counter (below score)
	#coin_label = _make_label("🪙 0", Vector2(14, 44), 20, Color(1.0, 0.88, 0.2))
	#layer.add_child(coin_label)
	# Coin UI container
	var coin_box = HBoxContainer.new()
	coin_box.position = Vector2(14, 44)
	coin_box.add_theme_constant_override("separation", 6)
	layer.add_child(coin_box)

	# Coin icon
	var coin_icon := Label.new()
	coin_icon.text = "🪙"
	coin_icon.add_theme_font_size_override("font_size", 22)
	coin_icon.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2))
	coin_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coin_box.add_child(coin_icon)

	# Coin amount
	coin_label = Label.new()
	coin_label.text = "0"
	coin_label.add_theme_font_size_override("font_size", 20)
	coin_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2))
	coin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coin_box.add_child(coin_label)
	
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
	var top_y := camera.global_position.y - SH / 2.0
	for _i in 6:
		_spawn_decoration(_find_free_decoration_position(top_y))

# ── Platform Spawning ──────────────────────────────────────
func _tick_platform_spawner() -> void:
	# Keep generating platforms until we're SPAWN_AHEAD above camera top
	var target_y := (camera.global_position.y - SH / 2.0) - SPAWN_AHEAD
	while _last_plat_y > target_y:
		_spawn_next_platform()

func _spawn_next_platform() -> void:
	var gap   := _calc_gap()
	var width := randf_range(68.0, 108.0)
	
	 # Force zigzag spread: minimum 110px horizontal distance from last
	var min_dist := 110.0
	var max_dist := 210.0
	var dir := 1.0 if randf() > 0.5 else -1.0
	var dist := randf_range(min_dist, max_dist)
	#var max_reach := 200.0 # max horizontal pixels player can travel per jump
	#var min_x := clampf(_last_plat_x - max_reach, 60.0, SW - 60.0)
	#var max_x := clampf(_last_plat_x + max_reach, 60.0, SW - 60.0)
	var x := _last_plat_x + dir * dist
	
	 # If out of screen bounds, flip direction
	if x < 65.0 or x > SW - 65.0:
		x = _last_plat_x - dir * dist
	
	x = clampf(x, 65.0, SW - 65.0)
	
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
	
	if GameManager.score > 200 and randf() < 0.20:
		p.enable_movement()
		
	# ~30 % chance to put a coin above this platform
	if randf() < 0.30:
		_spawn_coin(Vector2(pos.x + randf_range(-18.0, 18.0), pos.y - 40.0))

func _spawn_coin(pos: Vector2) -> void:
	var c := COIN_SCENE.instantiate()
	_coins.add_child(c)
	c.global_position = pos

# ── Decorations Spawning ─────────────────────────────────────────
func _tick_decoration_spawner() -> void:
	var limit := 8
	
	match GameManager.current_theme:
		0:
			limit = 8
		1:
			limit = 10 # many clouds
		2: 
			limit = 24 # many stars
		3: 
			limit = 6 # few planets
			
	if _decorations.get_child_count() < limit:
		var top_y := camera.global_position.y - SH / 2.0
		
		_spawn_decoration(Vector2(
			randf_range(-50.0, SW + 50.0),
			top_y - randf_range(40.0, 260.0)
		))

func _spawn_decoration(pos: Vector2) -> void:
	#var c := CLOUD_SCENE.instantiate()
	var deco 
	
	match GameManager.current_theme:
		0: 
			deco = CLOUD_SCENE.instantiate()
			deco.modulate = Color(1, 1, 1, 1)
		1:
			deco = CLOUD_SCENE.instantiate()
			deco.modulate = Color(
				1.0,
				randf_range(0.72, 0.88),
				randf_range(0.55, 0.75),
				1.0
			)
		2: 
			if not _moon_spawned:
				deco = MOON_SCENE.instantiate()
				_moon_spawned = true

				# apply phase
				deco.phase = _moon_phase
				
				_moon_phase = (_moon_phase + 1) % 5
				# make moon bigger
				deco.scale = Vector2.ONE * 1.8

			else:
				deco = TWINKLE_SCENE.instantiate()

		3: 
			if randf() < 0.35:
				deco = PLANET_SCENE.instantiate()
				
				var next_type := randi() % 5
				
				while next_type == _last_planet_type:
					next_type = randi() % 5
				
				deco._type = next_type
				_last_planet_type = next_type
			else:
				deco = TWINKLE_SCENE.instantiate()
	
	if deco == null:
		return
		
	if not deco.scene_file_path.contains("moon"):
		var s := randf_range(0.7, 1.6)
		deco.scale = Vector2.ONE * s

	## Random size
	#var s := randf_range(0.7, 1.8)
	#deco.scale = Vector2.ONE * 5 
	
	# Random size
	#if deco.scene_file_path.contains("moon"):
		#deco.scale *= 1.8
	
	# Fade-in effect
	deco.modulate.a = 0.0
	
	_decorations.add_child(deco)
	deco.global_position = pos
	
		# Smooth fade in

	var tween := create_tween()
	tween.tween_property(deco, "modulate:a", 1.0, 1.0)

## ── Ensure One Moving Platform ─────────────────────────────
#func _ensure_moving_platform() -> void:
	#"""Ensure exactly 1 platform visible on screen is always moving."""
	## Check if current moving platform is still valid and visible
	#if _moving_platform and is_instance_valid(_moving_platform):
		#var dist_to_camera: float = abs(_moving_platform.global_position.y - camera.global_position.y)
		#if dist_to_camera < SH * 0.6:  # Still on screen
			#return  # Keep current one moving
		#else:
			#_moving_platform.is_moving = false  # Stop old one
#
	## Current platform is gone or off-screen, pick a new visible one
	#var visible_platforms: Array = []
	#for plat in _platforms.get_children():
		#if is_instance_valid(plat):
			#var dist: float = abs(plat.global_position.y - camera.global_position.y)
			#if dist < SH * 0.6:  # On screen
				#visible_platforms.append(plat)
#
	#if visible_platforms.size() > 0:
		## Pick random visible platform and enable movement
		#if _moving_platform:
			#_moving_platform.is_moving = false  # Stop old one
		#_moving_platform = visible_platforms[randi() % visible_platforms.size()]
		#_moving_platform.enable_movement()

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
			#if node == _moving_platform:
				#_moving_platform = null
			node.queue_free()

	for node in _coins.get_children():
		if node.global_position.y > limit_y:
			node.queue_free()

	for node in _decorations.get_children():
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
	get_tree().paused = false
	_bg_music.stop()
	player.die()
	_fall_sfx.volume_db = GameManager.vol_to_db(GameManager.sfx_volume)
	_fall_sfx.play()
	await get_tree().create_timer(1.5).timeout
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
		#coin_label.text = "🪙 %d" % GameManager.coins_collected
		coin_label.text = str(GameManager.coins_collected)

func _on_theme_changed(theme: int) -> void:
	"""Called when the player advances to a new theme (every 5 coins)."""
	_apply_theme_colors(theme)
	_change_music(theme)
	_moon_spawned = false
	
	#if theme == 2:
		#_moon_phase = (_moon_phase + 1) % 5
	
	_fade_out_old_decorations()
	
	var amount := 8 
	
	match theme:
		0:
			amount = 8 # clouds
		1:
			amount = 10 # clouds
		2:
			amount = 24 # stars
		3:
			amount = 10 # planets
			
	var top_y := camera.global_position.y - SH / 2.0
	
	for i in amount:
		_spawn_decoration(_find_free_decoration_position(top_y))
		
func _find_free_decoration_position(top_y: float) -> Vector2:
	var tries := 20

	while tries > 0:
		var pos := Vector2(
			randf_range(40.0, SW - 40.0),
			top_y - randf_range(40.0, SH)
		)

		var valid := true

		for d in _decorations.get_children():
			if not is_instance_valid(d):
				continue

			# bigger spacing for planets
			var min_dist := 140.0
			
			if GameManager.current_theme == 3 and d.scene_file_path.contains("planet"):
				min_dist = 420

			# stars can be closer
			if d.scene_file_path.contains("star"):
				min_dist = 60.0

			if pos.distance_to(d.global_position) < min_dist:
				valid = false
				break

		if valid:
			return pos

		tries -= 1

	# fallback if no free spot found
	return Vector2(
		randf_range(40.0, SW - 40.0),
		top_y - randf_range(40.0, SH)
	)
func _fade_out_old_decorations() -> void:
	for node in _decorations.get_children():
		if is_instance_valid(node):
			node.modulate.a = 0.0
			node.queue_free()
			
		#var tween := create_tween()
#
		#tween.tween_property(node, "modulate:a", 0.0, 0.8)
#
		#tween.finished.connect(func():
			#if is_instance_valid(node):
				#node.queue_free())	
				
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
	#"""Adjust music volume based on theme (no stream reload needed)."""
	#if not _bg_music:
		#return
	
	# Only adjust volume per theme — no need to reload the stream
	# since all themes currently use the same music file
	#match theme:
		#0:  # Clear Sky
			#_bg_music.volume_db = -8.0
		#1:  # Sunset
			#_bg_music.volume_db = -8.5
		#2:  # Night
			#_bg_music.volume_db = -9.0
		#3:  # Space
			#_bg_music.volume_db = -8.0
	pass 
# ── In-Game Menu Panel ────────────────────────────────────
func _show_in_game_menu() -> void:
	if not _active:
		return

	_active = false
	_menu_open = true
	get_tree().paused = true
	_bg_music.stream_paused = true
	_hover_sfx.stream_paused = true
	_jump_sfx.stream_paused = true
	_fall_sfx.stream_paused = true
	player.set_physics_process(false)
	player.set_process(false)
	for p in _platforms.get_children():
		p.set_process(false)
		p.set_physics_process(false)
	for d in _decorations.get_children():
		d.set_process(false)
		d.set_physics_process(false)
	for o in _obstacles.get_children():
		o.set_process(false)
		o.set_physics_process(false)

	var hud_layer := get_node("HUD") as CanvasLayer

	# ── Dark overlay ──────────────────────────────────────
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.60)
	overlay.size = Vector2(SW, SH)
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	hud_layer.add_child(overlay)
	_pause_overlay = overlay

	# ── Card ─────────────────────────────────────────────
	var card := PanelContainer.new()
	card.position = Vector2(40, 160)
	card.custom_minimum_size = Vector2(400, 0)
	card.process_mode = Node.PROCESS_MODE_ALWAYS
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.08, 0.12, 0.32, 0.97)
	card_style.corner_radius_top_left    = 22
	card_style.corner_radius_top_right   = 22
	card_style.corner_radius_bottom_left = 22
	card_style.corner_radius_bottom_right = 22
	card_style.border_width_left   = 2
	card_style.border_width_right  = 2
	card_style.border_width_top    = 2
	card_style.border_width_bottom = 2
	card_style.border_color = Color(0.30, 0.55, 1.0, 0.35)
	card.add_theme_stylebox_override("panel", card_style)
	hud_layer.add_child(card)
	_pause_card = card

	# ── Margin + VBox ─────────────────────────────────────
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   22)
	margin.add_theme_constant_override("margin_right",  22)
	margin.add_theme_constant_override("margin_top",    22)
	margin.add_theme_constant_override("margin_bottom", 22)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	# ── Title ─────────────────────────────────────────────
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)

	# ── Helper: volume row ────────────────────────────────
	# Returns the HSlider so we can wire up value_changed
	var _make_vol_row = func(
		icon_text: String,
		label_text: String,
		sub_text: String,
		icon_color: Color,
		init_val: float
	) -> Array:  # [HSlider, Label]

		# Outer row card
		var row := PanelContainer.new()
		var row_style := StyleBoxFlat.new()
		row_style.bg_color = Color(0.12, 0.17, 0.36, 0.90)
		row_style.corner_radius_top_left    = 14
		row_style.corner_radius_top_right   = 14
		row_style.corner_radius_bottom_left = 14
		row_style.corner_radius_bottom_right = 14
		row_style.border_width_left   = 1
		row_style.border_width_right  = 1
		row_style.border_width_top    = 1
		row_style.border_width_bottom = 1
		row_style.border_color = Color(1, 1, 1, 0.10)
		row.add_theme_stylebox_override("panel", row_style)
		vbox.add_child(row)

		var row_margin := MarginContainer.new()
		row_margin.add_theme_constant_override("margin_left",   14)
		row_margin.add_theme_constant_override("margin_right",  14)
		row_margin.add_theme_constant_override("margin_top",    12)
		row_margin.add_theme_constant_override("margin_bottom", 12)
		row.add_child(row_margin)

		var row_vbox := VBoxContainer.new()
		row_vbox.add_theme_constant_override("separation", 8)
		row_margin.add_child(row_vbox)

		# Top row: icon + labels + badge
		var top_hbox := HBoxContainer.new()
		top_hbox.add_theme_constant_override("separation", 12)
		row_vbox.add_child(top_hbox)

		# Icon box
		var icon_panel := PanelContainer.new()
		icon_panel.custom_minimum_size = Vector2(44, 44)
		var icon_style := StyleBoxFlat.new()
		icon_style.bg_color = icon_color
		icon_style.corner_radius_top_left    = 10
		icon_style.corner_radius_top_right   = 10
		icon_style.corner_radius_bottom_left = 10
		icon_style.corner_radius_bottom_right = 10
		icon_panel.add_theme_stylebox_override("panel", icon_style)
		top_hbox.add_child(icon_panel)

		var icon_lbl := Label.new()
		icon_lbl.text = icon_text
		icon_lbl.add_theme_font_size_override("font_size", 22)
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		icon_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon_panel.add_child(icon_lbl)

		# Label + sub
		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.add_theme_constant_override("separation", 2)
		top_hbox.add_child(info_vbox)

		var name_lbl := Label.new()
		name_lbl.text = label_text
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", Color.WHITE)
		info_vbox.add_child(name_lbl)

		var sub_lbl := Label.new()
		sub_lbl.text = sub_text
		sub_lbl.add_theme_font_size_override("font_size", 12)
		sub_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
		info_vbox.add_child(sub_lbl)

		# Badge
		var badge_panel := PanelContainer.new()
		badge_panel.custom_minimum_size = Vector2(52, 36)
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = icon_color.darkened(0.28)
		badge_style.corner_radius_top_left    = 8
		badge_style.corner_radius_top_right   = 8
		badge_style.corner_radius_bottom_left = 8
		badge_style.corner_radius_bottom_right = 8
		badge_panel.add_theme_stylebox_override("panel", badge_style)
		top_hbox.add_child(badge_panel)

		var badge_lbl := Label.new()
		badge_lbl.text = "%d" % int(init_val)
		badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		badge_lbl.add_theme_font_size_override("font_size", 15)
		badge_lbl.add_theme_color_override("font_color", Color.WHITE)
		badge_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		badge_panel.add_child(badge_lbl)

		# Slider row: 0 — slider — 100
		var slider_hbox := HBoxContainer.new()
		slider_hbox.add_theme_constant_override("separation", 8)
		row_vbox.add_child(slider_hbox)

		var lbl0 := Label.new()
		lbl0.text = "0"
		lbl0.add_theme_font_size_override("font_size", 11)
		lbl0.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
		slider_hbox.add_child(lbl0)

		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.value = init_val
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size = Vector2(0, 26)

		slider.custom_minimum_size = Vector2(0, 28)

		slider_hbox.add_child(slider)

		var lbl100 := Label.new()
		lbl100.text = "100"
		lbl100.add_theme_font_size_override("font_size", 11)
		lbl100.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
		slider_hbox.add_child(lbl100)

		# Wire badge to slider
		slider.value_changed.connect(func(val: float) -> void:
			badge_lbl.text = "%d" % int(val))

		return [slider, badge_lbl]

	# ── Music row ─────────────────────────────────────────
	var music_result: Array = _make_vol_row.call(
		"🔊", "Music Volume", "Background tracks",
		Color(0.13, 0.75, 0.47),   # green
		GameManager.music_volume
	)
	var music_slider := music_result[0] as HSlider
	music_slider.value_changed.connect(func(val: float) -> void:
		GameManager.music_volume = val
		_bg_music.volume_db = GameManager.vol_to_db(val))

	# ── SFX row ───────────────────────────────────────────
	var sfx_result: Array = _make_vol_row.call(
		"🎵", "SFX Volume", "Sound effects",
		Color(0.29, 0.55, 0.96),   # blue
		GameManager.sfx_volume
	)
	var sfx_slider := sfx_result[0] as HSlider
	sfx_slider.value_changed.connect(func(val: float) -> void:
		GameManager.sfx_volume = val)

	# ── Spacer ────────────────────────────────────────────
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer)

	# ── Resume button (green, prominent) ──────────────────
	var resume_btn := _make_menu_button("▶  RESUME", Color(0.13, 0.75, 0.47), Color(0.18, 0.88, 0.55))
	resume_btn.pressed.connect(func():
		overlay.queue_free()
		card.queue_free()
		get_tree().paused = false
		_bg_music.stream_paused = false
		_menu_open = false
		_pause_overlay = null
		_pause_card = null
		_resume_game()
		_active = true)
	vbox.add_child(resume_btn)

	# ── Retry button (blue) ───────────────────────────────
	var retry_btn := _make_menu_button("↻  RETRY", Color(0.29, 0.55, 0.96), Color(0.38, 0.65, 1.0))
	retry_btn.pressed.connect(func():
		overlay.queue_free()
		card.queue_free()
		get_tree().paused = false
		_menu_open = false
		GameManager.go_to("res://scenes/game.tscn"))
	vbox.add_child(retry_btn)

	# ── Home button (subtle) ──────────────────────────────
	var home_btn := _make_menu_button("⌂  HOME", Color(1, 1, 1, 0.10), Color(1, 1, 1, 0.18))
	home_btn.pressed.connect(func():
		overlay.queue_free()
		card.queue_free()
		get_tree().paused = false
		_menu_open = false
		_bg_music.stop()
		GameManager.go_to("res://scenes/main_menu.tscn"))
	vbox.add_child(home_btn)


func _make_menu_button(text: String, col_normal: Color, col_hover: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(356, 52)

	var style := StyleBoxFlat.new()
	style.bg_color = col_normal
	style.corner_radius_top_left    = 12
	style.corner_radius_top_right   = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left   = 15
	style.content_margin_right  = 15
	style.content_margin_top    = 8
	style.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = col_hover
	btn.add_theme_stylebox_override("hover", hover)

	var pressed_style := style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = col_normal.darkened(0.15)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color.WHITE)

	btn.mouse_entered.connect(func():
		if _hover_sfx:
			_hover_sfx.stop()
			_hover_sfx.volume_db = GameManager.vol_to_db(GameManager.sfx_volume)
			_hover_sfx.play())

	return btn

# ── Obstacle Spawner ───────────────────────────────────────
func _tick_obstacle_spawner(delta: float) -> void:
	# Only spawn obstacles if score >= 1000
	if GameManager.score < 300:
		return
	
	# Count down timer — spawn ONE obstacle when it hits zero
	_obstacle_timer -= delta
	if _obstacle_timer > 0.0:
		return

	# ── Raindrop timing ─────────────────────────────────────
	# Spawn 1 obstacle every 0.4–1.2 seconds (easy) to 0.2–0.6 seconds (hard)
	# Because each obstacle takes ~3–5 sec to cross the screen,
	# several will always be visible at once = raindrop effect!
	var t := clampf(float(GameManager.score - 300) / 2000.0, 0.0, 1.0)
	_obstacle_timer = randf_range(lerpf(0.8, 0.25, t), lerpf(1.5, 0.6, t))

	# ── Spawn 1 at a random X ────────────────────────────────
	match GameManager.current_theme:
		1:   # Bird — random side each time
			var from_left := randi() % 2 == 0
			var spawn_y   := camera.global_position.y + randf_range(-SH * 0.3, SH * 0.15)
			var spawn_x   := -30.0 if from_left else SW + 30.0
			_spawn_obstacle(Vector2(spawn_x, spawn_y))
		_:   # Meteor/Star — random X across the top
			var top_y  := camera.global_position.y - SH / 2.0 - 30.0
			var rand_x := randf_range(40.0, SW - 40.0)
			_spawn_obstacle(Vector2(rand_x, top_y))

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
