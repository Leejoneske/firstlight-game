class_name Hud
extends CanvasLayer
## On-screen interface: family cards, day and supplies, hints, messages and touch controls.

signal switch_requested(index: int)
signal action_pressed
signal eat_pressed
signal switch_next_pressed

const TOAST_TIME := 3.5
const KEYBOARD_HELP := "WASD / arrows: move    Space: act    F: eat    1, 2 or Tab: switch    F2: touch controls"

var joystick: TouchStick
var touch_ui := false

var _cards_box: HBoxContainer
var _day_label: Label
var _inventory_label: Label
var _hint_label: Label
var _toast_label: Label
var _help_label: Label
var _fade: ColorRect
var _action_button: TouchScreenButton
var _eat_button: TouchScreenButton
var _switch_button: TouchScreenButton
var _toast_time := 0.0


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	joystick = TouchStick.new()
	root.add_child(joystick)

	_cards_box = HBoxContainer.new()
	_cards_box.position = Vector2(16, 16)
	_cards_box.add_theme_constant_override("separation", 10)
	root.add_child(_cards_box)

	var info := VBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.anchor_left = 1.0
	info.anchor_right = 1.0
	info.offset_left = -520
	info.offset_right = -16
	info.offset_top = 14
	root.add_child(info)
	_day_label = _make_label(28, HORIZONTAL_ALIGNMENT_RIGHT)
	info.add_child(_day_label)
	_inventory_label = _make_label(20, HORIZONTAL_ALIGNMENT_RIGHT)
	info.add_child(_inventory_label)

	_hint_label = _make_label(24, HORIZONTAL_ALIGNMENT_CENTER)
	_place_full_width(_hint_label, 1.0, -78, -44)
	root.add_child(_hint_label)

	_toast_label = _make_label(24, HORIZONTAL_ALIGNMENT_CENTER)
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place_full_width(_toast_label, 0.0, 110, 180)
	_toast_label.offset_left = 120
	_toast_label.offset_right = -120
	root.add_child(_toast_label)

	_help_label = _make_label(15, HORIZONTAL_ALIGNMENT_LEFT)
	_help_label.text = KEYBOARD_HELP
	_place_full_width(_help_label, 1.0, -30, -8)
	_help_label.offset_left = 16
	root.add_child(_help_label)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_fade)

	_action_button = _make_touch_button("ACT", 150, Color(0.95, 0.75, 0.3, 0.55))
	_action_button.pressed.connect(func() -> void: action_pressed.emit())
	_eat_button = _make_touch_button("EAT", 100, Color(0.9, 0.45, 0.35, 0.55))
	_eat_button.pressed.connect(func() -> void: eat_pressed.emit())
	_switch_button = _make_touch_button("SWAP", 100, Color(0.45, 0.7, 0.95, 0.55))
	_switch_button.pressed.connect(func() -> void: switch_next_pressed.emit())

	get_viewport().size_changed.connect(_layout_touch_buttons)
	_layout_touch_buttons()
	set_touch_ui(DisplayServer.is_touchscreen_available() or OS.has_feature("mobile"))


func _input(event: InputEvent) -> void:
	# Switch to touch controls the first time a real finger touches the screen
	if event is InputEventScreenTouch and event.device != InputEvent.DEVICE_ID_EMULATION and not touch_ui:
		set_touch_ui(true)


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast_label.modulate.a = clampf(_toast_time / 0.5, 0.0, 1.0)


func setup(members: Array[FamilyMember]) -> void:
	for i in members.size():
		var card := MemberCard.new()
		card.member = members[i]
		card.index = i
		card.pressed.connect(func() -> void: switch_requested.emit(i))
		_cards_box.add_child(card)


func set_touch_ui(enabled: bool) -> void:
	touch_ui = enabled
	joystick.visible = enabled
	joystick.release()
	for button in [_action_button, _eat_button, _switch_button]:
		button.visible = enabled
	_help_label.visible = not enabled
	_hint_label.offset_top = -190 if enabled else -78
	_hint_label.offset_bottom = -156 if enabled else -44


func toggle_touch_ui() -> void:
	set_touch_ui(not touch_ui)


func update_day(day: int, phase: String, night: bool) -> void:
	_day_label.text = "Day %d  -  %s" % [day, phase]
	_day_label.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0) if night else Color(1, 0.95, 0.8))


func update_inventory() -> void:
	var parts: PackedStringArray = []
	for item: String in GameState.ITEM_NAMES:
		parts.append("%s %d" % [GameState.ITEM_NAMES[item], GameState.inventory[item]])
	_inventory_label.text = "   ".join(parts)


func show_hint(text: String) -> void:
	if text != "" and not touch_ui:
		text = "[Space]  " + text
	_hint_label.text = text


func toast(text: String) -> void:
	_toast_label.text = text
	_toast_label.modulate.a = 1.0
	_toast_time = TOAST_TIME


## Fades the screen to black (alpha 1) or back (alpha 0). Returns the tween so callers can chain steps.
func fade(alpha: float, duration: float) -> Tween:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, duration)
	return tween


func _layout_touch_buttons() -> void:
	var view := get_viewport().get_visible_rect().size
	_action_button.position = view - Vector2(190, 190)
	_eat_button.position = view - Vector2(330, 140)
	_switch_button.position = view - Vector2(270, 310)


func _make_label(font_size: int, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	return label


func _place_full_width(control: Control, anchor_y: float, top: float, bottom: float) -> void:
	control.anchor_left = 0.0
	control.anchor_right = 1.0
	control.anchor_top = anchor_y
	control.anchor_bottom = anchor_y
	control.offset_left = 0
	control.offset_right = 0
	control.offset_top = top
	control.offset_bottom = bottom


func _make_touch_button(text: String, diameter: int, color: Color) -> TouchScreenButton:
	var button := TouchScreenButton.new()
	button.texture_normal = _circle_texture(diameter, color)
	button.texture_pressed = _circle_texture(diameter, color.lightened(0.35))
	var shape := CircleShape2D.new()
	shape.radius = diameter / 2.0
	button.shape = shape
	button.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
	var label := _make_label(22, HORIZONTAL_ALIGNMENT_CENTER)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(diameter, diameter)
	label.text = text
	button.add_child(label)
	add_child(button)
	return button


func _circle_texture(diameter: int, color: Color) -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.9, 1.0])
	gradient.colors = PackedColorArray([color, color, Color(color, 0.0)])
	var texture := GradientTexture2D.new()
	texture.width = diameter
	texture.height = diameter
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.gradient = gradient
	return texture
