extends Node3D

enum LightState { NORMAL, FLICKERING, OFF }

@export var initial_flicker_probability: float = 0.2
@export var initial_off_probability: float = 0.1

@onready var omni_light: OmniLight3D = $OmniLight3D
@onready var tube_mesh: MeshInstance3D = $MeshInstance3D
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var flicker_timer: Timer = $FlickerTimer

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var current_state: LightState = LightState.NORMAL
var buzz_stream: AudioStream
var click_stream: AudioStream

func _ready() -> void:
	rng.randomize()
	_configure_visuals()
	flicker_timer.timeout.connect(_on_flicker_timer_timeout)
	# Solo decidimos el estado inicial si no fue ya forzado desde fuera
	# (LevelBuilder puede haber asignado las probabilidades antes del add_child,
	# pero por seguridad siempre lo llamamos aquí también)
	_decide_initial_state()

func _configure_visuals() -> void:
	omni_light.light_color = Color("d4e8c2")
	omni_light.light_energy = 1.2
	omni_light.omni_range = 6.0
	
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("d4e8c2")
	material.emission_enabled = true
	material.emission = Color("e8ffe0")
	tube_mesh.material_override = material

func _decide_initial_state() -> void:
	# Forzamos valores mínimos para que siempre haya variedad visible:
	# al menos un 15% de apagadas y un 25% de parpadeantes en cualquier nivel.
	var off_prob:     float = max(initial_off_probability,     0.15)
	var flicker_prob: float = max(initial_flicker_probability, 0.25)

	var roll: float = rng.randf()
	if roll < off_prob:
		set_state(LightState.OFF)
	elif roll < off_prob + flicker_prob:
		set_state(LightState.FLICKERING)
	else:
		set_state(LightState.NORMAL)

func set_state(new_state: LightState) -> void:
	current_state = new_state
	
	match current_state:
		LightState.NORMAL:
			omni_light.visible = true
			flicker_timer.stop()
			if buzz_stream:
				audio_player.stream = buzz_stream
				audio_player.play()
		LightState.FLICKERING:
			_set_light_enabled(true)
			_schedule_next_flicker()
			if buzz_stream:
				audio_player.stream = buzz_stream
				audio_player.play()
		LightState.OFF:
			_set_light_enabled(false)
			flicker_timer.stop()
			audio_player.stop()

func _on_flicker_timer_timeout() -> void:
	if current_state != LightState.FLICKERING:
		return
	
	_set_light_enabled(not omni_light.visible)
	if not omni_light.visible and click_stream:
		audio_player.stream = click_stream
		audio_player.play()
	elif omni_light.visible and buzz_stream:
		audio_player.stream = buzz_stream
		audio_player.play()
	
	_schedule_next_flicker()

func _set_light_enabled(enabled: bool) -> void:
	omni_light.visible = enabled
	if tube_mesh.material_override is StandardMaterial3D:
		var material := tube_mesh.material_override as StandardMaterial3D
		material.emission_enabled = enabled

func _schedule_next_flicker() -> void:
	flicker_timer.wait_time = rng.randf_range(0.05, 0.4)
	if flicker_timer.is_stopped():
		flicker_timer.start()
