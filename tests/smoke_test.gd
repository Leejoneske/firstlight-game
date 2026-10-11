extends Node
## Automated smoke test for the first playable build. Runs the real main scene and
## checks gathering, talents, switching, eating, hunting and the knockout retreat.
##
## Run headless:  godot --headless --path . res://tests/smoke_test.tscn
## Exits with code 0 when everything passes, 1 otherwise.

var _main: Node3D
var _failures := 0


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await _frames(5)
	await _run()
	print("SMOKE TEST: %s" % ("PASSED" if _failures == 0 else "FAILED (%d)" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)


func _run() -> void:
	var krag: FamilyMember = _main.members[0]
	var zee: FamilyMember = _main.members[1]
	_check(_main.members.size() == 2, "two family members spawn")
	_check(_main.active == krag, "Krag starts as the active member")
	_check(_main.resources.size() > 80, "resources spawn (%d)" % _main.resources.size())
	_check(_main.boars.size() == 8, "eight Boarcupines spawn")

	# Keep the boars out of the way until the hunting test
	for boar: Boarcupine in _main.boars:
		boar.global_position = Vector3(-50, 30, 50)

	# Gathering berries
	var bush := _find_resource(ResourceNode.Kind.BERRY_BUSH)
	_stand_next_to(krag, bush)
	await _frames(2)
	_main._do_action()
	_check(GameState.inventory.berries == 2, "picking a bush gives 2 berries")

	# Switching
	_main._switch_to(1)
	_check(_main.active == zee and zee.is_active and not krag.is_active, "switching makes Zee active")
	_check(krag.leader == zee, "Krag follows Zee after switching")

	# Talents: Zee can't smash the grove boulder, Krag can
	var gate: ResourceNode = null
	for resource: ResourceNode in _main.resources:
		if resource.is_gate:
			gate = resource
	_stand_next_to(zee, gate)
	await _frames(2)
	zee.action_cooldown = 0.0
	_main._do_action()
	_check(GameState.inventory.stones == 0 and is_instance_valid(gate), "Zee is too weak to smash the boulder")
	_main._switch_to(0)
	_stand_next_to(krag, gate)
	await _frames(2)
	krag.action_cooldown = 0.0
	_main._do_action()
	await _frames(2)
	_check(GameState.inventory.stones == 5, "Krag smashes the boulder for 5 stones")
	_check(not is_instance_valid(gate) or not _main.resources.has(gate), "the grove gate is gone")

	# Talents: only Zee climbs tall trees
	var tall := _find_resource(ResourceNode.Kind.TALL_TREE)
	_stand_next_to(krag, tall)
	await _frames(2)
	krag.action_cooldown = 0.0
	_main._do_action()
	_check(GameState.inventory.fruit == 0, "Krag can't climb tall trees")
	_main._switch_to(1)
	_stand_next_to(zee, tall)
	await _frames(2)
	zee.action_cooldown = 0.0
	_main._do_action()
	_check(GameState.inventory.fruit == 2, "Zee climbs for 2 fruit")

	# Eating takes the most filling food first
	zee.hunger = 50.0
	_main._do_eat()
	_check(is_equal_approx(zee.hunger, 75.0) and GameState.inventory.fruit == 1, "eating fruit restores 25 hunger")

	# Hunting: hitting a calm Boarcupine hurts, hitting a dizzy one is safe
	var boar: Boarcupine = _main.boars[0]
	boar.global_position = zee.global_position + Vector3(1.2, 0.1, 0)
	await _frames(1)
	var health_before := zee.health
	zee.action_cooldown = 0.0
	boar.state = Boarcupine.State.WANDER
	_main._do_action()
	_check(zee.health < health_before, "spikes hurt when the boar isn't dizzy")
	var hits := 0
	while boar.is_alive() and hits < 10:
		boar.state = Boarcupine.State.DIZZY
		boar.set("_timer", 5.0)
		boar.global_position = zee.global_position + Vector3(1.2, 0.1, 0)
		zee.action_cooldown = 0.0
		zee.set("_invulnerable", 0.0)
		_main._do_action()
		hits += 1
		await _frames(1)
	_check(not boar.is_alive(), "the boar goes down after %d hits" % hits)
	_check(GameState.inventory.meat == 3, "hunting gives 3 meat")

	# A knocked-out member wakes up when helped
	krag.revive(krag.max_health)
	krag.set("_invulnerable", 0.0)
	krag.take_hit(1000.0, krag.global_position + Vector3(1, 0, 0))
	_check(krag.is_down, "Krag can be knocked out")
	_stand_next_to(zee, krag)
	await _frames(2)
	zee.action_cooldown = 0.0
	_main._do_action()
	_check(not krag.is_down, "Zee helps Krag back up")

	# Whole family down: retreat to the cave next morning
	var day_before: int = _main.day
	for member: FamilyMember in _main.members:
		member.set("_invulnerable", 0.0)
		member.take_hit(1000.0, member.global_position + Vector3(1, 0, 0))
	_check(_main._retreating, "the family retreats when everyone is down")
	await get_tree().create_timer(2.5).timeout
	_check(not _main._retreating, "the retreat finishes")
	_check(not krag.is_down and not zee.is_down, "everyone wakes up")
	_check(Vector2(krag.global_position.x, krag.global_position.z).length() < 6.0, "the family wakes at the cave")
	_check(_main.day == day_before + 1, "a new day starts after the retreat")

	# Camera views: first person hides the active member's body
	_main._switch_to(1)
	_main._rig.set_mode(CameraRig.Mode.FIRST_PERSON)
	_main._apply_camera_mode()
	await _frames(4)
	_check(not zee.get("_model").visible and krag.get("_model").visible, "first person hides only the active body")
	var eye := zee.global_position.y + zee.eye_height()
	_check(absf(_main._rig.camera.global_position.y - eye) < 0.3, "first-person camera sits at eye height")
	_main._rig.set_mode(CameraRig.Mode.OVERVIEW)
	_main._apply_camera_mode()
	await _frames(30)
	_check(zee.get("_model").visible, "overview shows the body again")
	_check(_main._rig.camera.global_position.y > zee.global_position.y + 10.0, "overview camera is high above")
	_main._rig.set_mode(CameraRig.Mode.THIRD_PERSON)
	_main._apply_camera_mode()

	# Walking: the active member moves where the camera faces
	var start := zee.global_position
	Input.action_press("move_up")
	await get_tree().create_timer(0.6).timeout
	Input.action_release("move_up")
	var moved := zee.global_position - start
	moved.y = 0.0
	_check(moved.length() > 1.5 and moved.normalized().dot(_main._rig.forward()) > 0.8, "pressing forward walks where the camera looks")
	_check(zee.is_on_floor(), "Zee stands on the ground")

	# Hunger drains over time
	var hunger_before := zee.hunger
	zee.in_camp = false
	await get_tree().create_timer(1.0).timeout
	_check(zee.hunger < hunger_before, "hunger drains over time")


func _find_resource(kind: ResourceNode.Kind) -> ResourceNode:
	for resource: ResourceNode in _main.resources:
		if resource.kind == kind and resource.is_available() and not resource.is_gate:
			return resource
	return null


func _stand_next_to(member: FamilyMember, target: Node3D) -> void:
	var gap := 0.4
	if target is ResourceNode:
		gap += (target as ResourceNode).radius
	var spot := target.global_position + Vector3(gap + FamilyMember.RADIUS * member.size_scale, 0, 0)
	spot.y = _main._terrain.height_at(spot.x, spot.z) + 0.05
	member.global_position = spot
	member.velocity = Vector3.ZERO
	member.facing = Vector3.LEFT


func _check(condition: bool, description: String) -> void:
	if condition:
		print("  ok   - " + description)
	else:
		_failures += 1
		print("  FAIL - " + description)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
