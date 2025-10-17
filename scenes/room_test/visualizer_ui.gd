class_name VisualizerUi
extends Control


signal step
signal screenful_clicked(screenful: Vector2i)
signal generate_pressed


enum WidgetState { EVALUATION, ACCEPTED, REJECTED }


const RoomTest = preload("res://scenes/room_test/room_test.gd")
const SCREENFUL_SIZE := Vector2(16, 8)
const WALL_WIDTH := 2.0
const DEFAULT_ROOM_STROKE := Color.DARK_SLATE_BLUE
const DEFAULT_ROOM_FILL := Color.CORNFLOWER_BLUE
const DEFAULT_EDGE_STROKE := Color.GOLDENROD
const DEFAULT_BLUEPRINT_ALPHA := 0.6
const DEFAULT_ACCEPT_COLOR := Color(Color.CHARTREUSE, 0.5)
const DEFAULT_REJECT_COLOR := Color(Color.CRIMSON, 0.5)

@export var room_test: RoomTest

var _run_to_completion: bool = false
#var _rooms: Array[Room]
var _room_blueprints: Array[RoomBlueprint]
var _int_offset: Vector2:
	get: return floor(_offset)
var _overlay := false

@warning_ignore("integer_division")
@onready var _offset: Vector2 = Vector2(
	get_tree().root.size.x / 2,
	get_tree().root.size.y / 2,
):
	get: return _offset
	set(value):
		var prev_int_offset := _int_offset
		_offset = value
		if prev_int_offset != _int_offset:
			queue_redraw()
@onready var _zoom: int = 1:
	get: return _zoom
	set(value):
		var prev := _zoom
		_zoom = maxi(value, 1)
		scale = Vector2i(_zoom, _zoom)
		if prev != value:
			queue_redraw()
@onready var _message_label: Label = %Message


#func _ready() -> void:
	#for key: StringName in [&"neutral", &"slide", &"dive", &"double_jump", &"super_jump"]:
		#print(key, ": ", _get_key_color(key))


func _physics_process(delta: float) -> void:
	var pan_speed := 200.0
	var input_movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_offset -= input_movement * pan_speed * delta


func _draw() -> void:
	#for r in _rooms:
	for r: Room in room_test._rooms:
		if _overlay:
			var fill := _get_key_color(r.region_key)
			var stroke := fill.darkened(0.2)
			_draw_room(r, stroke, fill)
		else:
			_draw_room(r)

		for e in r.edges:
			_draw_edge(e)

	for bp in _room_blueprints:
		var bp_room_stroke := DEFAULT_ROOM_STROKE
		var bp_room_fill := DEFAULT_ROOM_FILL
		var bp_edge_stroke := DEFAULT_EDGE_STROKE

		match bp.state:
			WidgetState.EVALUATION:
				bp_room_stroke = Color(bp_room_stroke, DEFAULT_BLUEPRINT_ALPHA)
				bp_room_fill = Color(bp_room_fill, DEFAULT_BLUEPRINT_ALPHA)
				bp_edge_stroke = Color(bp_edge_stroke, DEFAULT_BLUEPRINT_ALPHA)
			WidgetState.ACCEPTED:
				bp_room_stroke = bp_room_stroke.blend(DEFAULT_ACCEPT_COLOR)
				bp_room_fill = bp_room_fill.blend(DEFAULT_ACCEPT_COLOR)
				bp_edge_stroke = bp_edge_stroke.blend(DEFAULT_ACCEPT_COLOR)
			WidgetState.REJECTED:
				bp_room_stroke = bp_room_stroke.blend(DEFAULT_REJECT_COLOR)
				bp_room_fill = bp_room_fill.blend(DEFAULT_REJECT_COLOR)
				bp_edge_stroke = bp_edge_stroke.blend(DEFAULT_REJECT_COLOR)

		_draw_room(bp.room, bp_room_stroke, bp_room_fill)
		for e in bp.room.edges:
			_draw_edge(e, bp_edge_stroke)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"select"):
		var screenful: Vector2i = floor((get_local_mouse_position() - _int_offset) / SCREENFUL_SIZE)
		print("Screenful clicked: ", screenful)
		screenful_clicked.emit(screenful)
	elif event.is_action_pressed(&"overlay"):
		_overlay = not _overlay
		queue_redraw()
	#elif event.is_action_pressed(&"zoom_in"):
		#_zoom += 1
	#elif event.is_action_pressed(&"zoom_out"):
		#_zoom -= 1


func initialize() -> void:
	_run_to_completion = false
	_room_blueprints = []


func step_or_complete() -> Variant:
	if _run_to_completion:
		_clear()
		return null

	return step


func set_message(message: String) -> void:
	_message_label.text = message


func try_place_room(room: Room) -> void:
	var blueprint := RoomBlueprint.new(room)
	_room_blueprints.push_back(blueprint)
	queue_redraw()


func accept_place_room() -> void:
	_room_blueprints.back().state = WidgetState.ACCEPTED
	queue_redraw()


func reject_place_room() -> void:
	_room_blueprints.back().state = WidgetState.REJECTED
	queue_redraw()


func _draw_room(room: Room, stroke := Color.DARK_SLATE_BLUE, fill := Color.CORNFLOWER_BLUE) -> void:
	draw_rect(Rect2i(Vector2(room.position) * SCREENFUL_SIZE+_int_offset, Vector2(room.profile.size) * SCREENFUL_SIZE), fill)
	draw_rect(Rect2i(Vector2(room.position) * SCREENFUL_SIZE+_int_offset, Vector2(room.profile.size) * SCREENFUL_SIZE), stroke, false, WALL_WIDTH)


func _draw_edge(edge: Edge, stroke := Color.GOLDENROD) -> void:
	if edge.concrete_type == &"closed":
		return

	var from: Vector2 = edge.profile.position + edge.room.position
	var to: Vector2 = edge.profile.position + edge.room.position
	var margin: Vector2

	match edge.profile.side:
		EdgeProfile.EdgeSide.NORTH, EdgeProfile.EdgeSide.SOUTH:
			to.x += 1

			if edge.profile.side == EdgeProfile.EdgeSide.SOUTH:
				from.y += 1
				to.y += 1

			margin = Vector2(WALL_WIDTH/2, 0)

		EdgeProfile.EdgeSide.EAST, EdgeProfile.EdgeSide.WEST:
			to.y += 1

			if edge.profile.side == EdgeProfile.EdgeSide.EAST:
				from.x += 1
				to.x += 1

			margin = Vector2(0, WALL_WIDTH/2)

	draw_line(from*SCREENFUL_SIZE+margin+_int_offset, to*SCREENFUL_SIZE-margin+_int_offset, stroke, WALL_WIDTH)


func _clear() -> void:
	if not _room_blueprints.is_empty() and _room_blueprints.back().state != WidgetState.EVALUATION:
		var bp: RoomBlueprint = _room_blueprints.pop_back()
		#if bp.state == WidgetState.ACCEPTED:
			#_rooms.push_back(bp.room)

	_message_label.text = ""


func _step_generation() -> void:
	_clear()
	step.emit()


func _on_step_pressed() -> void:
	_step_generation()


func _on_complete_pressed() -> void:
	_run_to_completion = true
	_step_generation()


func _get_key_color(key: StringName) -> Color:
	var i := key.hash()

	var color := Color.GREEN
	color.h += fmod(0.42 * i, 1.0)

	return color


class RoomBlueprint:
	var room: Room
	var state: WidgetState = WidgetState.EVALUATION


	func _init(p_room: Room) -> void:
		room = p_room


func _on_generate_pressed() -> void:
	generate_pressed.emit()
