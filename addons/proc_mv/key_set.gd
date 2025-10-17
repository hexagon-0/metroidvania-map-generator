@tool
class_name KeySet
extends Resource


@export var keys: Array[StringName]: get = get_keys, set = set_keys

var _keys: Array[StringName]


func get_keys() -> Array[StringName]:
	return _keys


func set_keys(value: Array[StringName]) -> void:
	_keys = value
	_validate_keys()
	emit_changed()


func add_key(key: StringName) -> void:
	if key not in _keys:
		_keys.push_back(key)
		emit_changed()


func remove_key(key: StringName) -> void:
	var idx := _keys.find(key)
	if idx >= 0:
		_keys.remove_at(idx)
		emit_changed()


func _validate_keys() -> void:
	var found: Dictionary[StringName, bool]
	var i := 0
	while i < _keys.size():
		var key := _keys[i]
		if key in found:
			_keys.remove_at(i)
		else:
			found[key] = true
			i += 1
