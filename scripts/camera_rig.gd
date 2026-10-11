class_name CameraRig
extends Node3D
## Follows the active family member. Three views:
## over the shoulder (third person), through their eyes (first person) and a high overview.

enum Mode { THIRD_PERSON, FIRST_PERSON, OVERVIEW }

const MODE_NAMES := ["Third-person view", "First-person view", "Overview"]
const THIRD_MIN_DISTANCE := 2.5
const THIRD_MAX_DISTANCE := 11.0
const OVERVIEW_DISTANCE := 24.0
const OVERVIEW_PITCH := -0.95
const STICK_LOOK_SPEED := 2.6  ## Radians per second at full right-stick tilt.

var mode := Mode.THIRD_PERSON
var target: FamilyMember
var yaw := PI  ## Start looking toward the cave.
var pitch := -0.3
var third_distance := 6.0
var mouse_sensitivity := 0.0032
var touch_sensitivity := 0.006

var camera: Camera3D
var _arm: SpringArm3D


func _ready() -> void:
	_arm = SpringArm3D.new()
	_arm.collision_mask = 1
	_arm.margin = 0.3
	var probe := SphereShape3D.new()
	probe.radius = 0.25
	_arm.shape = probe
	add_child(_arm)
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.near = 0.08
	camera.far = 260.0
	_arm.add_child(camera)
	camera.make_current()


func cycle_mode() -> void:
	set_mode(((mode as int) + 1) % Mode.size() as Mode)


func set_mode(new_mode: Mode) -> void:
	mode = new_mode
	match mode:
		Mode.THIRD_PERSON:
			pitch = -0.3
		Mode.FIRST_PERSON:
			pitch = -0.1
		Mode.OVERVIEW:
			pitch = OVERVIEW_PITCH
	_apply_arm()
	snap()


## Turns the view by a mouse or touch movement in pixels.
func rotate_by_pixels(delta: Vector2, sensitivity: float) -> void:
	yaw -= delta.x * sensitivity
	if mode != Mode.OVERVIEW:
		pitch -= delta.y * sensitivity
	_clamp_pitch()


func zoom(steps: float) -> void:
	if mode == Mode.THIRD_PERSON:
		third_distance = clampf(third_distance + steps, THIRD_MIN_DISTANCE, THIRD_MAX_DISTANCE)


## Direction the camera faces along the ground.
func forward() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func right() -> Vector3:
	return Vector3(cos(yaw), 0.0, -sin(yaw))


## Jumps straight to the target instead of gliding (after switching member or view).
func snap() -> void:
	if target:
		global_position = _focus_point()


func _process(delta: float) -> void:
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if stick != Vector2.ZERO:
		yaw -= stick.x * STICK_LOOK_SPEED * delta
		if mode != Mode.OVERVIEW:
			pitch -= stick.y * STICK_LOOK_SPEED * delta
		_clamp_pitch()
	if target == null:
		return

	var focus := _focus_point()
	if mode == Mode.FIRST_PERSON:
		global_position = focus
	else:
		global_position = global_position.lerp(focus, clampf(1.0 - exp(-10.0 * delta), 0.0, 1.0))
	rotation = Vector3(pitch, yaw, 0.0)
	_apply_arm()


## Sets how far behind the focus point the camera sits for the current view.
func _apply_arm() -> void:
	match mode:
		Mode.THIRD_PERSON:
			_arm.spring_length = third_distance
			_arm.collision_mask = 1
		Mode.FIRST_PERSON:
			_arm.spring_length = 0.0
			_arm.collision_mask = 0
		Mode.OVERVIEW:
			_arm.spring_length = OVERVIEW_DISTANCE
			_arm.collision_mask = 0


func _focus_point() -> Vector3:
	match mode:
		Mode.FIRST_PERSON:
			return target.global_position + Vector3.UP * target.eye_height()
		Mode.OVERVIEW:
			return target.global_position + Vector3.UP * 1.0
	return target.global_position + Vector3.UP * (target.eye_height() + 0.25) + right() * 0.5


func _clamp_pitch() -> void:
	match mode:
		Mode.THIRD_PERSON:
			pitch = clampf(pitch, -1.2, 0.3)
		Mode.FIRST_PERSON:
			pitch = clampf(pitch, -1.35, 1.35)
		Mode.OVERVIEW:
			pitch = OVERVIEW_PITCH
