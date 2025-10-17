extends Node


signal generation_started
signal generation_ended
signal generation_succeeded
signal generation_failed


const RoomInstance = preload("res://addons/proc_mv/room_profile/room_instance.gd")


@export var key_ordering: KeyOrdering
@export_enum("Array", "Directory") var room_pool_search_mode: String = "Array"
@export var room_pool_array: Array[PackedScene]
@export_dir var room_pool_directory: String
@export var finalizer_room_array: Array[PackedScene]

var viz: GenerationVisualizer
var _room_pool: Array[RoomProfile]
var _finalizer_room_pool: Array[RoomProfile]
var _rooms: Array[Room]
var _available_edges: Array[Edge] ## Edges currently open (not connected)
var _accessible_edges: Array[Edge] ## Edges open and usable for current key cycle
var _next_keys: Array[StringName]
var _current_key: StringName
var _keys_so_far: Array[StringName]

@onready var pool_root: Node = $Pool


func _ready() -> void:
	viz = InteractiveVisualizer.new(%VisualizerUi)
	#viz = GenerationVisualizer.new()

	_populate_room_pool()
	_populate_pool_from_array(_finalizer_room_pool, finalizer_room_array)
	#await generate(10)
	#_populate_room_visuals()


func _process(_delta: float) -> void:
	if Input.is_key_pressed(KEY_P):
		breakpoint


func _populate_room_pool() -> void:
	match room_pool_search_mode:
		"Array":
			_populate_pool_from_array(_room_pool, room_pool_array)

		"Directory":
			_populate_pool_from_directory(_room_pool, room_pool_directory)


func _populate_pool_from_array(pool: Array[RoomProfile], array: Array[PackedScene]) -> void:
	for scn: PackedScene in array:
		_add_profile_from_scene(pool, scn)


func _populate_pool_from_directory(pool: Array[RoomProfile], directory: String) -> void:
	var res_names := ResourceLoader.list_directory(directory)
	for scn_name: String in res_names:
		var scn_path := room_pool_directory.path_join(scn_name)
		if not ResourceLoader.exists(scn_path, "PackedScene"):
			continue

		var scn := ResourceLoader.load(scn_path, "PackedScene")
		_add_profile_from_scene(pool, scn)


func _add_profile_from_scene(pool: Array[RoomProfile], scn: PackedScene) -> void:
	var state := scn.get_state()
	for i in state.get_node_count():
		var is_root := state.get_node_path(i) == ^"."
		if not is_root:
			continue

		var is_room_instance := false
		var room_profile_prop_idx: int = -1

		for p in state.get_node_property_count(i):
			var prop_name := state.get_node_property_name(i, p)
			match prop_name:
				&"script":
					if state.get_node_property_value(i, p) == RoomInstance:
						is_room_instance = true
					else:
						break
				&"room_profile":
					room_profile_prop_idx = p

		if is_room_instance and room_profile_prop_idx >= 0:
			var room_profile = state.get_node_property_value(i, room_profile_prop_idx)
			pool.push_back(room_profile)


func generate(region_length: int, initial_room_template: RoomProfile = null) -> bool:
	var success := true
	_rooms = []
	_available_edges = []
	_accessible_edges = []
	_next_keys = [key_ordering.starting_key]
	_keys_so_far = []

	generation_started.emit()

	if initial_room_template == null:
		initial_room_template = _room_pool.front()

	assert(initial_room_template != null)

	var initial_room := Room.from_profile(initial_room_template)
	initial_room.position = Vector2i(0, 0)
	initial_room.region_key = key_ordering.starting_key
	_rooms.push_back(initial_room)
	_available_edges.append_array(initial_room.edges)
	_accessible_edges.append_array(initial_room.edges)

	await viz.try_place_room(initial_room, "Initial room")
	await viz.accept_place_room("Place initial room")

	while not _next_keys.is_empty():
		#var prev_key := _current_key
		_current_key = _pick_random(_next_keys)
		_next_keys.erase(_current_key)
		_keys_so_far.push_back(_current_key)

		# Start new region from an edge in previous region
		while true:
			if _accessible_edges.is_empty():
				success = false
				break

			var edge: Edge = _pick_random(_accessible_edges)

			var placement_info := await _try_add_room_to(edge, _room_pool)
			if placement_info.can_place:
				_accessible_edges.clear()
				_apply_fixes_add_room(placement_info.room, placement_info.fixes, _available_edges, _accessible_edges)
				_add_edges_to_available_list(placement_info.room, _available_edges, _accessible_edges)

				await viz.accept_place_room("Room placed")
				break
			else: # Erase if failed (if successful, will be erased during fixes)
				_accessible_edges.erase(edge)
		if not success:
			break

		var remaining := region_length
		while not _accessible_edges.is_empty() and remaining > 0:
			var edge: Edge = _pick_random(_accessible_edges)

			var placement_info := await _try_add_room_to(edge, _room_pool)
			if placement_info.can_place:
				_apply_fixes_add_room(placement_info.room, placement_info.fixes, _available_edges, _accessible_edges)
				_add_edges_to_available_list(placement_info.room, _available_edges, _accessible_edges)

				await viz.accept_place_room("Room placed")
				remaining -= 1
			else: # If successful, it will be erased during fixes
				_accessible_edges.erase(edge)

		if remaining > 0:
			success = false
			break

		var follows: Array = key_ordering.follows.get(_current_key, [])
		_next_keys.append_array(follows.duplicate())

	if success:
		var i := 0
		while i < _available_edges.size():
			var e := _available_edges[i]
			if e.profile.optional:
				e.concrete_type = &"closed"
				_available_edges.remove_at(i)
			else:
				var placement_info := await _try_add_room_to(e, _finalizer_room_pool)
				if placement_info.can_place:
					_apply_fixes_add_room(placement_info.room, placement_info.fixes, _available_edges, _accessible_edges)
					_add_edges_to_available_list(placement_info.room, _available_edges, _accessible_edges)

					await viz.accept_place_room("Room placed")
				else:
					i += 1

	await viz.message("Generation finished")
	print("Generation successful" if success else "Generation failed")
	print("Total rooms: %s" % [_rooms.size()])
	print("Open edges: %s" % [_available_edges.size()])
	print("Final key order: %s" % [_keys_so_far])
	generation_ended.emit()
	return success


## Whether key is an ancestor of the current key
func _key_accessible(key: StringName) -> bool:
	return key in _keys_so_far


func _try_add_room_to(edge: Edge, pool: Array[RoomProfile]) -> Dictionary:
	var edge_compatible_fn := func (e: EdgeProfile) -> bool:
		return edge.profile.connects(e)
	var candidates: Array[RoomProfile]
	for tpl in pool: # _room_pool
		if tpl.edges.any(edge_compatible_fn):
			candidates.push_back(tpl)

	while not (edge.connected or candidates.is_empty()):
		var chosen_room: RoomProfile = _pick_random(candidates)
		candidates.erase(chosen_room)

		var possible_edges: Array[EdgeProfile] = (
			chosen_room.edges.filter(edge_compatible_fn)
		)

		for chosen_edge in possible_edges:
			var room := Room.from_profile(chosen_room)
			room.region_key = _current_key
			room.position = edge.connection_position() - chosen_edge.position

			await viz.try_place_room(room, "Trying to place room")

			var placement_info := _evaluate_placement(room)

			if placement_info.can_place:
				placement_info.room = room
				return placement_info

			await viz.reject_place_room("Failed to place room")

	return { can_place = false }


## Tests whether the room can be placed at position [code]room.position[/code].
## Resolves connections involving the perimeter and their keys, but does not
## apply any modifications, only returns an array of pending fixes.
func _evaluate_placement(room: Room) -> Dictionary:
	if _check_collision(room):
		return { can_place = false }

	var fixes = []
	var perimeter := room.get_perimeter()
	for e: Edge in perimeter:
		var conn_pos := e.connection_position()
		var conn_room := _room_containing(conn_pos)
		# If no room at conn_pos then it's free space
		if conn_room == null:
			continue
		var conn_edges := conn_room.edges_at(conn_pos)

		var e_is_closed := e.concrete_type == &"closed"
		# If we can't find a matching edge, default to true when closed, false
		# otherwise
		var connection_possible := e_is_closed
		var has_facing_edge := false
		for ce: Edge in conn_edges:
			if not ce.profile.connects(e.profile):
				continue
			has_facing_edge = true
			connection_possible = _evaluate_connection(e, ce, fixes)
			break

		if not connection_possible:
			if e.profile.optional and not has_facing_edge:
				fixes.push_back({
					to_edge = e,
					to_type = &"closed",
				})
			else:
				return { can_place = false }

	return { can_place = true, fixes = fixes }


func _evaluate_connection(e: Edge, ce: Edge, fixes: Array) -> bool:
	if e.concrete_type == &"closed":
		if not ce.profile.optional:
			return false

		fixes.push_back({
			to_edge = ce,
			to_type = &"closed",
		})
		return true

	var possible_from_type = e.profile.key_choices.filter(_keys_so_far.has)
	if possible_from_type.is_empty():
		return false
	var possible_to_type

	var to_type
	if ce.room.region_key == e.room.region_key:
		possible_to_type = ce.profile.key_choices.filter(_keys_so_far.has)
		if possible_to_type.is_empty():
			return false
		to_type = &"key:" + _pick_random(possible_to_type)
	else:
		if e.room.region_key not in ce.profile.key_choices:
			return false

		to_type = &"key:" + e.room.region_key

	fixes.push_back({
		from_edge = e,
		#from_type = &"key:neutral",
		from_type = &"key:" + _pick_random(possible_from_type),
		to_edge = ce,
		#to_type = &"key:neutral",
		to_type = to_type,
	})

	return true


## Applies [param fixes], adds [param room] to [member _rooms] and erases any fixed edges from
## [param available] and [param accessible].
func _apply_fixes_add_room(room: Room, fixes: Array, available: Array[Edge], accessible: Array[Edge]) -> void:
	for fix in fixes:
		if "from_edge" in fix:
			fix.from_edge.connected_to = fix.to_edge
			fix.from_edge.concrete_type = fix.from_type
			fix.to_edge.connected_to = fix.from_edge
		fix.to_edge.concrete_type = fix.to_type
		available.erase(fix.to_edge)
		if fix.to_edge.room.region_key == _current_key:
			accessible.erase(fix.to_edge)

	#room.region_key = _current_key
	_rooms.push_back(room)


func _add_edges_to_available_list(room: Room, available: Array[Edge], accessible: Array[Edge]) -> void:
	for e: Edge in room.edges:
		if e.concrete_type == &"undefined":
			available.push_back(e)
			accessible.push_back(e)


func _check_collision(room: Room) -> bool:
	var rect := room.get_rect()
	for other in _rooms:
		if rect.intersects(other.get_rect()):
			return true

	return false


func _room_containing(screenful: Vector2i) -> Room:
	for room in _rooms:
		var rect := Rect2i(room.position, room.profile.size)
		if rect.has_point(screenful):
			return room

	return null


func _pick_random(a: Array) -> Variant:
	return a.pick_random() # TODO: use seedable RNG


# ====================
# = END OF ALGORITHM =
# ====================


func _populate_room_visuals() -> void:
	for r in _rooms:
		var visual := Node2D.new()
		visual.script = preload("res://scenes/room_test/room_visual.gd")
		visual.profile = r.profile
		visual.position = Vector2(r.position) * RoomVisual.SCREENFUL_SIZE
		add_child(visual)


func _on_visualizer_ui_screenful_clicked(screenful: Vector2i) -> void:
	var room_contaning := _room_containing(screenful)
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
	await generate(10)
