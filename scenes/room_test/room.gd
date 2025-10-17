class_name Room
extends RefCounted


var position: Vector2i
var profile: RoomProfile
var edges: Array[Edge]
#var highest_keys: Array[StringName]
var region_key: StringName


@warning_ignore("shadowed_variable")
static func from_profile(profile: RoomProfile) -> Room:
	var room := Room.new()
	room.profile = profile

	for edge_template in profile.edges:
		var edge := Edge.new()
		edge.room = room
		edge.profile = edge_template
		room.edges.push_back(edge)

	return room


func get_rect() -> Rect2i:
	return Rect2i(position, profile.size)


func edges_at(screenful: Vector2i) -> Array[Edge]:
	var local_offset := screenful - position
	return edges.filter(
		func (e: Edge): return e.profile.position == local_offset
	)


func get_perimeter() -> Array[Edge]:
	var result: Array[Edge] = []

	for side_key in EdgeProfile.EdgeSide:
		var side: EdgeProfile.EdgeSide = EdgeProfile.EdgeSide[side_key]
		var from: Vector2i
		var to: Vector2i
		var inc: Vector2i
		match side:
			EdgeProfile.EdgeSide.NORTH:
				from = Vector2i(0, 0)
				to = Vector2i(profile.size.x, 0)
				inc = Vector2i(1, 0)
			EdgeProfile.EdgeSide.SOUTH:
				from = Vector2i(0, profile.size.y - 1)
				to = Vector2i(profile.size.x, profile.size.y - 1)
				inc = Vector2i(1, 0)
			EdgeProfile.EdgeSide.EAST:
				from = Vector2i(profile.size.x - 1, 0)
				to = Vector2i(profile.size.x - 1, profile.size.y)
				inc = Vector2i(0, 1)
			EdgeProfile.EdgeSide.WEST:
				from = Vector2i(0, 0)
				to = Vector2i(0, profile.size.y)
				inc = Vector2i(0, 1)

		while from != to:
			var edge_here := false
			for e in edges:
				if e.profile.position == from and e.profile.side == side:
					edge_here = true
					result.push_back(e)
					break

			if not edge_here:
				var fake_edge := Edge.new()
				fake_edge.room = self
				fake_edge.concrete_type = &"closed"
				fake_edge.profile = EdgeProfile.new()
				fake_edge.profile.side = side
				fake_edge.profile.position = from
				result.push_back(fake_edge)

			from += inc

	return result
