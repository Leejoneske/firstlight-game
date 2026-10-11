extends Node3D
## Builds the first test land (the Cracked Badlands) in 3D and runs the game loop:
## family switching, gathering, hunger, day and night, the Boarcupines and the camera views.

const WORLD_HALF := 60.0  ## Half the width of the play area, in metres.
const CAMP_RADIUS := 7.0
const DAY_LENGTH := 720.0  ## Seconds for a full day and night (12 minutes).
const START_TIME := 0.3  ## 0 = midnight, 0.25 = dawn, 0.5 = noon, 0.75 = dusk.
const BOAR_COUNT := 8
const BOAR_RESPAWN_TIME := 45.0
const ACTION_RANGE := 1.3  ## Largest gap (metres) between a member and something they can use.
const HUNGRY_WARNING := 25.0
const GROVE_RECT := Rect2(25, -60, 35, 35)  ## x, z, width, depth
const GROVE_GATE := Vector2(25, -42)
const ITEM_COLORS := {
	"berries": Color(0.85, 0.12, 0.2), "fruit": Color(0.98, 0.6, 0.16), "meat": Color(0.8, 0.35, 0.3),
	"sticks": Color(0.5, 0.34, 0.2), "stones": Color(0.6, 0.58, 0.55),
}

var members: Array[FamilyMember] = []
var boars: Array[Boarcupine] = []
var resources: Array[ResourceNode] = []
var active: FamilyMember
var time_of_day := START_TIME
var day := 1

var _rng := RandomNumberGenerator.new()
var _terrain: Terrain
var _scenery: Scenery
var _rig: CameraRig
var _hud: Hud
var _environment: Environment
var _sky_material: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _moon: DirectionalLight3D
var _glow: OmniLight3D
var _boar_respawns: Array[float] = []
var _retreating := false
var _hungry_warned := {}
var _lighting_timer := 0.0
var _palette := {}  ## Gradients for sky and light colours over the day.


func _ready() -> void:
	_rng.randomize()
	_build_environment()
	_build_world()
	_spawn_family()
	_spawn_resources()
	_scenery.build_ground_cover()
	for i in BOAR_COUNT:
		_spawn_boar()
	_rig = CameraRig.new()
	add_child(_rig)
	_build_hud()
	_switch_to(0)
	_apply_camera_mode()
	_advance_time(0.0)
	GameState.settings_changed.connect(_apply_settings)
	_apply_settings()
	if GameState.skip_title:
		_start_game()
	else:
		# Show the title over a slowly turning view of the badlands
		get_tree().paused = true
		_rig.showcase = true
		_hud.show_title()


func _start_game() -> void:
	get_tree().paused = false
	_rig.showcase = false
	_rig.set_mode(_rig.mode)
	GameState.notify("The ground keeps shaking... Gather food before nightfall!")


func _on_pause_toggled(paused: bool) -> void:
	get_tree().paused = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _restart() -> void:
	get_tree().paused = false
	GameState.skip_title = true
	GameState.reset_run()
	get_tree().reload_current_scene()


## Applies saved settings. Lower graphics drop shadows and grass and render at a lower
## resolution, which runs much more smoothly on older phones.
func _apply_settings() -> void:
	_sun.shadow_enabled = GameState.high_graphics
	_scenery.set_ground_cover_visible(GameState.high_graphics)
	# Phones have very high-resolution screens; drawing the 3D view at a lower resolution
	# (the interface stays sharp) is the biggest speed-up there is.
	var phone := OS.has_feature("mobile")
	if GameState.high_graphics:
		get_viewport().scaling_3d_scale = 0.75 if phone else 1.0
	else:
		get_viewport().scaling_3d_scale = 0.55 if phone else 0.7
	_sun.directional_shadow_max_distance = 30.0 if phone else 50.0


func _process(delta: float) -> void:
	if not _retreating:
		_advance_time(delta)
	_rig.rotate_by_pixels(_hud.look_pad.take_delta(), _rig.touch_sensitivity * GameState.look_sensitivity)
	_read_movement()
	_update_camp_flags()
	_update_boar_respawns(delta)
	_check_hunger()
	if active:
		_glow.global_position = active.global_position + Vector3.UP * 2.2
		_update_compass()
	_hud.show_hint(_hint_text())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
		_rig.rotate_by_pixels((event as InputEventMouseMotion).relative, _rig.mouse_sensitivity * GameState.look_sensitivity)
		return
	if event is InputEventMouseButton and event.pressed:
		var button := event as InputEventMouseButton
		match button.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_rig.zoom(-0.6)
			MOUSE_BUTTON_WHEEL_DOWN:
				_rig.zoom(0.6)
			MOUSE_BUTTON_LEFT:
				if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
					_do_action()
				elif not _hud.touch_ui and _rig.mode != CameraRig.Mode.OVERVIEW and button.device != InputEvent.DEVICE_ID_EMULATION:
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return

	if event.is_action_pressed("toggle_touch_ui"):
		_hud.toggle_touch_ui()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event.is_action_pressed("camera_mode"):
		_cycle_camera()
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

func _build_environment() -> void:
	_palette = {
		"sky_top": _gradient([Color(0.04, 0.05, 0.12), Color(0.04, 0.05, 0.12), Color(0.35, 0.45, 0.7), Color(0.3, 0.5, 0.85), Color(0.3, 0.5, 0.85), Color(0.35, 0.35, 0.6), Color(0.04, 0.05, 0.12), Color(0.04, 0.05, 0.12)]),
		"sky_horizon": _gradient([Color(0.1, 0.1, 0.2), Color(0.1, 0.1, 0.2), Color(0.98, 0.65, 0.45), Color(0.8, 0.85, 0.9), Color(0.8, 0.85, 0.9), Color(0.98, 0.55, 0.35), Color(0.1, 0.1, 0.2), Color(0.1, 0.1, 0.2)]),
		"sun": _gradient([Color(1, 0.6, 0.4), Color(1, 0.6, 0.4), Color(1, 0.7, 0.5), Color(1, 0.96, 0.88), Color(1, 0.96, 0.88), Color(1, 0.65, 0.4), Color(1, 0.6, 0.4), Color(1, 0.6, 0.4)]),
		"ambient": _gradient([Color(0.16, 0.18, 0.32), Color(0.16, 0.18, 0.32), Color(0.6, 0.5, 0.5), Color(0.62, 0.62, 0.66), Color(0.62, 0.62, 0.66), Color(0.6, 0.48, 0.45), Color(0.16, 0.18, 0.32), Color(0.16, 0.18, 0.32)]),
	}
	_sky_material = ProceduralSkyMaterial.new()
	_sky_material.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = _sky_material
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.fog_enabled = true
	_environment.fog_density = 0.0018
	_environment.fog_sky_affect = 0.3
	var world_environment := WorldEnvironment.new()
	world_environment.environment = _environment
	add_child(world_environment)

	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL  # One shadow map: cheapest
	_sun.directional_shadow_max_distance = 50.0
	add_child(_sun)
	_moon = DirectionalLight3D.new()
	_moon.light_color = Color(0.6, 0.7, 1.0)
	_moon.rotation = Vector3(-0.9, 0.6, 0)
	add_child(_moon)
	# A soft glow around the active member so the night isn't pitch black
	_glow = OmniLight3D.new()
	_glow.light_color = Color(1, 0.85, 0.65)
	_glow.omni_range = 9.0
	add_child(_glow)


func _gradient(colors: Array) -> Gradient:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.18, 0.26, 0.35, 0.65, 0.74, 0.82, 1.0])
	gradient.colors = PackedColorArray(colors)
	return gradient


func _build_world() -> void:
	_terrain = Terrain.new()
	_terrain.half_size = WORLD_HALF
	_terrain.grove_rect = GROVE_RECT
	_terrain.flat_spots = [Vector3(0, 0, CAMP_RADIUS + 2.0), Vector3(GROVE_GATE.x, GROVE_GATE.y, 5.0),
		Vector3(Scenery.POND_CENTER.x, Scenery.POND_CENTER.y, Scenery.POND_RADIUS + 1.5)]
	add_child(_terrain)
	_terrain.build(_rng.randi())
	_scenery = Scenery.new()
	_scenery.terrain = _terrain
	_scenery.half_size = WORLD_HALF
	_scenery.is_free = _is_open_ground
	add_child(_scenery)
	_scenery.build_landmarks(_rng.randi())

	# A ridge closes off the hidden grove. Its only way in is blocked by a boulder.
	var gx := GROVE_RECT.position.x
	_add_wall(Vector2(gx, -WORLD_HALF - 2.0), Vector2(gx, GROVE_GATE.y - 1.5))
	_add_wall(Vector2(gx, GROVE_GATE.y + 1.5), Vector2(gx, GROVE_RECT.end.y))
	_add_wall(Vector2(gx, GROVE_RECT.end.y), Vector2(WORLD_HALF + 2.0, GROVE_RECT.end.y))

	var camp := Camp.new()
	camp.radius = CAMP_RADIUS
	add_child(camp)


func _add_wall(from: Vector2, to: Vector2) -> void:
	var wall := RockWall.new()
	wall.from = from
	wall.to = to
	wall.terrain = _terrain
	add_child(wall)


func _spawn_family() -> void:
	var krag := FamilyMember.new()
	krag.member_name = "Krag"
	krag.talent = "Strong: smashes boulders, hits hard"
	krag.max_health = 130.0
	krag.move_speed = 4.6
	krag.strength = 2
	krag.hunger_rate = 0.3
	krag.size_scale = 1.15
	krag.skin_color = Color(0.78, 0.58, 0.43)
	krag.fur_color = Color(0.5, 0.33, 0.2)
	krag.hair_color = Color(0.15, 0.1, 0.07)
	krag.follow_side = -1.0
	krag.bulk = 1.3
	krag.hair_style = "beard"
	krag.eye_color = Color(0.3, 0.2, 0.1)

	var zee := FamilyMember.new()
	zee.member_name = "Zee"
	zee.talent = "Scout: fastest, climbs tall trees"
	zee.max_health = 85.0
	zee.move_speed = 6.5
	zee.strength = 1
	zee.can_climb = true
	zee.hunger_rate = 0.36
	zee.size_scale = 0.92
	zee.skin_color = Color(0.86, 0.66, 0.5)
	zee.fur_color = Color(0.78, 0.58, 0.32)
	zee.hair_color = Color(0.85, 0.38, 0.15)
	zee.follow_side = 1.0
	zee.bulk = 0.9
	zee.hair_style = "mane"
	zee.eye_color = Color(0.25, 0.5, 0.3)

	for i in 2:
		var member: FamilyMember = [krag, zee][i]
		member.position = _ground(Vector2(-1.2 + 2.4 * i, 4.0))
		member.facing = Vector3.BACK
		add_child(member)
		members.append(member)
		member.downed.connect(_on_member_downed.bind(member))
		member.hurt.connect(func() -> void:
			if member == active:
				_rig.shake(0.35))


func _spawn_resources() -> void:
	var gate := _add_resource(ResourceNode.Kind.BOULDER, GROVE_GATE)
	gate.is_gate = true
	var outside := {
		ResourceNode.Kind.BERRY_BUSH: 40,
		ResourceNode.Kind.TREE: 55,
		ResourceNode.Kind.ROCK: 35,
		ResourceNode.Kind.BOULDER: 10,
		ResourceNode.Kind.TALL_TREE: 9,
	}
	for kind: ResourceNode.Kind in outside:
		for i in outside[kind]:
			var point := _random_point(false)
			if point != Vector2.INF:
				_add_resource(kind, point)
	# The hidden grove is rich in food
	var grove := {ResourceNode.Kind.BERRY_BUSH: 16, ResourceNode.Kind.TALL_TREE: 7, ResourceNode.Kind.TREE: 6}
	for kind: ResourceNode.Kind in grove:
		for i in grove[kind]:
			var point := _random_point(true)
			if point != Vector2.INF:
				_add_resource(kind, point)


func _add_resource(kind: ResourceNode.Kind, point: Vector2) -> ResourceNode:
	var resource := ResourceNode.new()
	resource.kind = kind
	resource.position = _ground(point)
	add_child(resource)
	resources.append(resource)
	resource.tree_exiting.connect(func() -> void: resources.erase(resource))
	return resource


## A point on the ground at (x, z).
func _ground(point: Vector2) -> Vector3:
	return Vector3(point.x, _terrain.height_at(point.x, point.y), point.y)


## Finds a free spot (x, z) for something new, in the open badlands or inside the grove.
## Returns Vector2.INF if no spot was found.
func _random_point(in_grove: bool) -> Vector2:
	var margin := 3.0
	for attempt in 40:
		var point: Vector2
		if in_grove:
			point = Vector2(_rng.randf_range(GROVE_RECT.position.x + margin, GROVE_RECT.end.x - margin),
				_rng.randf_range(GROVE_RECT.position.y + margin, GROVE_RECT.end.y - margin))
		else:
			var limit := WORLD_HALF - 6.0
			point = Vector2(_rng.randf_range(-limit, limit), _rng.randf_range(-limit, limit))
			if GROVE_RECT.grow(2.5).has_point(point) or point.length() < CAMP_RADIUS + 3.0:
				continue
			if point.distance_to(GROVE_GATE) < 7.0:
				continue
		if _is_clear(point, 2.2):
			return point
	return Vector2.INF


func _is_clear(point: Vector2, min_distance: float) -> bool:
	if _scenery.blocks(point, min_distance * 0.5):
		return false
	for resource in resources:
		if Vector2(resource.position.x, resource.position.z).distance_to(point) < min_distance + resource.radius:
			return false
	return true


## True if a spot is away from the camp, the grove entrance and anything gatherable.
## Used to keep decorations out of the way.
func _is_open_ground(point: Vector2, radius: float) -> bool:
	if point.length() < CAMP_RADIUS + 1.0 + radius or point.distance_to(GROVE_GATE) < 5.0 + radius:
		return false
	for resource in resources:
		if Vector2(resource.position.x, resource.position.z).distance_to(point) < resource.radius + radius:
			return false
	return true


func _spawn_boar() -> void:
	for attempt in 20:
		var point := _random_point(false)
		if point == Vector2.INF:
			continue
		if active and _flat_distance(_ground(point), active.global_position) < 25.0:
			continue
		var boar := Boarcupine.new()
		boar.family = members
		boar.camp_radius = CAMP_RADIUS
		boar.world_half = WORLD_HALF
		boar.position = _ground(point) + Vector3.UP * 0.2
		add_child(boar)
		boars.append(boar)
		boar.died.connect(_on_boar_died)
		return


func _build_hud() -> void:
	_hud = Hud.new()
	add_child(_hud)
	_hud.setup(members)
	_hud.switch_requested.connect(_switch_to)
	_hud.action_pressed.connect(_do_action)
	_hud.eat_pressed.connect(_do_eat)
	_hud.switch_next_pressed.connect(_switch_next)
	_hud.view_pressed.connect(_cycle_camera)
	_hud.start_pressed.connect(_start_game)
	_hud.pause_toggled.connect(_on_pause_toggled)
	_hud.restart_pressed.connect(_restart)
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

	# Light changes slowly, so it's updated a few times a second rather than every frame
	_lighting_timer -= delta
	if _lighting_timer > 0.0 and delta > 0.0:
		return
	_lighting_timer = 0.25
	var night := is_night()
	for boar in boars:
		boar.aggressive = night
	_update_lighting()
	_hud.update_day(day, _phase_name(), time_of_day)


## Moves the sun across the sky and tints the sky, light and fog for the time of day.
func _update_lighting() -> void:
	var t := time_of_day
	var elevation := (t - 0.25) * TAU  # 0 at dawn, PI/2 at noon, PI at dusk
	var daylight := clampf(sin(elevation) * 3.0, 0.0, 1.0)
	_sun.rotation = Vector3(-elevation, 0.5, 0.0)
	_sun.light_energy = daylight * 0.78
	_sun.light_color = _palette.sun.sample(t)
	_sun.visible = daylight > 0.0
	var darkness := 1.0 - daylight
	_moon.light_energy = darkness * 0.35
	_moon.visible = darkness > 0.0
	_glow.light_energy = darkness * 1.4
	_glow.visible = darkness > 0.05  # A light costs extra drawing work, so only use it at night
	_scenery.set_darkness(darkness)
	_sky_material.sky_top_color = _palette.sky_top.sample(t)
	_sky_material.sky_horizon_color = _palette.sky_horizon.sample(t)
	_sky_material.ground_horizon_color = _palette.sky_horizon.sample(t).darkened(0.2)
	_sky_material.ground_bottom_color = _palette.sky_top.sample(t).darkened(0.4)
	_environment.ambient_light_color = _palette.ambient.sample(t)
	_environment.ambient_light_energy = 0.42 + daylight * 0.1
	_environment.fog_light_color = _palette.sky_horizon.sample(t)


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
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if _hud.joystick.output != Vector2.ZERO:
		input = _hud.joystick.output
	var direction := _rig.right() * input.x - _rig.forward() * input.y
	var first_person := _rig.mode == CameraRig.Mode.FIRST_PERSON
	for member in members:
		var controlled := member == active and not _retreating
		member.move_input = direction if controlled else Vector3.ZERO
		member.look_direction = _rig.forward() if controlled and first_person else Vector3.ZERO


func _update_camp_flags() -> void:
	for member in members:
		member.in_camp = _flat_distance(member.global_position, Vector3.ZERO) < CAMP_RADIUS


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


## Points the compass at the cave and the far peak.
func _update_compass() -> void:
	var me := active.global_position
	var markers: Array[Dictionary] = [
		{"angle": _bearing(Vector3.ZERO - me), "icon": "home", "distance": _flat_distance(me, Vector3.ZERO)},
		{"angle": _bearing(Scenery.FIRSTLIGHT_POSITION - me), "icon": "star"},
	]
	_hud.compass.update(_bearing(_rig.forward()), markers)


## Compass angle of a direction: 0 = north (-Z), clockwise.
func _bearing(direction: Vector3) -> float:
	return atan2(direction.x, -direction.z)


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# --- Camera ---------------------------------------------------------------

func _cycle_camera() -> void:
	if get_tree().paused:
		return
	_rig.cycle_mode()
	_apply_camera_mode()
	GameState.notify(CameraRig.MODE_NAMES[_rig.mode])


func _apply_camera_mode() -> void:
	var first_person := _rig.mode == CameraRig.Mode.FIRST_PERSON
	for member in members:
		member.set_first_person(first_person and member == active)
	_hud.set_crosshair(first_person)
	if _rig.mode == CameraRig.Mode.OVERVIEW:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# --- Actions --------------------------------------------------------------

## Finds what the active member should act on, in order of urgency: a creature to attack,
## then a knocked-out family member to help up, then something to gather.
## Things in front of the member are preferred, so in first person you act on what you look at.
func _find_target() -> Dictionary:
	if active == null or active.is_down:
		return {}
	var my_radius := FamilyMember.RADIUS * active.size_scale

	var living_boars := boars.filter(func(boar: Boarcupine) -> bool: return boar.is_alive())
	var boar: Node3D = _nearest_in_range(living_boars, func(_node: Node3D) -> float: return Boarcupine.RADIUS + my_radius)
	if boar:
		return {"kind": "boar", "node": boar}

	var downed := members.filter(func(member: FamilyMember) -> bool: return member != active and member.is_down)
	var member: Node3D = _nearest_in_range(downed, func(_node: Node3D) -> float: return 0.9)
	if member:
		return {"kind": "revive", "node": member}

	var available := resources.filter(func(resource: ResourceNode) -> bool: return resource.is_available())
	var resource: Node3D = _nearest_in_range(available, func(node: Node3D) -> float: return (node as ResourceNode).radius + my_radius)
	if resource:
		return {"kind": "resource", "node": resource}
	return {}


## Returns the best node within ACTION_RANGE of the active member, or null.
## `reach` gives the extra distance covered by each node's size.
func _nearest_in_range(nodes: Array, reach: Callable) -> Node3D:
	var best: Node3D = null
	var best_score := INF
	var me := active.global_position
	var facing_weight := 1.5 if _rig.mode == CameraRig.Mode.FIRST_PERSON else 0.5
	for node: Node3D in nodes:
		var offset := node.global_position - me
		offset.y = 0.0
		var gap := offset.length() - (reach.call(node) as float)
		if gap > ACTION_RANGE:
			continue
		var in_front := active.facing.dot(offset.normalized()) if offset.length() > 0.01 else 1.0
		var score := gap + (1.0 - in_front) * facing_weight
		if score < best_score:
			best = node
			best_score = score
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
	if get_tree().paused or _retreating or active == null or active.is_down or active.action_cooldown > 0.0:
		return
	var target := _find_target()
	if target.is_empty():
		return
	active.action_cooldown = 0.4
	var node: Node3D = target.node
	active.play_attack(node.global_position - active.global_position)
	match target.kind:
		"boar":
			(node as Boarcupine).take_hit(active.strength, active)
			Effects.burst(self, node.global_position + Vector3.UP * 0.8, Color(0.95, 0.9, 0.75), 6, 2.5)
		"revive":
			var member := node as FamilyMember
			member.revive(member.max_health * 0.3)
			_float_text(member.global_position + Vector3.UP * 2.0, "Back on their feet!", Color(0.6, 1, 0.6))
		"resource":
			var result := (node as ResourceNode).interact(active)
			if result.has("item"):
				GameState.add_item(result.item, result.amount)
				Effects.burst(self, node.global_position + Vector3.UP * 1.0, ITEM_COLORS.get(result.item, Color.WHITE))
				_float_text(node.global_position + Vector3.UP * 1.8,
					"+%d %s" % [result.amount, GameState.ITEM_NAMES[result.item]], Color(1, 0.95, 0.6))
			if result.has("message"):
				GameState.notify(result.message)


func _do_eat() -> void:
	if get_tree().paused or _retreating or active == null or active.is_down:
		return
	if active.hunger > FamilyMember.MAX_HUNGER - 5.0:
		GameState.notify("%s isn't hungry." % active.member_name)
		return
	var amount := GameState.take_food()
	if amount <= 0.0:
		GameState.notify("No food! Pick berries or hunt a Boarcupine.")
		return
	active.eat(amount)
	_float_text(active.global_position + Vector3.UP * 2.3, "Yum! +%d food" % int(amount), Color(1, 0.75, 0.4))


func _float_text(point: Vector3, text: String, color: Color) -> void:
	var label := FloatingText.new()
	label.text = text
	label.modulate = color
	label.position = point
	add_child(label)


# --- Switching and getting knocked out -----------------------------------

func _switch_to(index: int) -> void:
	if (get_tree().paused and active != null) or _retreating or index < 0 or index >= members.size():
		return
	var member := members[index]
	if member.is_down:
		GameState.notify("%s is knocked out. Help them up first." % member.member_name)
		return
	active = member
	for other in members:
		other.is_active = other == member
		other.leader = null if other == member else member
	_rig.target = member
	_rig.snap()
	_apply_camera_mode()


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
		member.global_position = _ground(Vector2(-1.2 + 2.4 * i, 4.0)) + Vector3.UP * 0.2
		member.velocity = Vector3.ZERO
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
	_float_text(boar.global_position + Vector3.UP * 1.8, "+3 Meat", Color(1, 0.7, 0.6))
	_boar_respawns.append(BOAR_RESPAWN_TIME)
