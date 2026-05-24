extends Area2D
## Meteor obstacle: fast falling, rotating, kills player on contact

const FALL_SPEED: float = 420.0
const ROTATION_SPEED: float = 3.5

func _ready() -> void:
    add_to_group("obstacle")
    body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
    if Engine.is_editor_hint():
        return
    # fall and spin
    global_position.y += FALL_SPEED * delta
    rotation += ROTATION_SPEED * delta
    queue_redraw()

func _draw() -> void:
    # Rocky exterior (dark gray)
    draw_circle(Vector2.ZERO, 12.0, Color(0.3, 0.3, 0.35))
    # Hot lava interior (bright orange/red)
    draw_circle(Vector2.ZERO, 8.0, Color(1.0, 0.4, 0.0))
    # Glow ring
    draw_circle(Vector2.ZERO, 10.0, Color(1.0, 0.6, 0.2, 0.3))

func _on_body_entered(body: Node) -> void:
    if body and body.is_in_group("player"):
        body.die()
        # Tell the active game scene to handle end-of-game flow
        var gs = get_tree().get_current_scene()
        if gs and gs.has_method("_end_game"):
            gs._end_game()
        queue_free()
