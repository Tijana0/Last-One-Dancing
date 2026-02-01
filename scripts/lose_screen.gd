extends CanvasLayer

@onready var retry_button = $Control/HBoxContainer/RetryButton
@onready var main_menu_button = $Control/HBoxContainer/MainMenuButton

var player_kills = 0
var player_dances = 0
var killer_name = "Unknown"

func _ready():
	# Connect buttons
	if retry_button:
		retry_button.pressed.connect(_on_retry)
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu)

func _on_retry():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_main_menu():
	get_tree().quit()