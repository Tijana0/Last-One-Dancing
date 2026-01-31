extends CharacterBody2D

# --- SETTINGS ---
@export var move_speed = 100.0      # Slower than players (makes them easier to spot if observing closely)
@export var wander_time = 2.0       # How long to walk before stopping
@export var dance_time = 3.0        # How long to stop (dance) before walking

# --- STATE ---
var move_direction = Vector2.ZERO
var time_until_change = 0.0
var is_dancing = false

# @onready var sprite = $Sprite2D
@onready var sprite = $Body

func _ready():
	# Visuals: Random color (Must match player logic eventually)
	sprite.modulate = Color(randf(), randf(), randf())
	
	# Add to a group so we can tell them apart in code (even if players can't tell visually)
	add_to_group("npcs")
	
	# Start with a random timer so they don't all move at the exact same time
	time_until_change = randf_range(0, wander_time)

func _physics_process(delta):
	# CRITICAL: Only the Server thinks for NPCs. 
	# Clients just watch what the server tells them.
	if not multiplayer.is_server():
		return

	# Timer Logic
	time_until_change -= delta
	if time_until_change <= 0:
		decide_next_move()
	
	# Apply Movement
	if not is_dancing:
		velocity = move_direction * move_speed
		move_and_slide()
	else:
		# If dancing, stand still (Velocity 0)
		velocity = Vector2.ZERO

# --- AI LOGIC (Server Only) ---
func decide_next_move():
	# Toggle between Moving and Dancing
	is_dancing = !is_dancing
	
	if is_dancing:
		# State: DANCE (Stop moving)
		time_until_change = randf_range(2.0, dance_time)
		move_direction = Vector2.ZERO
	else:
		# State: WANDER (Pick a random direction)
		time_until_change = randf_range(1.0, wander_time)
		# Pick a random angle
		var angle = randf() * TAU # TAU is 2*PI (360 degrees)
		move_direction = Vector2(cos(angle), sin(angle))

# --- NETWORK SYNC ---
# We need to send the Server's NPC position to all Clients
func _process(delta):
	if multiplayer.is_server():
		rpc("sync_npc_transform", position)

@rpc("authority", "unreliable") # "authority" means only server can call this
func sync_npc_transform(pos: Vector2):
	# Clients update their NPC position to match the server
	position = pos
