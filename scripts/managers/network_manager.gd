extends Node

# Configuration
const PORT = 7777
const MAX_PLAYERS = 6

var players = {}
var player_name = "Player"

func _ready():
	# Connect multiplayer signals
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

# HOST creates a server
func create_server(player_name: String):
	self.player_name = player_name
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT, MAX_PLAYERS)
	multiplayer.multiplayer_peer = peer
	
	print("Server created on port ", PORT)
	add_player(1, player_name)  # Add host as player
	
	# Load game scene
	#await get_tree().create_timer(0.5).timeout
	#get_tree().change_scene_to_file("res://scenes/game_room.tscn")

# CLIENT joins a server
func join_server(ip: String, player_name: String):
	self.player_name = player_name
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(ip, PORT)
	multiplayer.multiplayer_peer = peer
	
	print("Connecting to ", ip, ":", PORT)

# When a player connects
func _on_player_connected(id):
	print("Player connected: ", id)

# When a player disconnects
func _on_player_disconnected(id):
	print("Player disconnected: ", id)
	remove_player(id)
	
	# Remove their player node from game if it exists
	if get_tree().current_scene and get_tree().current_scene.has_node(str(id)):
		get_tree().current_scene.get_node(str(id)).queue_free()

# When THIS client connects successfully
func _on_connected_to_server():
	print("Successfully connected to server!")
	# Send our info to server
	register_player.rpc_id(1, multiplayer.get_unique_id(), player_name)

# If connection fails
func _on_connection_failed():
	print("Connection failed!")

# Called by clients to register themselves
@rpc("any_peer")
func register_player(id: int, pname: String):
	add_player(id, pname)
	
	# If we're the server, tell this new player about all existing players
	if multiplayer.is_server():
		for existing_id in players:
			register_player.rpc_id(id, existing_id, players[existing_id])

# Add player to tracking
func add_player(id: int, pname: String):
	players[id] = pname
	print("Player added: ", pname, " (", id, ")")
	
	# If we're in game room, spawn this player
	if get_tree().current_scene and get_tree().current_scene.name == "GameRoom":
		spawn_player(id, pname)

# Remove player
func remove_player(id: int):
	if players.has(id):
		print("Player removed: ", players[id])
		players.erase(id)

# Spawn a single player in the game room
func spawn_player(id: int, pname: String):
	# Safety checks
	if not get_tree().current_scene:
		print("No current scene!")
		return
		
	if get_tree().current_scene.name != "GameRoom":
		print("Not in game room, skipping spawn for ", pname)
		return
	
	# Check if player already exists
	if get_tree().current_scene.has_node(str(id)):
		print("Player ", pname, " already spawned")
		return
	
	# Load and instantiate player
	var player_scene = load("res://prefabs/player.tscn")
	if not player_scene:
		print("ERROR: Could not load player scene!")
		return
		
	var player = player_scene.instantiate()
	player.name = str(id)  # CRITICAL: name must be the network ID
	player.player_name = pname
	player.set_multiplayer_authority(id)
	
	# Random spawn position
	player.position = Vector2(randf_range(-400, 400), randf_range(-300, 300))
	
	print("Spawning player: ", pname, " (ID: ", id, ") at ", player.position)
	get_tree().current_scene.add_child(player, true)  # true = force readable name

# Spawn all existing players (called when game room loads)
func spawn_all_players():
	print("Spawning all players...")
	for id in players:
		spawn_player(id, players[id])
		
# RPC to start the game (called by host from lobby)
@rpc("any_peer", "call_local")
func start_game():
	print("Starting game for all players...")
	get_tree().change_scene_to_file("res://scenes/game_room.tscn")
