extends CharacterBody3D

enum EntityState { IDLE, ALERT, CHASE, SEARCH }

const IDLE_SPEED: float = 1.5
const ALERT_SPEED: float = 2.5
const CHASE_SPEED: float = 5.0
const SEARCH_SPEED: float = 2.0
const LOST_SIGHT_THRESHOLD: float = 2.0
const SEARCH_DURATION: float = 15.0

var state: EntityState = EntityState.IDLE
var move_speed: float = IDLE_SPEED

var detection_range_sight: float = 20.0
var detection_range_hearing: float = 20.0
var last_known_player_position: Vector3 = Vector3.ZERO
var search_timer: float = 0.0
var attack_cooldown: float = 0.0

var player: CharacterBody3D

@onready var _alert_light: OmniLight3D = $AlertLight
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _wander_target: Vector3 = Vector3.ZERO
var _has_wander_target: bool = false
var _lost_sight_timer: float = 0.0
var _search_wander_timer: float = 0.0

# Detección de atasco y evasión de paredes
var _stuck_check_timer: float = 0.0
var _last_stuck_position: Vector3 = Vector3.ZERO
var _escape_dir: Vector3 = Vector3.ZERO
var _escape_timer: float = 0.0

# Proximidad: rastrea si esta entidad ya contabiliza cercanía al jugador
var _is_near_player: bool = false
const NEARBY_RANGE: float = 18.0  # radio de habitación más amplio

func _ready() -> void:
	_rng.randomize()
	_set_state(EntityState.IDLE)

func _process(delta: float) -> void:
	if attack_cooldown > 0.0:
		attack_cooldown = max(0.0, attack_cooldown - delta)

	if player == null:
		return

	# Proximidad: si la entidad está en la misma habitación, la cordura baja más
	var near: bool = global_position.distance_to(player.global_position) <= NEARBY_RANGE
	if near != _is_near_player:
		_is_near_player = near
		if near:
			SanityManager.entities_nearby += 1
		else:
			SanityManager.entities_nearby = max(0, SanityManager.entities_nearby - 1)

	match state:
		EntityState.IDLE:
			_process_idle(delta)
		EntityState.ALERT:
			_process_alert(delta)
		EntityState.CHASE:
			_process_chase(delta)
		EntityState.SEARCH:
			_process_search(delta)

func _physics_process(delta: float) -> void:
	var desired_dir: Vector3 = _get_desired_direction()

	# --- Evasión activa de pared: deslizar a lo largo de la pared ---
	if get_slide_collision_count() > 0 and _escape_timer <= 0.0:
		var col := get_slide_collision(0)
		var wall_normal := col.get_normal()
		wall_normal.y = 0.0
		if wall_normal.length() > 0.01:
			# Proyectar la dirección deseada sobre el plano de la pared (slide)
			var slide_component := desired_dir - wall_normal * desired_dir.dot(wall_normal)
			if slide_component.length() > 0.01:
				desired_dir = slide_component.normalized()

	# --- Detección de atasco: si lleva 0.5 s sin moverse, girar 90° ---
	_stuck_check_timer += delta
	if _stuck_escape_timer_decrement(delta) or _stuck_check_timer >= 0.5:
		if _stuck_check_timer >= 0.5:
			_stuck_check_timer = 0.0
			var moved := global_position.distance_to(_last_stuck_position)
			if moved < 0.15 and move_speed > 0.0:
				# Perpendicular al objetivo, lado aleatorio
				var perp := Vector3(-desired_dir.z, 0.0, desired_dir.x)
				if _rng.randf() > 0.5:
					perp = -perp
				_escape_dir = perp
				_escape_timer = 0.55
			_last_stuck_position = global_position

	if _escape_timer > 0.0:
		desired_dir = _escape_dir

	if desired_dir.length() > 0.05:
		velocity.x = desired_dir.x * move_speed
		velocity.z = desired_dir.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 4.0)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 4.0)

	velocity.y -= 9.8 * delta
	move_and_slide()

	if velocity.length_squared() > 0.001:
		look_at(global_position + Vector3(velocity.x, 0.0, velocity.z), Vector3.UP)

func _stuck_escape_timer_decrement(delta: float) -> bool:
	if _escape_timer > 0.0:
		_escape_timer -= delta
		return true
	return false

func _get_desired_direction() -> Vector3:
	var nav_pos: Vector3 = navigation_agent.get_next_path_position()
	var nav_dir: Vector3 = nav_pos - global_position
	nav_dir.y = 0.0

	if nav_dir.length() > 0.2:
		return nav_dir.normalized()

	# Fallback: en CHASE seguir posición actual del jugador
	var target: Vector3 = Vector3.ZERO
	if state == EntityState.CHASE and player != null:
		target = player.global_position
	elif navigation_agent.target_position != Vector3.ZERO:
		target = navigation_agent.target_position
	elif player != null:
		target = player.global_position

	var fallback_dir: Vector3 = target - global_position
	fallback_dir.y = 0.0
	if fallback_dir.length() > 0.2:
		return fallback_dir.normalized()

	return Vector3.ZERO

func _process_idle(_delta: float) -> void:
	move_speed = IDLE_SPEED

	if _can_detect_player():
		last_known_player_position = player.global_position
		_set_state(EntityState.ALERT)
		return

	if not _has_wander_target or navigation_agent.is_navigation_finished():
		_wander_target = _get_random_point_near(global_position, 6.0)
		navigation_agent.target_position = _wander_target
		_has_wander_target = true

func _process_alert(_delta: float) -> void:
	move_speed = ALERT_SPEED
	navigation_agent.target_position = last_known_player_position

	if _can_see_player():
		_set_state(EntityState.CHASE)
		return

	if navigation_agent.is_navigation_finished():
		_set_state(EntityState.SEARCH)

func _process_chase(delta: float) -> void:
	# Iguala la velocidad del jugador: si el jugador camina, la entidad camina;
	# si el jugador se agacha, la entidad se ralentiza. Mínimo 0.5 para que
	# siempre se acerque aunque el jugador esté parado.
	var player_speed: float = 0.0
	if "current_speed" in player:
		player_speed = float(player.current_speed)
	else:
		player_speed = CHASE_SPEED
	move_speed = max(0.5, player_speed)

	SanityManager.is_seeing_entity = true

	if player == null:
		_set_state(EntityState.SEARCH)
		return

	navigation_agent.target_position = player.global_position

	if _can_see_player():
		last_known_player_position = player.global_position
		_lost_sight_timer = 0.0
	else:
		_lost_sight_timer += delta
		if _lost_sight_timer >= LOST_SIGHT_THRESHOLD:
			_set_state(EntityState.SEARCH)
			return

	if global_position.distance_to(player.global_position) < 1.5 and attack_cooldown <= 0.0:
		if player.has_method("take_damage"):
			player.take_damage(25)
		attack_cooldown = 1.5

func _process_search(delta: float) -> void:
	move_speed = SEARCH_SPEED
	search_timer += delta
	_search_wander_timer += delta

	if _can_see_player():
		_set_state(EntityState.CHASE)
		return

	if _search_wander_timer >= 2.0 or navigation_agent.is_navigation_finished():
		_search_wander_timer = 0.0
		var search_target: Vector3 = _get_random_point_near(last_known_player_position, 4.0)
		navigation_agent.target_position = search_target

	if search_timer >= SEARCH_DURATION:
		_set_state(EntityState.IDLE)

func _set_state(new_state: EntityState) -> void:
	if state == EntityState.CHASE and new_state != EntityState.CHASE:
		SanityManager.is_seeing_entity = false

	state = new_state

	# Luz roja: encendida solo cuando persigue (te ha visto directamente)
	if _alert_light != null:
		_alert_light.visible = (state == EntityState.CHASE)

	match state:
		EntityState.IDLE:
			_has_wander_target = false
		EntityState.ALERT:
			navigation_agent.target_position = last_known_player_position
		EntityState.CHASE:
			_lost_sight_timer = 0.0
		EntityState.SEARCH:
			search_timer = 0.0
			_search_wander_timer = 2.0

func _can_detect_player() -> bool:
	return _can_see_player() or _can_hear_player()

func _can_see_player() -> bool:
	if player == null:
		return false

	var effective_sight: float = detection_range_sight
	if player.has_node("Head/SpotLight3D"):
		var flashlight: SpotLight3D = player.get_node("Head/SpotLight3D") as SpotLight3D
		if flashlight != null and flashlight.visible:
			effective_sight *= 2.0

	var to_player: Vector3 = player.global_position - global_position
	var distance: float = to_player.length()
	if distance > effective_sight:
		return false

	# Ángulo amplio: la entidad percibe al jugador en toda la habitación
	var forward: Vector3 = -global_transform.basis.z
	var direction_to_player: Vector3 = to_player.normalized()
	var angle: float = rad_to_deg(acos(clamp(forward.dot(direction_to_player), -1.0, 1.0)))
	if angle > 180.0:
		return false

	var from: Vector3 = global_position + Vector3.UP * 1.4
	var to: Vector3 = player.global_position + Vector3.UP * 1.2
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)

	if result.is_empty():
		return false

	return result.get("collider") == player

func _can_hear_player() -> bool:
	if player == null:
		return false

	var effective_hearing: float = detection_range_hearing
	var player_crouching: bool = false
	var player_running: bool = false

	if "is_crouching" in player:
		player_crouching = bool(player.is_crouching)
	if "is_running" in player:
		player_running = bool(player.is_running)

	if player_crouching and not player_running:
		effective_hearing *= 0.5

	return global_position.distance_to(player.global_position) <= effective_hearing

func _get_random_point_near(origin: Vector3, radius: float) -> Vector3:
	var offset := Vector3(
		_rng.randf_range(-radius, radius),
		0.0,
		_rng.randf_range(-radius, radius)
	)
	return origin + offset
