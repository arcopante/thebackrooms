extends Node

const ENTITY_SCENE: PackedScene = preload("res://scenes/entities/Entity.tscn")

func spawn_entities(level: int, rooms: Array, parent: Node3D, player: CharacterBody3D) -> void:
	if ENTITY_SCENE == null or parent == null:
		return

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var entity_count: int = _get_entity_count_for_level(level, rng)
	if entity_count <= 0:
		return

	var valid_rooms: Array = []
	for room in rooms:
		var room_id: int = int(room.get("id", -1))
		if room_id != 0 and room_id != rooms.size() - 1:
			valid_rooms.append(room)

	if valid_rooms.is_empty():
		return

	for i in range(entity_count):
		var room: Dictionary = valid_rooms[rng.randi_range(0, valid_rooms.size() - 1)]
		var entity := ENTITY_SCENE.instantiate()
		if entity == null:
			continue

		var room_pos: Vector2 = room.get("position", Vector2.ZERO)
		var room_size: Vector2i = room.get("size", Vector2i(6, 6))
		var spawn_position := Vector3(
			room_pos.x + rng.randf_range(1.0, max(1.5, float(room_size.x) - 1.0)),
			0.95,  # mitad de la cápsula (height=1.9) para quedar sobre el suelo
			room_pos.y + rng.randf_range(1.0, max(1.5, float(room_size.y) - 1.0))
		)

		entity.set("player", player)
		parent.add_child(entity)
		# Posición DESPUÉS de add_child para que global_position funcione correctamente
		entity.global_position = spawn_position

func _get_entity_count_for_level(level: int, rng: RandomNumberGenerator) -> int:
	# El jugador progresa de nivel 5 → 0.
	# A medida que avanza, más entidades. Nivel 0 es victoria, sin entidades.
	match level:
		5: return rng.randi_range(1, 2)   # inicio: 1-2
		4: return rng.randi_range(2, 3)   # 2-3
		3: return rng.randi_range(3, 4)   # 3-4
		2: return 4                        # 4
		1: return rng.randi_range(4, 5)   # 4-5
		0: return 0                        # victoria
		_: return 1
