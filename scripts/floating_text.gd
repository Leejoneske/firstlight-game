class_name FloatingText
extends Node2D
## A short piece of text that floats up and fades out, e.g. "+2 Berries".

const LIFETIME := 1.3

var text := ""
var color := Color.WHITE

var _age := 0.0


func _process(delta: float) -> void:
	_age += delta
	position.y -= 40.0 * delta
	modulate.a = clampf(1.0 - _age / LIFETIME, 0.0, 1.0)
	if _age >= LIFETIME:
		queue_free()


func _draw() -> void:
	DrawUtil.label(self, Vector2.ZERO, text, 22, color)
