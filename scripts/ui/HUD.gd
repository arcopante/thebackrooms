extends CanvasLayer

@onready var level_label: Label = $VBoxContainer/LevelLabel
@onready var sanity_label: Label = $VBoxContainer/SanityLabel
@onready var sanity_bar: ProgressBar = $VBoxContainer/SanityBar
@onready var flashlight_icon: TextureRect = $FlashlightIcon
@onready var jadeo_player: AudioStreamPlayer = $JadeoPlayer

var player: CharacterBody3D
var player_camera: Camera3D
var shake_time_left: float = 0.0
var shake_elapsed: float = 0.0
var was_low_stamina: bool = false

func _ready() -> void:
	_try_apply_monospace_font()
	player = _find_player()
	if player != null:
		_connect_player_signals(player)
		player_camera = player.get_node_or_null("Head/Camera3D") as Camera3D
		_on_player_damaged(int(player.get("hp")))
		_update_flashlight_icon(bool(player.get_node("Head/SpotLight3D").visible))

	if SanityManager != null:
		if not SanityManager.on_sanity_changed.is_connected(_on_sanity_changed):
			SanityManager.on_sanity_changed.connect(_on_sanity_changed)
		_on_sanity_changed(SanityManager.sanity)

	if GameManager != null:
		if not GameManager.level_changed.is_connected(_on_level_changed):
			GameManager.level_changed.connect(_on_level_changed)
		_on_level_changed(GameManager.current_level)

func set_player(target_player: CharacterBody3D) -> void:
	player = target_player
	if player != null:
		_connect_player_signals(player)
		player_camera = player.get_node_or_null("Head/Camera3D") as Camera3D
		_on_player_damaged(int(player.get("hp")))
		if player.has_node("Head/SpotLight3D"):
			var flashlight: SpotLight3D = player.get_node("Head/SpotLight3D") as SpotLight3D
			if flashlight != null:
				_update_flashlight_icon(flashlight.visible)

func _process(delta: float) -> void:
	if player == null:
		player = _find_player()
		if player != null:
			_connect_player_signals(player)
			player_camera = player.get_node_or_null("Head/Camera3D") as Camera3D
		return

	var stamina: float = float(player.get("stamina"))
	var is_low_stamina: bool = stamina < 20.0
	if is_low_stamina and not was_low_stamina:
		if jadeo_player.stream:
			jadeo_player.play()
		_start_camera_shake()
	was_low_stamina = is_low_stamina

	_update_camera_shake(delta)

func _find_player() -> CharacterBody3D:
	var by_group := get_tree().get_first_node_in_group("player")
	if by_group is CharacterBody3D:
		return by_group as CharacterBody3D

	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return null
	var by_name: Node = scene_root.find_child("Player", true, false)
	if by_name is CharacterBody3D:
		return by_name as CharacterBody3D
	return null

func _connect_player_signals(target_player: CharacterBody3D) -> void:
	if target_player.has_signal("on_damaged") and not target_player.on_damaged.is_connected(_on_player_damaged):
		target_player.on_damaged.connect(_on_player_damaged)
	if target_player.has_signal("on_death") and not target_player.on_death.is_connected(_on_player_death):
		target_player.on_death.connect(_on_player_death)
	if target_player.has_signal("flashlight_toggled") and not target_player.flashlight_toggled.is_connected(_on_flashlight_toggled):
		target_player.flashlight_toggled.connect(_on_flashlight_toggled)

func _on_player_damaged(_new_hp: int) -> void:
	pass

func _on_player_death() -> void:
	pass

func _on_sanity_changed(value: float) -> void:
	sanity_label.text = "CORDURA"
	sanity_bar.value = value
	if value > 50.0:
		sanity_bar.modulate = Color(0.2, 0.85, 0.3)
	elif value > 25.0:
		sanity_bar.modulate = Color(0.95, 0.78, 0.1)
	else:
		sanity_bar.modulate = Color(0.9, 0.15, 0.15)
	if value > 50.0:
		sanity_bar.modulate = Color(0.2, 0.85, 0.3)
	elif value > 25.0:
		sanity_bar.modulate = Color(0.95, 0.78, 0.1)
	else:
		sanity_bar.modulate = Color(0.9, 0.15, 0.15)

func _on_level_changed(new_level: int) -> void:
	level_label.text = "NIVEL %d" % new_level

func _on_flashlight_toggled(enabled: bool) -> void:
	_update_flashlight_icon(enabled)

func _update_flashlight_icon(enabled: bool) -> void:
	if enabled:
		flashlight_icon.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		flashlight_icon.modulate = Color(0.35, 0.35, 0.35, 0.7)

func _start_camera_shake() -> void:
	shake_time_left = 1.0
	shake_elapsed = 0.0

func _update_camera_shake(delta: float) -> void:
	if player_camera == null:
		return
	if shake_time_left > 0.0:
		shake_time_left -= delta
		shake_elapsed += delta
		var frequency: float = 42.0
		var amplitude: float = 0.05
		player_camera.h_offset = sin(shake_elapsed * frequency) * amplitude
	else:
		player_camera.h_offset = lerp(player_camera.h_offset, 0.0, min(1.0, delta * 18.0))

func _try_apply_monospace_font() -> void:
	var system_font := SystemFont.new()
	system_font.font_names = PackedStringArray(["Menlo", "Consolas", "Courier New", "Monospace"])
	level_label.add_theme_font_override("font", system_font)
