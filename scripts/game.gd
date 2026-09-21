## manages game flow
extends Node3D

@onready var board: Board = $Board
@onready var cats_root: Node3D = $Cats
@onready var click_raycaster: ClickRaycaster = $ClickRaycaster
@onready var place_sound: AudioStreamPlayer = $PlaceSound
@onready var meow_sound: AudioStreamPlayer = $MeowSound
@onready var turn_label: Label = $UI/TopCenterContainer/TurnPanel/TurnMargin/TurnLabel
@onready var turn_panel: PanelContainer = $UI/TopCenterContainer/TurnPanel
@onready var game_over_panel: PanelContainer = $UI/GameOverPanel
@onready var victory_label: Label = $UI/GameOverPanel/VBoxContainer/VictoryLabel
@onready var restart_button: Button = $UI/GameOverPanel/VBoxContainer/RestartButton

const CAT_SCENE := preload("res://scenes/cat.tscn")

var current_player := 0
var game_over := false

func _ready() -> void:
	click_raycaster.cell_clicked.connect(_on_cell_clicked)
	restart_button.pressed.connect(_on_restart_pressed)
	
	game_over_panel.visible = false
	update_turn_label()

## turn flow: place a cat -> physics -> next turn
func _on_cell_clicked(coords: Vector2i) -> void:
	if game_over:
		return
	
	if not board.is_cell_empty(coords):
		return

	place_cat(coords)
	push_nearby_cats(coords)
	
	if check_win_condition(current_player):
		trigger_game_over(current_player)
		return
		
	var opponent := 1 - current_player
	if check_win_condition(opponent):
		trigger_game_over(opponent)
		return
		
	switch_turn()

func place_cat(coords: Vector2i) -> void:
	var cat := CAT_SCENE.instantiate()
	cat.position = board.to_world(coords) + Vector3(0, 0.5, 0)
	cats_root.add_child(cat)
	cat.setup(current_player)
	play_place_sound()
	board.grid[coords]["cat"] = cat
	board.grid[coords]["owner"] = current_player

func switch_turn() -> void:
	current_player = 1 - current_player
	update_turn_label()

func update_turn_label() -> void:
	turn_label.text = "Turno: Jugador %d" % (current_player + 1)
	
	if current_player == 0:
		turn_label.add_theme_color_override("font_color", Color(0.9, 0.45, 0.1))
	else:
		turn_label.add_theme_color_override("font_color", Color(0.25, 0.3, 0.4))

## looks for 4 directions and pushes cats
func push_nearby_cats(coords: Vector2i) -> void:
	var directions: Array[Vector2i] = [
		Vector2i.UP,
		Vector2i.DOWN,
		Vector2i.LEFT,
		Vector2i.RIGHT,
		Vector2i(1, 1),
		Vector2i(1, -1),
		Vector2i(-1, 1),
		Vector2i(-1, -1)
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
	
	var owner: int = board.grid[from_coords]["owner"]
	
	# clear original position before validation
	board.grid[from_coords]["cat"] = null
	board.grid[from_coords]["owner"] = -1

	# case 1: pushed outside board
	if not board.grid.has(to_coords):
		remove_cat(cat)
		return

	# case 2: cell blocked by another cat
	if board.grid[to_coords]["cat"] != null:
		board.grid[from_coords]["cat"] = cat
		board.grid[from_coords]["owner"] = owner
		return

	# case 3: valid movement
	board.grid[to_coords]["cat"] = cat
	board.grid[to_coords]["owner"] = owner
	
	play_meow_sound()

	# visual animation to new position
	var tween := create_tween()
	var target_position := board.to_world(to_coords) + Vector3(0, 0.5, 0)
	tween.tween_property(cat, "position", target_position, 0.2)

func remove_cat(cat: Node3D) -> void:
	cat.queue_free()
	
## scan board looking for 3 cats aligned
func check_win_condition(player: int) -> bool:
	
	var alignments := [
		Vector2i(1, 0),
		Vector2i(0, 1),
		Vector2i(1, 1),
		Vector2i(1, -1) 
	]
	
	for x in board.SIZE:
		for z in board.SIZE:
			var start := Vector2i(x, z)
			
			if board.grid[start]["owner"] != player:
				continue
			
			for dir in alignments:
				if _has_line(start, dir, player):
					return true
	return false
	
func _has_line(start: Vector2i, dir: Vector2i, player: int) -> bool:
	var count := 0
	var step := 0
	
	while step < 3:
		var check_coords := start + (dir*step)
		
		if board.grid.has(check_coords) and board.grid[check_coords]["owner"] == player:
			count += 1
			step += 1
		else:
			break
			
	return count >= 3
	
func trigger_game_over(winner: int) -> void:
	game_over = true
	$UI/TopCenterContainer.visible = false
	victory_label.text = "¡Jugador %d gana la partida!" % (winner + 1)
	game_over_panel.visible = true
	
func play_place_sound() -> void:
	place_sound.pitch_scale = randf_range(0.95, 1.05)
	place_sound.play()

func play_meow_sound() -> void:
	meow_sound.pitch_scale = randf_range(0.92, 1.08)
	meow_sound.play()

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()
