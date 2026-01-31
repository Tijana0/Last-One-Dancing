extends Control

# This script handles moving from the menu to the lobby
func _ready():
	# Signal connections link the buttons to the code below
	$CenterContainer/VBoxContainer/PlayButton.pressed.connect(_on_play_pressed)
	$CenterContainer/VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)

func _on_play_pressed():
	# This switches the entire scene to the lobby you are building
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")

func _on_quit_pressed():
	# Closes the game application
	get_tree().quit()
