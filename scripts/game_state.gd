extends Node
## Global game state (autoload "GameState"): the family's shared supplies,
## on-screen messages and the input map.

signal inventory_changed
signal message(text: String)

const ITEM_NAMES := {
	"berries": "Berries",
	"fruit": "Fruit",
	"meat": "Meat",
	"sticks": "Sticks",
	"stones": "Stones",
}
## Hunger restored per item, most filling first (eating picks the first available).
const FOOD_VALUE := {"meat": 40.0, "fruit": 25.0, "berries": 15.0}
const MESSAGE_REPEAT_DELAY := 2.0

var inventory := {"berries": 0, "fruit": 0, "meat": 0, "sticks": 0, "stones": 0}

var _last_message := ""
var _last_message_time := -100.0


func _ready() -> void:
	_setup_input()


func add_item(item: String, amount: int) -> void:
	inventory[item] = inventory.get(item, 0) + amount
	inventory_changed.emit()


## Eats the most filling food in the supplies. Returns the hunger restored, or 0 if there is none.
func take_food() -> float:
	for food: String in FOOD_VALUE:
		if inventory[food] > 0:
			inventory[food] -= 1
			inventory_changed.emit()
			return FOOD_VALUE[food]
	return 0.0


func lose_half_supplies() -> void:
	for item: String in inventory:
		inventory[item] = inventory[item] / 2
	inventory_changed.emit()


## Shows a message on screen. The same message is not repeated within a short delay.
func notify(text: String) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if text == _last_message and now - _last_message_time < MESSAGE_REPEAT_DELAY:
		return
	_last_message = text
	_last_message_time = now
	message.emit(text)


func _setup_input() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT])
	_add_action("move_up", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP])
	_add_action("move_down", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN])
	_add_action("action", [KEY_SPACE, KEY_E], [JOY_BUTTON_A])
	_add_action("eat", [KEY_F], [JOY_BUTTON_X])
	_add_action("switch_next", [KEY_TAB], [JOY_BUTTON_RIGHT_SHOULDER])
	_add_action("switch_1", [KEY_1])
	_add_action("switch_2", [KEY_2])
	_add_action("toggle_touch_ui", [KEY_F2])
	_add_action("camera_mode", [KEY_V], [JOY_BUTTON_Y])
	_add_action("free_mouse", [KEY_ESCAPE])
	_add_action("look_left", [])
	_add_action("look_right", [])
	_add_action("look_up", [])
	_add_action("look_down", [])
	_add_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_axis("move_down", JOY_AXIS_LEFT_Y, 1.0)
	_add_axis("look_left", JOY_AXIS_RIGHT_X, -1.0)
	_add_axis("look_right", JOY_AXIS_RIGHT_X, 1.0)
	_add_axis("look_up", JOY_AXIS_RIGHT_Y, -1.0)
	_add_axis("look_down", JOY_AXIS_RIGHT_Y, 1.0)


func _add_action(action: String, keys: Array, buttons: Array = []) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)
	for key: Key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
	for button: JoyButton in buttons:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		InputMap.action_add_event(action, event)


func _add_axis(action: String, axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	InputMap.action_add_event(action, event)
