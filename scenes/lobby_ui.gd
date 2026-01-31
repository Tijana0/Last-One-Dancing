extends Control

@onready var name_input = $CenterContainer/VBoxContainer/NameInput
@onready var ip_input = $CenterContainer/VBoxContainer/IPInput
@onready var status = $CenterContainer/VBoxContainer/StatusLabel
@onready var player_list_ui = $CenterContainer/VBoxContainer/PlayerList
@onready var start_button = $CenterContainer/VBoxContainer/StartButton
@onready var loading_overlay = $LoadingOverlay

func _ready():
	# Connect UI button signals to logic
	$CenterContainer/VBoxContainer/HBoxContainer/HostButton.pressed.connect(_on_host_pressed)
	$CenterContainer/VBoxContainer/HBoxContainer/JoinButton.pressed.connect(_on_join_pressed)
	start_button.pressed.connect(_on_start_pressed)
	
	# Listen for signals from Godot's multiplayer system
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)

func _on_host_pressed():
	var p_name = name_input.text if name_input.text != "" else "Mysterious Spy"
	NetworkManager.create_server(p_name) # Person 1's setup
	status.text = "Hosting..."
	status.modulate = Color.GREEN

func _on_join_pressed():
	var p_name = name_input.text if name_input.text != "" else "Guest"
	var ip = ip_input.text if ip_input.text != "" else "127.0.0.1"
	NetworkManager.join_server(ip, p_name) # Person 1's setup
	status.text = "Attempting to join..."                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               
	status.modulate = Color.YELLOW
	loading_overlay.visible = true

func _process(_delta):
	update_player_list()
	# Only the host (ID 1) can start, and only if others are present
	if multiplayer.is_server() and NetworkManager.players.size() >= 2:
		start_button.visible = true

func update_player_list():
	var text = "[center][b]Spies in Ballroom:[/b][/center]\n"
	for id in NetworkManager.players:
		text += "- " + NetworkManager.players[id] + "\n"
	player_list_ui.text = text

func _on_start_pressed():
	NetworkManager.start_game.rpc() # Synchronize scene change for everyone

func _on_connected():
	status.text = "Connected!"
	status.modulate = Color.GREEN

func _on_failed():
	status.text = "Connection Failed!"
	status.modulate = Color.RED
	loading_overlay.visible = false
