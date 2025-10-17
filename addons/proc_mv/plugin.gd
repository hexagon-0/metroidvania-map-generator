@tool
extends EditorPlugin


const PLUGIN_NAME := "proc_mv"
const SUB_PLUGINS := ["key_ordering", "room_profile"]


func _enable_plugin() -> void:
	for sub_plugin in SUB_PLUGINS:
		var s := "%s/%s" % [PLUGIN_NAME, sub_plugin]
		EditorInterface.set_plugin_enabled(s, true)


func _disable_plugin() -> void:
	var reversed_sub_plugins = SUB_PLUGINS.duplicate()
	reversed_sub_plugins.reverse()
	for sub_plugin in reversed_sub_plugins:
		var s := "%s/%s" % [PLUGIN_NAME, sub_plugin]
		EditorInterface.set_plugin_enabled(s, false)
