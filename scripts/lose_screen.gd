extends CanvasLayer

@onready var title_label = $Control/CenterContainer/VBoxContainer/TitleLabel
@onready var subtitle_label = $Control/CenterContainer/VBoxContainer/SubtitleLabel
@onready var kills_label = $Control/CenterContainer/VBoxContainer/StatsContainer/KillsLabel
@onready var dances_label = $Control/CenterContainer/VBoxContainer/StatsContainer/DancesLabel
@onready var killer_label = $Control/CenterContainer/VBoxContainer/StatsContainer/KillerLabel
@onready var retry_button = $Control/CenterContainer/VBoxContainer/HBoxContainer/RetryButton
@onready var main_menu_button = $Control/CenterContainer/VBoxContainer/HBoxContainer/MainMenuButton

var player_kills = 0
var player_dances = 0
var killer_name = "Unknown"

func _ready():
	# Display stats
	update_stats(player_kills, player_dances, killer_name)
	
	# Connect buttons
	retry_button.pressed.connect(_on_retry)
	main_menu_button.pressed.connect(_on_main_menu)

func update_stats(kills: int, dances: int, killer: String):
	if kills_label: kills_label.text = "Your Eliminations: " + str(kills)
	if dances_label: dances_label.text = "Dances Performed: " + str(dances)
	if killer_label: killer_label.text = "Eliminated By: " + killer

func _on_retry():
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")

func _on_main_menu():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
