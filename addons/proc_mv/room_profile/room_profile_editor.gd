@tool
extends Control


enum DragType { NONE, PAN }


var undo_redo: EditorUndoRedoManager

var _profile: RoomProfile
var _canvas: Control
var _zoom_minus: Button
var _zoom_reset: Button
var _zoom_plus: Button
var _button_center_view: Button
var _drag: DragType = DragType.NONE
var _zoom: float = 1
var _hover_valid: bool = false
var _hover_screenful: Vector2
var _hover_side: EdgeProfile.EdgeSide
var _inspector: EditorInspector
var _proxy: EdgeProfileProxy#:
	#get: return _proxy
	#set(value):
		#var prev := _proxy
		#_proxy = value
		#if _proxy != prev:
			#_inspector.edit(_proxy)
			#_canvas.queue_redraw()
			#_button_remove.disabled = (_proxy == null)
var _button_remove: Button


func _init() -> void:
	_inspector = EditorInspector.new()
	_inspector.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_proxy = EdgeProfileProxy.new()
	_inspector.edit(_proxy)


func _ready() -> void:
	%InspectorContainer.add_child(_inspector)

	_canvas = %Canvas
	_canvas.visibility_changed.connect(_canvas_visibility_changed)
	_canvas.draw.connect(_canvas_draw)
	ProjectSettings.settings_changed.connect(_canvas.queue_redraw)

	%CanvasContainer.gui_input.connect(_canvas_container_gui_input)

	%Redraw.pressed.connect(_canvas.queue_redraw)
	_button_remove = %Remove
	_button_remove.icon = _button_remove.get_theme_icon(&"Remove", &"EditorIcons")
	_button_remove.disabled = true
	_button_remove.pressed.connect(_on_button_remove_pressed)

	_zoom_minus = %ZoomMinus
	_zoom_reset = %ZoomReset
	_zoom_plus = %ZoomPlus
	_zoom_minus.icon = _zoom_minus.get_theme_icon(&"ZoomLess", &"EditorIcons")
	_zoom_plus.icon = _zoom_plus.get_theme_icon(&"ZoomMore", &"EditorIcons")
	_zoom_reset.pressed.connect(_on_zoom_reset_pressed)

	_button_center_view = %CenterView
	_button_center_view.icon = _button_center_view.get_theme_icon(&"CenterView", &"EditorIcons")
	_button_center_view.pressed.connect(_on_button_center_view_pressed)

	_update_zoom()


func edit(profile: RoomProfile) -> void:
	if _profile == profile:
		return

	if _profile:
		_profile.resized.disconnect(_on_profile_resized)
		_profile.changed.disconnect(_on_profile_changed)

	_profile = profile
	_set_proxy_edge_profile(null)

	if _profile:
		_profile.resized.connect(_on_profile_resized)
		_profile.changed.connect(_on_profile_changed)
		_proxy.key_set = _profile.key_set
	else:
		_proxy.key_set = null

	_canvas.queue_redraw()


func _canvas_draw() -> void:
	_draw_profile()
	_draw_selection()
	_draw_hover()


func _draw_selection() -> void:
	if _proxy.profile:
		_draw_edge_tri(_proxy.profile.position, _proxy.profile.side, Color(Color.GOLDENROD, 0.5))


func _draw_hover() -> void:
	if _hover_valid:
		_draw_edge_tri(_hover_screenful, _hover_side, Color(Color.AZURE, 0.5))


func _draw_profile() -> void:
	if not _profile:
		return

	var screenful_size: Vector2 = ProjectSettings.get_setting("debug/procedural_metroidvania/screenful_minipreview_size")
	var rect_size := Vector2(_profile.size) * screenful_size
	var rect_offset := rect_size / 2
	var stroke_width := _get_stroke_width()
	_canvas.draw_rect(Rect2i(-rect_offset, rect_size), Color.CORNFLOWER_BLUE)
	_canvas.draw_rect(Rect2i(-rect_offset, rect_size), Color.DARK_SLATE_BLUE, false, stroke_width)

	for e in _profile.edges:
		if e:
			_draw_edge(e, screenful_size, rect_size / 2)


func _draw_edge(edge: EdgeProfile, screenful_size: Vector2, offset: Vector2) -> void:
	var from: Vector2 = edge.position
	var to: Vector2 = edge.position
	var margin: Vector2

	var width := _get_stroke_width()
	var WALL_WIDTH: float = width

	match edge.side:
		EdgeProfile.EdgeSide.NORTH, EdgeProfile.EdgeSide.SOUTH:
			to.x += 1

			if edge.side == EdgeProfile.EdgeSide.SOUTH:
				from.y += 1
				to.y += 1

			margin = Vector2(WALL_WIDTH/2, 0)

		EdgeProfile.EdgeSide.EAST, EdgeProfile.EdgeSide.WEST:
			to.y += 1

			if edge.side == EdgeProfile.EdgeSide.EAST:
				from.x += 1
				to.x += 1

			margin = Vector2(0, WALL_WIDTH/2)

	_canvas.draw_line(from*screenful_size+margin-offset, to*screenful_size-margin-offset, Color.GOLDENROD, width)


func _draw_edge_tri(screenful: Vector2i, side: EdgeProfile.EdgeSide, color: Color) -> void:
	var tris: Dictionary[EdgeProfile.EdgeSide, Array] = {
		EdgeProfile.EdgeSide.EAST: [Vector2(0.5, 0.5), Vector2(1.0, 0.0), Vector2(1.0, 1.0)],
		EdgeProfile.EdgeSide.WEST: [Vector2(0.5, 0.5), Vector2(0.0, 1.0), Vector2(0.0, 0.0)],
		EdgeProfile.EdgeSide.SOUTH: [Vector2(0.5, 0.5), Vector2(1.0, 1.0), Vector2(0.0, 1.0)],
		EdgeProfile.EdgeSide.NORTH: [Vector2(0.5, 0.5), Vector2(0.0, 0.0), Vector2(1.0, 0.0)],
	}

	assert(_hover_side in tris)

	var screenful_size: Vector2 = ProjectSettings.get_setting("debug/procedural_metroidvania/screenful_minipreview_size")
	var triangle := PackedVector2Array(
		tris[side].map(func (point): return (point - Vector2(_profile.size)/2 + Vector2(screenful)) * screenful_size)
	)

	_canvas.draw_colored_polygon(triangle, color)


func _get_stroke_width() -> float:
	var WALL_WIDTH: float = ProjectSettings.get_setting("debug/procedural_metroidvania/screenful_minipreview_wall_width")
	return WALL_WIDTH


func _canvas_visibility_changed() -> void:
	if not _canvas.is_visible_in_tree():
		return

	_update_zoom()


func _canvas_container_gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb:
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if _hover_valid:
				for e: EdgeProfile in _profile.edges:
					if e.position == Vector2i(_hover_screenful) and e.side == _hover_side:
						_set_proxy_edge_profile(e)
						return
				var edge_profile := EdgeProfile.new()
				edge_profile.position = _hover_screenful
				edge_profile.side = _hover_side
				undo_redo.create_action("Room Profile Editor: Add Edge Profile", UndoRedo.MERGE_DISABLE, _profile)
				undo_redo.force_fixed_history()
				undo_redo.add_do_reference(edge_profile)
				undo_redo.add_do_method(_profile, &"add_edge_profile", edge_profile)
				undo_redo.add_do_method(self, &"_set_proxy_edge_profile", edge_profile)
				undo_redo.add_undo_method(self, &"_set_proxy_edge_profile", null)
				undo_redo.add_undo_method(_profile, &"remove_edge_profile", _hover_screenful, _hover_side)
				undo_redo.commit_action()
				return

			_set_proxy_edge_profile(null)

			return

		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_drag = DragType.PAN if mb.pressed else DragType.NONE
			return

		var scroll := int(mb.button_index == MOUSE_BUTTON_WHEEL_DOWN) - int(mb.button_index == MOUSE_BUTTON_WHEEL_UP)
		if scroll != 0 and mb.pressed:
			_zoom = max(_zoom - scroll, 1)
			_update_zoom()

	var mm := event as InputEventMouseMotion
	if mm:
		if _drag == DragType.NONE:
			_update_hover()
			return

		# Drag.PAN
		_canvas.position += mm.relative


func _update_hover() -> void:
	if not _profile:
		_hover_valid = false
		return

	var screenful_size: Vector2 = ProjectSettings.get_setting("debug/procedural_metroidvania/screenful_minipreview_size")
	var mpos := _canvas.get_local_mouse_position()
	var s := mpos / screenful_size + Vector2(_profile.size) / 2
	var screenful: Vector2 = floor(s)
	var screenful_midpoint := screenful+Vector2(0.5, 0.5)
	var rel_pos := s - screenful_midpoint
	var angle := atan2(rel_pos.y, rel_pos.x)

	var side: EdgeProfile.EdgeSide
	if abs(angle) < PI/4: side = EdgeProfile.EdgeSide.EAST
	elif abs(angle) < PI*3/4:
		if angle < 0: side = EdgeProfile.EdgeSide.NORTH
		else: side = EdgeProfile.EdgeSide.SOUTH
	else: side = EdgeProfile.EdgeSide.WEST

	var prev_valid := _hover_valid
	var prev_screenful := _hover_screenful
	var prev_side := _hover_side
	_hover_valid = RoomProfile.is_edge_valid(screenful, side, _profile.size)
	if _hover_valid:
		_hover_screenful = screenful
		_hover_side = side
	if _hover_valid != prev_valid or _hover_screenful != prev_screenful or _hover_side != prev_side:
		_canvas.queue_redraw()


func _update_zoom() -> void:
	_canvas.scale = Vector2(_zoom, _zoom) if _zoom > 1 else Vector2(1, 1)
	_canvas.notification(CanvasItem.NOTIFICATION_LOCAL_TRANSFORM_CHANGED)
	_update_hover()


func _on_button_center_view_pressed() -> void:
	_canvas.position = Vector2()


func _on_zoom_reset_pressed() -> void:
	_zoom = 1
	_update_zoom()


func _on_button_remove_pressed() -> void:
	undo_redo.create_action("Room Profile Editor: Remove Edge Profile", UndoRedo.MERGE_DISABLE, _profile)
	undo_redo.force_fixed_history()
	undo_redo.add_do_method(self, &"_set_proxy_edge_profile", null)
	undo_redo.add_do_method(_profile, &"remove_edge_profile", _proxy.profile.position, _proxy.profile.side)
	undo_redo.add_undo_reference(_proxy.profile)
	undo_redo.add_undo_method(_profile, &"add_edge_profile", _proxy.profile)
	undo_redo.add_undo_method(self, &"_set_proxy_edge_profile", _proxy.profile)
	undo_redo.commit_action()


func _on_profile_resized(difference: Vector2i) -> void:
	for e: EdgeProfile in _profile.edges:
		if RoomProfile.is_edge_valid(e.position, e.side, _profile.size):
			continue

		var new_pos := e.position + difference
		var conflict := false
		for ee: EdgeProfile in _profile.edges:
			if ee.side == e.side and ee.position == new_pos:
				if _proxy.profile == e:
					_set_proxy_edge_profile(null)
				_profile.remove_edge_profile(e.position, e.side)
				conflict = true
				break

		if not conflict:
			#_set_edge_profile_position(e, new_pos)
			e.position = new_pos


func _on_profile_changed() -> void:
	_proxy.key_set = _profile.key_set if _profile else null
	_canvas.queue_redraw()


#func _add_edge_profile(edge_profile: EdgeProfile) -> void:
	#_profile.edges.push_back(edge_profile)
	#_canvas.queue_redraw()
#
#
#func _remove_edge_profile(edge_profile: EdgeProfile) -> void:
	#_profile.edges.erase(edge_profile)
	#if _proxy != null and edge_profile == _proxy.profile:
		#_proxy = null
	#_canvas.queue_redraw()


#func _set_edge_profile_position(edge_profile: EdgeProfile, new_position: Vector2i) -> void:
	#edge_profile.position = new_position


func _set_proxy_edge_profile(edge_profile: EdgeProfile) -> void:
	var prev := _proxy.profile
	_proxy.profile = edge_profile
	_button_remove.disabled = (edge_profile == null)
	if prev != edge_profile:
		_canvas.queue_redraw()


class EdgeProfileProxy:
	var key_set: KeySet: get = get_key_set, set = set_key_set
	var profile: EdgeProfile: get = get_profile, set = set_profile

	var _key_set: KeySet
	var _profile: EdgeProfile


	#func _init(key_set: KeySet, profile: EdgeProfile) -> void:
		#_key_set = key_set
		#_profile = profile


	func _get_property_list() -> Array[Dictionary]:
		var result: Array[Dictionary] = []

		if _profile == null:
			return result

		result.push_back({
			name = "optional",
			type = TYPE_BOOL,
			usage = PROPERTY_USAGE_EDITOR,
		})

		#result.push_back({
			#name = "key_choices",
			#type = TYPE_ARRAY,
			#usage = PROPERTY_USAGE_EDITOR,
			#hint = PROPERTY_HINT_ARRAY_TYPE,
			#hint_string = "StringName",
		#})

		result.push_back({
			name = "Key Choices",
			type = TYPE_NIL,
			usage = PROPERTY_USAGE_CATEGORY,
		})

		if key_set:
			for key: StringName in key_set.keys:
				result.push_back({
					name = "key_choices/{0}".format([key]),
					type = TYPE_BOOL,
					usage = PROPERTY_USAGE_DEFAULT,
				})

		return result


	func _get(property: StringName) -> Variant:
		if property == &"optional":# or property == &"key_choices":
			return _profile.get(property)

		if property.begins_with("key_choices/"):
			var key := property.split("/")[1]
			return key in _profile.key_choices

		return null


	func _set(property: StringName, value: Variant) -> bool:
		if property == &"optional":# or property == &"key_choices":
			_profile.set(property, value)
			return true

		if property.begins_with("key_choices/"):
			var parts := property.split("/")
			var key := parts[1]
			if value:
				if key not in _profile.key_choices:
					_profile.key_choices.push_back(key)
				return true
			else:
				_profile.key_choices.erase(key)
				return true

		return false


	func get_key_set() -> KeySet:
		return _key_set


	func set_key_set(value: KeySet) -> void:
		var prev := _key_set
		_key_set = value
		if prev != _key_set:
			notify_property_list_changed()


	func get_profile() -> EdgeProfile:
		return _profile


	func set_profile(value: EdgeProfile) -> void:
		var prev := _profile
		_profile = value
		if prev != profile:
			notify_property_list_changed()
