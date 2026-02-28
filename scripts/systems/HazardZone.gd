extends Area3D

enum HazardType { WET_FLOOR, MOLD_ZONE, VOID_ZONE, ELECTRICAL }

@export var hazard_type: HazardType = HazardType.WET_FLOOR
@export var box_size: Vector3 = Vector3(4, 0.1, 4)

var player_inside: bool = false
var damage_timer: float = 0.0
var electrical_pulse_timer: float = 0.0

signal electrical_pulse()

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var omni_light: OmniLight3D = $OmniLight3D
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D

var _player: CharacterBody3D
var _wet_original_normal_speed: float = -1.0
var _wet_original_crouch_speed: float = -1.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_sync_geometry_to_box_size()
	_apply_visual_by_type()

func _process(delta: float) -> void:
	if not player_inside or _player == null:
		return

	match hazard_type:
		HazardType.WET_FLOOR:
			_apply_continuous_damage(2.0, delta)
		HazardType.MOLD_ZONE:
			_apply_continuous_damage(1.0, delta)
			SanityManager.reduce_sanity(2.0 * delta)
		HazardType.VOID_ZONE:
			SanityManager.reduce_sanity(5.0 * delta)
		HazardType.ELECTRICAL:
			electrical_pulse_timer += delta
			if electrical_pulse_timer >= 2.0:
				electrical_pulse_timer = 0.0
				if _player.has_method("take_damage"):
					_player.take_damage(5)
				electrical_pulse.emit()

func _on_body_entered(body: Node) -> void:
	if not (body is CharacterBody3D):
		return
	if not body.has_method("take_damage"):
		return

	_player = body as CharacterBody3D
	player_inside = true
	damage_timer = 0.0
	electrical_pulse_timer = 0.0

	match hazard_type:
		HazardType.WET_FLOOR:
			_apply_wet_floor_slow(true)
		HazardType.MOLD_ZONE:
			if audio_player.stream:
				audio_player.play()
		HazardType.VOID_ZONE:
			SanityManager.is_in_dark_zone = true
		HazardType.ELECTRICAL:
			pass

func _on_body_exited(body: Node) -> void:
	if body != _player:
		return

	player_inside = false
	damage_timer = 0.0
	electrical_pulse_timer = 0.0

	match hazard_type:
		HazardType.WET_FLOOR:
			_apply_wet_floor_slow(false)
		HazardType.MOLD_ZONE:
			audio_player.stop()
		HazardType.VOID_ZONE:
			SanityManager.is_in_dark_zone = false
		HazardType.ELECTRICAL:
			pass

	_player = null

func _apply_continuous_damage(damage_per_second: float, delta: float) -> void:
	damage_timer += damage_per_second * delta
	if damage_timer >= 1.0 and _player.has_method("take_damage"):
		var whole_damage: int = int(floor(damage_timer))
		damage_timer -= whole_damage
		_player.take_damage(whole_damage)

func _apply_wet_floor_slow(enabled: bool) -> void:
	if _player == null:
		return

	if not ("normal_speed" in _player and "crouch_speed" in _player and "current_speed" in _player):
		return

	if enabled:
		_wet_original_normal_speed = float(_player.get("normal_speed"))
		_wet_original_crouch_speed = float(_player.get("crouch_speed"))
		_player.set("normal_speed", _wet_original_normal_speed * 0.7)
		_player.set("crouch_speed", _wet_original_crouch_speed * 0.7)
		var is_crouching: bool = bool(_player.get("is_crouching"))
		if is_crouching:
			_player.set("current_speed", float(_player.get("crouch_speed")))
		else:
			_player.set("current_speed", float(_player.get("normal_speed")))
	else:
		if _wet_original_normal_speed > 0.0:
			_player.set("normal_speed", _wet_original_normal_speed)
		if _wet_original_crouch_speed > 0.0:
			_player.set("crouch_speed", _wet_original_crouch_speed)
		var is_crouching_restore: bool = bool(_player.get("is_crouching"))
		if is_crouching_restore:
			_player.set("current_speed", float(_player.get("crouch_speed")))
		else:
			_player.set("current_speed", float(_player.get("normal_speed")))
		_wet_original_normal_speed = -1.0
		_wet_original_crouch_speed = -1.0

func _sync_geometry_to_box_size() -> void:
	if collision_shape.shape is BoxShape3D:
		(collision_shape.shape as BoxShape3D).size = box_size
	if mesh_instance.mesh is BoxMesh:
		(mesh_instance.mesh as BoxMesh).size = box_size

func _apply_visual_by_type() -> void:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 1.0, 1.0, 0.25)
	material.emission_enabled = true
	material.emission = Color(0.0, 0.0, 0.0)

	omni_light.visible = false

	match hazard_type:
		HazardType.WET_FLOOR:
			material.albedo_color = Color(0.4, 0.6, 0.9, 0.25)
			material.emission = Color(0.1, 0.2, 0.35)
		HazardType.MOLD_ZONE:
			material.albedo_color = Color(0.35, 0.55, 0.35, 0.28)
			material.emission = Color(0.08, 0.18, 0.08)
			omni_light.visible = true
			omni_light.light_color = Color(0.45, 0.75, 0.45)
			omni_light.light_energy = 0.3
			omni_light.omni_range = 3.0
		HazardType.VOID_ZONE:
			material.albedo_color = Color(0.05, 0.05, 0.08, 0.4)
			material.emission = Color(0.0, 0.0, 0.0)
			omni_light.visible = false
		HazardType.ELECTRICAL:
			material.albedo_color = Color(0.8, 0.8, 0.45, 0.25)
			material.emission = Color(0.2, 0.2, 0.1)

	mesh_instance.material_override = material
