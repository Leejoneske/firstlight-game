class_name MemberCard
extends Control
## A family member's card in the HUD: portrait, health and hunger. Tap it to switch.

signal pressed

var member: FamilyMember
var index := 0

var _style_normal := StyleBoxFlat.new()
var _style_active := StyleBoxFlat.new()


func _ready() -> void:
	custom_minimum_size = Vector2(210, 74)
	mouse_filter = Control.MOUSE_FILTER_STOP
	for style in [_style_normal, _style_active]:
		style.bg_color = Color(0.1, 0.07, 0.05, 0.75)
		style.set_corner_radius_all(12)
		style.set_border_width_all(2)
		style.border_color = Color(1, 1, 1, 0.15)
	_style_active.set_border_width_all(3)
	_style_active.border_color = Color(1, 0.9, 0.45)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if member == null:
		return
	var rect := Rect2(Vector2.ZERO, size)
	draw_style_box(_style_active if member.is_active else _style_normal, rect)

	var face := Vector2(37, size.y / 2.0)
	draw_circle(face, 27.0, member.fur_color.darkened(0.2))
	draw_circle(face + Vector2(0, -4), 17.0, member.hair_color)
	draw_circle(face + Vector2(0, 2), 13.0, member.skin_color)
	for side in [-1.0, 1.0]:
		draw_circle(face + Vector2(side * 5.0, 0), 2.0, Color(0.1, 0.07, 0.05))

	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(74, 24), "%d  %s" % [index + 1, member.member_name], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	_draw_bar(Vector2(74, 33), member.health / member.max_health, Color(0.85, 0.25, 0.25), "Health")
	_draw_bar(Vector2(74, 51), member.hunger / FamilyMember.MAX_HUNGER, Color(0.95, 0.62, 0.18), "Food")

	if member.is_down:
		draw_rect(rect, Color(0, 0, 0, 0.55))
		draw_string(font, Vector2(0, size.y / 2.0 + 6), "KNOCKED OUT", HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, Color(1, 0.45, 0.4))


func _draw_bar(pos: Vector2, ratio: float, color: Color, text: String) -> void:
	var bar_size := Vector2(size.x - pos.x - 12.0, 14.0)
	draw_rect(Rect2(pos, bar_size), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(pos, Vector2(bar_size.x * clampf(ratio, 0.0, 1.0), bar_size.y)), color)
	draw_string(ThemeDB.fallback_font, pos + Vector2(5, 11), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.9))
