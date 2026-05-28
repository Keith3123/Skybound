extends Node2D

var _size := 2.0
var _time := 0.0
var _speed := 2.0

func _ready():
	_size = randf_range(1.0, 3.0)
	_speed = randf_range(1.5, 4.0)

func _process(delta):
	_time += delta
	queue_redraw()

func _draw():
	var alpha = 0.4 + sin(_time * _speed) * 0.4
	draw_circle(Vector2.ZERO, _size, Color(1,1,1,alpha))
