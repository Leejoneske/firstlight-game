class_name DayDial
extends Control
## Shows the day number and a dial with the sun or moon moving across it.

var day := 1
var phase := ""
var time_of_day := 0.3  ## 0 midnight, 0.25 dawn, 0.5 noon, 0.75 dusk


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(250, 64)


func set_time(new_day: int, new_phase: String, new_time: float) -> void:
	day = new_day
	phase = new_phase
	time_of_day = new_time
	queue_redraw()


func _draw() -> void:
	DrawShapes.rounded_rect(self, Rect2(Vector2.ZERO, size), Color(0.1, 0.07, 0.05, 0.62), 18)
	# The dial: a half circle; the sun travels across it by day, the moon by night
	var center := Vector2(size.x - 44, size.y - 12)
	var radius := 30.0
	var night := time_of_day < 0.25 or time_of_day > 0.75
	draw_arc(center, radius, PI, TAU, 24, Color(0.25, 0.3, 0.5, 0.9) if night else Color(1, 0.8, 0.45, 0.55), 4.0)
	var progress := fposmod(time_of_day - 0.25, 0.5) / 0.5
	var marker := center + Vector2.from_angle(PI + progress * PI) * radius
	UiIcons.draw(self, "moon" if night else "sun", marker, 26.0)
	DrawShapes.text(self, Vector2(18, 22), "Day %d" % day, 26, Color(1, 0.95, 0.8), HORIZONTAL_ALIGNMENT_LEFT)
	DrawShapes.text(self, Vector2(18, 46), phase, 17, Color(0.72, 0.8, 1.0) if night else Color(1, 0.86, 0.62), HORIZONTAL_ALIGNMENT_LEFT)
