@tool
extends Control


const GraphEditor = preload("res://addons/proc_mv/key_ordering/graph_editor.gd")
const KeyNode = preload("res://addons/proc_mv/key_ordering/key_node.gd")

var undo_redo: EditorUndoRedoManager

var _key_ordering: KeyOrdering
var _links: Dictionary[int, Dictionary]

@onready var _graph_editor: GraphEditor = %GraphEditor
@onready var _key_list: Control = %KeyList


func _ready() -> void:
	_graph_editor.plugin = self
	_graph_editor.undo_redo = undo_redo

	var panel := _key_list.get_parent() as PanelContainer
	panel.add_theme_stylebox_override(&"panel", panel.get_theme_stylebox(&"sub_inspector_bg_no_border", &"EditorStyles"))


func edit(object: KeyOrdering) -> void:
	if object == _key_ordering:
		return

	_clear_graph_editor()
	_clear_key_list()
	_links.clear()

	_key_ordering = object
	_graph_editor.key_ordering = _key_ordering

	if _key_ordering == null:
		return

	_graph_editor._updating = true
	_graph_editor.scroll_offset = _key_ordering.scroll_offset

	_populate_key_list()

	for id in _key_ordering._nodes:
		add_node(id)

	for from: int in _key_ordering._connections:
		for to: int in _key_ordering._connections[from]:
			connect_nodes(from, to)

	_graph_editor._updating = false


func add_node(id: int) -> void:
	var key_node := _key_ordering.get_node(id)
	var node := KeyNode.new()
	node.name = str(id)
	node.key = key_node.key
	node.position_offset = key_node.position
	node.dragged.connect(_graph_editor._on_node_dragged.bind(id))
	node.key_changed.connect(_graph_editor._on_node_key_changed.bind(id))
	_links[id] = { graph_node = node, key_node = key_node }
	_graph_editor.add_child(node)


func remove_node(id: int) -> void:
	var node: Node = _links[id].graph_node
	_graph_editor.remove_child(node)
	_links.erase(id)


func set_node_position(id: int, pos: Vector2) -> void:
	var node: GraphElement = _links[id].graph_node
	node.position_offset = pos


func set_node_key(id: int, key: StringName) -> void:
	var node: KeyNode = _links[id].graph_node
	node.key = key


func connect_nodes(from: int, to: int) -> void:
	_graph_editor.connect_node(_links[from].graph_node.name, 0, _links[to].graph_node.name, 0)


func disconnect_nodes(from: int, to: int) -> void:
	_graph_editor.disconnect_node(_links[from].graph_node.name, 0, _links[to].graph_node.name, 0)


func _clear_graph_editor() -> void:
	var i := 0
	while i < _graph_editor.get_child_count():
		var c := _graph_editor.get_child(i)
		if c is GraphElement:
			_graph_editor.remove_child(c)
			i -= 1
		i += 1


func _clear_key_list() -> void:
	while _key_list.get_child_count() > 0:
		_key_list.remove_child(_key_list.get_child(0))


func _populate_key_list() -> void:
	for key: StringName in _key_ordering.key_set.keys:
		var button := Button.new()
		button.flat = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = key
		_key_list.add_child(button)
