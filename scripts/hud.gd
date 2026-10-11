class_name Hud
extends CanvasLayer
## On-screen interface: family cards, day and supplies, hints, messages and touch controls.

signal switch_requested(index: int)
signal action_pressed
signal eat_pressed
signal switch_next_pressed
signal view_pressed
signal start_pressed
signal pause_toggled(paused: bool)
signal restart_pressed

const TOAST_TIME := 3.5
const KEYBOARD_HELP := "WASD: move    Mouse: look (click to grab)    Space / click: act    F: eat    1, 2, Tab: switch    V: view    Wheel: zoom    Esc / P: pause    F2: touch"
const TITLE := "FIRSTLIGHT"
const TAGLINE := "The ground is breaking. Your family must survive."

var joystick: TouchStick
var look_pad: TouchLook
var touch_ui := false

var _cards_box: HBoxContainer
var _day_dial: DayDial
var _inventory_bar: InventoryBar
var compass: Compass
var _hint_label: Label
var _hint_pill: PanelContainer
var _toast_label: Label
var _toast_panel: PanelContainer
var _help_label: Label
var _fade: ColorRect
var _action_button: TouchScreenButton
var _eat_button: TouchScreenButton
var _switch_button: TouchScreenButton
var _view_button: TouchScreenButton
var _crosshair: Control
var _toast_time := 0.0
var _pause_button: Button
var _pause_menu: Control
var _title_screen: Control
var _side_button: Button
var _graphics_button: Button
var _sensitivity_slider: HSlider


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS  # The menus must work while the game is paused
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	look_pad = TouchLook.new()
	look_pad.hud = self
	root.add_child(look_pad)
	joystick = TouchStick.new()
	joystick.hud = self
	root.add_child(joystick)

	_crosshair = _make_crosshair()
	root.add_child(_crosshair)

	_cards_box = HBoxContainer.new()
	_cards_box.position = Vector2(16, 16)
	_cards_box.add_theme_constant_override("separation", 10)
	root.add_child(_cards_box)

	var info := VBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.anchor_left = 1.0
	info.anchor_right = 1.0
	info.offset_left = -560
	info.offset_right = -16
	info.offset_top = 14
	root.add_child(info)
	info.alignment = BoxContainer.ALIGNMENT_BEGIN
	info.add_theme_constant_override("separation", 8)
	_day_dial = DayDial.new()
	_day_dial.size_flags_horizontal = Control.SIZE_SHRINK_END
	info.add_child(_day_dial)
	_inventory_bar = InventoryBar.new()
	_inventory_bar.size_flags_horizontal = Control.SIZE_SHRINK_END
	info.add_child(_inventory_bar)

	compass = Compass.new()
	compass.anchor_left = 0.5
	compass.anchor_right = 0.5
	compass.offset_left = -Compass.WIDTH / 2.0
	compass.offset_right = Compass.WIDTH / 2.0
	compass.offset_top = 14
	root.add_child(compass)

	# Hint: a pill above the bottom of the screen ("Pick berries")
	_hint_pill = _make_panel(Color(0.1, 0.07, 0.05, 0.7), 22)
	_hint_pill.anchor_left = 0.5
	_hint_pill.anchor_right = 0.5
	_hint_pill.anchor_top = 1.0
	_hint_pill.anchor_bottom = 1.0
	_hint_pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint_pill.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint_pill.offset_bottom = -44
	root.add_child(_hint_pill)
	_hint_label = _make_label(24, HORIZONTAL_ALIGNMENT_CENTER)
	_hint_label.add_theme_color_override("font_color", Color(1, 0.94, 0.78))
	_hint_pill.add_child(_hint_label)

	# Messages: a banner under the compass
	_toast_panel = _make_panel(Color(0.16, 0.11, 0.07, 0.85), 16)
	_toast_panel.anchor_left = 0.5
	_toast_panel.anchor_right = 0.5
	_toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_panel.offset_top = 82
	_toast_panel.visible = false
	root.add_child(_toast_panel)
	_toast_label = _make_label(22, HORIZONTAL_ALIGNMENT_CENTER)
	_toast_panel.add_child(_toast_label)

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

	_action_button = _make_touch_button("ACT", 150, Color(0.95, 0.72, 0.3), "hand")
	_action_button.pressed.connect(func() -> void: action_pressed.emit())
	_eat_button = _make_touch_button("EAT", 100, Color(0.9, 0.42, 0.35), "food")
	_eat_button.pressed.connect(func() -> void: eat_pressed.emit())
	_switch_button = _make_touch_button("SWAP", 100, Color(0.42, 0.66, 0.95), "swap")
	_switch_button.pressed.connect(func() -> void: switch_next_pressed.emit())
	_view_button = _make_touch_button("VIEW", 90, Color(0.7, 0.72, 0.75), "eye")
	_view_button.pressed.connect(func() -> void: view_pressed.emit())

	_pause_button = _make_button("II", 26)
	_pause_button.custom_minimum_size = Vector2(68, 60)
	_pause_button.anchor_left = 1.0
	_pause_button.anchor_right = 1.0
	_pause_button.offset_left = -84
	_pause_button.offset_right = -16
	_pause_button.offset_top = 154
	_pause_button.offset_bottom = 210
	_pause_button.pressed.connect(func() -> void: set_paused(true))
	root.add_child(_pause_button)

	_pause_menu = _build_pause_menu()
	root.add_child(_pause_menu)
	_title_screen = _build_title_screen()
	root.add_child(_title_screen)

	get_viewport().size_changed.connect(_layout_touch_buttons)
	GameState.settings_changed.connect(_apply_settings)
	_apply_settings()
	set_touch_ui(DisplayServer.is_touchscreen_available() or OS.has_feature("mobile"))


func _input(event: InputEvent) -> void:
	# Switch to touch controls the first time a real finger touches the screen
	if event is InputEventScreenTouch and event.device != InputEvent.DEVICE_ID_EMULATION and not touch_ui:
		set_touch_ui(true)


func _unhandled_input(event: InputEvent) -> void:
	if _title_screen.visible:
		return
	if event.is_action_pressed("free_mouse") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause") or event.is_action_pressed("free_mouse"):
		set_paused(not is_paused())
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast_panel.modulate.a = clampf(_toast_time / 0.5, 0.0, 1.0)
		_toast_panel.visible = _toast_time > 0.0


func setup(members: Array[FamilyMember]) -> void:
	for i in members.size():
		var card := MemberCard.new()
		card.member = members[i]
		card.index = i
		card.pressed.connect(func() -> void: switch_requested.emit(i))
		_cards_box.add_child(card)


func set_touch_ui(enabled: bool) -> void:
	touch_ui = enabled
	if _title_screen and _title_screen.visible:
		enabled = false  # Keep the title screen clean
	joystick.visible = enabled
	joystick.release()
	look_pad.visible = enabled
	look_pad.release()
	for button in _touch_buttons():
		button.visible = enabled
	_help_label.visible = not enabled and not (_title_screen and _title_screen.visible)
	_hint_pill.offset_bottom = -170.0 if enabled else -44.0


func toggle_touch_ui() -> void:
	set_touch_ui(not touch_ui)


func update_day(day: int, phase: String, time_of_day: float) -> void:
	_day_dial.set_time(day, phase, time_of_day)


func update_inventory() -> void:
	_inventory_bar.refresh()


func show_hint(text: String) -> void:
	if text != "" and not touch_ui:
		text = "Space  ·  " + text
	_hint_pill.visible = text != "" and not _title_screen.visible
	if _hint_label.text != text:
		_hint_label.text = text
		_hint_pill.reset_size()  # Shrink the pill to fit the new text


func toast(text: String) -> void:
	_toast_label.text = text
	_toast_panel.visible = true
	_toast_panel.modulate.a = 1.0
	_toast_panel.reset_size()
	_toast_time = TOAST_TIME


## Fades the screen to black (alpha 1) or back (alpha 0). Returns the tween so callers can chain steps.
func fade(alpha: float, duration: float) -> Tween:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, duration)
	return tween


## Places the action buttons in the corner opposite the movement stick.
func _layout_touch_buttons() -> void:
	var view := get_viewport().get_visible_rect().size
	var buttons_on_right := not GameState.move_stick_on_right
	for entry in [[_action_button, Vector2(190, 190)], [_eat_button, Vector2(330, 140)], [_switch_button, Vector2(270, 310)]]:
		var button: TouchScreenButton = entry[0]
		var from_corner: Vector2 = entry[1]
		var diameter := (button.shape as CircleShape2D).radius * 2.0
		var x := view.x - from_corner.x if buttons_on_right else from_corner.x - diameter
		button.position = Vector2(x, view.y - from_corner.y)
	_view_button.position = Vector2(view.x - 100, 222)


func _apply_settings() -> void:
	joystick.on_right = GameState.move_stick_on_right
	look_pad.on_right = not GameState.move_stick_on_right
	joystick.release()
	look_pad.release()
	joystick.queue_redraw()
	_layout_touch_buttons()
	_side_button.text = "Move stick: %s side" % ("Right" if GameState.move_stick_on_right else "Left")
	_graphics_button.text = "Graphics: %s" % ("High" if GameState.high_graphics else "Smooth (low)")
	_sensitivity_slider.set_value_no_signal(GameState.look_sensitivity)


# --- Title screen and pause menu --------------------------------------------

func show_title() -> void:
	_title_screen.visible = true
	_pause_button.visible = false
	_cards_box.visible = false
	set_touch_ui(touch_ui)


func is_paused() -> bool:
	return _pause_menu.visible


func set_paused(paused: bool) -> void:
	if _title_screen.visible:
		return
	_pause_menu.visible = paused
	pause_toggled.emit(paused)


func _build_title_screen() -> Control:
	var screen := ColorRect.new()
	screen.color = Color(0.08, 0.05, 0.03, 0.45)
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.visible = false
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	screen.add_child(box)
	var title := _make_label(96, HORIZONTAL_ALIGNMENT_CENTER)
	title.text = TITLE
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.5))
	title.add_theme_constant_override("outline_size", 18)
	box.add_child(title)
	var tagline := _make_label(26, HORIZONTAL_ALIGNMENT_CENTER)
	tagline.text = TAGLINE
	box.add_child(tagline)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	box.add_child(spacer)
	var play := _make_button("PLAY", 36)
	play.custom_minimum_size = Vector2(320, 84)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(func() -> void:
		screen.visible = false
		_pause_button.visible = true
		_cards_box.visible = true
		set_touch_ui(touch_ui)
		start_pressed.emit())
	box.add_child(play)
	var tip := _make_label(18, HORIZONTAL_ALIGNMENT_CENTER)
	tip.text = "Gather food, hunt, and get back to the cave before dark."
	box.add_child(tip)
	return screen


func _build_pause_menu() -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.visible = false
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.1, 0.07, 0.95)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(28)
	style.border_color = Color(1, 0.86, 0.5, 0.6)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	dim.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var heading := _make_label(40, HORIZONTAL_ALIGNMENT_CENTER)
	heading.text = "Paused"
	box.add_child(heading)
	var resume := _make_button("Resume", 26)
	resume.pressed.connect(func() -> void: set_paused(false))
	box.add_child(resume)

	_side_button = _make_button("", 22)
	_side_button.pressed.connect(func() -> void:
		GameState.move_stick_on_right = not GameState.move_stick_on_right
		GameState.save_settings())
	box.add_child(_side_button)

	var look_label := _make_label(20, HORIZONTAL_ALIGNMENT_CENTER)
	look_label.text = "Look speed"
	box.add_child(look_label)
	_sensitivity_slider = HSlider.new()
	_sensitivity_slider.min_value = 0.4
	_sensitivity_slider.max_value = 2.5
	_sensitivity_slider.step = 0.1
	_sensitivity_slider.custom_minimum_size = Vector2(360, 36)
	_sensitivity_slider.value_changed.connect(func(value: float) -> void:
		GameState.look_sensitivity = value
		GameState.save_settings())
	box.add_child(_sensitivity_slider)

	_graphics_button = _make_button("", 22)
	_graphics_button.pressed.connect(func() -> void:
		GameState.high_graphics = not GameState.high_graphics
		GameState.save_settings())
	box.add_child(_graphics_button)

	var restart := _make_button("Start over", 22)
	restart.pressed.connect(func() -> void:
		set_paused(false)
		restart_pressed.emit())
	box.add_child(restart)
	return dim


func _make_button(text: String, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(360, 60)
	button.add_theme_font_size_override("font_size", font_size)
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = {"normal": Color(0.55, 0.36, 0.2, 0.9), "hover": Color(0.65, 0.44, 0.25, 0.95), "pressed": Color(0.42, 0.27, 0.15, 0.95)}[state]
		style.set_corner_radius_all(14)
		style.set_content_margin_all(10)
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color(1, 0.96, 0.88))
	return button


## True if a screen point is on one of the on-screen buttons.
func is_over_button(point: Vector2) -> bool:
	for button in _touch_buttons():
		var radius: float = (button.shape as CircleShape2D).radius
		if point.distance_to(button.position + Vector2(radius, radius)) < radius + 10.0:
			return true
	return false


func set_crosshair(enabled: bool) -> void:
	_crosshair.visible = enabled


func _touch_buttons() -> Array[TouchScreenButton]:
	return [_action_button, _eat_button, _switch_button, _view_button]


func _make_crosshair() -> Control:
	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1, 0.8)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.offset_left = -3
	dot.offset_top = -3
	dot.offset_right = 3
	dot.offset_bottom = 3
	dot.visible = false
	return dot


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


func _make_touch_button(text: String, diameter: int, color: Color, icon := "") -> TouchScreenButton:
	var button := TouchScreenButton.new()
	# The texture is invisible and only sets the button's size; ButtonFace draws the look
	button.texture_normal = _circle_texture(diameter, Color(color, 0.0))
	var shape := CircleShape2D.new()
	shape.radius = diameter / 2.0
	button.shape = shape
	button.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
	var face := ButtonFace.new()
	face.button = button
	face.icon = icon
	face.caption = text
	face.color = Color(color, 1.0)
	face.diameter = diameter
	button.add_child(face)
	add_child(button)
	return button


func _make_panel(color: Color, radius: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.border_color = Color(1, 0.86, 0.5, 0.35)
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)
	return panel


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
