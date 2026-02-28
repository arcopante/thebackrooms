extends Node

var sanity: float = 100.0
var is_in_dark_zone: bool = false
var is_seeing_entity: bool = false
var entities_nearby: int = 0  # entidades en la misma habitación

signal on_sanity_changed(value: float)
signal on_sanity_critical()

func _process(delta: float) -> void:
	var current_level: int = int(GameManager.current_level)
	var reduction_per_second: float = _get_level_sanity_drain(current_level)

	if is_in_dark_zone:
		reduction_per_second += 0.8
	if is_seeing_entity:
		reduction_per_second += 1.5
	if entities_nearby > 0:
		# Cada entidad cercana añade drenaje aunque no te esté mirando
		reduction_per_second += 1.2 * entities_nearby

	# La cordura SIEMPRE baja, nunca sube pasivamente
	reduce_sanity(max(reduction_per_second, 0.01) * delta)

func _get_level_sanity_drain(level: int) -> float:
	# Valores reducidos para que el juego sea más justo.
	# Con estos valores el jugador tarda ~3 minutos en perder toda la cordura
	# en el nivel más difícil sin ninguna amenaza adicional.
	match level:
		5:
			return 1.2
		4:
			return 0.9
		3:
			return 0.65
		2:
			return 0.45
		1:
			return 0.28
		0:
			return 0.15
		_:
			return 0.65

func reduce_sanity(amount: float) -> void:
	sanity = clamp(sanity - amount, 0.0, 100.0)
	on_sanity_changed.emit(sanity)
	# No llamamos set_game_state aquí para evitar recursión con GameLevel.
	# GameLevel escucha on_sanity_critical y gestiona la muerte.
	if sanity < 10.0:
		on_sanity_critical.emit()

func restore_sanity(amount: float) -> void:
	sanity = clamp(sanity + amount, 0.0, 100.0)
	on_sanity_changed.emit(sanity)

func reset_for_new_level(sanity_value: float) -> void:
	sanity           = clamp(sanity_value, 0.0, 100.0)
	is_in_dark_zone  = false
	is_seeing_entity = false
	entities_nearby  = 0
	on_sanity_changed.emit(sanity)
