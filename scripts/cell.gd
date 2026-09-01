class_name Cell
extends StaticBody3D

@export var coords: Vector2i = Vector2i.ZERO

func _ready() -> void:
	# cell exists in layer 1
	collision_layer = 1
	# cell doesnt recognize any other object
	collision_mask = 0
