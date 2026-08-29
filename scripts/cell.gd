class_name Cell
extends Area3D

signal clicked(coords: Vector2i)

@export var coords: Vector2i = Vector2i.ZERO

func _ready() -> void:
	input_event.connect(_on_input_event)

func _on_input_event(_camera, event, _position, _normal, _shape_idx) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			clicked.emit(coords)
