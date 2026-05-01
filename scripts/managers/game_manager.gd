extends Node

# --- CONFIGURATION ---
const KILLS_TO_WIN = 999 
const SPAWN_RANGE_X = 1200.0 # Match background (2500 width)
const SPAWN_RANGE_Y = 950.0  # Match background (2000 height)

# NPC Settings (from feat-npc-ai)
const NPC_SCENE = preload("res://prefabs/npc.tscn")
const NPC_COUNT = 15  

var crown_holder_id = -1
var crown_npc_spawned = false

# Pickup Settings (from feat-item-pickup)
const PICKUP_SCENE = preload("res://prefabs/pickup_item.tscn")

var spawn_timer = 0.0
var waves_spawned = 0
var total_waves = 1

func _ready():
	print("GameManager ready")
	
	if multiplayer.is_server():
		# Spawn background NPCs
		spawn_npcs()
		
		# Initial wave spawn
		total_waves = 1 
		spawn_item_wave()

func _process(delta):
	if not multiplayer.is_server():
		return
	
	# Dynamically update total waves based on active players
	var player_count = get_tree().get_nodes_in_group("players").size()
	if player_count > total_waves:
		total_waves = player_count
		print("Total waves updated to: ", total_waves)

	if waves_spawned < total_waves:
		spawn_timer += delta
		if spawn_timer >= randf_range(10.0, 15.0):
			spawn_timer = 0.0
			spawn_item_wave()

func spawn_npcs():
	if not multiplayer.is_server():
		return

	print("Spawning ", NPC_COUNT, " NPCs...")
	
	for i in range(NPC_COUNT):
		# Randomize position within boundaries
		var random_x = randf_range(-SPAWN_RANGE_X + 50, SPAWN_RANGE_X - 50)
		var random_y = randf_range(-SPAWN_RANGE_Y + 50, SPAWN_RANGE_Y - 50)
		var pos = Vector2(random_x, random_y)
		var npc_name = "NPC_" + str(i)
		
		# Call RPC to spawn on all clients
		spawn_single_npc.rpc(pos, npc_name)

@rpc("authority", "call_local")
func spawn_single_npc(pos: Vector2, npc_name: String):
	var npc = NPC_SCENE.instantiate()
	npc.name = npc_name
	npc.position = pos
	get_parent().call_deferred("add_child", npc)

func spawn_item_wave():
	print("Spawning item wave ", waves_spawned + 1, "/", total_waves)
	waves_spawned += 1
	
	var types = [0, 1, 2] # POTION, GUN, MASK
	types.shuffle()
	
	for i in range(3):
		var item_name = "Pickup_W" + str(waves_spawned) + "_" + str(i)
		
		# Try to find a non-overlapping position
		var pos = Vector2.ZERO
		var valid_pos = false
		var attempts = 0
		
		while not valid_pos and attempts < 20:
			pos = Vector2(
				randf_range(-SPAWN_RANGE_X + 100, SPAWN_RANGE_X - 100),
				randf_range(-SPAWN_RANGE_Y + 100, SPAWN_RANGE_Y - 100)
			)
			valid_pos = true
			
			# Check against existing pickups
			var existing = get_tree().get_nodes_in_group("pickups")
			for other in existing:
				if pos.distance_to(other.global_position) < 150.0:
					valid_pos = false
					break
			attempts += 1
		
		spawn_item.rpc(pos, item_name, types[i])

@rpc("authority", "call_local")
func spawn_item(pos: Vector2, item_name: String, item_type: int):
	var item = PICKUP_SCENE.instantiate()
	item.name = item_name
	item.position = pos
	
	# Set type BEFORE adding to tree so _ready logic works if needed, 
	# but we removed randomization from _ready so we just set it here.
	item.type = item_type
	item.update_visuals() # Force visual update
	
	get_parent().call_deferred("add_child", item)

@rpc("any_peer", "call_local")
func destroy_item(item_name: String):
	var item = get_parent().get_node_or_null(item_name)
	if item:
		item.queue_free()

# Called by player.gd when a player dies
func check_survivors():
	# Only server manages game state
	if not multiplayer.is_server():
		return
		
	if crown_npc_spawned:
		return
		
	var players = get_tree().get_nodes_in_group("players")
	var alive_count = 0
	
	for p in players:
		# Count only real players who are alive
		if p.get("lives") != null and p.lives > 0 and not p.get("is_npc"):
			alive_count += 1
			
	print("Alive players: ", alive_count)
	
	# If only 1 player is left standing, spawn the Boss NPC
	if alive_count <= 1:
		spawn_crown_npc.rpc()

@rpc("authority", "call_local")
func spawn_crown_npc():
	if crown_npc_spawned: return
	crown_npc_spawned = true
	
	print("SPAWNING CROWN BOSS NPC!")
	
	# Use prefabs/player.tscn to ensure it has script and UI
	var player_scene = load("res://prefabs/player.tscn")
	if not player_scene:
		print("ERROR: Player scene not found!")
		return
		
	var npc = player_scene.instantiate()
	npc.name = "CrownNPC" # Important for unique ID
	
	# Start off-screen (Top)
	var start_pos = Vector2(0, -600)
	var end_pos = Vector2(0, 0)
	npc.position = start_pos
	
	# Configure NPC properties
	npc.is_npc = true
	npc.lives = 1
	npc.has_crown = true
	npc.player_name = "THE BOSS"
	
	# Add to scene
	get_parent().add_child(npc, true)
	
	# Visuals (Gold/Yellow)
	if npc.has_node("Sprite2D"):
		npc.get_node("Sprite2D").modulate = Color(1, 0.8, 0) # Gold
		npc.get_node("Sprite2D").scale = Vector2(1.5, 1.5) # Bigger
	elif npc.has_node("AnimatedSprite"): # Handle AnimatedSprite case
		npc.get_node("AnimatedSprite").modulate = Color(1, 0.8, 0)
		npc.get_node("AnimatedSprite").scale = Vector2(1.5, 1.5)
		
	# Animate Entry
	var tween = create_tween()
	tween.tween_property(npc, "position", end_pos, 2.0).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

@rpc("any_peer", "call_local")
func trigger_victory(winner_id: int):
	print("VICTORY! Winner ID: ", winner_id)
	
	if multiplayer.get_unique_id() == winner_id:
		show_win_screen()
	else:
		# For losers who are still watching (or dead), maybe show main menu button?
		pass

func show_win_screen():
	await get_tree().create_timer(1.0).timeout
	
	var win_scene = load("res://scenes/win_screen.tscn")
	if win_scene:
		var win_screen = win_scene.instantiate()
		
		# Find local player to get stats
		var players = get_tree().get_nodes_in_group("players")
		for player in players:
			if player.is_multiplayer_authority():
				win_screen.player_kills = player.kill_count
				# win_screen.player_dances = 0 
				win_screen.player_lives = player.lives
				
				# Hide HUD
				if player.hud: player.hud.visible = false
				break
		
		get_tree().root.add_child(win_screen)

@rpc("any_peer", "call_local")
func check_win_condition(player_id: int, kills: int):
	pass # Deprecated

@rpc("any_peer", "call_local")
func announce_winner(player_id: int):
	pass # Deprecated
