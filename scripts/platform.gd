@tool
extends StaticBody2D
class_name Platform
## ============================================================
##  Platform.gd
##  4 Platform Types:
##    NORMAL    (green)  — standard jump
##    BOOST     (blue)   — extra high jump
##    BREAKABLE (red)    — breaks after you land
##    SPEED     (yellow) — slightly faster bounce
## ============================================================

# ── Platform Type Enum ─────────────────────────────────────
enum PlatformType {
	NORMAL    = 0,
	BOOST     = 1,
	BREAKABLE = 2,
	SPEED     = 3,
}

# ── Platform Properties ────────────────────────────────────
var platform_type: int   = PlatformType.NORMAL
var jump_force:    float = -780.0
var plat_width:    float = 90.0

const PLAT_HEIGHT: float = 18.0

# Colors per type  [NORMAL, BOOST, BREAKABLE, SPEED]
const COLORS: Array = [
	Color(0.20, 0.78, 0.28),   # Green
	Color(0.15, 0.50, 1.00),   # Blue
	Color(0.88, 0.20, 0.18),   # Red
	Color(1.00, 0.85, 0.08),   # Yellow
]

# Jump forces per type
const JUMP_FORCES: Array = [
	-780.0,    # NORMAL
	-1100.0,   # BOOST   (big boost!)
	-740.0,    # BREAKABLE (slightly weaker)
	-880.0,    # SPEED
]

var _broken := false
var _col_node: CollisionShape2D  # Reference for disabling on break

# ── Platform Movement ──────────────────────────────
var is_moving := false
var move_speed: float = 100.0      # Oscillation speed
var move_range: float = 60.0       # Pixels left/right
var _start_x: float = 0.0
var _move_time: float = 0.0

# ── Lifecycle ──────────────────────────────────────────────
func _ready() -> void:
	add_to_group("platform")
	_start_x = global_position.x

	# Build collision shape in code
	_col_node = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(plat_width, PLAT_HEIGHT)
	_col_node.shape = rect
	_col_node.name = "Col"
	add_child(_col_node)

func _process(delta: float) -> void:
	if is_moving:
		_move_time += delta
		global_position.x = _start_x + sin(_move_time * 1.8) * move_range

func enable_movement() -> void:
	is_moving = true
	_start_x = global_position.x
	_move_time = 0.0

## Call this after add_child() to configure the platform.
func setup(type: int, width: float = 90.0) -> void:
	platform_type = type
	plat_width    = width
	jump_force    = JUMP_FORCES[type]

	# Resize the collision shape to match width
	if _col_node and _col_node.shape is RectangleShape2D:
		(_col_node.shape as RectangleShape2D).size = Vector2(plat_width, PLAT_HEIGHT)

	queue_redraw()

# ── Drawing ────────────────────────────────────────────────
func _draw() -> void:
	var col := COLORS[platform_type] as Color
	var hw  := plat_width   / 2.0
	var hh  := PLAT_HEIGHT  / 2.0

	# Drop shadow
	draw_rect(Rect2(-hw + 3, hh, plat_width, 5), Color(0, 0, 0, 0.22), true)

	# Main platform body
	draw_rect(Rect2(-hw, -hh, plat_width, PLAT_HEIGHT), col, true)

	# Top highlight (shine strip)
	draw_line(
		Vector2(-hw + 4, -hh + 3),
		Vector2( hw - 4, -hh + 3),
		col.lightened(0.55), 3.0
	)

	# Bottom dark edge
	draw_line(Vector2(-hw, hh), Vector2(hw, hh), col.darkened(0.4), 2.0)

	# ── Type-specific decorations ──────────────────────────
	match platform_type:

		PlatformType.BOOST:
			# Three upward arrows = "jump higher here!"
			for i in 3:
				var ax := -hw + 16.0 + i * (plat_width - 20.0) / 2.5
				_draw_up_arrow(ax, 0.0, 5.5, Color(1, 1, 1, 0.85))

		PlatformType.BREAKABLE:
			if not _broken:
				# Crack lines to show it's fragile
				draw_line(Vector2(-hw * 0.4,  -hh), Vector2(-hw * 0.05,  hh), Color(0.45, 0.08, 0.08, 0.75), 1.5)
				draw_line(Vector2( hw * 0.25, -hh), Vector2( hw * 0.55,  hh), Color(0.45, 0.08, 0.08, 0.75), 1.5)
				draw_line(Vector2(-hw * 0.1,   0),  Vector2( hw * 0.3,    0), Color(0.55, 0.10, 0.10, 0.50), 1.0)

		PlatformType.SPEED:
			# Use lines instead of polygon (no triangulation needed)
			var lc := Color(1.0, 0.55, 0.0, 0.95)
			draw_line(Vector2( 3, -hh + 2), Vector2(-2,  0), lc, 3.5)
			draw_line(Vector2(-2,  0),      Vector2( 3,  hh - 2), lc, 3.5)
			draw_circle(Vector2(0.5, 0), 2.5, Color(1.0, 0.85, 0.2, 0.85))

	# Border outline
	draw_rect(Rect2(-hw, -hh, plat_width, PLAT_HEIGHT), col.darkened(0.35), false, 1.5)

func _draw_up_arrow(x: float, y: float, s: float, c: Color) -> void:
	draw_line(Vector2(x, y + s), Vector2(x,     y - s),     c, 2.0)
	draw_line(Vector2(x, y - s), Vector2(x - s, y),         c, 2.0)
	draw_line(Vector2(x, y - s), Vector2(x + s, y),         c, 2.0)

# ── Player Interaction ─────────────────────────────────────
## Called by the player script the moment they land here.
func on_player_landed() -> void:
	match platform_type:
		PlatformType.BREAKABLE:
			if not _broken:
				_break()
		PlatformType.BOOST:
			_flash(Color(0.5, 0.8, 1.0))
		PlatformType.SPEED:
			_flash(Color(1.0, 1.0, 0.4))

func _break() -> void:
	_broken = true
	queue_redraw()
	# Disable collision so player falls through
	if _col_node:
		_col_node.set_deferred("disabled", true)
	# Fade out and self-destruct
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.28)
	tw.tween_callback(queue_free)

func _flash(c: Color) -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate", c,            0.05)
	tw.tween_property(self, "modulate", Color.WHITE,  0.18)
