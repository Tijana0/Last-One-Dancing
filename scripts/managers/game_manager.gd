extends Node

# --- CONFIGURATION ---
const KILLS_TO_WIN = 999 # Disabled old win condition
const SPAWN_RANGE_X = 400.0
const SPAWN_RANGE_Y = 300.0

# NPC Settings (from feat-npc-ai)
const NPC_SCENE = preload("res://prefabs/npc.tscn")
const NPC_COUNT = 15  # Balanced count

var crown_holder_id = -1
var crown_npc_spawned = false

# Pickup Settings (from feat-item-pickup)
const PICKUP_SCENE = preload("res://prefabs/pickup_item.tscn")
const PICKUP_COUNT = 3

func _ready():
	print("GameManager ready")
	
	if multiplayer.is_server():
		# Spawn background NPCs
		spawn_npcs()
		# Spawn scattered items
		spawn_scattered_items()

func spawn_npcs():
	if not multiplayer.is_server():
		return

	print("Spawning ", NPC_COUNT, " NPCs...")
	
	for i in range(NPC_COUNT):
		# Randomize position
		var random_x = randf_range(-SPAWN_RANGE_X, SPAWN_RANGE_X)
		var random_y = randf_range(-SPAWN_RANGE_Y, SPAWN_RANGE_Y)
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

func spawn_scattered_items():
	print("Spawning scattered items...")
	for i in range(PICKUP_COUNT):
		var item_name = "Pickup_" + str(i)
		var pos = Vector2(randf_range(-400, 400), randf_range(-300, 300))
		
		# Call RPC to spawn on all clients (including server)
		spawn_item.rpc(pos, item_name)

@rpc("authority", "call_local")
func spawn_item(pos: Vector2, item_name: String):
	var item = PICKUP_SCENE.instantiate()
	item.name = item_name
	item.position = pos
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
	
	var winner_name = "Player " + str(winner_id)
	if has_node("/root/NetworkManager"):
		var net_man = get_node("/root/NetworkManager")
		winner_name = net_man.players.get(winner_id, winner_name)
	
	var players = get_tree().get_nodes_in_group("players")
	for p in players:
		# We only want to update the UI for the LOCAL player (the one playing on this computer)
		if p.is_multiplayer_authority() and not p.get("is_npc"):
			if p.has_node("GameOverLayer"):
				var ui = p.get_node("GameOverLayer")
				var label = ui.get_node("Label")
				var bg = ui.get_node("Background")
				
				ui.visible = true
				
				if p.name.to_int() == winner_id:
					# I WON!
					label.text = "VICTORY!"
					bg.color = Color(0, 0.5, 0, 0.8) # Green
				else:
					# SOMEONE ELSE WON
					label.text = str(winner_name) + " WINS!"
					bg.color = Color(0.5, 0, 0, 0.8) # Red

@rpc("any_peer", "call_local")
func check_win_condition(player_id: int, kills: int):
	pass # Deprecated

@rpc("any_peer", "call_local")
func announce_winner(player_id: int):
	pass # Deprecated
