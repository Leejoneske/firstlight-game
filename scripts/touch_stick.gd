class_name TouchStick
extends Control
## Floating thumb-stick for touch screens: put a thumb down anywhere in the lower
## corner on the stick's side and drag. Read `output` for the direction (length 0 to 1).

const RADIUS := 80.0
const DEADZONE := 0.15

var output := Vector2.ZERO
var on_right := true  ## Which side of the screen the stick lives on.
var hud: Hud  ## Used to ignore touches that land on the on-screen buttons.

var _touch_index := -1
var _center := Vector2.ZERO
var _knob := Vector2.ZERO


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _touch_index == -1 and _in_zone(touch.position):
			_touch_index = touch.index
			_center = touch.position
			_move_knob(touch.position)
			get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == _touch_index:
			release()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			_move_knob(drag.position)
			get_viewport().set_input_as_handled()


func release() -> void:
	_touch_index = -1
	output = Vector2.ZERO
	queue_redraw()


func _in_zone(point: Vector2) -> bool:
	var view := get_viewport_rect().size
	var on_side := point.x > view.x * 0.55 if on_right else point.x < view.x * 0.45
	return on_side and point.y > view.y * 0.35 and not hud.is_over_button(point)


func _move_knob(point: Vector2) -> void:
	var offset := (point - _center).limit_length(RADIUS)
	_knob = _center + offset
	output = offset / RADIUS
	if output.length() < DEADZONE:
		output = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	var center := _center
	var knob := _knob
	var alpha := 0.5
	if _touch_index == -1:
		# Show a faint stick at rest so players know where to put their thumb
		var view := get_viewport_rect().size
		center = Vector2(view.x - 160.0 if on_right else 160.0, view.y - 160.0)
		knob = center
		alpha = 0.25
	draw_circle(center, RADIUS, Color(0, 0, 0, alpha * 0.5))
	draw_arc(center, RADIUS, 0.0, TAU, 48, Color(1, 1, 1, alpha), 3.0)
	draw_circle(knob, 34.0, Color(1, 1, 1, alpha + 0.15))
