extends CharacterBody2D

# --- PROPERTIES ---
@export var speed = 300.0

# --- KILL SYSTEM PROPERTIES ---
@export var kill_range = 100.0   # How close you must be to kill (pixels)
@export var kill_cooldown = 1.0  # Seconds you must wait between kills
var last_kill_time = 0.0         # Tracks when you last killed

# --- GAME LOGIC VARIABLES ---
var player_name = "Player"
var kill_count = 0
var has_crown = false

# --- REFERENCES ---
# IMPORTANT: Make sure your Sprite node is named "Sprite2D" in the scene tree!
@onready var sprite = $Sprite2D 

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
	
	# Only enable a camera for the local player
	if is_multiplayer_authority():
		var camera = Camera2D.new()
		add_child(camera)
		camera.enabled = true

# --- MOVEMENT LOOP ---
func _physics_process(delta):
	# CRITICAL: If this player node does not belong to me, STOP.
	if not is_multiplayer_authority():
		return
	
	# Movement Logic
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * speed
	move_and_slide()
	
	# Kill Input (Right Mouse Button)
	# Make sure you added "kill" to your Input Map!
	if Input.is_action_just_pressed("kill"):
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
	# 1. Check Cooldown
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_kill_time < kill_cooldown:
		print("Kill on cooldown!")
		return 
	
	last_kill_time = current_time
	
	# 2. Find closest target
	var players = get_tree().get_nodes_in_group("players")
	var killed_someone = false
	
	for player in players:
		if player == self:
			continue # Can't kill self
			
		# Check distance
		var distance = global_position.distance_to(player.global_position)
		
		if distance < kill_range:
			# 3. Kill them!
			player.rpc("die")      # Tell them they died
			rpc("add_kill")        # Tell everyone I got a kill
			
			print("Killed ", player.name)
			killed_someone = true
			break # Only kill one per click
			
	if not killed_someone:
		print("Missed! No one in range.")

# This function runs on EVERYONE'S computer to update the victim
@rpc("any_peer", "call_local")
func die():
	print(name, " died!")
	
	# Respawn at random location (Adjust 800/600 to your window size)
	global_position = Vector2(randf_range(0, 800), randf_range(0, 600))
	
	# Visual Feedback (Flash transparent)
	if sprite:
		sprite.modulate.a = 0.3
		await get_tree().create_timer(1.0).timeout
		sprite.modulate.a = 1.0
	
	# Drop crown logic (Placeholder for next step)
	if has_crown:
		has_crown = false

# This function updates the killer's score
@rpc("any_peer", "call_local")
func add_kill():
	kill_count += 1
	print("My Kill Count: ", kill_count)
