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

# ── Screen / World Constants ───────────────────────────────
const SW: float = 480.0    # Screen width
const SH: float = 854.0    # Screen height

# Platform spawning distances
const SPAWN_AHEAD:  float = 700.0   # Pre-spawn this far above camera top
const DESPAWN_GAP:  float = 350.0   # Remove objects this far below camera bottom

# Gap between platforms at min/max difficulty
const GAP_MIN_EASY: float = 120.0
const GAP_MAX_EASY: float = 165.0
const GAP_MIN_HARD: float = 260.0
const GAP_MAX_HARD: float = 340.0

# ── Runtime Nodes (created in code) ───────────────────────
var player:      CharacterBody2D
var camera:      Camera2D
var score_label: Label
var hs_label:    Label
var coin_label:  Label

var _platforms:  Node2D   # Container for all platform nodes
var _coins:      Node2D   # Container for all coin nodes
var _clouds:     Node2D   # Container for cloud nodes

# ── Game State ─────────────────────────────────────────────
var _active:          bool  = false
var _last_plat_y:     float = 0.0   # Y of highest spawned platform

# ── Lifecycle ──────────────────────────────────────────────
func _ready() -> void:
	GameManager.reset()
	GameManager.score_updated.connect(_on_score_updated)

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

	_active = true

func _process(delta: float) -> void:
	if not _active:
		return
	_move_camera(delta)
	_tick_platform_spawner()
	_tick_cloud_spawner()
	_despawn_old_objects()
	_check_game_over()

# ── Background ─────────────────────────────────────────────
func _build_background() -> void:
	# CanvasLayer with layer = -10 means it's ALWAYS behind everything
	# and does NOT move with the game camera.
	var layer := CanvasLayer.new()
	layer.layer = -10
	add_child(layer)

	# Top half  — deeper blue
	var top := ColorRect.new()
	top.color = Color(0.10, 0.32, 0.72)
	top.size  = Vector2(SW, SH * 0.52)
	layer.add_child(top)

	# Bottom half — lighter sky blue
	var bot := ColorRect.new()
	bot.color    = Color(0.40, 0.72, 0.98)
	bot.size     = Vector2(SW, SH * 0.52)
	bot.position = Vector2(0, SH * 0.48)
	layer.add_child(bot)

# ── Scene Containers ───────────────────────────────────────
func _build_containers() -> void:
	_clouds = Node2D.new();    _clouds.name   = "Clouds";    _clouds.z_index    = -4
	_platforms = Node2D.new(); _platforms.name = "Platforms"; _platforms.z_index = 0
	_coins = Node2D.new();     _coins.name    = "Coins";     _coins.z_index     = 1
	add_child(_clouds)
	add_child(_platforms)
	add_child(_coins)

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
	var x     := randf_range(55.0, SW - 55.0)
	var y     := _last_plat_y - gap
	var ptype := _pick_type()
	var width := randf_range(68.0, 108.0)

	_place_platform(Vector2(x, y), ptype, width)
	_last_plat_y = y

	# ~30 % chance to put a coin above this platform
	if randf() < 0.30:
		_spawn_coin(Vector2(x + randf_range(-18.0, 18.0), y - 40.0))

func _place_platform(pos: Vector2, ptype: int, width: float) -> void:
	var p := PLATFORM_SCENE.instantiate() as Platform
	_platforms.add_child(p)
	p.global_position = pos
	p.setup(ptype, width)

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
			node.queue_free()

	for node in _coins.get_children():
		if node.global_position.y > limit_y:
			node.queue_free()

	for node in _clouds.get_children():
		if node.global_position.y > limit_y + 150:
			node.queue_free()

# ── Game Over ──────────────────────────────────────────────
func _check_game_over() -> void:
	var fall_limit := camera.global_position.y + SH / 2.0 + 80.0
	if player.global_position.y > fall_limit:
		_end_game()

func _end_game() -> void:
	if not _active:
		return
	_active = false
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
		if r < 0.58:   return Platform.PlatformType.NORMAL
		elif r < 0.80: return Platform.PlatformType.BOOST
		elif r < 0.93: return Platform.PlatformType.BREAKABLE
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
