class_name Boarcupine
extends CharacterBody2D
## A spiky boar. It paws the ground, then charges in a straight line.
## Sidestep so it rams into something, then hit it while it's dizzy.
## Hitting it while it isn't dizzy hurts: spikes!

signal died(boar: Boarcupine)

enum State { WANDER, ALERT, CHARGE, DIZZY, DEAD }

const MAX_HEALTH := 4
const RADIUS := 20.0
const WANDER_SPEED := 60.0
const WANDER_RANGE := 260.0
const CHARGE_SPEED := 480.0
const SIGHT_DAY := 230.0
const SIGHT_NIGHT := 340.0
const ALERT_TIME := 0.9
const CHARGE_TIME := 1.3
const DIZZY_AFTER_RAM := 2.4  ## Seconds dizzy after ramming a tree, rock or wall.
const DIZZY_AFTER_CHARGE := 0.9  ## Seconds dizzy after a charge that hit nothing.
const CHARGE_DAMAGE := 22.0
const SPIKE_DAMAGE := 8.0

var family: Array[FamilyMember] = []
var camp_position := Vector2.ZERO
var camp_radius := 170.0
var world_half := 1600.0
var aggressive := false  ## True at night: it spots the family from farther away.
var health := MAX_HEALTH
var state := State.WANDER

var _home := Vector2.ZERO
var _timer := 0.0
var _wander_target := Vector2.ZERO
var _charge_dir := Vector2.RIGHT
var _target: FamilyMember
var _facing := Vector2.RIGHT
var _hurt_flash := 0.0
var _walk_time := 0.0
var _hit_someone := false


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 4
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)
	_home = global_position
	_pick_wander_target()


func is_alive() -> bool:
	return state != State.DEAD


func is_dizzy() -> bool:
	return state == State.DIZZY


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_hurt_flash = maxf(_hurt_flash - delta, 0.0)
	_timer -= delta

	match state:
		State.WANDER:
			_wander(delta)
		State.ALERT:
			velocity = Vector2.ZERO
			if _target and not _target.is_down:
				_facing = global_position.direction_to(_target.global_position)
			if _timer <= 0.0:
				_charge_dir = _facing
				_hit_someone = false
				state = State.CHARGE
				_timer = CHARGE_TIME
		State.CHARGE:
			velocity = _charge_dir * CHARGE_SPEED
		State.DIZZY:
			velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
			if _timer <= 0.0:
				state = State.WANDER
				_timer = 1.0

	move_and_slide()

	if state == State.CHARGE:
		_check_charge_hits()
		if get_slide_collision_count() > 0:
			_become_dizzy(DIZZY_AFTER_RAM)
		elif _timer <= 0.0 or _hit_someone or _near_camp(0.0):
			_become_dizzy(DIZZY_AFTER_CHARGE)
	queue_redraw()


func take_hit(amount: int, attacker: FamilyMember) -> void:
	if state == State.DEAD:
		return
	if state != State.DIZZY:
		attacker.take_hit(SPIKE_DAMAGE, global_position)
		GameState.notify("Ouch, spikes! Dodge its charge, then hit it while it's dizzy.")
	health -= amount
	_hurt_flash = 0.25
	velocity = attacker.global_position.direction_to(global_position) * 250.0
	if health <= 0:
		_die()
	elif state == State.WANDER:
		# Fight back against whoever hit it
		_target = attacker
		state = State.ALERT
		_timer = ALERT_TIME * 0.6


func _wander(delta: float) -> void:
	if _timer <= 0.0:
		var prey := _find_prey()
		if prey:
			_target = prey
			state = State.ALERT
			_timer = ALERT_TIME
			velocity = Vector2.ZERO
			return
	var to_target := _wander_target - global_position
	if to_target.length() < 10.0 or (get_slide_collision_count() > 0 and randf() < 0.05):
		_pick_wander_target()
	velocity = to_target.normalized() * WANDER_SPEED
	if velocity != Vector2.ZERO:
		_facing = velocity.normalized()
	_walk_time += delta


func _find_prey() -> FamilyMember:
	var sight := SIGHT_NIGHT if aggressive else SIGHT_DAY
	var best: FamilyMember = null
	var best_distance := sight
	for member in family:
		if member.is_down or member.in_camp:
			continue
		var distance := global_position.distance_to(member.global_position)
		if distance < best_distance:
			best = member
			best_distance = distance
	return best


func _check_charge_hits() -> void:
	for member in family:
		if member.is_down:
			continue
		if global_position.distance_to(member.global_position) < RADIUS + FamilyMember.RADIUS * member.size_scale + 4.0:
			member.take_hit(CHARGE_DAMAGE, global_position)
			_hit_someone = true
			return


func _become_dizzy(duration: float) -> void:
	state = State.DIZZY
	_timer = duration
	velocity = -_charge_dir * 120.0


func _near_camp(margin: float) -> bool:
	return global_position.distance_to(camp_position) < camp_radius + margin


func _pick_wander_target() -> void:
	for attempt in 10:
		var point := _home + Vector2.from_angle(randf() * TAU) * randf_range(60.0, WANDER_RANGE)
		var limit := world_half - 80.0
		if absf(point.x) > limit or absf(point.y) > limit:
			continue
		if point.distance_to(camp_position) < camp_radius + 80.0:
			continue
		_wander_target = point
		return
	_wander_target = _home


func _die() -> void:
	state = State.DEAD
	collision_layer = 0
	died.emit(self)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	tween.tween_callback(queue_free)


func _draw() -> void:
	var flip := -1.0 if _facing.x < 0.0 else 1.0
	var shake := Vector2(sin(Time.get_ticks_msec() * 0.06) * 2.0, 0) if state == State.ALERT else Vector2.ZERO
	var body_color := Color(1, 0.5, 0.45) if _hurt_flash > 0.0 else Color(0.48, 0.33, 0.22)
	var step := sin(_walk_time * 10.0) * 3.0

	DrawUtil.shadow(self, 26.0, 9.0)
	var lying := state == State.DEAD

	# Legs
	if not lying:
		for x in [-12.0, 12.0]:
			draw_line(_p(Vector2(x, -10), flip) + shake, _p(Vector2(x + step, 0), flip) + shake, body_color.darkened(0.3), 5.0)

	# Spikes along the back
	for i in 7:
		var base := Vector2(-16.0 + i * 5.0, -24.0 + absf(i - 3.0) * 1.5)
		var tip := base + Vector2(-6.0, -14.0 + absf(i - 3.0) * 2.0)
		draw_line(_p(base, flip) + shake, _p(tip, flip) + shake, Color(0.92, 0.88, 0.75), 3.0)

	# Body and head
	var body_points := DrawUtil.ellipse(Vector2(0, -18), 24.0, 13.0)
	for i in body_points.size():
		body_points[i] = _p(body_points[i], flip) + shake
	draw_colored_polygon(body_points, body_color)
	draw_circle(_p(Vector2(20, -18), flip) + shake, 10.0, body_color.lightened(0.05))
	draw_circle(_p(Vector2(29, -15), flip) + shake, 5.0, Color(0.85, 0.6, 0.55))  # snout
	draw_line(_p(Vector2(26, -11), flip) + shake, _p(Vector2(31, -19), flip) + shake, Color(1, 0.97, 0.88), 2.5)  # tusk
	var eye_color := Color(0.9, 0.2, 0.15) if state in [State.ALERT, State.CHARGE] else Color(0.08, 0.05, 0.03)
	draw_circle(_p(Vector2(22, -22), flip) + shake, 2.0, eye_color)

	match state:
		State.ALERT:
			DrawUtil.label(self, Vector2(0, -50), "!", 30, Color(1, 0.3, 0.2))
		State.DIZZY:
			var t := Time.get_ticks_msec() / 1000.0
			for i in 3:
				var angle := t * 4.0 + i * TAU / 3.0
				DrawUtil.label(self, Vector2(cos(angle) * 18.0, -46.0 + sin(angle) * 5.0), "*", 22, Color(1, 0.95, 0.4))


## Mirrors a point horizontally so the boar faces the way it is moving.
func _p(point: Vector2, flip: float) -> Vector2:
	return Vector2(point.x * flip, point.y)
