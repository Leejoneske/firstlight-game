class_name InventoryBar
extends Control
## The family's supplies as a row of icon chips. A chip pops when its count changes.

const CHIP := Vector2(78, 40)
const GAP := 8.0

var _counts := {}
var _pop := {}  ## item -> seconds of pop animation left


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2((CHIP.x + GAP) * GameState.ITEM_NAMES.size(), CHIP.y)
	refresh()


func refresh() -> void:
	for item: String in GameState.ITEM_NAMES:
		var count: int = GameState.inventory[item]
		if _counts.has(item) and _counts[item] != count:
			_pop[item] = 0.35
		_counts[item] = count
	queue_redraw()


func _process(delta: float) -> void:
	if _pop.is_empty():
		return
	for item: String in _pop.keys():
		_pop[item] -= delta
		if _pop[item] <= 0.0:
			_pop.erase(item)
	queue_redraw()


func _draw() -> void:
	var x := size.x - (CHIP.x + GAP) * GameState.ITEM_NAMES.size() + GAP
	for item: String in GameState.ITEM_NAMES:
		var pop: float = _pop.get(item, 0.0)
		var grow := sin(pop / 0.35 * PI) * 6.0
		var rect := Rect2(Vector2(x, 0) - Vector2(grow, grow) / 2.0, CHIP + Vector2(grow, grow))
		var empty: bool = _counts.get(item, 0) == 0
		DrawShapes.rounded_rect(self, rect, Color(0.1, 0.07, 0.05, 0.62 if not empty else 0.4))
		UiIcons.draw(self, item, rect.position + Vector2(22, rect.size.y / 2.0), 26.0, Color(1, 1, 1, 0.45) if empty else Color.WHITE)
		DrawShapes.text(self, rect.position + Vector2(56, rect.size.y / 2.0), str(_counts.get(item, 0)), 22,
			Color(1, 1, 1, 0.5) if empty else Color(1, 0.96, 0.86))
		x += CHIP.x + GAP
