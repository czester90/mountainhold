class_name CastlePathfinder
extends Node

const TERMINAL_DISTANCE := 18.0
const TERMINAL_HEIGHT := 8.0
const LOCAL_EDGE_DISTANCE := 7.5
const LOCAL_EDGE_HEIGHT := 3.5

func route(context: Node, from: Vector3, to: Vector3) -> Array[Vector3]:
	if context == null or from.x >= 1.0e19 or to.x >= 1.0e19:
		return []
	var points: Array[Vector3] = [from, to]
	var edge_pairs: Array[Vector2i] = []
	for edge in _navigation_edges(context):
		if not edge is Node or not is_instance_valid(edge):
			continue
		var edge_node := edge as Node
		if not edge_node.has_meta("nav_a") or not edge_node.has_meta("nav_b"):
			continue
		var a: Vector3 = edge_node.get_meta("nav_a")
		var b: Vector3 = edge_node.get_meta("nav_b")
		var a_idx := points.size()
		points.append(a)
		var b_idx := points.size()
		points.append(b)
		edge_pairs.append(Vector2i(a_idx, b_idx))
	if edge_pairs.is_empty():
		return []
	var start_links := _terminal_links(points, 0)
	var goal_links := _terminal_links(points, 1)
	if start_links.is_empty() or goal_links.is_empty():
		return []
	var path_indices := _shortest_path(points, edge_pairs, start_links, goal_links)
	if path_indices.size() < 2:
		return []
	var out: Array[Vector3] = []
	for i in range(1, path_indices.size()):
		out.append(points[path_indices[i]])
	return _compact_path(out)

func _navigation_edges(context: Node) -> Array:
	var model := context.get_tree().get_first_node_in_group("castle_model")
	if model != null and model.get("navigation_edges") != null:
		var model_edges: Array = model.get("navigation_edges")
		if not model_edges.is_empty():
			return model_edges
	return context.get_tree().get_nodes_in_group("castle_navigation_edge")

func _terminal_links(points: Array[Vector3], terminal_idx: int) -> Array[int]:
	var best_score := INF
	var links: Array[int] = []
	for i in range(2, points.size()):
		var distance := points[terminal_idx].distance_to(points[i])
		var height_delta := absf(points[terminal_idx].y - points[i].y)
		if distance > TERMINAL_DISTANCE or height_delta > TERMINAL_HEIGHT:
			continue
		if distance < best_score - 0.1:
			best_score = distance
			links = [i]
		elif absf(distance - best_score) <= 0.1:
			links.append(i)
	return links

func _shortest_path(points: Array[Vector3], edge_pairs: Array[Vector2i], start_links: Array[int], goal_links: Array[int]) -> Array[int]:
	var count := points.size()
	var dist: Array[float] = []
	var prev: Array[int] = []
	var used: Array[bool] = []
	for _i in count:
		dist.append(INF)
		prev.append(-1)
		used.append(false)
	dist[0] = 0.0
	for _step in count:
		var best := -1
		var best_dist := INF
		for i in count:
			if not used[i] and dist[i] < best_dist:
				best = i
				best_dist = dist[i]
		if best == -1 or best == 1:
			break
		used[best] = true
		for other in count:
			if used[other] or other == best:
				continue
			var cost := _edge_cost(best, other, points, edge_pairs, start_links, goal_links)
			if cost >= INF:
				continue
			var next_dist := dist[best] + cost
			if next_dist < dist[other]:
				dist[other] = next_dist
				prev[other] = best
	if prev[1] == -1:
		return []
	var path: Array[int] = []
	var cursor := 1
	while cursor != -1:
		path.push_front(cursor)
		cursor = prev[cursor]
	return path

func _edge_cost(a_idx: int, b_idx: int, points: Array[Vector3], edge_pairs: Array[Vector2i], start_links: Array[int], goal_links: Array[int]) -> float:
	if a_idx == b_idx:
		return INF
	if (a_idx == 0 and b_idx == 1) or (a_idx == 1 and b_idx == 0):
		return INF
	if _is_navigation_edge_pair(a_idx, b_idx, edge_pairs):
		return points[a_idx].distance_to(points[b_idx])
	var a := points[a_idx]
	var b := points[b_idx]
	var distance := a.distance_to(b)
	var height_delta := absf(a.y - b.y)
	if a_idx == 0 or b_idx == 0:
		var other_start := b_idx if a_idx == 0 else a_idx
		return distance if start_links.has(other_start) and distance <= TERMINAL_DISTANCE and height_delta <= TERMINAL_HEIGHT else INF
	if a_idx == 1 or b_idx == 1:
		var other_goal := b_idx if a_idx == 1 else a_idx
		return distance if goal_links.has(other_goal) and distance <= TERMINAL_DISTANCE and height_delta <= TERMINAL_HEIGHT else INF
	return distance if distance <= LOCAL_EDGE_DISTANCE and height_delta <= LOCAL_EDGE_HEIGHT else INF

func _is_navigation_edge_pair(a_idx: int, b_idx: int, edge_pairs: Array[Vector2i]) -> bool:
	for pair in edge_pairs:
		if (pair.x == a_idx and pair.y == b_idx) or (pair.x == b_idx and pair.y == a_idx):
			return true
	return false

func _compact_path(points: Array[Vector3]) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for point in points:
		if out.is_empty() or out.back().distance_squared_to(point) > 1.0:
			out.append(point)
	return out
