#tool
extends Container

func _process(delta):
	_refresh()

export var max_spacing = 30.0 setget set_1
export var min_spacing = 4.0 setget set_2
export var include_hidden = false setget set_3
func set_1(v):
	max_spacing = v
	_refresh()
func set_2(v):
	min_spacing = v
	_refresh()
func set_3(v):
	include_hidden = v
	_refresh()
func _ready():
	_refresh()

func _notification(what):
	
	if what == NOTIFICATION_SORT_CHILDREN:
		_sort_children()
		return
	_refresh()

func _refresh(_v = null):
	_sort_children()
	minimum_size_changed()
	queue_sort()

func _visible_controls() -> Array:
	var out = []
	for c in get_children():
		if c is Control and (include_hidden or c.visible):
			out.append(c)
	return out

func _total_min_height(items: Array) -> float:
	var s = 0.0
	for c in items:
		s += c.get_combined_minimum_size().y
	return s

func _sort_children():
	var items = _visible_controls()
	var n = items.size()
	if n == 0:
		return
	var total_h = _total_min_height(items)
	var available = rect_size.y - total_h
	var spacing = clamp(available / (n - 1), min_spacing, max_spacing)
	var used_h = total_h + spacing * (n - 1)
	var y_top = 0.0
	var y_bottom = rect_size.y
	if n == 1:
		var c = items[0]
		var h = c.get_combined_minimum_size().y
		c.rect_position = Vector2(0, y_bottom * 0.5 - h * 0.5)
		c.rect_size = Vector2(rect_size.x, h)
		return
	for i in range(n):
		var c = items[i]
		var h = c.get_combined_minimum_size().y
		if i == 0:
			c.rect_position = Vector2(0, 0)
		elif i == n - 1:
			c.rect_position = Vector2(0, rect_size.y - h)
		else:
			var t = float(i) / (n - 1)
			c.rect_position = Vector2(0, t * (rect_size.y - h))
		c.rect_size = Vector2(rect_size.x, h)

func get_minimum_size() -> Vector2:
	var items = _visible_controls()
	if items.size() == 0:
		return Vector2.ZERO
	var total_h = _total_min_height(items)
	var gaps = max(items.size() - 1, 0)
	var h = total_h + gaps * min_spacing
	var w = 0.0
	for c in items:
		w = max(w, c.get_combined_minimum_size().x)
	return Vector2(w, h)
