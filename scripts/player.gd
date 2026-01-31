extends CharacterBody2D

# --- PROPERTIES ---
@export var speed = 300.0

# --- KILL SYSTEM PROPERTIES ---
@export var kill_range = 100.0   # How close you must be to kill (pixels)
@export var kill_cooldown = 1.0  # Seconds you must wait between kills
var last_kill_time = 0.0         # Tracks when you last killed

# --- GAME LOGIC VARIABLES ---
var player_name = "Player"
var lives = 3
var kill_count = 0
var has_crown = false

# --- REFERENCES ---
# IMPORTANT: Make sure your Sprite node is named "Sprite2D" in the scene tree!
@onready var sprite = $Sprite2D 
@onready var lives_container = $LivesContainer

# --- SETUP ---
func _enter_tree():
	# This helps the MultiplayerSpawner find this node and assign authority
	set_multiplayer_authority(name.to_int())

func _ready():
	# Give every player a random color so we can tell them apart for now
	if sprite:
		sprite.modulate = Color(randf(), randf(), randf())
	
	# CRITICAL: Add to group so players can find each other for killing
	add_to_group("players")
	
	# Update UI initially
	update_lives_ui()
	
	# Only enable a camera for the local player
	if is_multiplayer_authority():
		var camera = Camera2D.new()
		add_child(camera)
		camera.enabled = true

# --- UI UPDATES ---
func update_lives_ui():
	if lives_container:
		var hearts = lives_container.get_children()
		for i in range(hearts.size()):
			# Show heart if index is less than lives count
			hearts[i].visible = i < lives

# --- MOVEMENT LOOP ---
func _physics_process(delta):
	
	print("I am running!")
	
	# CRITICAL: If this player node does not belong to me, STOP.
	if not is_multiplayer_authority():
		return
	
	# Movement Logic
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * speed
	move_and_slide()
	
	# --- DEBUG TEST: BYPASS INPUT MAP ---
	# We use is_physical_key_pressed to ignore the Input Map entirely
	if Input.is_physical_key_pressed(KEY_K):
		# We use 'just_pressed' logic manually to stop it from spamming
		if not Input.is_action_just_pressed("kill"): # Just a check to see if map is working
			print("Raw 'K' key detected, but Input Map 'kill' did NOT trigger!")
		
		attempt_kill()

# --- NETWORK SYNC ---
func _process(delta):
	if is_multiplayer_authority():
		# If I am me, send my position to the server/others
		rpc("sync_transform", position, rotation)

@rpc("any_peer", "unreliable")
func sync_transform(pos: Vector2, rot: float):
	# If I am NOT the authority (meaning this is someone else's player),
	# update their position on my screen.
	if not is_multiplayer_authority():
		position = pos
		rotation = rot

# --- KILL SYSTEM FUNCTIONS ---

func attempt_kill():
	print("--- ATTEMPTING KILL ---") # 1. Confirm Input works
	
	# Check Cooldown
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_kill_time < kill_cooldown:
		print("Failed: Cooldown active")
		return 
	
	last_kill_time = current_time
	
	# Find players
	var players = get_tree().get_nodes_in_group("players")
	print("Found ", players.size(), " players in group.") # 2. Confirm Group works
	
	var killed_someone = false
	
	for player in players:
		# Skip self
		if player == self:
			continue 
			
		# Check distance
		var distance = global_position.distance_to(player.global_position)
		print("Checking target: ", player.name, " | Distance: ", distance) # 3. Confirm Distance
		
		# TEMPORARY: Increased range for testing
		if distance < 300.0: # Increased from 100 to 300 to make testing easier
			print("!!! HIT CONFIRMED on ", player.name, " !!!")
			# Pass my ID so the victim knows who hit them (for score credit)
			player.rpc("take_damage", name.to_int())      
			killed_someone = true
			break 
			
	if not killed_someone:
		print("Failed: No one close enough")

# This function runs on EVERYONE'S computer to update the victim
@rpc("any_peer", "call_local")
func take_damage(killer_id: int):
	lives -= 1
	print(name, " took damage! Lives remaining: ", lives)
	update_lives_ui()

	if lives > 0:
		# --- RESPAWN LOGIC ---
		# Respawn at random location (Adjust 800/600 to your window size)
		global_position = Vector2(randf_range(0, 800), randf_range(0, 600))
		
		# Visual Feedback (Flash transparent)
		if sprite:
			sprite.modulate.a = 0.3
			await get_tree().create_timer(1.0).timeout
			# Only restore opacity if we haven't died in the meantime
			if lives > 0:
				sprite.modulate.a = 1.0
	else:
		# --- PERMANENT DEATH LOGIC ---
		print(name, " has been ELIMINATED!")
		
		# 1. Hide the player and disable collision
		visible = false
		$CollisionShape2D.set_deferred("disabled", true)
		set_physics_process(false) # Stop movement
		
		# 2. Remove from "players" group so they can't be targeted anymore
		remove_from_group("players")
		
		# 3. Award the kill to the killer
		# We use rpc_id to send the message specifically to the killer
		if killer_id != 0:
			rpc_id(killer_id, "add_kill")

		# Drop crown logic (Placeholder for next step)
		if has_crown:
			has_crown = false

# This function updates the killer's score
@rpc("any_peer", "call_local")
func add_kill():
	kill_count += 1
	print("My Kill Count: ", kill_count)
