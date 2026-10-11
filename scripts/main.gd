extends Node2D
## Builds the first test land (the Cracked Badlands) and runs the game loop:
## family switching, gathering, hunger, day and night, and the Boarcupines.

const WORLD_HALF := 1600.0
const CAMP_RADIUS := 170.0
const DAY_LENGTH := 240.0  ## Seconds for a full day and night.
const START_TIME := 0.3  ## 0 = midnight, 0.25 = dawn, 0.5 = noon, 0.75 = dusk.
const BOAR_COUNT := 6
const BOAR_RESPAWN_TIME := 45.0
const ACTION_RANGE := 46.0  ## Largest gap between a member and something they can use.
const HUNGRY_WARNING := 25.0
const GROVE_RECT := Rect2(700, -1600, 900, 900)
const GROVE_GATE := Vector2(700, -1150)

var members: Array[FamilyMember] = []
var boars: Array[Boarcupine] = []
var resources: Array[ResourceNode] = []
var active: FamilyMember
var time_of_day := START_TIME
var day := 1

var _rng := RandomNumberGenerator.new()
var _world: Node2D
var _effects: Node2D
var _camera: Camera2D
var _hud: Hud
var _sky: CanvasModulate
var _sky_gradient := Gradient.new()
var _light: PointLight2D
var _boar_respawns: Array[float] = []
var _retreating := false
var _hungry_warned := {}


func _ready() -> void:
	_rng.randomize()
	_build_sky()
	_build_world()
	_spawn_family()
	_spawn_resources()
	for i in BOAR_COUNT:
		_spawn_boar()
	_build_camera()
	_build_hud()
	_switch_to(0)
	_advance_time(0.0)
	GameState.notify("The ground keeps shaking... Gather food before nightfall!")


func _process(delta: float) -> void:
	if not _retreating:
		_advance_time(delta)
	_read_movement()
	_update_camp_flags()
	_update_boar_respawns(delta)
	_check_hunger()
	if active:
		_camera.global_position = active.global_position
		_light.global_position = active.global_position + Vector2(0, -20)
	_hud.show_hint(_hint_text())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_touch_ui"):
		_hud.toggle_touch_ui()
	if _retreating:
		return
	if event.is_action_pressed("action"):
		_do_action()
	elif event.is_action_pressed("eat"):
		_do_eat()
	elif event.is_action_pressed("switch_next"):
		_switch_next()
	else:
		for i in members.size():
			if event.is_action_pressed("switch_%d" % (i + 1)):
				_switch_to(i)


# --- Building the world ---------------------------------------------------

func _build_sky() -> void:
	var night := Color(0.22, 0.25, 0.45)
	var dawn := Color(0.95, 0.75, 0.65)
	var dusk := Color(0.95, 0.65, 0.5)
	_sky_gradient.offsets = PackedFloat32Array([0.0, 0.18, 0.26, 0.35, 0.65, 0.74, 0.82, 1.0])
	_sky_gradient.colors = PackedColorArray([night, night, dawn, Color.WHITE, Color.WHITE, dusk, night, night])
	_sky = CanvasModulate.new()
	add_child(_sky)

	# A soft glow around the active member so the night isn't pitch black
	var glow := Gradient.new()
	glow.colors = PackedColorArray([Color(1, 0.9, 0.7, 1), Color(1, 0.9, 0.7, 0)])
	var texture := GradientTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.gradient = glow
	_light = PointLight2D.new()
	_light.texture = texture
	_light.energy = 0.0
	add_child(_light)


func _build_world() -> void:
	var ground := Ground.new()
	ground.world_half = WORLD_HALF
	ground.grove_rect = GROVE_RECT
	ground.camp_radius = CAMP_RADIUS
	add_child(ground)

	var h := WORLD_HALF
	_add_wall(Vector2(-h, -h), Vector2(h, -h))
	_add_wall(Vector2(h, -h), Vector2(h, h))
	_add_wall(Vector2(h, h), Vector2(-h, h))
	_add_wall(Vector2(-h, h), Vector2(-h, -h))
	# A ridge closes off the hidden grove. Its only way in is blocked by a boulder.
	var gx := GROVE_RECT.position.x
	_add_wall(Vector2(gx, -h), Vector2(gx, GROVE_GATE.y - 60.0))
	_add_wall(Vector2(gx, GROVE_GATE.y + 60.0), Vector2(gx, GROVE_RECT.end.y))
	_add_wall(Vector2(gx, GROVE_RECT.end.y), Vector2(h, GROVE_RECT.end.y))

	_world = Node2D.new()
	_world.y_sort_enabled = true
	add_child(_world)
	_world.add_child(Camp.new())

	_effects = Node2D.new()
	_effects.z_index = 50
	add_child(_effects)


func _add_wall(from: Vector2, to: Vector2) -> void:
	var wall := RockWall.new()
	wall.from = from
	wall.to = to
	add_child(wall)


func _spawn_family() -> void:
	var krag := FamilyMember.new()
	krag.member_name = "Krag"
	krag.talent = "Strong: smashes boulders, hits hard"
	krag.max_health = 130.0
	krag.move_speed = 190.0
	krag.strength = 2
	krag.hunger_rate = 0.35
	krag.size_scale = 1.2
	krag.skin_color = Color(0.78, 0.58, 0.43)
	krag.fur_color = Color(0.5, 0.33, 0.2)
	krag.hair_color = Color(0.15, 0.1, 0.07)
	krag.position = Vector2(-40, 100)
	krag.follow_offset = Vector2(-45, 35)

	var zee := FamilyMember.new()
	zee.member_name = "Zee"
	zee.talent = "Scout: fastest, climbs tall trees"
	zee.max_health = 85.0
	zee.move_speed = 270.0
	zee.strength = 1
	zee.can_climb = true
	zee.hunger_rate = 0.42
	zee.size_scale = 0.95
	zee.skin_color = Color(0.86, 0.66, 0.5)
	zee.fur_color = Color(0.78, 0.58, 0.32)
	zee.hair_color = Color(0.85, 0.38, 0.15)
	zee.position = Vector2(40, 100)
	zee.follow_offset = Vector2(45, 35)

	for member in [krag, zee]:
		_world.add_child(member)
		members.append(member)
		member.downed.connect(_on_member_downed.bind(member))


func _spawn_resources() -> void:
	var gate := _add_resource(ResourceNode.Kind.BOULDER, GROVE_GATE)
	gate.is_gate = true
	var outside := {
		ResourceNode.Kind.BERRY_BUSH: 22,
		ResourceNode.Kind.TREE: 28,
		ResourceNode.Kind.ROCK: 22,
		ResourceNode.Kind.BOULDER: 6,
		ResourceNode.Kind.TALL_TREE: 5,
	}
	for kind: ResourceNode.Kind in outside:
		for i in outside[kind]:
			var point := _random_point(false)
			if point != Vector2.INF:
				_add_resource(kind, point)
	# The hidden grove is rich in food
	var grove := {ResourceNode.Kind.BERRY_BUSH: 10, ResourceNode.Kind.TALL_TREE: 4}
	for kind: ResourceNode.Kind in grove:
		for i in grove[kind]:
			var point := _random_point(true)
			if point != Vector2.INF:
				_add_resource(kind, point)


func _add_resource(kind: ResourceNode.Kind, point: Vector2) -> ResourceNode:
	var resource := ResourceNode.new()
	resource.kind = kind
	resource.position = point
	_world.add_child(resource)
	resources.append(resource)
	resource.tree_exiting.connect(func() -> void: resources.erase(resource))
	return resource


## Finds a free spot for something new, either in the open badlands or inside the grove.
## Returns Vector2.INF if no spot was found.
func _random_point(in_grove: bool) -> Vector2:
	var margin := 90.0
	for attempt in 40:
		var point: Vector2
		if in_grove:
			point = Vector2(_rng.randf_range(GROVE_RECT.position.x + margin, GROVE_RECT.end.x - margin),
				_rng.randf_range(GROVE_RECT.position.y + margin, GROVE_RECT.end.y - margin))
		else:
			point = Vector2(_rng.randf_range(-WORLD_HALF + margin, WORLD_HALF - margin),
				_rng.randf_range(-WORLD_HALF + margin, WORLD_HALF - margin))
			if GROVE_RECT.grow(80.0).has_point(point) or point.length() < CAMP_RADIUS + 90.0:
				continue
			if point.distance_to(GROVE_GATE) < 200.0:
				continue
		if _is_clear(point, 80.0):
			return point
	return Vector2.INF


func _is_clear(point: Vector2, min_distance: float) -> bool:
	for resource in resources:
		if resource.position.distance_to(point) < min_distance + resource.radius:
			return false
	return true


func _spawn_boar() -> void:
	for attempt in 20:
		var point := _random_point(false)
		if point == Vector2.INF:
			continue
		if active and point.distance_to(active.global_position) < 600.0:
			continue
		var boar := Boarcupine.new()
		boar.family = members
		boar.camp_radius = CAMP_RADIUS
		boar.world_half = WORLD_HALF
		boar.position = point
		_world.add_child(boar)
		boars.append(boar)
		boar.died.connect(_on_boar_died)
		return


func _build_camera() -> void:
	_camera = Camera2D.new()
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 6.0
	_camera.limit_left = int(-WORLD_HALF - 200)
	_camera.limit_top = int(-WORLD_HALF - 200)
	_camera.limit_right = int(WORLD_HALF + 200)
	_camera.limit_bottom = int(WORLD_HALF + 200)
	add_child(_camera)
	_camera.make_current()


func _build_hud() -> void:
	_hud = Hud.new()
	add_child(_hud)
	_hud.setup(members)
	_hud.switch_requested.connect(_switch_to)
	_hud.action_pressed.connect(_do_action)
	_hud.eat_pressed.connect(_do_eat)
	_hud.switch_next_pressed.connect(_switch_next)
	GameState.message.connect(_hud.toast)
	GameState.inventory_changed.connect(_hud.update_inventory)
	_hud.update_inventory()


# --- Game loop ------------------------------------------------------------

func _advance_time(delta: float) -> void:
	var previous := time_of_day
	time_of_day = fmod(time_of_day + delta / DAY_LENGTH, 1.0)
	if previous < 0.25 and time_of_day >= 0.25:
		day += 1
		GameState.notify("Day %d. You survived the night!" % day)
	elif previous < 0.75 and time_of_day >= 0.75:
		GameState.notify("Night is coming. Head back to the cave!")

	var night := is_night()
	for boar in boars:
		boar.aggressive = night
	_sky.color = _sky_gradient.sample(time_of_day)
	_light.energy = clampf((1.0 - _sky.color.v) * 1.8, 0.0, 1.0) * 0.8
	_hud.update_day(day, _phase_name(), night)


func is_night() -> bool:
	return time_of_day < 0.2 or time_of_day > 0.8


func _phase_name() -> String:
	if is_night():
		return "Night"
	if time_of_day < 0.3:
		return "Dawn"
	if time_of_day < 0.5:
		return "Morning"
	if time_of_day < 0.7:
		return "Afternoon"
	return "Dusk"


func _read_movement() -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if _hud.joystick.output != Vector2.ZERO:
		direction = _hud.joystick.output
	for member in members:
		member.move_input = direction if member == active and not _retreating else Vector2.ZERO


func _update_camp_flags() -> void:
	for member in members:
		member.in_camp = member.global_position.length() < CAMP_RADIUS


func _update_boar_respawns(delta: float) -> void:
	for i in range(_boar_respawns.size() - 1, -1, -1):
		_boar_respawns[i] -= delta
		if _boar_respawns[i] <= 0.0:
			_boar_respawns.remove_at(i)
			_spawn_boar()


func _check_hunger() -> void:
	for member in members:
		var warned: bool = _hungry_warned.get(member, false)
		if member.hunger < HUNGRY_WARNING and not warned and not member.is_down:
			var how := "tap EAT" if _hud.touch_ui else "press F"
			GameState.notify("%s is getting hungry! Switch to them and %s." % [member.member_name, how])
			_hungry_warned[member] = true
		elif member.hunger > HUNGRY_WARNING + 15.0:
			_hungry_warned[member] = false


# --- Actions --------------------------------------------------------------

## Finds what the active member should act on, in order of urgency: a creature to attack,
## then a knocked-out family member to help up, then the nearest thing to gather.
func _find_target() -> Dictionary:
	if active == null or active.is_down:
		return {}
	var me := active.global_position
	var my_radius := FamilyMember.RADIUS * active.size_scale

	var living_boars := boars.filter(func(boar: Boarcupine) -> bool: return boar.is_alive())
	var boar: Node2D = _nearest_in_range(me, living_boars, func(_node: Node2D) -> float: return Boarcupine.RADIUS + my_radius)
	if boar:
		return {"kind": "boar", "node": boar}

	var downed := members.filter(func(member: FamilyMember) -> bool: return member != active and member.is_down)
	var member: Node2D = _nearest_in_range(me, downed, func(_node: Node2D) -> float: return 30.0)
	if member:
		return {"kind": "revive", "node": member}

	var available := resources.filter(func(resource: ResourceNode) -> bool: return resource.is_available())
	var resource: Node2D = _nearest_in_range(me, available, func(node: Node2D) -> float: return (node as ResourceNode).radius + my_radius)
	if resource:
		return {"kind": "resource", "node": resource}
	return {}


## Returns the node closest to `point` whose edge is within ACTION_RANGE, or null.
## `reach` gives the extra distance covered by each node's size.
func _nearest_in_range(point: Vector2, nodes: Array, reach: Callable) -> Node2D:
	var best: Node2D = null
	var best_gap := ACTION_RANGE
	for node: Node2D in nodes:
		var gap := point.distance_to(node.global_position) - (reach.call(node) as float)
		if gap < best_gap:
			best = node
			best_gap = gap
	return best


func _hint_text() -> String:
	var target := _find_target()
	match target.get("kind", ""):
		"boar":
			var boar: Boarcupine = target.node
			return "Hit the Boarcupine (it's dizzy!)" if boar.is_dizzy() else "Attack the Boarcupine (careful, spikes!)"
		"revive":
			return "Help %s up" % target.node.member_name
		"resource":
			return target.node.action_name(active)
	return ""


func _do_action() -> void:
	if _retreating or active == null or active.is_down or active.action_cooldown > 0.0:
		return
	var target := _find_target()
	if target.is_empty():
		return
	active.action_cooldown = 0.4
	var node: Node2D = target.node
	active.play_attack(active.global_position.direction_to(node.global_position))
	match target.kind:
		"boar":
			(node as Boarcupine).take_hit(active.strength, active)
		"revive":
			var member := node as FamilyMember
			member.revive(member.max_health * 0.3)
			_float_text(member.global_position + Vector2(0, -60), "Back on their feet!", Color(0.6, 1, 0.6))
		"resource":
			var result := (node as ResourceNode).interact(active)
			if result.has("item"):
				GameState.add_item(result.item, result.amount)
				_float_text(node.global_position + Vector2(0, -50),
					"+%d %s" % [result.amount, GameState.ITEM_NAMES[result.item]], Color(1, 0.95, 0.6))
			if result.has("message"):
				GameState.notify(result.message)


func _do_eat() -> void:
	if _retreating or active == null or active.is_down:
		return
	if active.hunger > FamilyMember.MAX_HUNGER - 5.0:
		GameState.notify("%s isn't hungry." % active.member_name)
		return
	var amount := GameState.take_food()
	if amount <= 0.0:
		GameState.notify("No food! Pick berries or hunt a Boarcupine.")
		return
	active.eat(amount)
	_float_text(active.global_position + Vector2(0, -70), "Yum! +%d food" % int(amount), Color(1, 0.75, 0.4))


func _float_text(point: Vector2, text: String, color: Color) -> void:
	var label := FloatingText.new()
	label.text = text
	label.color = color
	label.position = point
	_effects.add_child(label)


# --- Switching and getting knocked out -----------------------------------

func _switch_to(index: int) -> void:
	if _retreating or index < 0 or index >= members.size():
		return
	var member := members[index]
	if member.is_down:
		GameState.notify("%s is knocked out. Help them up first." % member.member_name)
		return
	active = member
	for other in members:
		other.is_active = other == member
		other.leader = null if other == member else member


func _switch_next() -> void:
	var start := members.find(active)
	for step in range(1, members.size()):
		var index := (start + step) % members.size()
		if not members[index].is_down:
			_switch_to(index)
			return


func _on_member_downed(member: FamilyMember) -> void:
	GameState.notify("%s is knocked out!" % member.member_name)
	if member != active:
		return
	for other in members:
		if not other.is_down:
			_switch_to(members.find(other))
			return
	_retreat()


## Everyone is down: fade out and wake up at the cave the next morning, minus some supplies.
func _retreat() -> void:
	_retreating = true
	GameState.notify("The whole family is down...")
	var tween := _hud.fade(1.0, 1.5)
	tween.tween_callback(_finish_retreat)


func _finish_retreat() -> void:
	for i in members.size():
		var member := members[i]
		member.global_position = Vector2(-40 + 80 * i, 100)
		member.revive(member.max_health * 0.5)
		member.hunger = maxf(member.hunger, 40.0)
	GameState.lose_half_supplies()
	if time_of_day > 0.25:
		day += 1
	time_of_day = 0.25
	_retreating = false
	_switch_to(0)
	_hud.fade(0.0, 1.0)
	GameState.notify("You woke up in the cave. Half your supplies were lost.")


func _on_boar_died(boar: Boarcupine) -> void:
	boars.erase(boar)
	GameState.add_item("meat", 3)
	_float_text(boar.global_position + Vector2(0, -50), "+3 Meat", Color(1, 0.7, 0.6))
	_boar_respawns.append(BOAR_RESPAWN_TIME)
