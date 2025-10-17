@tool
extends GraphNode


signal key_changed(new_key: String)


const START_NODE_TITLEBAR_STYLEBOX = preload("res://addons/proc_mv/key_ordering/start_node_titlebar_stylebox.tres")


var is_start: bool:
	get: return _is_start
	set(value):
		_is_start = value
		_update_is_start

var key: StringName: get = get_key, set = set_key

var _key: StringName
var _is_start: bool = false
var _input: LineEdit


func _init() -> void:
	var hbox := HBoxContainer.new()
	add_child(hbox)

	var label := Label.new()
	label.text = tr("Name")
	hbox.add_child(label)

	_input = LineEdit.new()
	_input.add_theme_constant_override(&"minimum_character_width", 8)
	_input.text_changed.connect(_set_key)
	hbox.add_child(_input)

	set_slot_enabled_right(0, true)
	_update_is_start()


func get_key() -> StringName:
	return _key


func set_key(value: StringName) -> void:
	_key = value
	_input.text = _key


func _set_key(value: StringName) -> void:
	key_changed.emit(value)
	_key = value


func _update_is_start() -> void:
	set_slot_enabled_left(0, not _is_start)
	if _is_start:
		add_theme_stylebox_override("titlebar", START_NODE_TITLEBAR_STYLEBOX)
	else:
		remove_theme_stylebox_override("titlebar")
