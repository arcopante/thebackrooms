extends CharacterBody3D

@export var mouse_sensitivity: float = 0.003
@export var normal_speed: float = 4.5
@export var crouch_speed: float = 2.5
@export var acceleration: float = 10.0
@export var friction: float = 8.0

var is_crouching: bool = false
var current_speed: float = normal_speed

var stamina: float = 100.0
var max_stamina: float = 100.0
var is_running: bool = false
var can_run: bool = true

var hp: int = 100
var max_hp: int = 100

var head_bob_time: float = 0.0
var head_bob_amplitude: float = 0.05
var head_bob_frequency: float = 5.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var flashlight: SpotLight3D = $Head/SpotLight3D
@onready var game_manager = GameManager
@onready var sanity_manager = SanityManager

signal on_death()
signal on_damaged(new_hp: int)
signal flashlight_toggled(enabled: bool)

var sanity_damage_timer: float = 0.0
var _crouch_key_was_down: bool = false
var _flashlight_key_was_down: bool = false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	add_to_group("player")
	if sanity_manager:
		sanity_manager.on_sanity_changed.connect(_on_sanity_changed)
	flashlight_toggled.emit(flashlight.visible)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_delta = event.relative
		_handle_mouselook(mouse_delta)

func _process(delta: float) -> void:
	_handle_input()
	_update_stamina(delta)
	_update_head_bob(delta)
	_apply_sanity_damage(delta)
	_update_flashlight_input()

func _physics_process(delta: float) -> void:
	var input_dir := _get_movement_input()
	
	var move_dir = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if move_dir:
		velocity.x = lerp(velocity.x, move_dir.x * current_speed, acceleration * delta)
		velocity.z = lerp(velocity.z, move_dir.z * current_speed, acceleration * delta)
	else:
		velocity.x = lerp(velocity.x, 0.0, friction * delta)
		velocity.z = lerp(velocity.z, 0.0, friction * delta)
	
	velocity.y -= 9.8 * delta
	
	move_and_slide()

func _handle_mouselook(mouse_delta: Vector2) -> void:
	rotate_y(-mouse_delta.x * mouse_sensitivity)
	head.rotate_object_local(Vector3.RIGHT, -mouse_delta.y * mouse_sensitivity)
	head.rotation.x = clamp(head.rotation.x, -PI / 2 + 0.1, PI / 2 - 0.1)

func _handle_input() -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		GameManager.save_game()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
		return
	
	if _is_crouch_just_pressed():
		is_crouching = !is_crouching
		current_speed = crouch_speed if is_crouching else normal_speed
	
	is_running = _is_run_pressed() and not is_crouching and can_run and stamina > 0

func _update_stamina(delta: float) -> void:
	if is_running:
		stamina = max(0.0, stamina - 15.0 * delta)
		if stamina <= 0.0:
			can_run = false
	else:
		stamina = min(max_stamina, stamina + 10.0 * delta)
		if stamina >= 20.0:
			can_run = true

func _update_head_bob(delta: float) -> void:
	var speed_magnitude = Vector2(velocity.x, velocity.z).length()
	if speed_magnitude > 0.1:
		head_bob_time += delta * head_bob_frequency * (speed_magnitude / normal_speed)
		var bob_offset = sin(head_bob_time) * head_bob_amplitude
		head.position.y = 0.7 + bob_offset
	else:
		head_bob_time = 0.0
		head.position.y = 0.7

func _apply_sanity_damage(delta: float) -> void:
	if sanity_manager and sanity_manager.sanity < 30.0:
		sanity_damage_timer += delta
		if sanity_damage_timer >= 1.0:
			take_damage(1)
			sanity_damage_timer = 0.0

func _update_flashlight_input() -> void:
	if _is_flashlight_just_pressed():
		flashlight.visible = !flashlight.visible
		flashlight_toggled.emit(flashlight.visible)

func _get_movement_input() -> Vector2:
	var x_axis: float = 0.0
	var y_axis: float = 0.0

	if Input.is_action_pressed("move_left") or Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A):
		x_axis -= 1.0
	if Input.is_action_pressed("move_right") or Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_D):
		x_axis += 1.0
	if Input.is_action_pressed("move_forward") or Input.is_action_pressed("ui_up") or Input.is_physical_key_pressed(KEY_W):
		y_axis -= 1.0
	if Input.is_action_pressed("move_back") or Input.is_action_pressed("ui_down") or Input.is_physical_key_pressed(KEY_S):
		y_axis += 1.0

	return Vector2(x_axis, y_axis).normalized()

func _is_run_pressed() -> bool:
	return Input.is_action_pressed("run") or Input.is_action_pressed("ui_shift") or Input.is_physical_key_pressed(KEY_SHIFT)

func _is_crouch_just_pressed() -> bool:
	if Input.is_action_just_pressed("crouch") or Input.is_action_just_pressed("ui_select"):
		return true

	var current_down: bool = Input.is_physical_key_pressed(KEY_C)
	var just_pressed: bool = current_down and not _crouch_key_was_down
	_crouch_key_was_down = current_down
	return just_pressed

func _is_flashlight_just_pressed() -> bool:
	if Input.is_action_just_pressed("toggle_flashlight") or Input.is_action_just_pressed("ui_f"):
		return true

	var current_down: bool = Input.is_physical_key_pressed(KEY_F)
	var just_pressed: bool = current_down and not _flashlight_key_was_down
	_flashlight_key_was_down = current_down
	return just_pressed

func take_damage(amount: int) -> void:
	hp = max(0, hp - amount)
	on_damaged.emit(hp)
	if hp <= 0:
		game_manager.set_game_over_message("HAS SIDO ENCONTRADO")
		on_death.emit()
		game_manager.set_game_state("dead")

func heal(amount: int) -> void:
	hp = min(max_hp, hp + amount)
	on_damaged.emit(hp)

func _on_sanity_changed(value: float) -> void:
	pass
