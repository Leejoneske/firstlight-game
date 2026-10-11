extends Node
## Automated smoke test for the first playable build. Runs the real main scene and
## checks gathering, talents, switching, eating, hunting and the knockout retreat.
##
## Run headless:  godot --headless --path . res://tests/smoke_test.tscn
## Exits with code 0 when everything passes, 1 otherwise.

var _main: Node2D
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
	_check(_main.boars.size() == 6, "six Boarcupines spawn")

	# Keep the boars out of the way until the hunting test
	for boar: Boarcupine in _main.boars:
		boar.global_position = Vector2(-1450, 1450)

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
	boar.global_position = zee.global_position + Vector2(50, 0)
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
		boar.global_position = zee.global_position + Vector2(50, 0)
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
	krag.take_hit(1000.0, krag.global_position + Vector2(10, 0))
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
		member.take_hit(1000.0, member.global_position + Vector2(10, 0))
	_check(_main._retreating, "the family retreats when everyone is down")
	await get_tree().create_timer(2.5).timeout
	_check(not _main._retreating, "the retreat finishes")
	_check(not krag.is_down and not zee.is_down, "everyone wakes up")
	_check(krag.global_position.length() < 200.0, "the family wakes at the cave")
	_check(_main.day == day_before + 1, "a new day starts after the retreat")

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


func _stand_next_to(member: FamilyMember, target: Node2D) -> void:
	var gap := 20.0
	if target is ResourceNode:
		gap += (target as ResourceNode).radius
	member.global_position = target.global_position + Vector2(-gap - FamilyMember.RADIUS * member.size_scale, 0)
	member.velocity = Vector2.ZERO


func _check(condition: bool, description: String) -> void:
	if condition:
		print("  ok   - " + description)
	else:
		_failures += 1
		print("  FAIL - " + description)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
