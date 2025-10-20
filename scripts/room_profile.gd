@tool
class_name RoomProfile
extends Resource


signal resized(difference: Vector2)


@export var key_set: KeySet: get = get_key_set, set = set_key_set

@export var size: Vector2i = Vector2i(1, 1): get = get_size, set = set_size

@export var edges: Array[EdgeProfile]: get = get_edges, set = set_edges


var _key_set: KeySet
var _size: Vector2i
var _edges: Array[EdgeProfile]


static func is_edge_valid(edge_offset: Vector2i, edge_side: EdgeProfile.EdgeSide, room_size: Vector2i) -> bool:
	var delta := EdgeProfile.side_facing_dir(edge_side)
	var dest := edge_offset + delta
	var room_extents := Rect2i(Vector2(0, 0), room_size)
	return room_extents.has_point(edge_offset) and not room_extents.has_point(dest)


func get_size() -> Vector2i:
	return _size


func set_size(value: Vector2i) -> void:
	var prev_size := _size
	_size = value
	resized.emit(_size - prev_size)
	emit_changed()


func get_edges() -> Array[EdgeProfile]:
	return _edges


func set_edges(value: Array[EdgeProfile]) -> void:
	for e in _edges:
		if e and e.changed.is_connected(emit_changed):
			e.changed.disconnect(emit_changed)
	_edges = value
	for e in _edges:
		if e and not e.changed.is_connected(emit_changed):
			e.changed.connect(emit_changed)
	emit_changed()


func get_key_set() -> KeySet:
	return _key_set


func set_key_set(value: KeySet) -> void:
	_key_set = value
	emit_changed()


func get_edge_at(offset: Vector2i, side: EdgeProfile.EdgeSide) -> EdgeProfile:
	for e in _edges:
		if e.position == offset and e.side == side:
			return e
	return null


func add_edge_profile(edge_profile: EdgeProfile) -> void:
	edges.push_back(edge_profile)
	emit_changed()


func remove_edge_profile(offset: Vector2i, side: EdgeProfile.EdgeSide) -> void:
	for i in _edges.size():
		var e := _edges[i]
		if e.position == offset and e.side == side:
			_edges.remove_at(i)
			emit_changed()
			break
