class_name FamilyMember
extends CharacterBody2D
## A family member. The player controls one at a time; the others follow the leader.

signal downed

const MAX_HUNGER := 100.0
const RADIUS := 16.0
const STARVE_DAMAGE := 1.5  ## Health lost per second while hunger is empty.
const CAMP_HEAL := 2.0  ## Health gained per second while resting at camp.
const CAMP_WAKE_RATIO := 0.4  ## A knocked-out member at camp wakes up at this share of health.

@export var member_name := "Member"
@export var talent := ""
@export var skin_color := Color(0.87, 0.67, 0.5)
@export var fur_color := Color(0.6, 0.4, 0.2)
@export var hair_color := Color(0.2, 0.12, 0.08)
@export var max_health := 100.0
@export var move_speed := 220.0
@export var strength := 1  ## Damage per hit. 2 or more can smash boulders.
@export var can_climb := false
@export var hunger_rate := 0.4  ## Hunger lost per second.
@export var size_scale := 1.0

var health := 0.0
var hunger := MAX_HUNGER
var is_active := false
var is_down := false
var in_camp := false
var leader: FamilyMember  ## Who to follow when not controlled.
var follow_offset := Vector2.ZERO
var move_input := Vector2.ZERO
var facing := Vector2.RIGHT
var action_cooldown := 0.0

var _knockback := Vector2.ZERO
var _hurt_flash := 0.0
var _invulnerable := 0.0
var _walk_time := 0.0
var _attack_anim := 0.0


func _ready() -> void:
	health = max_health
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS * size_scale
	shape.shape = circle
	add_child(shape)


func _physics_process(delta: float) -> void:
	action_cooldown = maxf(action_cooldown - delta, 0.0)
	_hurt_flash = maxf(_hurt_flash - delta, 0.0)
	_invulnerable = maxf(_invulnerable - delta, 0.0)
	_attack_anim = maxf(_attack_anim - delta, 0.0)
	_update_needs(delta)

	var desired := Vector2.ZERO
	if not is_down:
		if is_active:
			desired = move_input.limit_length(1.0) * move_speed
		elif leader and not leader.is_down:
			var to_target := leader.global_position + follow_offset - global_position
			var distance := to_target.length()
			if distance > 24.0:
				desired = to_target / distance * move_speed * clampf(distance / 120.0, 0.3, 1.0)

	velocity = desired + _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, 900.0 * delta)
	move_and_slide()

	if desired.length() > 5.0:
		facing = desired.normalized()
		_walk_time += delta
	else:
		_walk_time = 0.0
	queue_redraw()


func _update_needs(delta: float) -> void:
	var rate := hunger_rate * (0.5 if in_camp else 1.0)
	hunger = maxf(hunger - rate * delta, 0.0)
	if hunger <= 0.0:
		_lose_health(STARVE_DAMAGE * delta)
	elif in_camp:
		health = minf(health + CAMP_HEAL * delta, max_health)
		if is_down and health >= max_health * CAMP_WAKE_RATIO:
			revive(health)


func take_hit(amount: float, from_position: Vector2) -> void:
	if is_down or _invulnerable > 0.0:
		return
	_hurt_flash = 0.3
	_invulnerable = 0.7
	_knockback = (global_position - from_position).normalized() * 450.0
	_lose_health(amount)


func revive(to_health: float) -> void:
	is_down = false
	health = clampf(to_health, 1.0, max_health)
	_invulnerable = 1.5


func eat(amount: float) -> void:
	hunger = minf(hunger + amount, MAX_HUNGER)


func play_attack(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		facing = direction
	_attack_anim = 0.2


func _lose_health(amount: float) -> void:
	health = maxf(health - amount, 0.0)
	if health <= 0.0 and not is_down:
		is_down = true
		_knockback = Vector2.ZERO
		downed.emit()


func _draw() -> void:
	var s := size_scale
	DrawUtil.shadow(self, 18.0 * s, 7.0 * s)
	if is_active:
		draw_polyline(DrawUtil.ellipse(Vector2.ZERO, 27.0 * s, 11.0 * s, 32) + PackedVector2Array([Vector2(27.0 * s, 0)]),
			Color(1, 0.95, 0.5, 0.9), 3.0)
	if is_down:
		_draw_downed()
		return

	var flashing := _hurt_flash > 0.0 and int(_hurt_flash * 20.0) % 2 == 0
	var skin := Color(1, 0.45, 0.4) if flashing else skin_color
	var bob := -absf(sin(_walk_time * 12.0)) * 3.0
	var body := Vector2(0, -20.0 * s + bob)

	# Legs
	var swing := sin(_walk_time * 12.0) * 4.0
	draw_line(Vector2(-5, -10) * s + Vector2(0, bob), Vector2(-5.0 * s + swing, 0), skin, 5.0 * s)
	draw_line(Vector2(5, -10) * s + Vector2(0, bob), Vector2(5.0 * s - swing, 0), skin, 5.0 * s)

	# Fur tunic with spots
	draw_circle(body, 13.0 * s, fur_color)
	draw_circle(body + Vector2(-5, 3) * s, 2.5 * s, fur_color.darkened(0.3))
	draw_circle(body + Vector2(4, -4) * s, 2.0 * s, fur_color.darkened(0.3))

	# Arm reaching toward where they face; it stretches out when attacking or gathering
	var reach := (16.0 + (12.0 if _attack_anim > 0.0 else 0.0)) * s
	var shoulder := body + Vector2(0, -3.0 * s)
	draw_line(shoulder, shoulder + facing * reach, skin, 5.0 * s)

	# Head: hair behind, face in front unless walking away from the camera
	var head := body + Vector2(0, -17.0 * s)
	draw_circle(head + Vector2(0, -2.0 * s), 11.0 * s, hair_color)
	if facing.y > -0.6:
		var look := Vector2(facing.x * 3.0, maxf(facing.y, 0.0) * 2.0) * s
		draw_circle(head + Vector2(0, 2.0 * s) + look * 0.5, 8.0 * s, skin)
		for side in [-1.0, 1.0]:
			draw_circle(head + Vector2(side * 3.2 * s, 1.0 * s) + look, 1.6 * s, Color(0.1, 0.07, 0.05))

	DrawUtil.label(self, Vector2(0, -60.0 * s), member_name, 14, Color(1, 1, 1, 0.85))


func _draw_downed() -> void:
	var s := size_scale
	draw_colored_polygon(DrawUtil.ellipse(Vector2(0, -8.0 * s), 16.0 * s, 9.0 * s), fur_color)
	draw_circle(Vector2(18.0 * s, -9.0 * s), 9.0 * s, hair_color)
	draw_circle(Vector2(19.0 * s, -7.0 * s), 7.0 * s, skin_color)
	DrawUtil.label(self, Vector2(0, -28.0 * s), "Zz", 18, Color(0.85, 0.9, 1.0))
	DrawUtil.label(self, Vector2(0, -46.0 * s), member_name, 14, Color(1, 0.6, 0.55))
