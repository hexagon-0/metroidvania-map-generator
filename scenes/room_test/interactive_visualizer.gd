class_name InteractiveVisualizer
extends GenerationVisualizer


var ui: VisualizerUi


func _init(p_ui: VisualizerUi) -> void:
	ui = p_ui


func try_place_room(room: Room, msg: String) -> Variant:
	ui.set_message(msg)
	ui.try_place_room(room)
	return ui.step_or_complete()


func accept_place_room(msg: String) -> Variant:
	ui.set_message(msg)
	ui.accept_place_room()
	return ui.step_or_complete()


func reject_place_room(msg: String) -> Variant:
	ui.set_message(msg)
	ui.reject_place_room()
	return ui.step_or_complete()
