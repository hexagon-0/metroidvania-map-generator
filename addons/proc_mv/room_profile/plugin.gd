@tool
extends EditorPlugin


const ScnRoomProfileEditor = preload("res://addons/proc_mv/room_profile/room_profile_editor.tscn")
const RoomProfileEditor = preload("res://addons/proc_mv/room_profile/room_profile_editor.gd")

var _editor: RoomProfileEditor
var _button: Button


func _enter_tree() -> void:
	_editor = ScnRoomProfileEditor.instantiate() as RoomProfileEditor
	_editor.undo_redo = get_undo_redo()
	_button = add_control_to_bottom_panel(_editor, "Room Profile")
	_button.hide()


func _exit_tree() -> void:
	remove_control_from_bottom_panel(_editor)
	_editor.queue_free()


func _handles(object: Object) -> bool:
	return object is RoomProfile


func _edit(object: Object) -> void:
	_editor.edit(object as RoomProfile)


func _make_visible(visible: bool) -> void:
	_button.visible = visible
	if visible:
		make_bottom_panel_item_visible(_editor)
	elif not visible and _editor.is_visible_in_tree():
		hide_bottom_panel()
