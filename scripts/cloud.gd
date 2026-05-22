@tool
extends Node2D
## ============================================================
##  Cloud.gd
##  Decorative cloud that slowly drifts left or right.
##  Purely visual — no gameplay effect.
## ============================================================

var _speed:  float = 18.0
var _dir:    float = 1.0
var _width:  float = 80.0
var _alpha:  float = 0.70

# ── Lifecycle ──────────────────────────────────────────────
func _ready() -> void:
	# Randomise appearance so every cloud looks a bit different
	_speed = randf_range(9.0, 26.0)
	_dir   = 1.0 if randf() > 0.5 else -1.0
	_width = randf_range(55.0, 115.0)
	_alpha = randf_range(0.50, 0.82)
	queue_redraw()

func _process(delta: float) -> void:
	# Drift horizontally; wrap around screen edges
	global_position.x += _dir * _speed * delta
	var sw := get_viewport_rect().size.x
	if   global_position.x >  sw + 160: global_position.x = -160.0
	elif global_position.x < -160:      global_position.x =  sw + 160.0

# ── Drawing ────────────────────────────────────────────────
func _draw() -> void:
	var w := _width
	var c := Color(1.0, 1.0, 1.0, _alpha)

	# Cloud = overlapping circles + a filled base rectangle
	draw_circle(Vector2(0,        0),        w * 0.22, c)
	draw_circle(Vector2(w * 0.22, -w * 0.10), w * 0.29, c)
	draw_circle(Vector2(w * 0.50, -w * 0.06), w * 0.26, c)
	draw_circle(Vector2(w * 0.75,  0),        w * 0.21, c)

	# Solid base to fill gaps between circles
	var base := PackedVector2Array([
		Vector2(-w * 0.06,  0),
		Vector2( w * 0.88,  0),
		Vector2( w * 0.88,  w * 0.18),
		Vector2(-w * 0.06,  w * 0.18),
	])
	draw_colored_polygon(base, c)
