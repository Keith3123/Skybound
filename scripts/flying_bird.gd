extends Area2D
## Flying bird obstacle: falls slowly, moves sideways, kills player on contact

const FALL_SPEED: float = 120.0
const WOBBLE_SPEED: float = 2.0
const WOBBLE_AMOUNT: float = 60.0

var _time: float = 0.0
var _start_x: float = 0.0

func _ready() -> void:
	add_to_group("obstacle")
	body_entered.connect(_on_body_entered)
	_start_x = global_position.x

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	global_position.y += FALL_SPEED * delta
	_time += delta
	global_position.x = _start_x + sin(_time * WOBBLE_SPEED) * WOBBLE_AMOUNT
	queue_redraw()

func _draw() -> void:
	# Bird body (brown ellipse)
	draw_circle(Vector2(0, 0), 10.0, Color(0.6, 0.4, 0.2))
	# Bird head
	draw_circle(Vector2(8, -3), 6.0, Color(0.7, 0.45, 0.25))
	# Eye
	draw_circle(Vector2(11, -4), 2.0, Color.BLACK)
	# Beak
	draw_line(Vector2(13, -4), Vector2(16, -3), Color(1.0, 0.6, 0.1), 2.0)
	# Left wing
	draw_line(Vector2(-2, -2), Vector2(-12, -8), Color(0.5, 0.3, 0.1), 3.0)
	draw_line(Vector2(-12, -8), Vector2(-8, -2), Color(0.5, 0.3, 0.1), 3.0)
	# Right wing
	draw_line(Vector2(-2, 2), Vector2(-12, 8), Color(0.5, 0.3, 0.1), 3.0)
	draw_line(Vector2(-12, 8), Vector2(-8, 2), Color(0.5, 0.3, 0.1), 3.0)
	# Tail
	draw_line(Vector2(-8, 0), Vector2(-16, 0), Color(0.5, 0.3, 0.1), 2.5)

func _on_body_entered(body: Node) -> void:
	if body and body.is_in_group("player"):
		body.die()
		var gs = get_tree().get_current_scene()
		if gs and gs.has_method("_end_game"):
			gs._end_game()
		queue_free()
