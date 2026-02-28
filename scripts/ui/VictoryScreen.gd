extends Control

@onready var white_overlay: ColorRect = $WhiteOverlay
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_setup_fade_animation()
	animation_player.play("fade_to_white")

func _setup_fade_animation() -> void:
	white_overlay.color = Color(1.0, 1.0, 1.0, 0.0)
	if animation_player.has_animation("fade_to_white"):
		return

	var animation := Animation.new()
	animation.length = 3.0
	var track_idx := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track_idx, NodePath("WhiteOverlay:color"))
	animation.track_insert_key(track_idx, 0.0, Color(1.0, 1.0, 1.0, 0.0))
	animation.track_insert_key(track_idx, 3.0, Color(1.0, 1.0, 1.0, 1.0))

	# En Godot 4 las animaciones se añaden a través de una AnimationLibrary
	var library := AnimationLibrary.new()
	library.add_animation("fade_to_white", animation)
	animation_player.add_animation_library("", library)

func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
