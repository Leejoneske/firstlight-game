class_name FloatingText
extends Label3D
## A short piece of text that floats up and fades out, e.g. "+2 Berries".

const LIFETIME := 1.4

var _age := 0.0


func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	font_size = 44
	outline_size = 12
	pixel_size = 0.01
	outline_modulate = Color(0, 0, 0, 0.85)


func _process(delta: float) -> void:
	_age += delta
	position.y += 0.9 * delta
	modulate.a = clampf(1.0 - _age / LIFETIME, 0.0, 1.0)
	outline_modulate.a = modulate.a * 0.85
	if _age >= LIFETIME:
		queue_free()
