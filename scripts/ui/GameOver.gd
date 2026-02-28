extends Control

@onready var fade_rect: ColorRect = $FadeRect
@onready var message_label: Label = $CenterContainer/VBoxContainer/MessageLabel
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	# Liberamos el ratón: el juego lo captura para el mouselook y hay que
	# restaurarlo explícitamente al entrar en cualquier pantalla de UI.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if GameManager != null:
		if GameManager.death_reason == "sanity":
			message_label.text = "HAS PERDIDO LA RAZÓN"
		elif GameManager.death_reason == "damage":
			message_label.text = "HAS SIDO ENCONTRADO"
		elif "game_over_message" in GameManager:
			message_label.text = String(GameManager.game_over_message)
	_setup_fade_animation()
	animation_player.play("fade_in")

func _setup_fade_animation() -> void:
	fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	if animation_player.has_animation("fade_in"):
		return

	var animation := Animation.new()
	animation.length = 2.0
	var track_idx := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track_idx, NodePath("FadeRect:color"))
	animation.track_insert_key(track_idx, 0.0, Color(0.0, 0.0, 0.0, 0.0))
	animation.track_insert_key(track_idx, 2.0, Color(0.0, 0.0, 0.0, 1.0))
	animation_player.add_animation("fade_in", animation)

func _on_back_to_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
