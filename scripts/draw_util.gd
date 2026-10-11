class_name DrawUtil
## Small helpers for drawing placeholder art with shapes.


static func ellipse(center: Vector2, rx: float, ry: float, points := 24) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in points:
		var angle := TAU * i / points
		result.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	return result


## Draws a soft shadow on the ground under an object whose base is at the origin.
static func shadow(item: CanvasItem, rx: float, ry: float) -> void:
	item.draw_colored_polygon(ellipse(Vector2.ZERO, rx, ry), Color(0, 0, 0, 0.22))


## Draws text centred on a point, with a dark outline so it reads on any background.
static func label(item: CanvasItem, pos: Vector2, text: String, size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var origin := pos - Vector2(width / 2.0, 0)
	item.draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0, 0, 0, 0.8))
	item.draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
