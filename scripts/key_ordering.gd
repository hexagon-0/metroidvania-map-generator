@tool
class_name KeyOrdering
extends Resource


@export var key_set: KeySet
@export var follows: Dictionary[StringName, Array] = {}
@export var starting_key: StringName
@export_storage var scroll_offset: Vector2

var _nodes: Dictionary[int, KeyNode]
var _connections: Dictionary[int, Array] ## Output connections


func _get_property_list() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for id in _nodes:
		result.append({
			name = "nodes/{0}/position".format([id]),
			type = TYPE_VECTOR2,
			usage = PROPERTY_USAGE_STORAGE,
		})

		result.append({
			name = "nodes/{0}/key".format([id]),
			type = TYPE_STRING_NAME,
			usage = PROPERTY_USAGE_STORAGE,
		})

		result.append({
			name = "connections/{0}".format([id]),
			type = TYPE_ARRAY,
			#hint = PROPERTY_HINT_ARRAY_TYPE,
			#hint_string = "int",
			usage = PROPERTY_USAGE_STORAGE,
		})

	return result


func _get(property: StringName) -> Variant:
	if property.begins_with("nodes/"):
		var node_id := int(property.get_slice("/", 1))
		var node_property := property.get_slice("/", 2)
		if node_id not in _nodes:
			return null
		return _nodes[node_id][node_property]

	if property.begins_with("connections/"):
		var node_id := int(property.get_slice("/", 1))
		if node_id not in _connections:
			return null
		return _connections[node_id]

	return null


func _set(property: StringName, value: Variant) -> bool:
	if property.begins_with("nodes/"):
		var node_id := int(property.get_slice("/", 1))
		var node_property := property.get_slice("/", 2)
		if not _nodes.has(node_id):
			_nodes[node_id] = KeyNode.new("", Vector2())
		_nodes[node_id][node_property] = value
		return true

	if property.begins_with("connections/"):
		var node_id := int(property.get_slice("/", 1))
		_connections[node_id] = value
		return true

	return false


func add_node(id: int, key: StringName, pos: Vector2) -> void:
	var node := KeyNode.new(key, pos)
	_nodes[id] = node
	_connections[id] = []


func remove_node(id: int) -> void:
	_nodes.erase(id)
	_connections.erase(id)
	for from: int in _connections:
		_connections[from].erase(id)


func get_node(id: int) -> KeyNode:
	if id not in _nodes:
		return KeyNode.new("", Vector2())
	return _nodes[id]


func set_node_position(id: int, pos: Vector2) -> void:
	_nodes[id].position = pos


func set_node_key(id: int, key: StringName) -> void:
	_nodes[id].key = key


func connect_nodes(from: int, to: int) -> void:
	if to in _connections[from]:
		return

	_connections[from].push_back(to)


func disconnect_nodes(from: int, to: int) -> void:
	_connections[from].erase(to)


func get_valid_node_id() -> int:
	return 0 if _nodes.is_empty() else _nodes.keys().max() + 1


func _generate_public_properties() -> void:
	follows.clear()
	for id in _connections:
		var from := _nodes[id].key
		var to: Array[StringName] = _connections[id].map(
			func (idx): return _nodes[idx].key
		)
		follows[from] = to


class KeyNode:
	var key: StringName
	var position: Vector2

	func _init(p_key: StringName, p_position: Vector2) -> void:
		key = p_key
		position = p_position
