class_name ButtonFace
extends Control
## The look of an on-screen touch button: a soft disc, a ring, an icon and a small label.

var button: TouchScreenButton
var icon := ""
var caption := ""
var color := Color.WHITE
var diameter := 100.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(diameter, diameter)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var pressed := button != null and button.is_pressed()
	var center := Vector2(diameter, diameter) / 2.0
	var radius := diameter / 2.0 * (0.93 if pressed else 1.0)
	draw_circle(center, radius, Color(0.08, 0.06, 0.04, 0.45 if not pressed else 0.6))
	draw_circle(center, radius * 0.86, Color(color, 0.35 if not pressed else 0.6))
	draw_arc(center, radius - 2.0, 0.0, TAU, 40, Color(color.lightened(0.4), 0.85), 3.0)
	UiIcons.draw(self, icon, center - Vector2(0, diameter * 0.08), diameter * 0.38, Color(1, 0.97, 0.9))
	DrawShapes.text(self, center + Vector2(0, diameter * 0.3), caption, int(maxf(diameter * 0.13, 12.0)), Color(1, 0.97, 0.9))
