class_name UiIcons
## Simple vector icons for the interface, drawn with shapes so they stay sharp at any size.

const BERRY := Color(0.86, 0.15, 0.25)
const LEAF := Color(0.36, 0.66, 0.3)
const FRUIT := Color(0.98, 0.6, 0.16)
const MEAT := Color(0.8, 0.36, 0.3)
const BONE := Color(0.96, 0.93, 0.85)
const WOOD := Color(0.6, 0.4, 0.24)
const STONE := Color(0.62, 0.6, 0.58)
const HEART := Color(0.92, 0.27, 0.3)
const SUN := Color(1.0, 0.82, 0.32)
const MOON := Color(0.78, 0.84, 1.0)


## Draws icon `name` centred on `c`, roughly `s` pixels across.
static func draw(ci: CanvasItem, name: String, c: Vector2, s: float, tint := Color.WHITE) -> void:
	var r := s / 2.0
	match name:
		"berries":
			for offset in [Vector2(-0.35, 0.25), Vector2(0.35, 0.25), Vector2(0, -0.2)]:
				ci.draw_circle(c + offset * r, r * 0.42, BERRY * tint)
				ci.draw_circle(c + offset * r + Vector2(-0.12, -0.12) * r, r * 0.12, Color(1, 1, 1, 0.6) * tint)
			ci.draw_colored_polygon(_leaf(c + Vector2(0.25, -0.75) * r, r * 0.45, -0.6), LEAF * tint)
		"fruit":
			ci.draw_circle(c + Vector2(0, 0.1) * r, r * 0.78, FRUIT * tint)
			ci.draw_circle(c + Vector2(-0.3, -0.15) * r, r * 0.2, Color(1, 1, 1, 0.5) * tint)
			ci.draw_line(c + Vector2(0, -0.6) * r, c + Vector2(0.1, -0.95) * r, WOOD * tint, maxf(r * 0.15, 1.5))
			ci.draw_colored_polygon(_leaf(c + Vector2(0.4, -0.8) * r, r * 0.4, 0.4), LEAF * tint)
		"meat":
			ci.draw_line(c + Vector2(0.15, 0.15) * r, c + Vector2(0.75, 0.75) * r, BONE * tint, r * 0.3)
			ci.draw_circle(c + Vector2(0.8, 0.6) * r, r * 0.18, BONE * tint)
			ci.draw_circle(c + Vector2(0.6, 0.85) * r, r * 0.18, BONE * tint)
			ci.draw_circle(c + Vector2(-0.2, -0.2) * r, r * 0.68, MEAT * tint)
			ci.draw_circle(c + Vector2(-0.4, -0.4) * r, r * 0.22, Color(1, 0.75, 0.7, 0.6) * tint)
		"sticks":
			ci.draw_line(c + Vector2(-0.8, 0.6) * r, c + Vector2(0.8, -0.6) * r, WOOD * tint, r * 0.3)
			ci.draw_line(c + Vector2(-0.8, -0.3) * r, c + Vector2(0.7, 0.7) * r, WOOD.darkened(0.2) * tint, r * 0.28)
			ci.draw_line(c + Vector2(0.2, -0.15) * r, c + Vector2(0.45, -0.7) * r, WOOD * tint, r * 0.16)
		"stones":
			ci.draw_colored_polygon(DrawShapes.ellipse(c + Vector2(-0.3, 0.25) * r, r * 0.55, r * 0.42), STONE.darkened(0.15) * tint)
			ci.draw_colored_polygon(DrawShapes.ellipse(c + Vector2(0.35, 0.15) * r, r * 0.45, r * 0.36), STONE * tint)
			ci.draw_colored_polygon(DrawShapes.ellipse(c + Vector2(0, -0.35) * r, r * 0.42, r * 0.32), STONE.lightened(0.15) * tint)
		"heart":
			ci.draw_circle(c + Vector2(-0.38, -0.2) * r, r * 0.45, HEART * tint)
			ci.draw_circle(c + Vector2(0.38, -0.2) * r, r * 0.45, HEART * tint)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.8, 0.0) * r, c + Vector2(0.8, 0.0) * r, c + Vector2(0, 0.9) * r]), HEART * tint)
		"food":
			draw(ci, "meat", c, s, tint)
		"sun":
			for i in 8:
				var direction := Vector2.from_angle(i * TAU / 8.0)
				ci.draw_line(c + direction * r * 0.62, c + direction * r * 0.95, SUN * tint, maxf(r * 0.14, 1.5))
			ci.draw_circle(c, r * 0.48, SUN * tint)
		"moon":
			ci.draw_circle(c, r * 0.7, MOON * tint)
			ci.draw_circle(c + Vector2(0.35, -0.2) * r, r * 0.6, Color(0.12, 0.13, 0.25, 1) * tint)
		"hand":
			# An open hand: palm and four fingers, with a thumb
			ci.draw_colored_polygon(DrawShapes.ellipse(c + Vector2(0, 0.25) * r, r * 0.5, r * 0.45), tint)
			for i in 4:
				var x := (-0.36 + i * 0.24) * r
				ci.draw_line(c + Vector2(x, 0.0), c + Vector2(x * 1.1, -0.75 * r + absf(i - 1.5) * 0.12 * r), tint, r * 0.2)
			ci.draw_line(c + Vector2(-0.4, 0.3) * r, c + Vector2(-0.8, -0.05) * r, tint, r * 0.2)
		"swap":
			ci.draw_arc(c, r * 0.6, PI * 1.1, PI * 1.9, 12, tint, r * 0.16)
			ci.draw_arc(c, r * 0.6, PI * 0.1, PI * 0.9, 12, tint, r * 0.16)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0.5, -0.65) * r, c + Vector2(0.95, -0.3) * r, c + Vector2(0.4, -0.15) * r]), tint)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.5, 0.65) * r, c + Vector2(-0.95, 0.3) * r, c + Vector2(-0.4, 0.15) * r]), tint)
		"eye":
			ci.draw_colored_polygon(DrawShapes.ellipse(c, r * 0.9, r * 0.5), tint)
			ci.draw_circle(c, r * 0.36, Color(0.15, 0.12, 0.1))
			ci.draw_circle(c + Vector2(-0.12, -0.12) * r, r * 0.1, tint)
		"home":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.85, 0.75) * r, c + Vector2(-0.85, -0.05) * r,
				c + Vector2(0, -0.8) * r, c + Vector2(0.85, -0.05) * r, c + Vector2(0.85, 0.75) * r]), tint)
			ci.draw_colored_polygon(DrawShapes.ellipse(c + Vector2(0, 0.45) * r, r * 0.32, r * 0.35), Color(0.12, 0.08, 0.06))
		"star":
			var points := PackedVector2Array()
			for i in 10:
				var radius := r if i % 2 == 0 else r * 0.45
				points.append(c + Vector2.from_angle(-PI / 2.0 + i * TAU / 10.0) * radius)
			ci.draw_colored_polygon(points, SUN * tint)


static func _leaf(c: Vector2, r: float, angle: float) -> PackedVector2Array:
	var points := DrawShapes.ellipse(Vector2.ZERO, r, r * 0.45, 10)
	for i in points.size():
		points[i] = c + points[i].rotated(angle)
	return points
