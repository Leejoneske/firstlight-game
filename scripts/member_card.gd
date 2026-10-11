class_name MemberCard
extends Control
## A family member's card in the HUD: portrait, health and food. Tap it to switch.
## The food bar pulses when they're getting hungry.

signal pressed

const LOW := 0.25

var member: FamilyMember
var index := 0

var _time := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(212, 76)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if member == null:
		return
	var rect := Rect2(Vector2.ZERO, size)
	var active := member.is_active
	DrawShapes.rounded_rect(self, rect, Color(0.1, 0.07, 0.05, 0.72), 16)
	if active:
		var glow := StyleBoxFlat.new()
		glow.draw_center = false
		glow.set_corner_radius_all(16)
		glow.set_border_width_all(3)
		glow.border_color = Color(1, 0.86, 0.45)
		draw_style_box(glow, rect)

	# Portrait: a little face in a ring
	var face := Vector2(38, size.y / 2.0)
	draw_circle(face, 29.0, Color(1, 0.86, 0.45) if active else Color(0.35, 0.28, 0.22))
	draw_circle(face, 26.0, member.fur_color.darkened(0.25))
	draw_circle(face + Vector2(0, -5), 18.0, member.hair_color)
	draw_circle(face + Vector2(0, 2), 14.0, member.skin_color)
	for side in [-1.0, 1.0]:
		draw_circle(face + Vector2(side * 5.5, 0), 3.4, Color(0.98, 0.97, 0.94))
		draw_circle(face + Vector2(side * 5.5, 0.5), 1.8, Color(0.1, 0.07, 0.05))
	draw_arc(face + Vector2(0, 5), 4.0, 0.3, PI - 0.3, 8, Color(0.35, 0.12, 0.1), 1.6)

	# Name with its number key
	DrawShapes.text(self, Vector2(76, 18), member.member_name, 19, Color(1, 0.96, 0.86), HORIZONTAL_ALIGNMENT_LEFT)
	DrawShapes.rounded_rect(self, Rect2(size.x - 34, 8, 24, 20), Color(1, 1, 1, 0.12), 6)
	DrawShapes.text(self, Vector2(size.x - 22, 18), str(index + 1), 14, Color(1, 1, 1, 0.75))

	var health := member.health / member.max_health
	var food := member.hunger / FamilyMember.MAX_HUNGER
	_draw_bar(Vector2(76, 36), health, Color(0.9, 0.3, 0.32), "heart", health < LOW)
	_draw_bar(Vector2(76, 56), food, Color(0.97, 0.66, 0.22), "food", food < LOW)

	if member.is_down:
		DrawShapes.rounded_rect(self, rect, Color(0, 0, 0, 0.6), 16)
		DrawShapes.text(self, size / 2.0, "KNOCKED OUT", 18, Color(1, 0.5, 0.45))


func _draw_bar(pos: Vector2, ratio: float, color: Color, icon: String, warn: bool) -> void:
	var bar := Rect2(pos + Vector2(20, -6), Vector2(size.x - pos.x - 30, 12))
	UiIcons.draw(self, icon, pos + Vector2(6, 0), 15.0)
	DrawShapes.rounded_rect(self, bar, Color(0, 0, 0, 0.5))
	var fill := color
	if warn:
		fill = color.lerp(Color.WHITE, (sin(_time * 8.0) * 0.5 + 0.5) * 0.45)
	DrawShapes.rounded_rect(self, Rect2(bar.position, Vector2(maxf(bar.size.x * clampf(ratio, 0.0, 1.0), bar.size.y if ratio > 0.0 else 0.0), bar.size.y)), fill)
