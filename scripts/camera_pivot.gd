## controls board camera using a pivot
## players can move and zoom the camera

extends Node3D

@export_group("Orbit")
@export var rotation_sensitivity: float = 0.005
@export var min_pitch: float = -75.0
@export var max_pitch: float = -15.0

@export_group("Zoom")
@export var zoom_step: float = 0.5
@export var min_distance: float = 0.6
@export var max_distance: float = 15.0

@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	# set an initial position 
	camera.position = Vector3(0.0, 8.0, 8.0)
	# camera should always point to origin
	camera.look_at(Vector3.ZERO)
	
func _unhandled_input(event: InputEvent) -> void:
	# rotation and grabwith right click
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_handle_rotation(event.relative)
			
	# zoom with mouse wheel
	if event is InputEventMouseButton:
		_handle_zoom(event)
		
## rotate the pivot horizontally and limits vertical inclination
func _handle_rotation(relative_motion: Vector2) -> void:
	# horizontal rotation
	rotate_y(-relative_motion.x * rotation_sensitivity)
	
	# vertical rotation
	var new_pitch := rotation_degrees.x - relative_motion.y * rotation_sensitivity
	rotation_degrees.x = clampf(new_pitch, min_pitch, max_pitch)
	
## zoom in or zoom out camera keeping focus on origin
func _handle_zoom(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_apply_zoom(-zoom_step)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_apply_zoom(zoom_step)
		
func _apply_zoom(amount: float) -> void:
	# calculates distance from origin to camera
	var direction := camera.position.normalized()
	var new_distance := camera.position.length() + amount
	
	new_distance = clampf(new_distance, min_distance, max_distance)
	camera.position = direction * new_distance
	
	camera.look_at(Vector3.ZERO)
