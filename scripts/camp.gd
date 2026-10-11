class_name Camp
extends Node2D
## The family cave. Resting inside the camp area heals the family and slows hunger,
## and creatures won't follow them in.

const MOUND_CENTER := Vector2(0, -120)
const MOUND_RADIUS := 80.0


func _ready() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = MOUND_RADIUS
	shape.shape = circle
	shape.position = MOUND_CENTER
	body.add_child(shape)
	add_child(body)


func _draw() -> void:
	# Rock mound with the cave mouth
	var rock := Color(0.55, 0.43, 0.33)
	draw_colored_polygon(DrawUtil.ellipse(MOUND_CENTER + Vector2(0, 10), 125.0, 85.0, 28), rock.darkened(0.25))
	draw_colored_polygon(DrawUtil.ellipse(MOUND_CENTER, 112.0, 74.0, 28), rock)
	draw_colored_polygon(DrawUtil.ellipse(MOUND_CENTER + Vector2(-30, -30), 40.0, 20.0, 16), rock.lightened(0.12))
	var mouth := PackedVector2Array()
	for i in 17:
		var angle := PI + PI * i / 16.0
		mouth.append(Vector2(0, -52) + Vector2(cos(angle) * 46.0, sin(angle) * 52.0))
	draw_colored_polygon(mouth, Color(0.12, 0.08, 0.06))

	# Sleeping furs
	draw_colored_polygon(DrawUtil.ellipse(Vector2(-75, 25), 30.0, 14.0), Color(0.62, 0.45, 0.28))
	draw_colored_polygon(DrawUtil.ellipse(Vector2(75, 25), 30.0, 14.0), Color(0.55, 0.4, 0.3))

	# Unlit fire pit: a ring of stones and a pile of sticks
	var pit := Vector2(0, 55)
	for i in 9:
		draw_circle(pit + Vector2.from_angle(TAU * i / 9.0) * Vector2(26, 13), 6.0, Color(0.5, 0.48, 0.45))
	draw_line(pit + Vector2(-14, 4), pit + Vector2(12, -6), Color(0.45, 0.3, 0.18), 4.0)
	draw_line(pit + Vector2(-12, -6), pit + Vector2(14, 4), Color(0.4, 0.27, 0.16), 4.0)

	DrawUtil.label(self, Vector2(0, -215), "Family Cave", 18, Color(1, 0.95, 0.8, 0.9))
