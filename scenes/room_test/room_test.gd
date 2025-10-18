extends Node


@export var map_generator: MapGenerator

@onready var _viz_ui: VisualizerUi = %VisualizerUi


func _ready() -> void:
	assert(map_generator != null)
	map_generator.init()
	map_generator.viz = InteractiveVisualizer.new(_viz_ui)
	map_generator.generation_started.connect(_on_map_generator_generation_started)


func _process(_delta: float) -> void:
	if Input.is_key_pressed(KEY_P):
		breakpoint


func _populate_room_visuals() -> void:
	for r in map_generator.rooms:
		var visual := Node2D.new()
		visual.script = preload("res://scenes/room_test/room_visual.gd")
		visual.profile = r.profile
		visual.position = Vector2(r.position) * RoomVisual.SCREENFUL_SIZE
		add_child(visual)


func _on_map_generator_generation_started() -> void:
	_viz_ui.initialize(map_generator.rooms)


func _on_visualizer_ui_screenful_clicked(screenful: Vector2i) -> void:
	var room_contaning := map_generator._room_containing(screenful)
	var edges_at: Array[Edge]
	if room_contaning != null:
		edges_at = room_contaning.edges_at(screenful)
		print("Room at %s | Region: %s" % [room_contaning.position, room_contaning.region_key])
		if not edges_at.is_empty():
			var edge_faces := edges_at.map(
				func (e: Edge) -> String:
					return "%s %s" % [EdgeProfile.side_name(e.profile.side), e.concrete_type]
			)
			print("Edges at %s: %s" % [screenful, edge_faces])


func _on_visualizer_ui_generate_pressed() -> void:
	await map_generator.generate(10)
