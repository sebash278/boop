## manages game flow
extends Node3D

@onready var board: Board = $Board
@onready var cats_root: Node3D = $Cats
@onready var turn_label: Label = $UI/TurnLabel
@onready var click_raycaster: ClickRaycaster = $ClickRaycaster

const CAT_SCENE := preload("res://scenes/cat.tscn")

var current_player := 0

func _ready() -> void:
	click_raycaster.cell_clicked.connect(_on_cell_clicked)
	update_turn_label()

## turn flow: place a cat -> physics -> next turn
func _on_cell_clicked(coords: Vector2i) -> void:
	if not board.is_cell_empty(coords):
		return

	place_cat(coords)
	push_nearby_cats(coords)
	switch_turn()

func place_cat(coords: Vector2i) -> void:
	var cat := CAT_SCENE.instantiate()
	cat.position = board.to_world(coords) + Vector3(0, 0.5, 0)
	cats_root.add_child(cat)

	board.grid[coords]["cat"] = cat

func switch_turn() -> void:
	current_player = 1 - current_player
	update_turn_label()

func update_turn_label() -> void:
	turn_label.text = "Turno: Jugador %d" % (current_player + 1)

## looks for 4 directions and pushes cats
func push_nearby_cats(coords: Vector2i) -> void:
	var directions: Array[Vector2i] = [
		Vector2i.UP,
		Vector2i.DOWN,
		Vector2i.LEFT,
		Vector2i.RIGHT,
	]

	for dir in directions:
		var target_coords := coords + dir

		if not board.grid.has(target_coords):
			continue

		var cat = board.grid[target_coords]["cat"]

		if cat == null:
			continue

		var destination := target_coords + dir
		move_cat(cat, target_coords, destination)

## logic movement of cats and animations
## Boop rules in game
## 1. Cat outside the board = DEAD (delete)
## 2. If cell is ocupped, BLOCK
## 3. If cell is free, animation and board update
func move_cat(cat: Node3D, from_coords: Vector2i, to_coords: Vector2i) -> void:
	# clear original position before validation
	board.grid[from_coords]["cat"] = null

	# case 1: pushed outside board
	if not board.grid.has(to_coords):
		remove_cat(cat)
		return

	# case 2: cell blocked by another cat
	if board.grid[to_coords]["cat"] != null:
		board.grid[from_coords]["cat"] = cat
		return

	# case 3: valid movement
	board.grid[to_coords]["cat"] = cat

	# visual animation to new position
	var tween := create_tween()
	var target_position := board.to_world(to_coords) + Vector3(0, 0.5, 0)
	tween.tween_property(cat, "position", target_position, 0.2)

func remove_cat(cat: Node3D) -> void:
	cat.queue_free()
