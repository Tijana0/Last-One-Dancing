extends Node

# --- CONFIGURATION ---
const KILLS_TO_WIN = 3

# NEW: Much larger area!
# This creates a world from -1000 to +1000 (Width 2000) and -800 to +800 (Height 1600)
const SPAWN_RANGE_X = 1000.0
const SPAWN_RANGE_Y = 800.0
const MIN_SPAWN_DISTANCE = 80.0 

# NPC Settings
const NPC_SCENE = preload("res://prefabs/npc.tscn")
const NPC_COUNT = 30  

var crown_holder_id = -1

func _ready():
	print("GameManager ready")
	
	if not multiplayer.is_server():
		return
	
	spawn_npcs()
	
	await get_tree().create_timer(2.0).timeout
	spawn_crown()

func spawn_npcs():
	if not multiplayer.is_server():
		return

	print("Spawning ", NPC_COUNT, " NPCs safely...")
	
	var spawned_npcs = []
	
	for i in range(NPC_COUNT):
		var npc = NPC_SCENE.instantiate()
		npc.name = "NPC_" + str(i)
		
		# --- SAFE SPAWN LOGIC ---
		var attempts = 0
		var safe_position = Vector2.ZERO
		var found_spot = false
		
		while attempts < 30 and not found_spot:
			# Use the NEW larger ranges
			var random_x = randf_range(-SPAWN_RANGE_X, SPAWN_RANGE_X)
			var random_y = randf_range(-SPAWN_RANGE_Y, SPAWN_RANGE_Y)
			var test_pos = Vector2(random_x, random_y)
			
			var too_close = false
			for existing_npc in spawned_npcs:
				if test_pos.distance_to(existing_npc.position) < MIN_SPAWN_DISTANCE:
					too_close = true
					break
			
			if not too_close:
				safe_position = test_pos
				found_spot = true
			
			attempts += 1
		
		if not found_spot:
			print("Warning: Could not find empty spot for ", npc.name)
		
		npc.position = safe_position
		
		get_parent().call_deferred("add_child", npc)
		spawned_npcs.append(npc)

	assign_dance_partners.call_deferred(spawned_npcs)

func assign_dance_partners(npc_list):
	print("Waiting for NPCs to initialize...")
	await get_tree().create_timer(1.0).timeout
	
	print("Starting the Ball...")
	
	var couples = 5
	
	for i in range(couples):
		if not is_instance_valid(npc_list[i*2]) or not is_instance_valid(npc_list[i*2+1]):
			continue
			
		var npc_a = npc_list[i * 2]
		var npc_b = npc_list[(i * 2) + 1]
		
		var center = (npc_a.global_position + npc_b.global_position) / 2.0
		
		npc_a.start_dancing(center, 0.0, npc_b)
		npc_b.start_dancing(center, PI, npc_a)

func spawn_crown():
	if not multiplayer.is_server():
		return
		
	print("Spawning crown...")
	var crown_scene = load("res://prefabs/crown.tscn")
	if crown_scene:
		var crown = crown_scene.instantiate()
		# Update crown spawn to match new map size
		crown.position = Vector2(randf_range(-1000, 1000), randf_range(-800, 800))
		get_parent().add_child(crown)

@rpc("any_peer", "call_local")
func check_win_condition(player_id: int, kills: int):
	if kills >= KILLS_TO_WIN:
		announce_winner.rpc(player_id)

@rpc("any_peer", "call_local")
func announce_winner(player_id: int):
	print("Player ", player_id, " wins!")
