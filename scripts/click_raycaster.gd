class_name ClickRaycaster
extends Node3D

# ClickRaycaster emit a signal if it detects a cell
signal cell_clicked(coords: Vector2i)

const MAX_RAY_DISTANCE := 1000.0
const CELL_LAYER := 1

# function that prevents UI clicks to be detected
func _unhandled_input(event: InputEvent) -> void:
	# Click detection to get coords
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var coords = get_clicked_cell_coords()

			if coords != null:
				cell_clicked.emit(coords)


func get_clicked_cell_coords():
	# i need to get camera active and its position
	var viewport := get_viewport()
	var camera := viewport.get_camera_3d()

	if camera == null:
		return null

	var mouse_pos := viewport.get_mouse_position()

	# ray origins from camera and gets to screen point where mouse is in the moment
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_direction := camera.project_ray_normal(mouse_pos)
	var ray_end := ray_origin + ray_direction * MAX_RAY_DISTANCE

	var space_state := get_world_3d().direct_space_state

	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	# ray only searches for layer 1 objects
	query.collision_mask = CELL_LAYER
	query.collide_with_bodies = true
	query.collide_with_areas = true

	var result := space_state.intersect_ray(query)

	if result.is_empty():
		return null

	var collider = result.get("collider")

	if collider is Cell:
		return collider.coords

	return null
