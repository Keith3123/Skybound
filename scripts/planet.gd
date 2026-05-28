extends Node2D

enum PlanetType { MERCURY, VENUS, EARTH, MARS, JUPITER, SATURN, NEPTUNE, PLUTO }

var _type: int = 0

func _ready() -> void:
	_type = randi() % 8
	queue_redraw()

func _draw() -> void:
	match _type:

		PlanetType.MERCURY:
			# Tiny, dark gray, cratered
			draw_circle(Vector2.ZERO, 12, Color(0.52, 0.50, 0.48))
			draw_circle(Vector2( 4, -3), 3,  Color(0.38, 0.36, 0.34))
			draw_circle(Vector2(-4,  4), 2,  Color(0.38, 0.36, 0.34))
			draw_circle(Vector2( 1,  5), 1.5,Color(0.38, 0.36, 0.34))

		PlanetType.VENUS:
			# Medium, thick yellow-orange clouds, no surface
			draw_circle(Vector2.ZERO, 22, Color(0.90, 0.76, 0.38))
			draw_circle(Vector2(-6, -3), 11, Color(0.98, 0.88, 0.58, 0.45))
			draw_circle(Vector2( 5,  6), 9,  Color(0.98, 0.88, 0.58, 0.35))

		PlanetType.EARTH:
			# Blue ocean + green continents + white clouds
			draw_circle(Vector2.ZERO, 24, Color(0.16, 0.40, 0.88))
			draw_circle(Vector2(-6, -1), 10, Color(0.22, 0.65, 0.26))
			draw_circle(Vector2( 7,  5),  8, Color(0.22, 0.65, 0.26))
			draw_circle(Vector2(-2,  9),  5, Color(0.28, 0.58, 0.22))
			draw_circle(Vector2(-9, -8),  6, Color(1.0, 1.0, 1.0, 0.65))
			draw_circle(Vector2( 4, -10), 5, Color(1.0, 1.0, 1.0, 0.55))

		PlanetType.MARS:
			# Reddish-orange, polar ice cap
			draw_circle(Vector2.ZERO, 20, Color(0.76, 0.30, 0.16))
			draw_circle(Vector2(-3,  3), 7,  Color(0.68, 0.24, 0.12))
			draw_circle(Vector2( 0,-17), 7,  Color(0.94, 0.90, 0.86, 0.88))

		PlanetType.JUPITER:
			# Large, brown-orange bands + Great Red Spot
			draw_circle(Vector2.ZERO, 38, Color(0.80, 0.60, 0.40))
			for i in 4:
				var by := -22.0 + i * 14.0
				draw_rect(Rect2(-38, by, 76, 8),
					Color(0.64, 0.42, 0.24, 0.55), true)
			draw_circle(Vector2(12, 8), 9, Color(0.76, 0.26, 0.18))
			draw_circle(Vector2(12, 8), 6, Color(0.82, 0.38, 0.26, 0.7))

		PlanetType.SATURN:
			# Golden planet with visible ring
			draw_arc(Vector2.ZERO, 46, 0, TAU, 64,
				Color(0.85, 0.75, 0.52, 0.45), 8.0)
			draw_circle(Vector2.ZERO, 28, Color(0.90, 0.80, 0.52))
			draw_circle(Vector2(-5, -3), 12, Color(0.98, 0.88, 0.62, 0.4))
			draw_arc(Vector2.ZERO, 38, 0, TAU, 64,
				Color(0.78, 0.68, 0.44, 0.35), 4.0)

		PlanetType.NEPTUNE:
			# Deep blue with storm bands
			draw_circle(Vector2.ZERO, 22, Color(0.10, 0.22, 0.78))
			draw_circle(Vector2(-4, -5), 10, Color(0.18, 0.38, 0.90, 0.45))
			draw_circle(Vector2( 5,  6),  7, Color(0.08, 0.18, 0.68, 0.4))
			draw_circle(Vector2(-2,  4),  5, Color(0.55, 0.75, 1.0, 0.3))

		PlanetType.PLUTO:
			# Tiny, icy gray-lavender, heart-shaped feature
			draw_circle(Vector2.ZERO, 10, Color(0.80, 0.76, 0.86))
			draw_circle(Vector2( 1,  1),  4, Color(0.95, 0.90, 0.92, 0.7))
			draw_circle(Vector2(-3, -2),  2, Color(0.70, 0.65, 0.75))
