class_name ResourceNode
extends StaticBody2D
## Something the family can gather from: bushes, trees, rocks and boulders.
## Some need a particular talent: boulders need strength, tall trees need a climber.

enum Kind { BERRY_BUSH, TREE, ROCK, BOULDER, TALL_TREE }

## regrow < 0 means the resource is gone for good once used up.
const DATA := {
	Kind.BERRY_BUSH: {"item": "berries", "amount": 2, "uses": 3, "regrow": 60.0, "radius": 22.0, "solid": false, "verb": "Pick berries"},
	Kind.TREE: {"item": "sticks", "amount": 1, "uses": 4, "regrow": 90.0, "radius": 14.0, "solid": true, "verb": "Gather sticks"},
	Kind.ROCK: {"item": "stones", "amount": 1, "uses": 3, "regrow": 120.0, "radius": 16.0, "solid": true, "verb": "Collect stones"},
	Kind.BOULDER: {"item": "stones", "amount": 5, "uses": 1, "regrow": -1.0, "radius": 42.0, "solid": true, "verb": "Smash boulder"},
	Kind.TALL_TREE: {"item": "fruit", "amount": 2, "uses": 2, "regrow": 90.0, "radius": 16.0, "solid": true, "verb": "Climb for fruit"},
}

var kind := Kind.BERRY_BUSH
var is_gate := false  ## The boulder blocking the hidden grove.
var radius := 20.0
var uses_left := 0

var _regrow_timer := 0.0
var _shake := 0.0
var _shape: CollisionShape2D
var _tint := 0.0


func _ready() -> void:
	var data: Dictionary = DATA[kind]
	radius = data.radius
	uses_left = data.uses
	_tint = randf_range(-0.06, 0.06)
	collision_layer = 1
	collision_mask = 0
	if data.solid:
		_shape = CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = radius
		_shape.shape = circle
		add_child(_shape)


func is_available() -> bool:
	return uses_left > 0


func can_use(member: FamilyMember) -> bool:
	match kind:
		Kind.BOULDER:
			return member.strength >= 2
		Kind.TALL_TREE:
			return member.can_climb
	return true


func action_name(member: FamilyMember) -> String:
	var verb: String = DATA[kind].verb
	if can_use(member):
		return verb
	if kind == Kind.BOULDER:
		return verb + " (needs someone strong)"
	return verb + " (needs a climber)"


## Gathers from this resource. Returns {"item", "amount"} on success, and/or {"message"}.
func interact(member: FamilyMember) -> Dictionary:
	if not is_available():
		return {}
	_shake = 0.3
	if not can_use(member):
		if kind == Kind.BOULDER:
			return {"message": "Too heavy for %s. Switch to someone stronger!" % member.member_name}
		return {"message": "Too high for %s to climb. Switch to a climber!" % member.member_name}
	var data: Dictionary = DATA[kind]
	var result := {"item": data.item, "amount": data.amount}
	uses_left -= 1
	if uses_left <= 0:
		if is_gate:
			result["message"] = "The boulder shatters... there's a hidden grove behind it!"
		_deplete()
	return result


func _deplete() -> void:
	var regrow: float = DATA[kind].regrow
	if regrow < 0.0:
		queue_free()
		return
	_regrow_timer = regrow
	if kind == Kind.ROCK:
		visible = false
		_shape.set_deferred("disabled", true)
	queue_redraw()


func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake -= delta
		queue_redraw()
	if uses_left <= 0:
		_regrow_timer -= delta
		if _regrow_timer <= 0.0:
			uses_left = DATA[kind].uses
			visible = true
			if _shape:
				_shape.set_deferred("disabled", false)
			queue_redraw()


func _draw() -> void:
	var sx := sin(_shake * 60.0) * 3.0 if _shake > 0.0 else 0.0
	match kind:
		Kind.BERRY_BUSH:
			_draw_bush(sx)
		Kind.TREE:
			_draw_tree(sx)
		Kind.ROCK:
			_draw_rock(sx)
		Kind.BOULDER:
			_draw_boulder(sx)
		Kind.TALL_TREE:
			_draw_tall_tree(sx)


func _draw_bush(sx: float) -> void:
	DrawUtil.shadow(self, 26.0, 9.0)
	var green := Color(0.33 + _tint, 0.52, 0.24)
	for blob in [Vector3(-12, -14, 14), Vector3(12, -14, 14), Vector3(0, -24, 16), Vector3(0, -11, 14)]:
		draw_circle(Vector2(blob.x + sx, blob.y), blob.z, green.darkened(0.15) if blob.y < -20 else green)
	var spots := [Vector2(-14, -16), Vector2(-4, -27), Vector2(8, -20), Vector2(15, -11), Vector2(-6, -9),
		Vector2(4, -31), Vector2(-17, -8), Vector2(11, -27), Vector2(0, -16)]
	for i in mini(uses_left * 3, spots.size()):
		draw_circle(spots[i] + Vector2(sx, 0), 3.2, Color(0.85, 0.12, 0.2))


func _draw_tree(sx: float) -> void:
	DrawUtil.shadow(self, 22.0, 8.0)
	var trunk := Color(0.42, 0.28, 0.17)
	draw_colored_polygon(PackedVector2Array([Vector2(-7, 0), Vector2(7, 0), Vector2(4 + sx, -52), Vector2(-4 + sx, -52)]), trunk)
	draw_line(Vector2(sx, -40), Vector2(-16 + sx, -56), trunk, 4.0)
	draw_line(Vector2(sx, -46), Vector2(16 + sx, -60), trunk, 4.0)
	var leaves := Color(0.5 + _tint, 0.55, 0.28)
	if uses_left <= 0:
		leaves = leaves.lerp(Color(0.6, 0.5, 0.35), 0.6)
	for blob in [Vector3(-16, -60, 14), Vector3(16, -64, 14), Vector3(0, -70, 18)]:
		draw_circle(Vector2(blob.x + sx * 1.5, blob.y), blob.z, leaves)


func _draw_rock(sx: float) -> void:
	DrawUtil.shadow(self, 20.0, 7.0)
	var grey := Color(0.55 + _tint, 0.52 + _tint, 0.5)
	draw_colored_polygon(DrawUtil.ellipse(Vector2(sx, -9), 19.0, 13.0, 10), grey.darkened(0.2))
	draw_colored_polygon(DrawUtil.ellipse(Vector2(sx - 2, -12), 15.0, 9.0, 10), grey)
	for i in uses_left:
		draw_circle(Vector2(-8 + i * 8 + sx, -12), 2.0, grey.lightened(0.3))


func _draw_boulder(sx: float) -> void:
	DrawUtil.shadow(self, 46.0, 14.0)
	var grey := Color(0.5 + _tint, 0.45, 0.4)
	draw_colored_polygon(DrawUtil.ellipse(Vector2(sx, -30), 44.0, 34.0, 14), grey.darkened(0.25))
	draw_colored_polygon(DrawUtil.ellipse(Vector2(sx - 4, -36), 36.0, 26.0, 14), grey)
	draw_polyline(PackedVector2Array([Vector2(-10 + sx, -58), Vector2(-2 + sx, -40), Vector2(-12 + sx, -26), Vector2(-4 + sx, -14)]),
		grey.darkened(0.45), 2.5)
	draw_polyline(PackedVector2Array([Vector2(14 + sx, -50), Vector2(20 + sx, -36), Vector2(30 + sx, -32)]), grey.darkened(0.45), 2.0)


func _draw_tall_tree(sx: float) -> void:
	DrawUtil.shadow(self, 24.0, 8.0)
	var trunk := Color(0.5, 0.36, 0.22)
	for i in 6:
		var y := -i * 20.0
		draw_colored_polygon(PackedVector2Array([Vector2(-8, y), Vector2(8, y), Vector2(6 + sx * 0.3, y - 20), Vector2(-6 + sx * 0.3, y - 20)]),
			trunk if i % 2 == 0 else trunk.darkened(0.12))
	var top := Vector2(sx, -122)
	var frond := Color(0.3 + _tint, 0.6, 0.3)
	for angle in [-2.8, -2.2, -1.6, -1.0, -0.4, 0.3, 2.9 + PI]:
		draw_line(top, top + Vector2.from_angle(angle) * 44.0 + Vector2(0, 12), frond, 7.0)
	var fruit_spots := [Vector2(-7, 6), Vector2(7, 6), Vector2(0, 11), Vector2(-12, 12)]
	for i in mini(uses_left * 2, fruit_spots.size()):
		draw_circle(top + fruit_spots[i], 5.5, Color(0.98, 0.58, 0.15))
