extends Control

@onready var name_input = $CenterContainer/VBoxContainer/NameInput
@onready var ip_input = $CenterContainer/VBoxContainer/IPInput
@onready var status = $CenterContainer/VBoxContainer/StatusLabel
@onready var player_list_ui = $CenterContainer/VBoxContainer/PlayerList
@onready var start_button = $CenterContainer/VBoxContainer/StartButton
@onready var loading_panel = $LoadingPanel

func _ready():
	# Connect UI button signals to logic
	$CenterContainer/VBoxContainer/HBoxContainer/HostButton.pressed.connect(_on_host_pressed)
	$CenterContainer/VBoxContainer/HBoxContainer/JoinButton.pressed.connect(_on_join_pressed)
	start_button.pressed.connect(_on_start_pressed)
	
	# Hide start button and loading panel initially
	start_button.visible = false
	loading_panel.visible = false
	
	# Listen for signals from Godot's multiplayer system
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)

func _on_host_pressed():
	var p_name = name_input.text if name_input.text != "" else "Mysterious Spy"
	NetworkManager.create_server(p_name)
	status.text = "Hosting as " + p_name + "..."
	status.modulate = Color.GREEN

func _on_join_pressed():
	var p_name = name_input.text if name_input.text != "" else "Guest Spy"
	var ip = ip_input.text if ip_input.text != "" else "127.0.0.1"
	NetworkManager.join_server(ip, p_name)
	status.text = "Connecting to " + ip + "..."
	status.modulate = Color.YELLOW
	loading_panel.visible = true

func _process(_delta):
	update_player_list()
	# Only the host can start, and only if at least 2 players
	if multiplayer.is_server() and NetworkManager.players.size() >= 2:
		start_button.visible = true
	else:
		start_button.visible = false

func update_player_list():
	var text = "[center][b]Spies in Ballroom:[/b][/center]\n\n"
	for id in NetworkManager.players:
		var player_name = NetworkManager.players[id]
		# Mark the host
		if id == 1:
			text += "👑 " + player_name + " [color=yellow](HOST)[/color]\n"
		else:
			text += "🎭 " + player_name + "\n"
	player_list_ui.text = text

func _on_start_pressed():
	# Call NetworkManager's start_game RPC
	NetworkManager.start_game.rpc()

func _on_connected():
	status.text = "Connected! Waiting for host to start..."
	status.modulate = Color.GREEN
	loading_panel.visible = false

func _on_failed():
	status.text = "Connection Failed! Check IP address."
	status.modulate = Color.RED
	loading_panel.visible = false
