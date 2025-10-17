@tool
extends GraphEdit


const Plugin = preload("res://addons/proc_mv/key_ordering/key_ordering_editor.gd")
const KeyNode = preload("res://addons/proc_mv/key_ordering/key_node.gd")

var plugin: Plugin
var undo_redo: EditorUndoRedoManager
var key_ordering: KeyOrdering

var _add_node_dialog: PopupMenu
var _mouse_pos_on_click: Vector2
var _updating := false


func _ready() -> void:
	_add_node_dialog = PopupMenu.new()
	_add_node_dialog.id_pressed.connect(_on_add_node_dialog_id_pressed)
	_add_node_dialog.add_item("Add node", 0, KEY_A)
	add_child(_add_node_dialog)

	delete_nodes_request.connect(_on_delete_nodes_request)
	connection_request.connect(_on_connection_request)
	disconnection_request.connect(_on_disconnection_request)

	scroll_offset_changed.connect(_on_scroll_offset_changed)


func _exit_tree() -> void:
	pass


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_RIGHT:
		_mouse_pos_on_click = scroll_offset + get_local_mouse_position()
		_add_node_dialog.position = get_screen_position() + get_local_mouse_position()
		_add_node_dialog.popup()


func _add_node(pos: Vector2) -> void:
	undo_redo.create_action("Add KeyOrdering node")
	var id := key_ordering.get_valid_node_id()
	undo_redo.add_do_method(key_ordering, &"add_node", id, "", pos)
	undo_redo.add_undo_method(key_ordering, &"remove_node", id)
	undo_redo.add_do_method(plugin, &"add_node", id)
	undo_redo.add_undo_method(plugin, &"remove_node", id)
	undo_redo.commit_action()


func _on_add_node_dialog_id_pressed(id: int) -> void:
	if id != 0:
		return

	_add_node(_mouse_pos_on_click)


func _on_delete_nodes_request(node_names: Array[StringName]) -> void:
	undo_redo.create_action("Delete KeyNode(s)")
	for id_str in node_names:
		var id := int(id_str)
		var node: KeyNode = get_node(NodePath(id_str))
		undo_redo.add_do_method(key_ordering, &"remove_node", id)
		undo_redo.add_undo_method(key_ordering, &"add_node", id, node.key, node.position_offset)
		undo_redo.add_do_method(plugin, &"remove_node", id)
		undo_redo.add_undo_method(plugin, &"add_node", id)
	undo_redo.commit_action()


func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	var from := from_node.to_int()
	var to := to_node.to_int()

	undo_redo.create_action("Connect nodes")

	# Disconnect to's input if connected
	for id: int in key_ordering._connections:
		if to in key_ordering._connections[id]:
			undo_redo.add_do_method(key_ordering, &"disconnect_nodes", id, to)
			undo_redo.add_undo_method(key_ordering, &"connect_nodes", id, to)
			undo_redo.add_do_method(plugin, &"disconnect_nodes", id, to)
			undo_redo.add_undo_method(plugin, &"connect_nodes", id, to)
			break

	# Connect
	undo_redo.add_do_method(key_ordering, &"connect_nodes", from, to)
	undo_redo.add_undo_method(key_ordering, &"disconnect_nodes", from, to)
	undo_redo.add_do_method(plugin, &"connect_nodes", from, to)
	undo_redo.add_undo_method(plugin, &"disconnect_nodes", from, to)

	undo_redo.commit_action()


func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	var from := from_node.to_int()
	var to := to_node.to_int()

	undo_redo.create_action("Disconnect nodes")
	undo_redo.add_do_method(key_ordering, &"disconnect_nodes", from, to)
	undo_redo.add_undo_method(key_ordering, &"connect_nodes", from, to)
	undo_redo.add_do_method(plugin, &"disconnect_nodes", from, to)
	undo_redo.add_undo_method(plugin, &"connect_nodes", from, to)
	undo_redo.commit_action()


func _on_node_dragged(from: Vector2, to: Vector2, id: int) -> void:
	undo_redo.create_action("Move KeyOrdering node")
	undo_redo.add_do_method(key_ordering, &"set_node_position", id, to)
	undo_redo.add_undo_method(key_ordering, &"set_node_position", id, from)
	undo_redo.add_do_method(plugin, &"set_node_position", id, to)
	undo_redo.add_undo_method(plugin, &"set_node_position", id, from)
	undo_redo.commit_action(false)

	key_ordering.set_node_position(id, to)


func _on_node_key_changed(new_key: StringName, id: int) -> void:
	var old_key := key_ordering.get_node(id).key

	undo_redo.create_action("Set KeyNode key", UndoRedo.MERGE_ENDS)
	undo_redo.add_do_method(key_ordering, &"set_node_key", id, new_key)
	undo_redo.add_undo_method(key_ordering, &"set_node_key", id, old_key)
	undo_redo.add_do_method(plugin, &"set_node_key", id, new_key)
	undo_redo.add_undo_method(plugin, &"set_node_key", id, old_key)
	undo_redo.commit_action(false)

	key_ordering.set_node_key(id, new_key)


func _on_scroll_offset_changed(value: Vector2) -> void:
	if _updating or key_ordering == null:
		return

	key_ordering.scroll_offset = value
