class_name Edge
extends RefCounted


var room: Room:
	get: return _room.get_ref()
	set(value):
		_room = weakref(value)
var profile: EdgeProfile
var connected_to: Edge
var connected: bool:
	get: return connected_to != null
var concrete_type: StringName = &"undefined" ## Valid values: &"undefined", &"closed", &"key:my_key"

var _room: WeakRef


func connection_position() -> Vector2i:
	return room.position + profile.connection_position()
