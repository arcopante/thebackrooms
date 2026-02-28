extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/Player.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/HUD.tscn")
const SANITY_EFFECTS_SCENE: PackedScene = preload("res://scenes/ui/SanityEffects.tscn")
const ROOM_GENERATOR_SCRIPT: Script = preload("res://scripts/generation/RoomGenerator.gd")
const LEVEL_BUILDER_SCRIPT: Script = preload("res://scripts/generation/LevelBuilder.gd")
const ENTITY_SPAWNER_SCRIPT: Script = preload("res://scripts/entities/EntitySpawner.gd")
const LEVEL_CONFIG_SCRIPT: Script = preload("res://scripts/generation/LevelConfig.gd")

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var room_generator: Node
var level_builder: Node
var player: CharacterBody3D
var current_rooms: Array = []

var _entity_spawner: Node
var _current_level: int = 5
var _current_exit_position: Vector3 = Vector3.ZERO
var _is_transitioning: bool = false

@onready var generated_level: Node3D = $NavRegion/GeneratedLevel
@onready var ui_layer: CanvasLayer = $UILayer
@onready var nav_region: NavigationRegion3D = $NavRegion

func _ready() -> void:
	rng.randomize()
	_current_level = int(GameManager.current_level)

	var config: Dictionary = LEVEL_CONFIG_SCRIPT.get_level(_current_level).duplicate(true)
	config["level"] = _current_level
	config["initial_flicker_probability"] = float(config.get("flicker_probability", 0.2))
	config["initial_off_probability"] = float(config.get("off_light_probability", 0.1))

	# Usar seed guardada al continuar para regenerar el mismo mapa
	var map_seed: int
	if GameManager.is_loading_save and GameManager.loaded_map_seed != 0:
		map_seed = GameManager.loaded_map_seed
	else:
		map_seed = rng.randi()
		GameManager.loaded_map_seed = map_seed

	room_generator = ROOM_GENERATOR_SCRIPT.new()
	add_child(room_generator)
	current_rooms = room_generator.generate(int(config.get("room_count", 10)), map_seed)

	level_builder = LEVEL_BUILDER_SCRIPT.new()
	level_builder.level_config = config
	add_child(level_builder)
	if not level_builder.level_built.is_connected(_on_level_built):
		level_builder.level_built.connect(_on_level_built)
	level_builder.build_level(current_rooms, generated_level)

	_entity_spawner = ENTITY_SPAWNER_SCRIPT.new()
	add_child(_entity_spawner)
	_entity_spawner.spawn_entities(_current_level, current_rooms, generated_level, player)

	if not GameManager.game_state_changed.is_connected(_on_game_state_changed):
		GameManager.game_state_changed.connect(_on_game_state_changed)

func _on_level_built(start_pos: Vector3, exit_pos: Vector3) -> void:
	_current_exit_position = exit_pos

	var player_instance := PLAYER_SCENE.instantiate() as CharacterBody3D
	if player_instance == null:
		return
	player = player_instance
	# Restaurar posición guardada al continuar; si no, usar el spawn inicial
	if GameManager.is_loading_save and GameManager.loaded_player_position != Vector3.ZERO:
		player.global_position = GameManager.loaded_player_position
		GameManager.is_loading_save = false
	else:
		player.global_position = start_pos
	generated_level.add_child(player)

	if GameManager.loaded_player_hp > 0 and "hp" in player:
		player.set("hp", clamp(GameManager.loaded_player_hp, 0, 100))
	if SanityManager != null:
		SanityManager.reset_for_new_level(GameManager.loaded_player_sanity)

	if player.has_signal("on_death") and not player.on_death.is_connected(_on_player_death):
		player.on_death.connect(_on_player_death)

	if _entity_spawner != null:
		_bind_player_to_existing_entities(player)

	var hud := HUD_SCENE.instantiate()
	ui_layer.add_child(hud)
	if hud.has_method("set_player"):
		hud.set_player(player)

	var sanity_effects := SANITY_EFFECTS_SCENE.instantiate()
	ui_layer.add_child(sanity_effects)

	if SanityManager != null:
		if not SanityManager.on_sanity_changed.is_connected(_on_sanity_changed):
			SanityManager.on_sanity_changed.connect(_on_sanity_changed)

	_create_exit_trigger(exit_pos)
	_bake_navigation()

func _on_sanity_changed(value: float) -> void:
	if value > 0.0:
		return
	if _is_transitioning:
		return
	_is_transitioning = true
	GameManager.death_reason = "sanity"
	GameManager.set_game_over_message("HAS PERDIDO LA RAZÓN")
	get_tree().change_scene_to_file("res://scenes/ui/GameOver.tscn")

func _create_exit_trigger(exit_pos: Vector3) -> void:
	var exit_area := Area3D.new()
	exit_area.name = "ExitTrigger"
	var collision_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(1.6, 2.4, 1.6)
	collision_shape.shape = box_shape
	exit_area.add_child(collision_shape)
	exit_area.position = exit_pos + Vector3(0.0, 1.2, 0.0)
	generated_level.add_child(exit_area)
	if not exit_area.body_entered.is_connected(_on_exit_reached):
		exit_area.body_entered.connect(_on_exit_reached)

func _on_exit_reached(body: Node) -> void:
	if _is_transitioning:
		return
	if player == null or body != player:
		return

	_is_transitioning = true
	if _current_level == 0:
		GameManager.save_game()
		get_tree().change_scene_to_file("res://scenes/ui/VictoryScreen.tscn")
		return

	await _play_fall_transition()
	GameManager.change_level(_current_level - 1)
	GameManager.save_game()
	get_tree().change_scene_to_file("res://scenes/levels/GameLevel.tscn")

func _play_fall_transition() -> void:
	var transition_layer := CanvasLayer.new()
	transition_layer.layer = 100
	add_child(transition_layer)

	var fade_rect := ColorRect.new()
	fade_rect.anchors_preset = Control.PRESET_FULL_RECT
	fade_rect.anchor_right = 1.0
	fade_rect.anchor_bottom = 1.0
	fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	transition_layer.add_child(fade_rect)

	var distortion_player := AudioStreamPlayer.new()
	distortion_player.stream = AudioStreamGenerator.new()
	transition_layer.add_child(distortion_player)
	distortion_player.play()

	var tween := create_tween()
	tween.tween_property(fade_rect, "color", Color(0.0, 0.0, 0.0, 1.0), 1.5)
	await tween.finished
	transition_layer.queue_free()

func _on_player_death() -> void:
	# Evitar doble ejecucion
	if _is_transitioning:
		return
	_is_transitioning = true

	if SanityManager != null and float(SanityManager.sanity) <= 0.0:
		GameManager.death_reason = "sanity"
		if GameManager.has_method("set_game_over_message"):
			GameManager.set_game_over_message("HAS PERDIDO LA RAZÓN")
	else:
		GameManager.death_reason = "damage"
		if GameManager.has_method("set_game_over_message"):
			GameManager.set_game_over_message("HAS SIDO ENCONTRADO")

	# NO llamamos set_game_state("dead") aqui porque emitiria game_state_changed
	# y volveriamos a entrar en este flujo creando recursion infinita.
	get_tree().change_scene_to_file("res://scenes/ui/GameOver.tscn")

func _on_game_state_changed(new_state: String) -> void:
	# Solo reacciona a muerte por cordura = 0.
	# La muerte por HP la gestiona _on_player_death() directamente.
	if new_state != "dead":
		return
	if _is_transitioning:
		return
	if get_tree().current_scene != self:
		return
	if SanityManager != null and float(SanityManager.sanity) <= 0.0:
		_is_transitioning = true
		GameManager.death_reason = "sanity"
		if GameManager.has_method("set_game_over_message"):
			GameManager.set_game_over_message("HAS PERDIDO LA RAZÓN")
		get_tree().change_scene_to_file("res://scenes/ui/GameOver.tscn")

func _bind_player_to_existing_entities(target_player: CharacterBody3D) -> void:
	for child in generated_level.get_children():
		if child != null and "player" in child:
			child.set("player", target_player)

func _bake_navigation() -> void:
	var nm: NavigationMesh = nav_region.navigation_mesh
	if nm == null:
		nm = NavigationMesh.new()
		nav_region.navigation_mesh = nm

	# Propiedades del agente acordes a la cápsula de Entity (height=1.9, radius=0.35)
	nm.agent_height = 1.9
	nm.agent_radius = 0.3
	nm.agent_max_climb = 0.25
	nm.agent_max_slope = 45.0
	nm.cell_size = 0.25
	nm.cell_height = 0.1

	# Parsear manualmente la geometría del nivel y hornear sincrónicamente
	var source_geometry := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, source_geometry, nav_region)
	NavigationServer3D.bake_from_source_geometry_data(nm, source_geometry)
	nav_region.navigation_mesh = nm
