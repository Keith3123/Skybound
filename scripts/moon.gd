extends Node2D

@export var radius := 36.0

enum Phase {
	NEW_MOON  = 0,   # Fully dark
	CRESCENT  = 1,   # Thin lit sliver
	QUARTER   = 2,   # Half lit
	GIBBOUS   = 3,   # Mostly lit
	FULL_MOON = 4,   # Fully lit
}

var phase := Phase.FULL_MOON

func _draw():
	var moon_col := Color(0.95, 0.95, 0.85)
	var shadow := Color(0.05, 0.08, 0.25)
	
	match phase:
		Phase.NEW_MOON:
			# Dark 
			draw_circle(Vector2.ZERO, radius, Color(0.12, 0.14, 0.20))
			draw_circle(Vector2.ZERO, radius, Color(0.35, 0.38, 0.45, 0.6), false, 1.5)
			
		Phase.CRESCENT:
			# lit circle
			draw_circle(Vector2.ZERO, radius, moon_col)
			draw_circle(Vector2(radius * 0.68, 0), radius * 1.08, shadow)
			
		Phase.QUARTER:
			# Right half shadow
			draw_circle(Vector2.ZERO, radius, moon_col)
			var points = PackedVector2Array()
			var steps: int = 32
			
			for i in range(steps + 1):
				var angle: float = -PI/2 + (PI * i / steps) 
				points.append(Vector2(cos(angle), sin(angle)) * radius)	
				
			points.append(Vector2(0, radius))
			points.append(Vector2(0, -radius))
			
			draw_polygon(points, PackedColorArray([shadow]))
			draw_circle(Vector2(-8, -6), 4, Color(0.88, 0.88, 0.78, 0.6))
			draw_circle(Vector2(-12, 8), 3, Color(0.88, 0.88, 0.78, 0.5))
			
		Phase.GIBBOUS:
			# Mostly lit
			draw_circle(Vector2.ZERO, radius, moon_col)
			
			var points = PackedVector2Array()
			var steps: int = 32
			
			for i in range(steps + 1):
				var angle: float = -PI/2 + (PI * i / steps)
				points.append(Vector2(cos(angle), sin(angle)) * radius)
				
			for i in range(steps, -1, -1):
				var angle: float = -PI/2 + (PI * i / steps)
				points.append(Vector2(cos(angle) * 0.4, sin(angle)) * radius)
				
			draw_polygon(points, PackedColorArray([shadow]))
			draw_circle(Vector2(-6, -5), 4, Color(0.88, 0.88, 0.78, 0.6))
			draw_circle(Vector2(8, -12), 3, Color(0.88, 0.88, 0.78, 0.5))
			
		Phase.FULL_MOON:
			# Fully lit
			draw_circle(Vector2.ZERO, radius, moon_col)
			draw_circle(Vector2(-8, -6), 5, Color(0.87, 0.87, 0.77))
			draw_circle(Vector2(10, 8), 4, Color(0.87, 0.87, 0.77))
			draw_circle(Vector2(-4, 10), 3, Color(0.87, 0.87, 0.77))
			draw_circle(Vector2(6, -12), 3, Color(0.87, 0.87, 0.77))
			# Glow
			draw_circle(Vector2.ZERO, radius + 6, Color(0.95, 0.95, 0.82, 0.12))

func _ready():
	queue_redraw()
