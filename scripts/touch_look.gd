class_name TouchLook
extends Control
## Drag a finger on the side of the screen opposite the movement stick to turn the camera.
## Touches that start on a button are left alone.

var hud: Hud  ## Used to ignore touches that land on the on-screen buttons.
var on_right := false  ## Which side of the screen turns the camera.

var _touch_index := -1
var _pending := Vector2.ZERO


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
		elif not touch.pressed and touch.index == _touch_index:
			_touch_index = -1
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			_pending += drag.relative


## Returns how far the finger moved (in pixels) since the last call.
func take_delta() -> Vector2:
	var delta := _pending
	_pending = Vector2.ZERO
	return delta


func release() -> void:
	_touch_index = -1
	_pending = Vector2.ZERO


func _in_zone(point: Vector2) -> bool:
	var view := get_viewport_rect().size
	var on_side := point.x > view.x * 0.45 if on_right else point.x < view.x * 0.55
	return on_side and point.y > 110.0 and not hud.is_over_button(point)
