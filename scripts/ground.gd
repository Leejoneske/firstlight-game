class_name Ground
extends Node2D
## Draws the dry ground of the Cracked Badlands, the green hidden grove and the camp area.

const SAND := Color(0.86, 0.68, 0.45)
const OUTSIDE := Color(0.45, 0.34, 0.25)

var world_half := 1600.0
var grove_rect := Rect2()
var camp_radius := 170.0

var _patches: Array[Vector4] = []  ## x, y, radius, lightness
var _cracks: Array[PackedVector2Array] = []
var _pebbles: Array[Vector3] = []  ## x, y, radius
var _grass: Array[Vector2] = []


func _ready() -> void:
	z_index = -10
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var h := world_half
	for i in 260:
		_patches.append(Vector4(rng.randf_range(-h, h), rng.randf_range(-h, h), rng.randf_range(30, 120), rng.randf_range(-1, 1)))
	for i in 80:
		var crack := PackedVector2Array([Vector2(rng.randf_range(-h, h), rng.randf_range(-h, h))])
		var heading := rng.randf() * TAU
		for j in rng.randi_range(3, 6):
			heading += rng.randf_range(-0.8, 0.8)
			crack.append(crack[-1] + Vector2.from_angle(heading) * rng.randf_range(20, 45))
		_cracks.append(crack)
	for i in 500:
		_pebbles.append(Vector3(rng.randf_range(-h, h), rng.randf_range(-h, h), rng.randf_range(2, 5)))
	for i in 120:
		_grass.append(Vector2(rng.randf_range(grove_rect.position.x, grove_rect.end.x), rng.randf_range(grove_rect.position.y, grove_rect.end.y)))


func _draw() -> void:
	var h := world_half
	draw_rect(Rect2(-h - 800, -h - 800, 2 * h + 1600, 2 * h + 1600), OUTSIDE)
	draw_rect(Rect2(-h, -h, 2 * h, 2 * h), SAND)
	for patch in _patches:
		var color := SAND.lightened(0.08 * patch.w) if patch.w > 0 else SAND.darkened(-0.08 * patch.w)
		draw_circle(Vector2(patch.x, patch.y), patch.z, color)

	if grove_rect.has_area():
		draw_rect(grove_rect, Color(0.52, 0.66, 0.36))
		for tuft in _grass:
			for k in 3:
				draw_line(tuft, tuft + Vector2(-5 + k * 5, -10 - k % 2 * 4), Color(0.36, 0.55, 0.25), 2.0)

	for crack in _cracks:
		draw_polyline(crack, SAND.darkened(0.3), 3.0)
	for pebble in _pebbles:
		draw_circle(Vector2(pebble.x, pebble.y), pebble.z, SAND.darkened(0.22))

	# Trampled ground around the family cave, with a dashed edge marking the safe area
	draw_circle(Vector2.ZERO, camp_radius, SAND.darkened(0.12))
	var dashes := 36
	for i in dashes:
		var start := TAU * i / dashes
		draw_arc(Vector2.ZERO, camp_radius, start, start + TAU / dashes * 0.55, 6, Color(1, 1, 1, 0.35), 3.0)
