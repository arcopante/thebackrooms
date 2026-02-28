extends Node

var current_level: int = 5
var game_state: String = "playing"
var game_over_message: String = "HAS SIDO ENCONTRADO"
var death_reason: String = ""

var loaded_player_hp: int = 100
var loaded_player_sanity: float = 100.0
var loaded_player_position: Vector3 = Vector3.ZERO
var loaded_map_seed: int = 0
var is_loading_save: bool = false

signal level_changed(new_level: int)
signal game_state_changed(new_state: String)

func change_level(new_level: int) -> void:
	current_level = new_level
	level_changed.emit(new_level)

func set_game_state(new_state: String) -> void:
	game_state = new_state
	game_state_changed.emit(new_state)

func set_game_over_message(message: String) -> void:
	game_over_message = message

func save_game() -> void:
	var player_node := get_tree().get_first_node_in_group("player")
	if player_node != null and "hp" in player_node:
		loaded_player_hp = int(player_node.get("hp"))
	if player_node != null:
		loaded_player_position = (player_node as Node3D).global_position
	if SanityManager != null and "sanity" in SanityManager:
		loaded_player_sanity = float(SanityManager.sanity)

	var save_data: Dictionary = {
		"current_level": current_level,
		"player_hp": loaded_player_hp,
		"player_sanity": loaded_player_sanity,
		"player_pos_x": loaded_player_position.x,
		"player_pos_y": loaded_player_position.y,
		"player_pos_z": loaded_player_position.z,
		"map_seed": loaded_map_seed
	}

	var file := FileAccess.open("user://save.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(save_data))

func load_game() -> void:
	if not FileAccess.file_exists("user://save.json"):
		return

	var file := FileAccess.open("user://save.json", FileAccess.READ)
	if file == null:
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		current_level = int(parsed.get("current_level", current_level))
		loaded_player_hp = int(parsed.get("player_hp", loaded_player_hp))
		loaded_player_sanity = float(parsed.get("player_sanity", loaded_player_sanity))
		loaded_map_seed = int(parsed.get("map_seed", 0))
		loaded_player_position = Vector3(
			float(parsed.get("player_pos_x", 0.0)),
			float(parsed.get("player_pos_y", 0.0)),
			float(parsed.get("player_pos_z", 0.0))
		)
		is_loading_save = true
		if SanityManager != null and "sanity" in SanityManager:
			SanityManager.sanity = loaded_player_sanity
		level_changed.emit(current_level)
