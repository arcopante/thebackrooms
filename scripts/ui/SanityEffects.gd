extends CanvasLayer

const CHROMATIC_ABERRATION_SHADER: Shader = preload("res://scripts/ui/ChromaticAberration.gdshader")

@onready var vignette: ColorRect = $Vignette
@onready var fullscreen_distortion: ColorRect = $FullscreenDistortion
@onready var whisper_player: AudioStreamPlayer = $WhisperPlayer

var _distortion_material: ShaderMaterial
var _whisper_timer: float = 0.0

var _next_whisper_interval: float = 10.0
var _flash_timer: float = 0.0
var _next_flash_interval: float = 3.0
var _flash_duration_timer: float = 0.0
var _is_flashing: bool = false

func _ready() -> void:
	_randomize_whisper_interval()
	_randomize_flash_interval()
	_setup_distortion_material()
	vignette.color = Color(0.0, 0.0, 0.0, 0.0)
	fullscreen_distortion.color = Color(0.0, 0.0, 0.0, 0.0)

func _process(delta: float) -> void:
	var sanity_value: float = SanityManager.sanity
	_update_visuals(sanity_value, delta)
	_update_audio_and_flashes(sanity_value, delta)

func _update_visuals(sanity_value: float, delta: float) -> void:
	var vignette_alpha: float = 0.0
	var intensity: float = 0.0

	if sanity_value < 70.0 and sanity_value >= 50.0:
		var t_70_50: float = (70.0 - sanity_value) / 20.0
		vignette_alpha = lerp(0.0, 0.35, t_70_50)
		intensity = 0.0
	elif sanity_value < 50.0 and sanity_value >= 30.0:
		var t_50_30: float = (50.0 - sanity_value) / 20.0
		vignette_alpha = lerp(0.35, 0.6, t_50_30)
		intensity = lerp(0.12, 0.2, t_50_30)
	elif sanity_value < 30.0 and sanity_value >= 10.0:
		var t_30_10: float = (30.0 - sanity_value) / 20.0
		vignette_alpha = lerp(0.6, 0.8, t_30_10)
		intensity = lerp(0.25, 0.45, t_30_10)
	elif sanity_value < 10.0:
		var t_10_0: float = (10.0 - sanity_value) / 10.0
		vignette_alpha = lerp(0.8, 0.95, t_10_0)
		intensity = lerp(0.5, 0.75, t_10_0)

	vignette.color.a = vignette_alpha
	_distortion_material.set_shader_parameter("intensity", intensity)
	_distortion_material.set_shader_parameter("time", Time.get_ticks_msec() / 1000.0)
	fullscreen_distortion.color.a = clamp(intensity, 0.0, 1.0)

	if _is_flashing:
		_flash_duration_timer += delta
		if _flash_duration_timer >= 0.1:
			_is_flashing = false
			_flash_duration_timer = 0.0

	if sanity_value < 10.0 and _is_flashing:
		vignette.color.a = 1.0

func _update_audio_and_flashes(sanity_value: float, delta: float) -> void:
	if sanity_value <= 30.0 and sanity_value > 10.0:
		_whisper_timer += delta
		if _whisper_timer >= _next_whisper_interval:
			if whisper_player.stream:
				whisper_player.play()
			_whisper_timer = 0.0
			_randomize_whisper_interval()
	elif sanity_value > 30.0:
		_whisper_timer = 0.0

	if sanity_value <= 10.0:
		_flash_timer += delta
		if _flash_timer >= _next_flash_interval:
			_is_flashing = true
			_flash_duration_timer = 0.0
			_flash_timer = 0.0
			_randomize_flash_interval()
	else:
		_flash_timer = 0.0
		_is_flashing = false
		_flash_duration_timer = 0.0

func _setup_distortion_material() -> void:
	_distortion_material = ShaderMaterial.new()
	_distortion_material.shader = CHROMATIC_ABERRATION_SHADER
	fullscreen_distortion.material = _distortion_material

func _randomize_whisper_interval() -> void:
	_next_whisper_interval = randf_range(8.0, 15.0)

func _randomize_flash_interval() -> void:
	_next_flash_interval = randf_range(2.5, 5.0)


