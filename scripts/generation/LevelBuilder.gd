extends Node

@export var level_config: Dictionary = {}

signal level_built(start_position: Vector3, exit_position: Vector3)

const CEILING_HEIGHT: float = 2.8
const DOORWAY_WIDTH: float  = 2.0   # ancho del hueco entre habitaciones
const DOORWAY_HEIGHT: float = 2.4   # alto del hueco (deja un dintel arriba)

const FLUORESCENT_SCENE: PackedScene = preload("res://scenes/rooms/FluorescentLight.tscn")
const HAZARD_ZONE_SCENE: PackedScene  = preload("res://scenes/rooms/HazardZone.tscn")

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# ---------------------------------------------------------------------------
# PUNTO DE ENTRADA
# ---------------------------------------------------------------------------
func build_level(rooms: Array, parent_node: Node3D) -> void:
	rng.randomize()
	_ensure_world_environment(parent_node)
	var level_number: int = int(level_config.get("level", int(GameManager.current_level)))

	var start_position: Vector3 = Vector3.ZERO
	var exit_position:  Vector3 = Vector3.ZERO

	# Pre-calculamos para cada habitación qué lados tienen hueco y dónde
	var door_info: Dictionary = _compute_door_info(rooms)

	var exit_room: Dictionary = {}
	var has_windows: bool = bool(level_config.get("has_windows", false))

	for room in rooms:
		var room_id:    int      = room["id"]
		var size:       Vector2i = room["size"]
		var pos2d:      Vector2  = room["position"]
		var pos3d:      Vector3  = Vector3(pos2d.x, 0.0, pos2d.y)

		if room_id == 0:
			start_position = pos3d + Vector3(size.x * 0.5, 1.0, size.y * 0.5)
		elif room_id == rooms.size() - 1:
			exit_position = pos3d + Vector3(size.x * 0.5, 1.0, size.y * 0.5)
			exit_room = room

		var doors: Array = door_info.get(room_id, [])
		_build_room(size, pos3d, doors, parent_node)
		_add_fluorescent_lights(size, pos3d, parent_node)
		if has_windows:
			_add_windows(size, pos3d, doors, parent_node)

	_add_hazard_zones(level_number, rooms, parent_node)

	# Construimos la salida visible en la habitación de destino
	if not exit_room.is_empty():
		_build_exit_marker(exit_room, parent_node)

	level_built.emit(start_position, exit_position)

# ---------------------------------------------------------------------------
# CÁLCULO DE PUERTAS
# Para cada par de habitaciones conectadas calculamos en qué lado de cada
# habitación está el hueco y cuál es el centro del hueco en coords mundo.
#
# door_info[room_id] = Array de { side, center_along }
#   side:         "x_neg" | "x_pos" | "z_neg" | "z_pos"
#   center_along: coordenada mundo del centro del hueco a lo largo de la pared
# ---------------------------------------------------------------------------
func _compute_door_info(rooms: Array) -> Dictionary:
	var result: Dictionary = {}
	var processed: Dictionary = {}

	for room in rooms:
		var rid: int = room["id"]
		if not result.has(rid):
			result[rid] = []

		for nb_id_v in room["connections"]:
			var nb_id: int = int(nb_id_v)
			var key: String = "%d_%d" % [min(rid, nb_id), max(rid, nb_id)]
			if processed.has(key):
				continue
			processed[key] = true

			var nb_room: Dictionary = _find_room_by_id(rooms, nb_id)
			if nb_room.is_empty():
				continue

			if not result.has(nb_id):
				result[nb_id] = []

			var side_a: String = _side_towards(room, nb_room)
			var side_b: String = _side_towards(nb_room, room)

			# El centro del hueco es el centro de la pared compartida.
			# Para habitaciones adyacentes la pared compartida es exactamente
			# el borde de ambas, así que usamos el centro de la habitación
			# proyectado sobre el eje paralelo a la pared.
			var ca: float = _center_along(room, side_a)
			var cb: float = _center_along(nb_room, side_b)
			# Usamos el promedio para que el hueco quede centrado respecto a ambas
			var shared_center: float = (ca + cb) * 0.5

			result[rid].append({ "side": side_a, "center_along": shared_center })
			result[nb_id].append({ "side": side_b, "center_along": shared_center })

	return result

func _center_along(room: Dictionary, side: String) -> float:
	var p: Vector2  = room["position"]
	var s: Vector2i = room["size"]
	match side:
		"x_pos", "x_neg":
			return p.y + float(s.y) * 0.5   # centro en Z
		"z_pos", "z_neg":
			return p.x + float(s.x) * 0.5   # centro en X
		_:
			return 0.0

# ---------------------------------------------------------------------------
# CONSTRUCCIÓN DE UNA HABITACIÓN
# ---------------------------------------------------------------------------
func _build_room(size: Vector2i, room_pos: Vector3, doors: Array, parent: Node3D) -> void:
	# Suelo
	_place_box(Vector3(size.x, 0.1, size.y),
			   room_pos + Vector3(size.x * 0.5, -0.05, size.y * 0.5), parent)
	# Techo
	_place_box(Vector3(size.x, 0.1, size.y),
			   room_pos + Vector3(size.x * 0.5, CEILING_HEIGHT + 0.05, size.y * 0.5), parent)

	# Agrupamos las puertas por lado
	var by_side: Dictionary = { "x_neg": [], "x_pos": [], "z_neg": [], "z_pos": [] }
	for d in doors:
		by_side[d["side"]].append(d["center_along"])

	# Cuatro paredes
	_build_wall_z(room_pos, size, room_pos.z,              by_side["z_neg"], parent)  # Sur
	_build_wall_z(room_pos, size, room_pos.z + size.y,     by_side["z_pos"], parent)  # Norte
	_build_wall_x(room_pos, size, room_pos.x,              by_side["x_neg"], parent)  # Oeste
	_build_wall_x(room_pos, size, room_pos.x + size.x,     by_side["x_pos"], parent)  # Este

# Pared horizontal (perpendicular a Z, a lo largo de X)
func _build_wall_z(room_pos: Vector3, size: Vector2i, z_world: float,
				   door_centers: Array, parent: Node3D) -> void:
	var wall_start: float = room_pos.x
	var wall_end:   float = room_pos.x + float(size.x)
	_build_wall_segments(wall_start, wall_end, door_centers,
		func(seg_start, seg_end):
			var seg_len: float = seg_end - seg_start
			var cx: float = seg_start + seg_len * 0.5
			# Parte baja (suelo → alto hueco)
			_place_box(Vector3(seg_len, DOORWAY_HEIGHT, 0.1),
					   Vector3(cx, DOORWAY_HEIGHT * 0.5, z_world), parent)
			# Dintel (alto hueco → techo)
			var lintel_h: float = CEILING_HEIGHT - DOORWAY_HEIGHT
			if lintel_h > 0.01:
				_place_box(Vector3(seg_len, lintel_h, 0.1),
						   Vector3(cx, DOORWAY_HEIGHT + lintel_h * 0.5, z_world), parent)
	)

# Pared vertical (perpendicular a X, a lo largo de Z)
func _build_wall_x(room_pos: Vector3, size: Vector2i, x_world: float,
				   door_centers: Array, parent: Node3D) -> void:
	var wall_start: float = room_pos.z
	var wall_end:   float = room_pos.z + float(size.y)
	_build_wall_segments(wall_start, wall_end, door_centers,
		func(seg_start, seg_end):
			var seg_len: float = seg_end - seg_start
			var cz: float = seg_start + seg_len * 0.5
			_place_box(Vector3(0.1, DOORWAY_HEIGHT, seg_len),
					   Vector3(x_world, DOORWAY_HEIGHT * 0.5, cz), parent)
			var lintel_h: float = CEILING_HEIGHT - DOORWAY_HEIGHT
			if lintel_h > 0.01:
				_place_box(Vector3(0.1, lintel_h, seg_len),
						   Vector3(x_world, DOORWAY_HEIGHT + lintel_h * 0.5, cz), parent)
	)

# Divide una pared lineal [wall_start, wall_end] en segmentos sólidos
# evitando los huecos de las puertas, y llama a emit_fn(seg_start, seg_end)
# para cada segmento sólido.
func _build_wall_segments(wall_start: float, wall_end: float,
						  door_centers: Array, emit_fn: Callable) -> void:
	var half: float = DOORWAY_WIDTH * 0.5
	var wall_len: float = wall_end - wall_start

	# Construimos la lista de huecos como intervalos [a, b] en coords mundo,
	# clampados al rango de la pared.
	var gaps: Array = []
	for dc in door_centers:
		var a: float = clamp(float(dc) - half, wall_start, wall_end)
		var b: float = clamp(float(dc) + half, wall_start, wall_end)
		if b > a + 0.05:
			gaps.append([a, b])

	# Ordenamos y fusionamos huecos solapados
	gaps.sort_custom(func(x, y): return x[0] < y[0])
	var merged: Array = []
	for g in gaps:
		if merged.is_empty() or g[0] >= merged[-1][1]:
			merged.append([g[0], g[1]])
		else:
			merged[-1][1] = max(merged[-1][1], g[1])

	# Emitimos segmentos sólidos entre los huecos
	var cursor: float = wall_start
	for gap in merged:
		if gap[0] > cursor + 0.05:
			emit_fn.call(cursor, gap[0])
		cursor = gap[1]
	if cursor < wall_end - 0.05:
		emit_fn.call(cursor, wall_end)

# ---------------------------------------------------------------------------
# HELPERS DE GEOMETRÍA
# ---------------------------------------------------------------------------
func _place_box(box_size: Vector3, box_center: Vector3, parent: Node3D) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box_size
	mi.mesh = bm
	mi.position = box_center
	parent.add_child(mi)

	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = box_size
	cs.shape = bs
	sb.add_child(cs)
	sb.position = box_center
	parent.add_child(sb)

# ---------------------------------------------------------------------------
# HELPERS DE CÁLCULO
# ---------------------------------------------------------------------------
func _side_towards(room: Dictionary, target: Dictionary) -> String:
	var rp: Vector2  = room["position"]
	var rs: Vector2i = room["size"]
	var tp: Vector2  = target["position"]
	var ts: Vector2i = target["size"]
	var my_c: Vector2    = rp + Vector2(rs.x, rs.y) * 0.5
	var their_c: Vector2 = tp + Vector2(ts.x, ts.y) * 0.5
	var d: Vector2 = their_c - my_c
	if abs(d.x) >= abs(d.y):
		return "x_pos" if d.x >= 0.0 else "x_neg"
	return "z_pos" if d.y >= 0.0 else "z_neg"

func _find_room_by_id(rooms: Array, room_id: int) -> Dictionary:
	for r in rooms:
		if int(r.get("id", -1)) == room_id:
			return r
	return {}

# ---------------------------------------------------------------------------
# ENTORNO
# ---------------------------------------------------------------------------
func _ensure_world_environment(parent: Node3D) -> void:
	for child in parent.get_children():
		if child is WorldEnvironment:
			return
	var we := WorldEnvironment.new()
	we.name = "LevelWorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_energy = float(level_config.get("ambient_light_energy", 0.06))
	env.fog_enabled = true
	env.fog_light_color = Color("000000")
	env.fog_density = float(level_config.get("fog_density", 0.02))
	we.environment = env
	parent.add_child(we)

func _add_fluorescent_lights(size: Vector2i, room_position: Vector3, parent: Node3D) -> void:
	if FLUORESCENT_SCENE == null:
		return
	var area: int = size.x * size.y
	var light_count: int = 1
	if area >= 120:
		light_count = 3
	elif area >= 60:
		light_count = 2

	var flicker_prob: float = float(level_config.get("initial_flicker_probability", 0.2))
	var off_prob:     float = float(level_config.get("initial_off_probability", 0.1))

	for i in range(light_count):
		var li := FLUORESCENT_SCENE.instantiate()
		if li == null:
			continue
		var px: float = room_position.x + (float(i + 1) / float(light_count + 1)) * size.x
		var pz: float = room_position.z + size.y * 0.5
		li.position = Vector3(px, CEILING_HEIGHT - 0.12, pz)
		# IMPORTANTE: asignar ANTES de add_child para que _ready() use estos valores
		li.set("initial_flicker_probability", flicker_prob)
		li.set("initial_off_probability", off_prob)
		# Forzamos también el estado inicial aquí por si _ready ya se ejecutó
		parent.add_child(li)
		if li.has_method("_decide_initial_state"):
			li._decide_initial_state()


# ---------------------------------------------------------------------------
# VENTANAS (solo nivel 0)
# Se colocan en segmentos de pared que no tienen puerta.
# Cada ventana es un panel emisivo azul-gris que simula luz exterior
# más una OmniLight tenue que proyecta luz fría hacia el interior.
# ---------------------------------------------------------------------------
func _add_windows(size: Vector2i, room_pos: Vector3, doors: Array, parent: Node3D) -> void:
	# Agrupamos los centros de puerta por lado para saber qué lados tienen hueco
	var by_side: Dictionary = { "x_neg": [], "x_pos": [], "z_neg": [], "z_pos": [] }
	for d in doors:
		by_side[d["side"]].append(d["center_along"])

	# Intentamos poner una ventana en cada lado que tenga espacio libre suficiente
	# Definimos los 4 lados como [side_key, coord_fija, wall_start, wall_end, es_z]
	var sides_data: Array = [
		["z_neg", room_pos.z,                room_pos.x, room_pos.x + size.x, true],
		["z_pos", room_pos.z + size.y,        room_pos.x, room_pos.x + size.x, true],
		["x_neg", room_pos.x,                room_pos.z, room_pos.z + size.y,  false],
		["x_pos", room_pos.x + size.x,       room_pos.z, room_pos.z + size.y,  false],
	]

	var WIN_W: float = 1.8   # ancho de la ventana
	var WIN_H: float = 1.0   # alto de la ventana
	var WIN_Y: float = 1.4   # altura del centro de la ventana desde el suelo

	# Material de ventana: emisivo azul-gris frío simulando cielo exterior
	var win_mat := StandardMaterial3D.new()
	win_mat.albedo_color    = Color(0.55, 0.65, 0.75, 1.0)
	win_mat.emission_enabled = true
	win_mat.emission        = Color(0.4, 0.55, 0.7) * 1.8
	win_mat.metallic        = 0.0
	win_mat.roughness       = 1.0

	for sd in sides_data:
		var side_key:   String  = sd[0]
		var fixed:      float   = sd[1]
		var wstart:     float   = sd[2]
		var wend:       float   = sd[3]
		var is_z_wall:  bool    = sd[4]

		var door_centers: Array = by_side[side_key]

		# Buscamos un hueco libre de al menos WIN_W + 1.0 metros en esta pared
		# construyendo la lista de segmentos libres igual que _build_wall_segments
		var half: float  = DOORWAY_WIDTH * 0.5
		var gaps: Array  = []
		for dc in door_centers:
			var a: float = clamp(float(dc) - half, wstart, wend)
			var b: float = clamp(float(dc) + half, wstart, wend)
			if b > a + 0.05:
				gaps.append([a, b])
		gaps.sort_custom(func(x, y): return x[0] < y[0])
		var merged: Array = []
		for g in gaps:
			if merged.is_empty() or g[0] >= merged[-1][1]:
				merged.append([g[0], g[1]])
			else:
				merged[-1][1] = max(merged[-1][1], g[1])

		# Lista de segmentos libres
		var free_segments: Array = []
		var cursor: float = wstart
		for gap in merged:
			if gap[0] > cursor + 0.05:
				free_segments.append([cursor, gap[0]])
			cursor = gap[1]
		if cursor < wend - 0.05:
			free_segments.append([cursor, wend])

		# Ponemos una ventana por segmento libre si cabe
		for seg in free_segments:
			var seg_len: float = seg[1] - seg[0]
			if seg_len < WIN_W + 1.0:
				continue   # segmento demasiado corto

			# Centramos la ventana en el segmento
			var win_center_along: float = seg[0] + seg_len * 0.5

			# Posición 3D del centro de la ventana
			var win_pos: Vector3
			if is_z_wall:
				win_pos = Vector3(win_center_along, WIN_Y, fixed)
			else:
				win_pos = Vector3(fixed, WIN_Y, win_center_along)

			# Panel de ventana (fino, sin colisión, solo visual)
			var wmi := MeshInstance3D.new()
			var wbm := BoxMesh.new()
			wbm.size = Vector3(WIN_W, WIN_H, 0.05) if is_z_wall else Vector3(0.05, WIN_H, WIN_W)
			wmi.mesh = wbm
			wmi.position = win_pos
			wmi.material_override = win_mat
			parent.add_child(wmi)

			# Marco de la ventana (4 piezas finas en color gris oscuro)
			var frame_mat := StandardMaterial3D.new()
			frame_mat.albedo_color = Color(0.25, 0.25, 0.25)
			var frame_thickness: float = 0.08
			var frame_pieces: Array
			if is_z_wall:
				frame_pieces = [
					# arriba
					[Vector3(WIN_W + frame_thickness * 2, frame_thickness, 0.1),
					 win_pos + Vector3(0, WIN_H * 0.5 + frame_thickness * 0.5, 0)],
					# abajo
					[Vector3(WIN_W + frame_thickness * 2, frame_thickness, 0.1),
					 win_pos + Vector3(0, -WIN_H * 0.5 - frame_thickness * 0.5, 0)],
					# izquierda
					[Vector3(frame_thickness, WIN_H, 0.1),
					 win_pos + Vector3(-WIN_W * 0.5 - frame_thickness * 0.5, 0, 0)],
					# derecha
					[Vector3(frame_thickness, WIN_H, 0.1),
					 win_pos + Vector3(WIN_W * 0.5 + frame_thickness * 0.5, 0, 0)],
				]
			else:
				frame_pieces = [
					[Vector3(0.1, frame_thickness, WIN_W + frame_thickness * 2),
					 win_pos + Vector3(0, WIN_H * 0.5 + frame_thickness * 0.5, 0)],
					[Vector3(0.1, frame_thickness, WIN_W + frame_thickness * 2),
					 win_pos + Vector3(0, -WIN_H * 0.5 - frame_thickness * 0.5, 0)],
					[Vector3(0.1, WIN_H, frame_thickness),
					 win_pos + Vector3(0, 0, -WIN_W * 0.5 - frame_thickness * 0.5)],
					[Vector3(0.1, WIN_H, frame_thickness),
					 win_pos + Vector3(0, 0, WIN_W * 0.5 + frame_thickness * 0.5)],
				]
			for fp in frame_pieces:
				var fmi := MeshInstance3D.new()
				var fbm := BoxMesh.new()
				fbm.size = fp[0]
				fmi.mesh = fbm
				fmi.position = fp[1]
				fmi.material_override = frame_mat
				parent.add_child(fmi)

			# Luz fría que entra por la ventana hacia el interior
			var wlight := OmniLight3D.new()
			var light_offset: Vector3
			if is_z_wall:
				light_offset = Vector3(0, 0, 1.5) if fixed < room_pos.z + size.y * 0.5 else Vector3(0, 0, -1.5)
			else:
				light_offset = Vector3(1.5, 0, 0) if fixed < room_pos.x + size.x * 0.5 else Vector3(-1.5, 0, 0)
			wlight.position      = win_pos + light_offset
			wlight.light_color   = Color(0.7, 0.82, 1.0)
			wlight.light_energy  = 0.9
			wlight.omni_range    = 6.0
			parent.add_child(wlight)

# ---------------------------------------------------------------------------
# ZONAS DE PELIGRO
# ---------------------------------------------------------------------------
func _add_hazard_zones(level: int, rooms: Array, parent: Node3D) -> void:
	if level < 3 or HAZARD_ZONE_SCENE == null:
		return
	var hazard_count: int = rng.randi_range(2, 5)
	var candidates: Array = []
	for room in rooms:
		var rid: int = int(room.get("id", -1))
		if rid != 0 and rid != rooms.size() - 1:
			candidates.append(room)
	if candidates.is_empty():
		return
	for _i in range(hazard_count):
		var room: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
		var hz := HAZARD_ZONE_SCENE.instantiate()
		if hz == null:
			continue
		var rp: Vector2   = room.get("position", Vector2.ZERO)
		var rs: Vector2i  = room.get("size", Vector2i(6, 6))
		var zs := Vector3(clamp(float(rs.x) * 0.4, 2.0, 5.0), 0.1, clamp(float(rs.y) * 0.4, 2.0, 5.0))
		hz.position = Vector3(rp.x + float(rs.x) * 0.5, 0.05, rp.y + float(rs.y) * 0.5)
		hz.set("box_size", zs)
		hz.set("hazard_type", _pick_hazard_type(level))
		parent.add_child(hz)

func _pick_hazard_type(level: int) -> int:
	var types: Array[int] = [0, 1, 3]
	if level >= 4:
		types.append(2)
	return types[rng.randi_range(0, types.size() - 1)]
# ---------------------------------------------------------------------------
# SALIDA DEL NIVEL: hueco en el suelo con luz verde y señal visual
# ---------------------------------------------------------------------------
func _build_exit_marker(room: Dictionary, parent: Node3D) -> void:
	var pos2d: Vector2  = room["position"]
	var size:  Vector2i = room["size"]

	# Centro de la habitación en 3D
	var cx: float = pos2d.x + float(size.x) * 0.5
	var cz: float = pos2d.y + float(size.y) * 0.5

	# --- Hueco en el suelo: quitamos el suelo central y ponemos un marco ---
	# Marco norte
	_place_box(Vector3(float(size.x), 0.1, float(size.y) * 0.5 - 1.0),
			   Vector3(cx, -0.05, pos2d.y + float(size.y) * 0.25 - 0.5), parent)
	# Marco sur
	_place_box(Vector3(float(size.x), 0.1, float(size.y) * 0.5 - 1.0),
			   Vector3(cx, -0.05, pos2d.y + float(size.y) * 0.75 + 0.5), parent)
	# Marco oeste
	_place_box(Vector3(float(size.x) * 0.5 - 1.0, 0.1, 2.0),
			   Vector3(pos2d.x + float(size.x) * 0.25 - 0.5, -0.05, cz), parent)
	# Marco este
	_place_box(Vector3(float(size.x) * 0.5 - 1.0, 0.1, 2.0),
			   Vector3(pos2d.x + float(size.x) * 0.75 + 0.5, -0.05, cz), parent)

	# --- Fondo del hueco: plano negro a -1m para que parezca profundo ---
	_place_box(Vector3(2.0, 0.1, 2.0), Vector3(cx, -1.0, cz), parent)

	# --- Luz verde que sube desde el hueco ---
	var exit_light := OmniLight3D.new()
	exit_light.light_color     = Color(0.0, 1.0, 0.3)
	exit_light.light_energy    = 2.5
	exit_light.omni_range      = 8.0
	exit_light.position        = Vector3(cx, 0.3, cz)
	parent.add_child(exit_light)

	# --- Partículas de niebla verde (GPUParticles3D simple) ---
	var particles := GPUParticles3D.new()
	particles.position     = Vector3(cx, 0.5, cz)
	particles.amount       = 24
	particles.lifetime     = 2.0
	particles.emitting     = true
	particles.one_shot     = false

	var pmaterial := ParticleProcessMaterial.new()
	pmaterial.direction            = Vector3(0, 1, 0)
	pmaterial.initial_velocity_min = 0.3
	pmaterial.initial_velocity_max = 0.8
	pmaterial.spread               = 20.0
	pmaterial.gravity              = Vector3(0, -0.1, 0)
	pmaterial.scale_min            = 0.15
	pmaterial.scale_max            = 0.35
	pmaterial.color                = Color(0.0, 1.0, 0.3, 0.6)
	particles.process_material     = pmaterial

	var pmesh := SphereMesh.new()
	pmesh.radius = 0.08
	pmesh.height = 0.16
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color     = Color(0.0, 1.0, 0.3, 0.6)
	pmat.emission_enabled = true
	pmat.emission         = Color(0.0, 1.0, 0.3)
	pmat.transparency     = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmesh.surface_set_material(0, pmat)
	particles.draw_passes = 1
	particles.set_draw_pass_mesh(0, pmesh)
	parent.add_child(particles)

	# --- Borde del hueco: 4 bordes de color verde oscuro ---
	var border_mat := StandardMaterial3D.new()
	border_mat.albedo_color   = Color(0.0, 0.4, 0.1)
	border_mat.emission_enabled = true
	border_mat.emission       = Color(0.0, 0.6, 0.15)

	for border_data in [
		[Vector3(2.2, 0.12, 0.1),  Vector3(cx,       -0.05, cz - 1.05)],
		[Vector3(2.2, 0.12, 0.1),  Vector3(cx,       -0.05, cz + 1.05)],
		[Vector3(0.1, 0.12, 2.0),  Vector3(cx - 1.05, -0.05, cz)],
		[Vector3(0.1, 0.12, 2.0),  Vector3(cx + 1.05, -0.05, cz)],
	]:
		var bmi := MeshInstance3D.new()
		var bbm := BoxMesh.new()
		bbm.size          = border_data[0]
		bmi.mesh          = bbm
		bmi.position      = border_data[1]
		bmi.material_override = border_mat
		parent.add_child(bmi)
