extends Node


@onready var map_generator := $MapGenerator as MapGenerator
@onready var map_visualizer := $Demo as MapVisualizer


func _ready() -> void:
	map_generator.generate()
	map_visualizer.map = map_generator.map
	map_visualizer.screenful_clicked.connect(_on_map_visualizer_screenful_clicked)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("generate"):
		map_generator.generate()
		map_visualizer.map = map_generator.map


func _on_map_visualizer_screenful_clicked(screenful: Vector2i) -> void:
	var initial_region = map_generator.map.root.find_region_containing_point(screenful)
	if initial_region == null:
		return

	map_generator._assign_gatings(initial_region.rect)
	map_visualizer.queue_redraw()
