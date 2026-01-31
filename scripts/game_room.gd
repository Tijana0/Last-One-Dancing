extends Node2D

var network_manager

func _ready():
	print("GameRoom scene loaded")
	
	# Get NetworkManager
	network_manager = get_node("/root/NetworkManager")
	
	# Small delay to ensure scene is fully loaded
	await get_tree().create_timer(0.1).timeout
	
	# Spawn all connected players
	print("Calling spawn_all_players...")
	network_manager.spawn_all_players()
