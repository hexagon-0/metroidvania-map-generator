class_name MapVisualizer
extends CanvasItem


signal screenful_clicked(screenful: Vector2i)


@export var screenful_size: Vector2 = Vector2(10, 6)
@export var outline_width: int = 2
@export var anchor: Vector2 = Vector2(0.5, 0.5)

var map: MapGenerator.Map:
	set(value):
		map = value
		queue_redraw()

var _key_list_origin: Vector2 = Vector2(400.0, 20.0)
var _offset: Vector2:
	get:
		return Vector2(map.size) * anchor
var _selected_region: MapGenerator.BspNode
var _adjacent_regions: Array[Rect2i]
var _overlay: bool = false


func _ready() -> void:
	get_window().focus_exited.connect(_on_window_focus_exited)


func _draw() -> void:
	_draw_regions()
	if _overlay:
		_draw_screenful_grid()
	_draw_keys()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("select"):
		var screenful := Vector2i(get_local_mouse_position() / screenful_size + _offset)
		if not map.root.rect.has_point(screenful):
			return

		if Input.is_action_pressed("overlay"):
			var region = map.root.find_region_containing_point(screenful)
			print("Screenful {0} is within region {1}".format([screenful, region.rect]))
		else:
			screenful_clicked.emit(screenful)
	elif event is InputEventMouseMotion:
		var screenful := Vector2i(get_local_mouse_position() / screenful_size + _offset)
		if not Rect2i(Vector2i.ZERO, map.size).has_point(screenful):
			_set_selected_region(null)
			return

		var region = map.root.find_region_containing_point(screenful)
		_set_selected_region(region)
	elif event.is_action_pressed("overlay"):
		_overlay = true
		queue_redraw()
	elif event.is_action_released("overlay"):
		_overlay = false
		queue_redraw()


func _on_window_focus_exited() -> void:
	_overlay = false
	queue_redraw()


func _set_selected_region(region: MapGenerator.BspNode) -> void:
	if _selected_region != region:
		_selected_region = region
		if _selected_region != null:
			_adjacent_regions = map.get_adjacency_list(_selected_region.rect)
		else:
			_adjacent_regions = []
		queue_redraw()


func _draw_regions() -> void:
	var outline_vector := Vector2(outline_width, outline_width)
	var half_outline_vector := outline_vector / 2

	var iterator := map.iterator()
	var region = iterator.next()
	while region:
		var r: Rect2 = region
		r.position -= _offset
		r.position *= screenful_size
		r.size *= screenful_size

		var outline_rect = r
		outline_rect.position += half_outline_vector
		outline_rect.size -= outline_vector

		#var color := (_get_region_color(region)
				#if _selected_region == null or _selected_region.rect != region
				#else Color.SALMON)
		var color: Color
		if Input.is_action_pressed("adjacency") and _selected_region != null:
			if _selected_region.rect == region:
				color = Color.SALMON
			elif region in _adjacent_regions:
				color = Color.LIGHT_GREEN
			else:
				color = _get_region_color(region)
		else:
			color = _get_region_color(region)

		var outline_color := color.darkened(0.2)
		draw_rect(r, color)
		draw_rect(outline_rect, outline_color, false, outline_width)

		region = iterator.next()



func _draw_screenful_grid() -> void:
	for axis in 2:
		var line_length := map.size[axis] * screenful_size[axis ^ 1]
		for i in range(1, map.size[axis]):
			var from := -_offset * screenful_size
			from[axis] += i * screenful_size[axis]
			var to := from
			to[axis ^ 1] += line_length
			draw_line(from, to, Color(0, 0, 0, 0.2), outline_width)


func _draw_keys() -> void:
	var default_font = ThemeDB.fallback_font
	var default_font_size = ThemeDB.fallback_font_size
	var pos := _key_list_origin
	for key in map.key_order:
		var color := _get_key_color(key)
		draw_circle(pos, 8.0, color)
		draw_arc(pos, 8.0, 0, 2*PI, 9, color.darkened(0.2), 2)
		draw_string(
			default_font, pos + Vector2(16.0, 6.0), key,
			HORIZONTAL_ALIGNMENT_LEFT, -1, default_font_size
		)
		pos.y += 36


func _get_region_color(region: Rect2i) -> Color:
	var key = map.gatings.get(region)
	if not key:
		return Color.SLATE_GRAY

	return _get_key_color(key)


func _get_key_color(key: StringName) -> Color:
	var i := map.key_order.find(key)
	if i < 0:
		return Color.SLATE_GRAY

	var color := Color.GREEN
	color.h += 0.42 * i

	return color
