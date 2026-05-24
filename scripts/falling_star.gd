extends Area2D
## Falling star obstacle: medium speed, rotates, kills player on contact

const FALL_SPEED: float = 320.0
const ROTATION_SPEED: float = 2.0

func _ready() -> void:
    add_to_group("obstacle")
    body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
    if Engine.is_editor_hint():
        return
    global_position.y += FALL_SPEED * delta
    rotation += ROTATION_SPEED * delta
    queue_redraw()

func _draw() -> void:
    # Draw 5-pointed star
    var points = []
    for i in range(10):
        var angle = PI * 2.0 * i / 10.0 - PI / 2.0
        var radius = 12.0 if i % 2 == 0 else 5.0
        points.append(Vector2(cos(angle) * radius, sin(angle) * radius))
    draw_colored_polygon(points, Color(1.0, 1.0, 0.0))
    # Glow
    draw_circle(Vector2.ZERO, 13.0, Color(1.0, 1.0, 0.3, 0.2))

func _on_body_entered(body: Node) -> void:
    if body and body.is_in_group("player"):
        body.die()
        var gs = get_tree().get_current_scene()
        if gs and gs.has_method("_end_game"):
            gs._end_game()
        queue_free()
