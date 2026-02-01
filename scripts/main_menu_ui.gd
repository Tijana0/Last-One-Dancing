extends Control

@onready var play_button = $HBoxContainer/PlayButton
@onready var quit_button = $HBoxContainer/QuitButton

func _ready():
	# Rename buttons to match your design
	if play_button:
		play_button.text = "Enter Ballroom"
	
	if quit_button:
		quit_button.text = "Leave"
	
	# Connect button signals
	if play_button:
		play_button.pressed.connect(_on_play_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

func _on_play_pressed():
	# Fade out animation (optional)
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")

func _on_quit_pressed():
	get_tree().quit()
