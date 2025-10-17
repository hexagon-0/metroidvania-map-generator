class_name MapGenerator
extends Node


@export var min_size: Vector2i = Vector2i(6, 6)
@export_range(0.0, 1.0) var min_factor: float = 0.25
@export_range(0.0, 1.0) var max_factor: float = 0.75
@export var key_ordering: KeyOrdering

var map: Map
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	rng.seed = 1337


func generate() -> void:
	_generate_regions()


func _generate_regions() -> void:
	map = Map.new()
	map.size = Vector2i(128, 128)

	#rng.seed = 1337
	map.root = _bsp_tree(Rect2i(Vector2(0, 0), map.size))


func _assign_gatings(initial_region: Rect2i) -> void:
	map.key_order.clear()
	map.gatings.clear()
	var possible_keys := [key_ordering.starting_key]
	var possible_regions := { initial_region: true }
	while possible_keys:
		# TODO: use rng to choose
		var chosen_key: StringName = possible_keys.pick_random()
		possible_keys.erase(chosen_key)
		map.key_order.push_back(chosen_key)
		possible_keys.append_array(
			key_ordering.follows.get(chosen_key, []))

		# TODO: use rng to choose
		var chosen_region: Rect2i = possible_regions.keys().pick_random()
		possible_regions.erase(chosen_region)
		map.gatings[chosen_region] = chosen_key
		for r in map.get_adjacency_list(chosen_region):
			if not map.gatings.has(r):
				possible_regions[r] = true


func _bsp(rect: Rect2i, axis: int = Vector2i.AXIS_X) -> Array[Rect2i]:
	var f := rng.randf_range(min_factor, max_factor) # partition factor

	var a := rect
	a.size[axis] = int(a.size[axis] * f)
	if a.size[axis] <= min_size[axis]:
		return [rect]

	var b := rect
	b.size[axis] -= a.size[axis]
	b.position[axis] = a.position[axis] + a.size[axis]
	if b.size[axis] <= min_size[axis]:
		return [rect]

	var r := _bsp(a, axis ^ 1)
	r.append_array(_bsp(b, axis ^ 1))
	return r


func _bsp_tree(rect: Rect2i, axis: int = Vector2i.AXIS_X) -> BspNode:
	var tree := BspNode.new()
	tree.axis = axis
	tree.rect = rect

	var f := rng.randf_range(min_factor, max_factor) # partition factor

	var a_size := int(rect.size[axis] * f)
	var b_size := rect.size[axis] - a_size
	if a_size <= min_size[axis] or b_size <= min_size[axis]:
		return tree

	var a := rect
	a.size[axis] = a_size
	var b := rect
	b.position[axis] += a_size
	b.size[axis] = b_size

	tree.left = _bsp_tree(a, axis ^ 1)
	tree.right = _bsp_tree(b, axis ^ 1)

	return tree


## Node from a binary space partition tree.
##
## If [member left] and [member right] are not null, this node is a branch, otherwise it is a
## leaf. For leaf nodes, only the [member rect] field contains useful information.
## [br][br]
## [b]Note:[/b] [member left] and [member right] should always be both null or non-null.
class BspNode:
	var axis: int ## [constant Vector2.AXIS_X] or [constant Vector2.AXIS_Y].
	var left: BspNode ## Can be null or [MapGenerator.BspNode].
	var right: BspNode ## Can be null or [MapGenerator.BspNode].
	var rect: Rect2i ## Full rectangle represented by this node.
	var partition: int: ## Coordinate along [member axis] where this node is partitioned.
		get:
			if !right:
				return 0
			return right.rect.position[axis]


	func find_region_containing_point(point: Vector2i) -> BspNode:
		if not rect.has_point(point):
			return null

		# Tree fully covers rect, so we can expect this to return non-null
		return _region_with_point(point)


	func _region_with_point(point: Vector2i) -> BspNode:
		if left == null: # Leaf node
			return self

		if point[axis] < partition:
			return left._region_with_point(point)

		return right._region_with_point(point)


class Map:
	var size: Vector2i
	var root: BspNode
	var adjacency: Dictionary # Rect2i -> Array[Rect2i]
	var gatings: Dictionary # Rect2i -> StringName
	var key_order: Array[StringName]

	func iterator() -> MapIterator:
		return BspTreeIterator.new(self)


	func get_adjacency_list(region: Rect2i) -> Array[Rect2i]:
		if region not in adjacency:
			_generate_adjacency_array(region)
		return adjacency[region]


	func _generate_adjacency_array(region: Rect2i) -> Array[Rect2i]:
		var aa: Array[Rect2i] = []
		aa.append_array(_adjacent_lt(region, Vector2.AXIS_X, root))
		aa.append_array(_adjacent_lt(region, Vector2.AXIS_Y, root))
		aa.append_array(_adjacent_gt(region, Vector2.AXIS_X, root))
		aa.append_array(_adjacent_gt(region, Vector2.AXIS_Y, root))
		adjacency[region] = aa
		return aa


	func _adjacent_lt(region: Rect2i, axis: int, tree: BspNode) -> Array[Rect2i]:
		if tree.left == null:
			var alt_axis = axis ^ 1
			if (
				tree.rect.end[axis] == region.position[axis]
				and tree.rect.end[alt_axis] > region.position[alt_axis]
			):
				return [tree.rect]
			return []

		if tree.axis == axis:
			if tree.partition >= region.position[axis]:
				return _adjacent_lt(region, axis, tree.left)
			else:
				return _adjacent_lt(region, axis, tree.right)
		else:
			var alt_axis = tree.axis
			if tree.partition < region.position[alt_axis]:
				# region:       |---|
				# tree:   |---:-.....
				if tree.right.rect.end[alt_axis] > region.position[alt_axis]:
					return _adjacent_lt(region, axis, tree.right)
			elif tree.partition >= region.end[alt_axis]:
				# region: |---|
				# tree:   .....-:---|
				if tree.left.rect.position[alt_axis] < region.end[alt_axis]:
					return _adjacent_lt(region, axis, tree.left)
			else:
				# region:   |---|
				# tree:   |---:---|
				return _adjacent_lt(region, axis, tree.left) + _adjacent_lt(region, axis, tree.right)

		return []


	func _adjacent_gt(region: Rect2i, axis: int, tree: BspNode) -> Array[Rect2i]:
		if tree.right == null:
			var alt_axis = axis ^ 1
			if (
				region.end[axis] == tree.rect.position[axis]
				and tree.rect.end[alt_axis] > region.position[alt_axis]
			):
				return [tree.rect]
			return []

		if tree.axis == axis:
			if tree.partition > region.end[axis]:
				return _adjacent_gt(region, axis, tree.left)
			else:
				return _adjacent_gt(region, axis, tree.right)
		else:
			var alt_axis = tree.axis
			if tree.partition < region.position[alt_axis]:
				# region:       |---|
				# tree:   |---:-.....
				if tree.right.rect.end[alt_axis] > region.position[alt_axis]:
					return _adjacent_gt(region, axis, tree.right)
			elif tree.partition >= region.end[alt_axis]:
				# region: |---|
				# tree:   .....-:---|
				if tree.left.rect.position[alt_axis] < region.end[alt_axis]:
					return _adjacent_gt(region, axis, tree.left)
			else:
				# region:   |---|
				# tree:   |---:---|
				return _adjacent_gt(region, axis, tree.left) + _adjacent_gt(region, axis, tree.right)

		return []


class MapIterator:
	func next() -> Variant: ## Returns `Rect2i | null`
		return null


class BspTreeIterator extends MapIterator:
	enum Branch {
		LEFT, ## Iterator should return the left branch next.
		RIGHT, ## Iterator should return the right branch next.
	}


	var _stack: Array ## Array of [code][Branch, BspNode][/code]
	var _map: Map


	func _init(map: Map) -> void:
		_stack = [[Branch.LEFT, map.root]]
		_map = map


	func next() -> Variant:
		if _stack.is_empty():
			return null

		return _next()


	func _next() -> Variant:
		var current = _stack.back()
		match current:
			[Branch.LEFT, var node]:
				if node.left == null:
					_stack.pop_back()
					return node.rect
				current[0] = Branch.RIGHT
				_stack.push_back([Branch.LEFT, node.left])
			[Branch.RIGHT, var node]:
				# TODO: since we're popping and pushing, may change in place instead?
				_stack.pop_back()
				if node.right == null:
					return node.rect
				_stack.push_back([Branch.LEFT, node.right])

		return _next()
