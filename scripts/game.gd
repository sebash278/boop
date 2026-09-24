## manages game flow
extends Node3D

@onready var board: Board = $Board
@onready var cats_root: Node3D = $Cats
@onready var click_raycaster: ClickRaycaster = $ClickRaycaster
@onready var place_sound: AudioStreamPlayer = $PlaceSound
@onready var meow_sound: AudioStreamPlayer = $MeowSound
@onready var turn_label: Label = $UI/TopCenterContainer/TurnPanel/TurnMargin/VBoxContainer/TurnLabel
@onready var turn_panel: PanelContainer = $UI/TopCenterContainer/TurnPanel
@onready var game_over_panel: PanelContainer = $UI/GameOverPanel
@onready var victory_label: Label = $UI/GameOverPanel/VBoxContainer/VictoryLabel
@onready var restart_button: Button = $UI/GameOverPanel/VBoxContainer/RestartButton
@onready var main_menu: Control = $UI/MainMenu
@onready var play_button: Button = $UI/MainMenu/CenterContainer/VBoxContainer/PlayButton
@onready var quit_button: Button = $UI/MainMenu/CenterContainer/VBoxContainer/QuitButton
@onready var top_center_container: Control = $UI/TopCenterContainer
@onready var instructions_label: Control = $UI/Instructions
@onready var camera_pivot: Node3D = $CameraPivot
@onready var piece_type_button: Button = $UI/TopCenterContainer/TurnPanel/TurnMargin/VBoxContainer/PieceTypeButton
@onready var how_to_play_button: Button = $UI/MainMenu/CenterContainer/VBoxContainer/HowToPlayButton
@onready var how_to_play_panel: PanelContainer = $UI/HowToPlayPanel
@onready var close_rules_button: Button = $UI/HowToPlayPanel/MarginContainer/VBoxContainer/CloseRulesButton

const CAT_SCENE := preload("res://scenes/cat.tscn")

var current_player := 0
var game_over := false
var in_menu := true

# players cat reserve
var kitten_reserve: Array[int] = [8, 8]
var big_cat_reserve: Array[int] = [0, 0]

# current cat selected
var placing_big_cat: bool = false

func _ready() -> void:
	click_raycaster.cell_clicked.connect(_on_cell_clicked)
	restart_button.pressed.connect(_on_restart_pressed)
	
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# initial state (visible menu)
	game_over_panel.visible = false
	top_center_container.visible = false
	instructions_label.visible = false
	main_menu.visible = true
	
	# different angle than in-game
	camera_pivot.rotation_degrees = Vector3(-15, 45, 0)
	
	piece_type_button.pressed.connect(_on_piece_type_toggle)
	update_piece_selector_ui()
	
	how_to_play_button.pressed.connect(_on_how_to_play_pressed)
	close_rules_button.pressed.connect(_on_close_rules_pressed)
	
	how_to_play_panel.visible = false
	how_to_play_panel.scale = Vector2.ZERO
	
	update_turn_label()
	
## turn flow: place a cat -> physics -> next turn
func _on_cell_clicked(coords: Vector2i) -> void:
	if game_over or in_menu:
		return
	
	if not board.is_cell_empty(coords):
		return

	place_cat(coords)
	push_nearby_cats(coords)
	
	if check_win_condition(current_player, true):
		trigger_game_over(current_player)
		return
		
	var opponent := 1 - current_player
	if check_win_condition(opponent, true):
		trigger_game_over(opponent)
		return

	check_and_graduate_kittens(current_player)
	check_and_graduate_kittens(opponent)
		
	switch_turn()
	placing_big_cat = false # new turn always starts with kittens
	update_piece_selector_ui()

func place_cat(coords: Vector2i) -> void:
	var cat := CAT_SCENE.instantiate()
	cat.position = board.to_world(coords) + Vector3(0, 0.5, 0)
	cats_root.add_child(cat)

	cat.setup(current_player)
	cat.set_big(placing_big_cat)

	if placing_big_cat:
		big_cat_reserve[current_player] -= 1
		# If no more big cats, back to kittens
		if big_cat_reserve[current_player] == 0:
			placing_big_cat = false
	else:
		kitten_reserve[current_player] -= 1

	play_place_sound()

	board.grid[coords]["cat"] = cat
	board.grid[coords]["owner"] = current_player
	board.grid[coords]["is_big"] = cat.is_big

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
	
	var placing_cat: Node3D = board.grid[coords]["cat"]
	var is_placer_big: bool = placing_cat.is_big

	var directions: Array[Vector2i] = [
		Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT,
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
	]

	for dir in directions:
		var target_coords := coords + dir
		if not board.grid.has(target_coords):
			continue

		var target_cat = board.grid[target_coords]["cat"]
		if target_cat == null:
			continue

		# kittens cant push big cats
		if not is_placer_big and target_cat.is_big:
			continue

		var destination := target_coords + dir
		move_cat(target_cat, target_coords, destination)

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
	
# graduates 3 kittens into big cats
func check_and_graduate_kittens(player: int) -> void:
	var line_coords := find_line_coords(player, false) # search 3 kittens
	if line_coords.size() >= 3:
		play_meow_sound()
		
		for c in line_coords:
			var cat_node: Node3D = board.grid[c]["cat"]
			board.grid[c]["cat"] = null
			board.grid[c]["owner"] = -1
			board.grid[c]["is_big"] = false
			
			# poof animation
			var tween := create_tween()
			tween.tween_property(cat_node, "scale", Vector3.ZERO, 0.35)
			tween.tween_callback(cat_node.queue_free)

		big_cat_reserve[player] += 3

func find_line_coords(player: int, must_be_big: bool) -> Array[Vector2i]:
	var alignments: Array[Vector2i] = [
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
			var start_cat = board.grid[start]["cat"]
			if start_cat == null or start_cat.is_big != must_be_big:
				continue
				
			for dir: Vector2i in alignments:
				var coords_list: Array[Vector2i] = []
				for step: int in 3:
					var check: Vector2i = start + (dir * step)
					
					if board.grid.has(check) and board.grid[check]["owner"] == player:
						var other_cat = board.grid[check]["cat"]
						if other_cat != null and other_cat.is_big == must_be_big:
							coords_list.append(check)
						else:
							break
					else:
						break
						
				if coords_list.size() == 3:
					return coords_list
	return []

# verifies only lines of 3 big cats
func check_win_condition(player: int, must_be_big: bool = true) -> bool:
	return find_line_coords(player, must_be_big).size() >= 3
	
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

func _on_play_pressed() -> void:
	play_meow_sound() # meowelcome xd
	
	var tween := create_tween().set_parallel(true)
	
	# main menu fades up
	tween.tween_property(main_menu, "modulate:a", 0.0, 0.5)
	tween.tween_property(main_menu, "position:y", -30.0, 0.5)
	
	tween.tween_property(camera_pivot, "rotation_degrees", Vector3(0, 45, 0), 1.0)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
	
	# match starts
	await tween.finished
	main_menu.visible = false
	in_menu = false
	
	# turns and controls UI appear
	top_center_container.visible = true
	instructions_label.visible = true
	top_center_container.modulate.a = 0.0
	instructions_label.modulate.a = 0.0
	
	var ui_tween := create_tween().set_parallel(true)
	ui_tween.tween_property(top_center_container, "modulate:a", 1.0, 0.4)
	ui_tween.tween_property(instructions_label, "modulate:a", 1.0, 0.4)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_piece_type_toggle() -> void:
	# player can change to big cat only if at least 1 is available
	if big_cat_reserve[current_player] > 0:
		placing_big_cat = !placing_big_cat
	else:
		placing_big_cat = false
	update_piece_selector_ui()

func update_piece_selector_ui() -> void:
	var big_count = big_cat_reserve[current_player]
	var small_count = kitten_reserve[current_player]
	
	if placing_big_cat:
		piece_type_button.text = "Colocar: GATO GRANDE (%d)" % big_count
	else:
		piece_type_button.text = "Colocar: Gatito (%d)" % small_count
		
	# disabled button if no big cats available
	piece_type_button.disabled = (big_count == 0)

func _on_how_to_play_pressed() -> void:
	play_meow_sound()
	how_to_play_panel.visible = true
	how_to_play_panel.pivot_offset = how_to_play_panel.size / 2.0
	how_to_play_panel.scale = Vector2.ZERO
	
	var tween := create_tween()
	tween.tween_property(how_to_play_panel, "scale", Vector2.ONE, 0.25)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

func _on_close_rules_pressed() -> void:
	var tween := create_tween()
	tween.tween_property(how_to_play_panel, "scale", Vector2.ZERO, 0.2)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_IN)
	await tween.finished
	how_to_play_panel.visible = false
