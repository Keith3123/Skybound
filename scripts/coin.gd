@tool
extends Area2D
## ============================================================
##  Coin.gd
##  Collectible gold coin. Bobs up and down gently.
##  Gives the player +50 points when collected.
## ============================================================

var _time:     float = 0.0
var _start_y:  float = 0.0
var _ready_ok: bool  = false 
var _sfx: AudioStreamPlayer  # Wait one frame so global_position is set

# ── Lifecycle ──────────────────────────────────────────────
func _ready() -> void:
	add_to_group("coin")

	# Build circle collision shape in code
	var col   := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 13.0
	col.shape = shape
	add_child(col)

	# Connect collection signal
	body_entered.connect(_on_body_entered)
	
	_sfx = AudioStreamPlayer.new()
	_sfx.stream = load("res://sounds/336933__the-sacha-rush__coin4.wav")
	_sfx.volume_db = 0.0
	add_child(_sfx)
	
func _process(delta: float) -> void:
	# On the very first frame, global_position is correctly set by game.gd
	if not _ready_ok:
		_start_y  = global_position.y
		_ready_ok = true

	# Bob up and down
	_time += delta
	global_position.y = _start_y + sin(_time * 2.6) * 6.0
	# Gentle wobble rotation
	rotation = sin(_time * 1.8) * 0.18

# ── Drawing ────────────────────────────────────────────────
func _draw() -> void:
	# Glow ring
	draw_circle(Vector2.ZERO, 15.0, Color(1.0, 0.92, 0.0, 0.28))

	# Main coin body
	draw_circle(Vector2.ZERO, 11.5, Color(1.0, 0.80, 0.0))

	# Inner highlight (top-left shine)
	draw_circle(Vector2(-2.5, -3.0), 6.0, Color(1.0, 0.95, 0.55))

	# Shine dot
	draw_circle(Vector2(-3.5, -4.5), 2.5, Color(1.0, 1.0, 0.9, 0.9))

	# Rim
	draw_circle(Vector2.ZERO, 11.5, Color(0.82, 0.60, 0.0), false, 2.2)

	# Simple star / sparkle lines
	for i in 4:
		var angle := TAU * i / 4 + _time * 0.8
		var p1 := Vector2(cos(angle), sin(angle)) * 13.5
		var p2 := Vector2(cos(angle), sin(angle)) * 16.5
		draw_line(p1, p2, Color(1.0, 0.95, 0.3, 0.7), 1.5)

# ── Collection ─────────────────────────────────────────────
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.collect_coin()
		visible = false     # <- hide the coin
		if GameManager.sfx_enabled:
			_sfx.volume_db = GameManager.sfx_volume
		_sfx.play()			# <- play sound
		await _sfx.finished  # <- wait to finished the sound
		queue_free()         # <- then remove
