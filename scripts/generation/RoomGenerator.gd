extends Node

enum RoomType { NORMAL, JUNCTION, DEAD_END }

var rng: RandomNumberGenerator

func generate(room_count: int, seed_value: int) -> Array:
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value

	var rooms: Array = []
	var grid: Dictionary = {}
	var room_grid_pos: Array = []

	var cols: int = max(1, int(ceil(sqrt(float(room_count)))))
	var rows_count: int = int(ceil(float(room_count) / float(cols)))

	# Cada columna tiene un ancho fijo y cada fila un alto fijo.
	# Todas las habitaciones de una columna comparten ese ancho,
	# y todas las de una fila comparten ese alto.
	# Resultado: cada habitación ocupa EXACTAMENTE su celda, sin gaps.
	var col_widths: Array = []
	for _c in range(cols):
		col_widths.append(rng.randi_range(7, 14))

	var row_heights: Array = []
	for _r in range(rows_count):
		row_heights.append(rng.randi_range(7, 14))

	# Acumulamos offsets para conocer la posición de inicio de cada celda
	var col_offsets: Array = []
	var running: float = 0.0
	for c in range(cols):
		col_offsets.append(running)
		running += float(col_widths[c])

	var row_offsets: Array = []
	running = 0.0
	for r in range(rows_count):
		row_offsets.append(running)
		running += float(row_heights[r])

	# Construimos los rooms: el tamaño ES el tamaño de la celda
	for i in range(room_count):
		var col: int = i % cols
		var row: int = i / cols
		var gpos := Vector2i(col, row)
		grid[gpos] = i
		room_grid_pos.append(gpos)

		var room: Dictionary = {
			"id": i,
			"type": _get_room_type(i, room_count),
			"size": Vector2i(col_widths[col], row_heights[row]),
			"position": Vector2(col_offsets[col], row_offsets[row]),
			"connections": []
		}
		rooms.append(room)

	# Conectamos vecinos ortogonales inmediatos (derecha y abajo)
	for i in range(room_count):
		var gpos: Vector2i = room_grid_pos[i]

		var right := Vector2i(gpos.x + 1, gpos.y)
		if grid.has(right):
			var nb: int = grid[right]
			rooms[i]["connections"].append(nb)
			rooms[nb]["connections"].append(i)

		var below := Vector2i(gpos.x, gpos.y + 1)
		if grid.has(below):
			var nb: int = grid[below]
			rooms[i]["connections"].append(nb)
			rooms[nb]["connections"].append(i)

	return rooms

func _get_room_type(room_id: int, total_rooms: int) -> int:
	if room_id == 0 or room_id == total_rooms - 1:
		return RoomType.NORMAL
	return rng.randi_range(0, 2)
