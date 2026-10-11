class_name RockWall
extends StaticBody2D
## A straight wall of rocks between two points that nobody can walk through.

const THICKNESS := 60.0

var from := Vector2.ZERO
var to := Vector2.ZERO

var _rocks: Array[Vector4] = []  ## x, y, radius, shade


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var segment := to - from
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(segment.length(), THICKNESS)
	shape.shape = rect
	shape.position = (from + to) / 2.0
	shape.rotation = segment.angle()
	add_child(shape)

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(from) ^ hash(to)
	var direction := segment.normalized()
	var side := direction.orthogonal()
	var distance := 0.0
	while distance <= segment.length():
		var point := from + direction * distance + side * rng.randf_range(-16.0, 16.0)
		_rocks.append(Vector4(point.x, point.y, rng.randf_range(22.0, 34.0), rng.randf_range(-0.08, 0.08)))
		distance += rng.randf_range(20.0, 30.0)


func _draw() -> void:
	for rock in _rocks:
		var center := Vector2(rock.x, rock.y)
		var color := Color(0.5 + rock.w, 0.42 + rock.w, 0.36 + rock.w)
		draw_circle(center, rock.z, color.darkened(0.3))
		draw_circle(center + Vector2(-rock.z * 0.15, -rock.z * 0.2), rock.z * 0.8, color)
		draw_circle(center + Vector2(-rock.z * 0.35, -rock.z * 0.4), rock.z * 0.25, color.lightened(0.15))
