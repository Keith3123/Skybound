extends CharacterBody2D
class_name Player
## ============================================================
##  Player.gd
##  Controls: arrow keys / WASD  (left & right only)
##  The player AUTOMATICALLY jumps when landing on a platform.
## ============================================================

# ── Constants ──────────────────────────────────────────────
const GRAVITY:    float = 1900.0   # Pixels/second²
const BASE_JUMP:  float = -780.0   # Negative = upward
const MOVE_SPEED: float = 270.0    # Horizontal speed

# ── State ──────────────────────────────────────────────────
var is_alive:      bool  = true
var _jump_force:   float = BASE_JUMP  # May be changed by platform type
var _prev_y:       float = 0.0        # For height-based scoring
var _facing:       float = 1.0        # 1 = right, -1 = left (for eye drawing)
var _jump_sfx: 	   AudioStreamPlayer

# ── Shield ─────────────────────────────────────────────────
var shield_up: bool = false    # UP arrow held — blocks falling obstacles
var shield_side: bool = false  # SPACE/CTRL held — blocks side obstacles
#var _shield_timer: float = 0.0
#var _shield_cooldown: float = 0.0
#const SHIELD_DURATION: float = 1.5 # seconds active
#const SHIELD_COOLDOWN: float = 3.5 # seconds recharge

# ── Lifecycle ──────────────────────────────────────────────
func _ready() -> void:
	add_to_group("player")
	_prev_y = global_position.y
	
	_jump_sfx = AudioStreamPlayer.new()
	_jump_sfx.stream = load("res://sounds/369515__lefty_studios__jumping-sfx.wav")
	_jump_sfx.volume_db = -5.0
	add_child(_jump_sfx)

	# ── Build collision shape in code (no need for scene editor) ──
	var col := CollisionShape2D.new()
	var shape := CapsuleShape2D.new()
	shape.radius = 11.0
	shape.height = 12.0
	col.position = Vector2(0, 4)   # Shift down so feet touch platforms
	col.shape = shape
	add_child(col)

# ── Physics Loop ───────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	# 1. Apply gravity when airborne
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# 2. Horizontal movement  (arrow keys OR WASD)
	var dir := Input.get_axis("ui_left", "ui_right")
	velocity.x = dir * MOVE_SPEED

	# Track facing direction for the character drawing
	if dir > 0.1:
		_facing = 1.0
		queue_redraw()
	elif dir < -0.1:
		_facing = -1.0
		queue_redraw()

	# 3. Screen-edge wrapping
	var sw := get_viewport_rect().size.x
	if global_position.x < -14:
		global_position.x = sw + 14
	elif global_position.x > sw + 14:
		global_position.x = -14

	# 4. Execute movement
	move_and_slide()

	# 5. Auto-jump when we land on a surface
	if is_on_floor():
		_on_landed()

	# 6. Award score for height climbed
	if global_position.y < _prev_y:
		GameManager.add_score(int((_prev_y - global_position.y) * 0.18))
		_prev_y = global_position.y

# ── Shield ────────────────────────────── 
func _process(_delta: float) -> void:
	if not is_alive:
		return
	# Shield is active ONLY while key is held — release = disappears
	var new_up := Input.is_action_pressed("ui_up")
	var new_side := Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_CTRL)
	if new_up != shield_up or new_side != shield_side:
		shield_up = new_up
		shield_side = new_side
		queue_redraw()
		
# ── Shield Activation (SPACE key) ───────────────────
#func _input(event: InputEvent) -> void:
	#if not is_alive:
		#return
	#if event is InputEventKey:
		#if event.keycode == KEY_SPACE and not event.echo:
			#if _shield_cooldown <= 0.0 and not shield_active:
				#shield_active = true
				#_shield_timer = SHIELD_DURATION
				#_shield_cooldown = SHIELD_COOLDOWN
				#queue_redraw()
				
# ── Shield Hit Flash ────────────────────────────────
func _flash_shield() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(05, 0.95, 1.0, 1.0), 0.05)
	tw.tween_property(self, "modulate", Color.WHITE, 0.20)
	
# ── Landing / Jump ─────────────────────────────────────────
func _on_landed() -> void:
	# Default jump force
	_jump_force = BASE_JUMP
	var bonus_speed: float = 0.0
	# Check what platform we landed on and get its jump force
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		if col.get_normal().y < -0.5: # Normal pointing UP means floor (negative y in Godot)
			var body := col.get_collider()
			if body != null and body.is_in_group("platform"):
				_jump_force = body.jump_force
				body.on_player_landed()
				if body.platform_type == Platform.PlatformType.SPEED:
					bonus_speed = 180.0
			break
				
	if GameManager.sfx_enabled:
		_jump_sfx.volume_db = GameManager.sfx_volume
		_jump_sfx.play()

	if bonus_speed > 0.0:
		var dir:float = sign(velocity.x) if velocity.x != 0 else 1.0
		velocity.x += dir * bonus_speed
	
	velocity.y = _jump_force

# ── Draw Character ─────────────────────────────────────────
func _draw() -> void:
	var f := _facing  # 1 = right, -1 = left

	# Colors
	var body_col  := Color(0.22, 0.60, 1.00)   # Blue shirt
	var skin_col  := Color(1.00, 0.82, 0.66)   # Skin tone
	var hair_col  := Color(0.22, 0.13, 0.04)   # Dark brown hair
	var eye_white := Color.WHITE
	var pupil_col := Color(0.10, 0.10, 0.30)
	var shoe_col  := Color(0.12, 0.12, 0.35)   # Dark blue shoes
	var pants_col := Color(0.18, 0.38, 0.72)   # Pants

	# ── SHOES ──
	draw_rect(Rect2(-11, 22, 11, 7), shoe_col, true)
	draw_rect(Rect2(0,   22, 11, 7), shoe_col, true)

	# ── LEGS / PANTS ──
	draw_rect(Rect2(-10, 12, 9, 12), pants_col, true)
	draw_rect(Rect2(1,   12, 9, 12), pants_col, true)

	# ── BODY ──
	draw_rect(Rect2(-11, -10, 22, 24), body_col, true)
	# Collar detail
	draw_line(Vector2(-6, -10), Vector2(0, -5), Color.WHITE, 1.5)
	draw_line(Vector2(6,  -10), Vector2(0, -5), Color.WHITE, 1.5)

	# ── HEAD ──
	draw_circle(Vector2(0, -21), 13, skin_col)

	# ── HAIR (arc on top of head) ──
	draw_arc(Vector2(0, -21), 13, PI * 0.95, PI * 2.05, 14, hair_col, 8.0)
	draw_rect(Rect2(-13, -30, 26, 10), hair_col, true)
	# Hair tuft
	draw_circle(Vector2(f * 6, -32), 5, hair_col)

	# ── EYES ──
	draw_circle(Vector2(-f * 4.5, -23), 4.5, eye_white)
	draw_circle(Vector2( f * 2.5, -23), 4.5, eye_white)
	# Pupils (slightly toward center for cute look)
	draw_circle(Vector2(-f * 3.5, -22), 2.5, pupil_col)
	draw_circle(Vector2( f * 3.2, -22), 2.5, pupil_col)
	# Shine dots
	draw_circle(Vector2(-f * 2.8, -23), 0.9, Color.WHITE)
	draw_circle(Vector2( f * 3.8, -23), 0.9, Color.WHITE)

	# ── SMILE ──
	draw_arc(Vector2(0, -16), 5, 0.25, PI - 0.25, 8, Color(0.75, 0.35, 0.20), 1.8)

	# ── OUTLINE on body ──
	draw_rect(Rect2(-11, -10, 22, 24), body_col.darkened(0.3), false, 1.5)

#  ── TOP SHIELD (↑ Up Arrow) — blocks meteors & stars ──
	if shield_up:
		var sc := Color(0.20, 0.78, 1.0)
		# Outer glow
		draw_arc(Vector2(0, -14), 38, PI, TAU, 36, Color(sc.r, sc.g, sc.b, 0.12), 14.0)
		# Main shield arc
		draw_arc(Vector2(0, -14), 33, PI, TAU, 36, sc, 5.0)
		# Inner highlight
		draw_arc(Vector2(0, -14), 27, PI + 0.2, TAU - 0.2, 30, Color(0.75, 0.97, 1.0, 0.55), 2.0)
		# Handle (small line from center to arc base)
		draw_line(Vector2(-33, -14), Vector2(-33, 8), sc, 3.0)
		draw_line(Vector2( 33, -14), Vector2( 33, 8), sc, 3.0)

	# ── SIDE SHIELDS (Space / Ctrl) — blocks birds ──
	if shield_side:
		var sc := Color(1.0, 0.72, 0.15)
		# Left shield
		draw_arc(Vector2(-14, -8), 30, PI * 0.5,  PI * 1.5, 28, Color(sc.r, sc.g, sc.b, 0.12), 14.0)
		draw_arc(Vector2(-14, -8), 26, PI * 0.5,  PI * 1.5, 28, sc, 5.0)
		draw_arc(Vector2(-14, -8), 21, PI * 0.55, PI * 1.45, 24, Color(1.0, 0.95, 0.6, 0.5), 2.0)
		# Right shield
		draw_arc(Vector2(14, -8), 30, -PI * 0.5, PI * 0.5, 28, Color(sc.r, sc.g, sc.b, 0.12), 14.0)
		draw_arc(Vector2(14, -8), 26, -PI * 0.5, PI * 0.5, 28, sc, 5.0)
		draw_arc(Vector2(14, -8), 21, -PI * 0.45, PI * 0.45, 24, Color(1.0, 0.95, 0.6, 0.5), 2.0)
		
# ── Death ──────────────────────────────────────────────────
func die() -> void:
	if not is_alive:
		return
	is_alive = false
	velocity = Vector2.ZERO

	# Quick squish and fade effect
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(1.0, 0.25, 0.25, 1.0), 0.12)
	tw.tween_property(self, "scale",    Vector2(1.4, 0.5),            0.15)
	tw.tween_property(self, "modulate", Color(1.0, 0.25, 0.25, 0.0), 0.35)
