extends Control

@onready var title_label = $CenterContainer/VBoxContainer/TitleLabel
@onready var subtitle_label = $CenterContainer/VBoxContainer/SubtitleLabel
@onready var kills_label = $CenterContainer/VBoxContainer/StatsContainer/KillsLabel
@onready var dances_label = $CenterContainer/VBoxContainer/StatsContainer/DancesLabel
@onready var lives_label = $CenterContainer/VBoxContainer/StatsContainer/LivesLabel
@onready var play_again_button = $CenterContainer/VBoxContainer/HBoxContainer/PlayAgainButton
@onready var main_menu_button = $CenterContainer/VBoxContainer/HBoxContainer/MainMenuButton

var player_kills = 0
var player_dances = 0
var player_lives = 0

func _ready():
	# Display stats
	update_stats(player_kills, player_dances, player_lives)
	
	# Connect buttons
	play_again_button.pressed.connect(_on_play_again)
	main_menu_button.pressed.connect(_on_main_menu)

func update_stats(kills: int, dances: int, lives: int):
	if kills_label: kills_label.text = "Eliminations: " + str(kills)
	if dances_label: dances_label.text = "Dances Performed: " + str(dances)
	if lives_label: lives_label.text = "Lives Remaining: " + str(lives) + "/3"

func _on_play_again():
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")

func _on_main_menu():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
