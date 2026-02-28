extends Node

@onready var ambient_player: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var sfx_player: AudioStreamPlayer = AudioStreamPlayer.new()

func _ready() -> void:
	add_child(ambient_player)
	add_child(sfx_player)

func play_ambient(track: AudioStream) -> void:
	ambient_player.stream = track
	ambient_player.play()

func play_sfx(sound: AudioStream) -> void:
	sfx_player.stream = sound
	sfx_player.play()

func stop_ambient() -> void:
	ambient_player.stop()
