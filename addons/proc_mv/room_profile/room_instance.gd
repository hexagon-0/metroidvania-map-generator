@tool
extends Node2D


@export var room_profile: RoomProfile: get = get_room_profile, set = set_room_profile

@export_tool_button("Update")
var _update := self._update_guides

var _room_profile: RoomProfile


static func _get_extents(node: Node, former_rect: Rect2) -> Rect2:
	if node is TileMapLayer:
		var xform := Transform2D(0, node.tile_set.tile_size, 0, Vector2())
		former_rect = former_rect.merge(xform * Rect2(node.get_used_rect()))

	for c: Node in node.get_children():
		former_rect = _get_extents(c, former_rect)

	return former_rect


func _ready() -> void:
	_connect_tilemap_signals(self)


func _draw() -> void:
	if not Engine.is_editor_hint():
		return

	var screenful_size = ProjectSettings.get_setting("debug/procedural_metroidvania/screenful_size", Vector2(800, 600))
	var extents := _get_extents(self, Rect2())
	extents.position = extents.position.snapped(screenful_size)
	extents.size = extents.size.snapped(screenful_size).max(screenful_size)
	var color := ProjectSettings.get_setting("debug/procedural_metroidvania/room_extents_color", Color("6ddaa2"))
	draw_rect(extents, color, false, -1)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if room_profile:
		var screenful_size = ProjectSettings.get_setting("debug/procedural_metroidvania/screenful_size", Vector2(800, 600))
		var extents := _get_extents(self, Rect2())
		#extents.position = extents.position.snapped(screenful_size) / screenful_size
		extents.size = extents.size.snapped(screenful_size).max(screenful_size) / screenful_size

		if Vector2i(extents.size) != room_profile.size:
			warnings.push_back("Tilemap used area {0} mismatches room profile size {1}".format([extents.size, room_profile.size]))
	else:
		warnings.push_back("No room profile assigned")

	return warnings


func get_room_profile() -> RoomProfile:
	return _room_profile


func set_room_profile(value: RoomProfile) -> void:
	if value == _room_profile:
		return

	if _room_profile:
		_room_profile.changed.disconnect(_on_room_profile_changed)

	_room_profile = value

	if _room_profile:
		_room_profile.changed.connect(_on_room_profile_changed)


func _connect_tilemap_signals(node: Node) -> void:
	if node is TileMapLayer:
		node.changed.connect(_on_tilemap_changed)

	for c: Node in node.get_children():
		_connect_tilemap_signals(c)


func _on_room_profile_changed() -> void:
	_update_guides()


func _on_tilemap_changed() -> void:
	_update_guides()


func _update_guides() -> void:
	update_configuration_warnings()
	queue_redraw()
