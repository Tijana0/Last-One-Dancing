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
	get_tree().change_scene_to_file("res://scenes/game_room.tscn")

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
	
	# If we're in game, spawn player
	if get_tree().current_scene.name == "GameRoom":
		spawn_player(id, pname)

# Remove player
func remove_player(id: int):
	if players.has(id):
		print("Player removed: ", players[id])
		players.erase(id)

# Spawn player in game (called by add_player)
func spawn_player(id: int, pname: String):
	var player_scene = load("res://prefabs/player.tscn")
	var player = player_scene.instantiate()
	player.name = str(id)  # CRITICAL: name must be the network ID
	player.player_name = pname
	player.set_multiplayer_authority(id)  # This player controls this node
	
	# Random spawn position
	player.position = Vector2(randf_range(-400, 400), randf_range(-300, 300))
	
	get_tree().current_scene.add_child(player)
