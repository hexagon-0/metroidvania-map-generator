@tool
class_name RoomVisual
extends CanvasItem


const SCREENFUL_SIZE := Vector2(16, 8)
const WALL_WIDTH := 2.0

@export var profile: RoomProfile:
	get:
		return profile

	set(value):
		profile = value
		profile.changed.connect(queue_redraw)
		queue_redraw()


func _draw() -> void:
	if profile == null:
		return

	draw_rect(Rect2i(Vector2.ZERO, Vector2(profile.size) * SCREENFUL_SIZE), Color.CORNFLOWER_BLUE)
	draw_rect(Rect2i(Vector2.ZERO, Vector2(profile.size) * SCREENFUL_SIZE), Color.DARK_SLATE_BLUE, false, WALL_WIDTH)

	for e in profile.edges:
		if e:
			_draw_edge(e)


func _draw_edge(edge: EdgeProfile) -> void:
	var from: Vector2 = edge.position
	var to: Vector2 = edge.position
	var margin: Vector2

	match edge.side:
		EdgeProfile.EdgeSide.NORTH, EdgeProfile.EdgeSide.SOUTH:
			to.x += 1

			if edge.side == EdgeProfile.EdgeSide.SOUTH:
				from.y += 1
				to.y += 1

			margin = Vector2(WALL_WIDTH/2, 0)

		EdgeProfile.EdgeSide.EAST, EdgeProfile.EdgeSide.WEST:
			to.y += 1

			if edge.side == EdgeProfile.EdgeSide.EAST:
				from.x += 1
				to.x += 1

			margin = Vector2(0, WALL_WIDTH/2)

	draw_line(from*SCREENFUL_SIZE+margin, to*SCREENFUL_SIZE-margin, Color.GOLDENROD, WALL_WIDTH)
