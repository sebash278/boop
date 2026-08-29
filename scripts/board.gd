class_name Board
extends Node3D

signal cell_clicked(coords: Vector2i)

const SIZE := 5
const CELL_SIZE := 1.0
const CELL_SCENE := preload("res://scenes/cell.tscn")

var grid := {}

func _ready() -> void:
	build_board()

func build_board() -> void:
	for x in SIZE:
		for z in SIZE:
			var coords := Vector2i(x, z)
			var cell: Cell = CELL_SCENE.instantiate()
			cell.coords = coords
			cell.position = to_world(coords)
			cell.clicked.connect(_on_cell_clicked)
			add_child(cell)

			grid[coords] = {
				"cat": null
			}

func to_world(coords: Vector2i) -> Vector3:
	var offset := (SIZE - 1) * CELL_SIZE / 2.0
	return Vector3(
		coords.x * CELL_SIZE - offset,
		0.0,
		coords.y * CELL_SIZE - offset
	)

func _on_cell_clicked(coords: Vector2i) -> void:
	cell_clicked.emit(coords)
