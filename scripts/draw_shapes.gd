class_name DrawShapes
## 2D shape helpers for interface drawing.


static func ellipse(center: Vector2, rx: float, ry: float, points := 20) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in points:
		var angle := TAU * i / points
		result.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	return result


## A filled rectangle with rounded ends, used for bars and pills.
static func rounded_rect(ci: CanvasItem, rect: Rect2, color: Color, radius := -1.0) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(rect.size.y / 2.0 if radius < 0.0 else radius))
	style.anti_aliasing = true
	ci.draw_style_box(style, rect)


## Text centred on a point with a soft outline.
static func text(ci: CanvasItem, pos: Vector2, value: String, size: int, color := Color.WHITE, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var origin := pos
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		origin.x -= width / 2.0
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		origin.x -= width
	origin.y += size * 0.35
	ci.draw_string_outline(font, origin, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, 0.6))
	ci.draw_string(font, origin, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
