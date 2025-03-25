extends Node2D


#var node references
@onready var map: Node2D = %map
@onready var start_marker: Marker2D = %start
@onready var target_marker: Marker2D = %target

#var for astar setting
@export var bidirectional: bool = true

#var for processing
var astar: AStar2D = AStar2D.new()


#init scene
func _ready() -> void:
	upload_streets()
	aling_node2d(start_marker, start_marker.position)
	target_marker.hide()


#upload all the streets in the scene
func upload_streets() -> void:
	#delete lines that already exist
	var deleted_lines: Array[Line2D]
	for i: Line2D in map.get_children():
		for j: Line2D in map.get_children():
			if not deleted_lines.has(i) and i != j and i.points == j.points:
				push_error(j.name, " already exists")
				deleted_lines.append(j)
				map.remove_child(j)
	#check and fix points of the lines
	for i: Line2D in map.get_children():
		if i.get_point_count() < 2: #delete lines with less than 2 points
			push_error(i.name, " has less than 2 points")
			map.remove_child(i)
		elif i.get_point_count() > 2: #split lines with more than 2 points
			var points_number: int = i.get_point_count()
			for j in range(1, points_number - 1): #create new lines
				var new_line: Line2D = Line2D.new()
				new_line.add_point(i.get_point_position(j)) #first point
				new_line.add_point(i.get_point_position(j + 1)) #second point
				new_line.name = str(map.get_child_count()) #name
				new_line.position = i.position #position
				map.add_child(new_line)
			for j in range(points_number, 2, -1): #delete useless points
				i.remove_point(j - 1)
	#check and fix if position isn't (0, 0)
	for i: Line2D in map.get_children():
		if i.position != Vector2.ZERO:
			i.set_point_position(0, i.get_point_position(0) + i.position)
			i.set_point_position(1, i.get_point_position(1) + i.position)
			i.position = Vector2.ZERO
	#from lines to astar
	for i: Line2D in map.get_children():
		add_new_line(i)
	#check if there is at least one point
	if astar.get_closest_point(Vector2(0, 0)) == -1:
		push_error("there is no point")


func add_new_line(line: Line2D) -> void:
	#start point of the line
	var first_id: int = -1
	for i in astar.get_point_ids():
		if line.get_point_position(0) == astar.get_point_position(i):
			first_id = i
			break
	if first_id == -1:
		first_id = astar.get_available_point_id()
		astar.add_point(first_id, line.get_point_position(0))
	#end point of the line
	var second_id: int = -1
	for i in astar.get_point_ids():
		if line.get_point_position(1) == astar.get_point_position(i):
			second_id = i
			break
	if second_id == -1:
		second_id = astar.get_available_point_id()
		astar.add_point(second_id, line.get_point_position(1))
	#conneting points
	astar.connect_points(first_id, second_id, bidirectional)
	line.name = str(first_id) + " " + str(second_id)


#align to closest point
func aling_node2d(node2d: Node2D, target_position: Vector2) -> void:
	var nearest_point_from_node2d: int = astar.get_closest_point(target_position)
	node2d.position = astar.get_point_position(nearest_point_from_node2d)


func get_aling_position(target_position: Vector2) -> Vector2:
	var nearest_point_from_position: int = astar.get_closest_point(target_position)
	return astar.get_point_position(nearest_point_from_position)
 

#find shortest path on click
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			target_marker.show()
			aling_node2d(target_marker, event.position)
			var shortest_path: Array[int] = get_shortest_path_ids(start_marker.position, target_marker.position)
			set_color_to_path(shortest_path)


#find shortest path callable
func get_shortest_path_ids(start_position: Vector2, target_position: Vector2, allow_partial_path: bool = false, allow_warnings: bool = true) -> Array[int]:
	var start_point: int = astar.get_closest_point(start_position)
	var target_point: int = astar.get_closest_point(target_position)
	var shortest_path_ids: PackedInt64Array = astar.get_id_path(start_point, target_point, allow_partial_path)
	#warnings logic
	if allow_warnings:
		if start_point == target_point: #check if start position is on target position
			push_warning("target is on start position")
		elif shortest_path_ids.size() == 0: #check if there is at least one path
				push_warning("no path to target")
	return convert_packed_array_to_int_array(shortest_path_ids)


func get_shortest_path_points(start_position: Vector2, target_position: Vector2, allow_partial_path: bool = false, allow_warnings: bool = true) -> Array[Vector2]:
	var start_point: int = astar.get_closest_point(start_position)
	var target_point: int = astar.get_closest_point(target_position)
	var shortest_path_ids: PackedInt64Array = astar.get_id_path(start_point, target_point, allow_partial_path)
	var shortest_path_points: PackedVector2Array = astar.get_point_path(start_point, target_point, allow_partial_path)
	#warnings logic
	if allow_warnings:
		if start_point == target_point: #check if start position is on target position
			push_warning("target is on start position")
		elif shortest_path_ids.size() == 0: #check if there is at least one path
				push_warning("no path to target")
	return convert_packed_array_to_vector2_array(shortest_path_points)


#convert packed array to normal array
func convert_packed_array_to_int_array(array: PackedInt64Array) -> Array[int]:
	var new_array: Array[int]
	for i in array:
		new_array.append(i)
	return new_array


func convert_packed_array_to_vector2_array(array: PackedVector2Array) -> Array[Vector2]:
	var new_array: Array[Vector2]
	for i in array:
		new_array.append(i)
	return new_array


#visual
func reset_color() -> void:
	for i: Line2D in map.get_children():
		i.default_color = Color.WHITE


func set_color_to_path(path_to_color: Array[int]) -> void:
	reset_color()
	for i in range(0, path_to_color.size() - 1):
		for j: Line2D in map.get_children():
			if str(path_to_color[i]) + " " + str(path_to_color[i + 1]) == j.name or str(path_to_color[i + 1]) + " " + str(path_to_color[i]) == j.name:
				j.default_color = Color.RED
