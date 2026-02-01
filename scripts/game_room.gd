extends Node2D

var network_manager

func _ready():
	print("GameRoom scene loaded")
	
	# --- DETECTIVE CODE (DEBUGGING SPAWNER) ---
	# This block checks if your Spawner is actually set up correctly
	var spawner = $MultiplayerSpawner
	if spawner:
		print("--- SPAWNER DEBUG REPORT ---")
		
		# 1. Check what node it is watching (Should point to GameRoom)
		print("1. Spawner is watching: ", spawner.spawn_path)
		
		# 2. Check how many files are on the whitelist
		var count = spawner.get_spawnable_scene_count()
		print("2. Number of items in list: ", count)
		
		# 3. Check the specific file path (Must match res://prefabs/npc.tscn EXACTLY)
		if count > 0:
			var path_in_list = spawner.get_spawnable_scene(0)
			print("3. Item 0 Path: ", path_in_list)
		else:
			print("CRITICAL ERROR: The Auto Spawn List is EMPTY! The Client cannot see NPCs.")
	else:
		print("CRITICAL ERROR: Could not find node $MultiplayerSpawner inside GameRoom.")
	# --- END DETECTIVE CODE ---
	
	# Get NetworkManager
	network_manager = get_node("/root/NetworkManager")
	
	# Small delay to ensure scene is fully loaded
	await get_tree().create_timer(0.1).timeout
	
	# Spawn all connected players
	print("Calling spawn_all_players...")
	network_manager.spawn_all_players()
