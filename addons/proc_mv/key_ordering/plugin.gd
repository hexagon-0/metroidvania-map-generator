@tool
extends EditorPlugin


const ScnKeyOrderingEditor = preload("uid://7oingyvnvegj")
const KeyOrderingEditor = preload("uid://h56ums6clypw")

var _editor: KeyOrderingEditor
var _button: Button


func _enter_tree() -> void:
	_editor = ScnKeyOrderingEditor.instantiate() as KeyOrderingEditor
	_editor.undo_redo = get_undo_redo()
	_button = add_control_to_bottom_panel(_editor, "Key Order")
	_button.hide()


func _exit_tree() -> void:
	remove_control_from_bottom_panel(_editor)
	_editor.queue_free()


func _handles(object: Object) -> bool:
	return object is KeyOrdering


func _edit(object: Object) -> void:
	_editor.edit(object as KeyOrdering)


func _make_visible(visible: bool) -> void:
	_button.visible = visible
	if not visible and _editor.is_visible_in_tree():
		hide_bottom_panel()
