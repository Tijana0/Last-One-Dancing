extends CanvasLayer

@onready var play_again_button = $Control/HBoxContainer/PlayAgainButton
@onready var main_menu_button = $Control/HBoxContainer/MainMenuButton

# Stats kept in variables in case needed for logic, but UI labels removed
var player_kills = 0
var player_dances = 0
var player_lives = 0

func _ready():
	# Connect buttons
	if play_again_button:
		play_again_button.pressed.connect(_on_play_again)
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu)

func _on_play_again():
	print("Play Again Pressed")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	queue_free()

func _on_main_menu():
	print("Quit Pressed")
	get_tree().quit()