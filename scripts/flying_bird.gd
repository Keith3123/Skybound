extends Area2D
## Flying bird — flies ACROSS the screen from left or right

const FLY_SPEED_X: float = 220.0   # horizontal crossing speed
const FLY_SPEED_Y: float = 60.0    # gentle downward drift
const WOBBLE_SPEED: float = 3.5    # vertical wobble frequency

var _dir_x: float = 1.0   # 1 = left→right,  -1 = right→left
var _time:   float = 0.0

func _ready() -> void:
	add_to_group("obstacle")
	body_entered.connect(_on_body_entered)
	# Direction is based on which side the bird spawns from
	_dir_x = 1.0 if global_position.x < 0 else -1.0

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	# Fly horizontally across the screen
	global_position.x += _dir_x * FLY_SPEED_X * delta
	# Gentle downward drift with vertical wobble
	global_position.y += FLY_SPEED_Y * delta
	global_position.y += sin(_time * WOBBLE_SPEED) * 0.8
	queue_redraw()

func _draw() -> void:
	# Bird body
	draw_circle(Vector2(0, 0), 10.0, Color(0.6, 0.4, 0.2))
	# Head (faces direction of movement)
	var hx := 8.0 * _dir_x
	draw_circle(Vector2(hx, -3), 6.0, Color(0.7, 0.45, 0.25))
	draw_circle(Vector2(hx * 1.4, -4), 2.0, Color.BLACK)
	draw_line(Vector2(hx * 1.6, -4), Vector2(hx * 2.0, -3), Color(1.0, 0.6, 0.1), 2.0)
	# Wings
	draw_line(Vector2(-2, -2), Vector2(-12, -8), Color(0.5, 0.3, 0.1), 3.0)
	draw_line(Vector2(-12, -8), Vector2(-8, -2), Color(0.5, 0.3, 0.1), 3.0)
	draw_line(Vector2(-2,  2), Vector2(-12,  8), Color(0.5, 0.3, 0.1), 3.0)
	draw_line(Vector2(-12,  8), Vector2(-8,  2), Color(0.5, 0.3, 0.1), 3.0)
	# Tail
	draw_line(Vector2(-8, 0), Vector2(-16 * _dir_x, 0), Color(0.5, 0.3, 0.1), 2.5)

func _on_body_entered(body: Node) -> void:
	if body and body.is_in_group("player"):
		if body.get("shield_side") == true:
			var tw := body.create_tween()
			tw.tween_property(body, "modulate", Color(1.0, 0.85, 0.3), 0.05)
			tw.tween_property(body, "modulate", Color.WHITE, 0.18)
			queue_free()
			return
		body.die()
		var gs := get_tree().get_current_scene()
		if gs and gs.has_method("_end_game"):
			gs._end_game()
		queue_free()
