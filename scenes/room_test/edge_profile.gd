@tool
class_name EdgeProfile
extends Resource


enum EdgeSide { EAST, SOUTH, WEST, NORTH }


@export var side: EdgeSide:
	get: return side
	set(value):
		side = value
		emit_changed()

@export var position: Vector2i: ## Offset from parent room position.
	get: return position
	set(value):
		position = value
		emit_changed()

@export var key_choices: Array[StringName]:
	get: return key_choices
	set(value):
		key_choices = value
		emit_changed()

@export var optional: bool = false:
	get: return optional
	set(value):
		optional = value
		emit_changed()


static func opposing_side(sside: EdgeSide) -> EdgeSide:
	match sside:
		EdgeSide.NORTH: return EdgeSide.SOUTH
		EdgeSide.SOUTH: return EdgeSide.NORTH
		EdgeSide.EAST: return EdgeSide.WEST
		EdgeSide.WEST: return EdgeSide.EAST
		_:
			assert(false, "Invalid EdgeSide")
			return EdgeSide.NORTH


static func side_facing_dir(p_side: EdgeSide) -> Vector2i:
	match p_side:
		EdgeSide.NORTH: return Vector2i(0, -1)
		EdgeSide.SOUTH: return Vector2i(0, 1)
		EdgeSide.EAST: return Vector2i(1, 0)
		EdgeSide.WEST: return Vector2i(-1, 0)
		_:
			assert(false, "Invalid EdgeSide")
			return Vector2i(0, 0)


static func side_name(sside: EdgeSide) -> String:
	return EdgeSide.find_key(sside)


func connects(other: EdgeProfile) -> bool:
	return side == opposing_side(other.side)


func connection_position() -> Vector2i:
	return position + facing_dir()


func facing_dir() -> Vector2i:
	return side_facing_dir(side)


func matches(other: EdgeProfile) -> bool:
	return other.key_choices.any(
		func (key: StringName) -> bool:
			return key in key_choices
	)


func connects_and_matches(other: EdgeProfile) -> bool:
	return connects(other) and matches(other)
