class_name Compass
extends Control
## A strip across the top of the screen showing which way you face, with markers for
## places that matter (the cave, the far peak).

const WIDTH := 340.0
const HEIGHT := 34.0
const VIEW_ANGLE := PI * 0.75  ## How much of the circle the strip shows.

var heading := 0.0  ## Radians; 0 = facing north (-Z).
var markers: Array[Dictionary] = []  ## {"angle": float, "icon": String, "distance": float}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, HEIGHT + 16)


func update(new_heading: float, new_markers: Array[Dictionary]) -> void:
	heading = new_heading
	markers = new_markers
	queue_redraw()


func _draw() -> void:
	var strip := Rect2(Vector2.ZERO, Vector2(WIDTH, HEIGHT))
	DrawShapes.rounded_rect(self, strip, Color(0.1, 0.07, 0.05, 0.5))
	var mid := WIDTH / 2.0
	for i in 8:
		var angle := i * TAU / 8.0
		var x := _x_for(angle)
		if x < 0.0:
			continue
		var label: String = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"][i]
		var main := i % 2 == 0
		DrawShapes.text(self, Vector2(x, HEIGHT / 2.0), label, 18 if main else 13,
			Color(1, 0.95, 0.8, 0.95 if main else 0.6))
	for marker in markers:
		var x := _x_for(marker.angle)
		if x < 0.0:
			continue
		UiIcons.draw(self, marker.icon, Vector2(x, HEIGHT + 6), 18.0)
		if marker.has("distance"):
			DrawShapes.text(self, Vector2(x, HEIGHT + 22), "%dm" % int(marker.distance), 12, Color(1, 1, 1, 0.8))
	draw_line(Vector2(mid, 2), Vector2(mid, HEIGHT - 2), Color(1, 0.86, 0.5, 0.9), 2.0)


## Horizontal position on the strip for a world direction, or -1 if it's off the strip.
func _x_for(angle: float) -> float:
	var offset := wrapf(angle - heading, -PI, PI)
	if absf(offset) > VIEW_ANGLE / 2.0:
		return -1.0
	return WIDTH / 2.0 + offset / (VIEW_ANGLE / 2.0) * (WIDTH / 2.0 - 16.0)
