extends CharacterBody2D

# --- PROPERTIES ---
@export var speed = 300.0

# --- KILL SYSTEM ---
@export var kill_range = 100.0
@export var kill_cooldown = 1.0
var last_kill_time = 0.0

# --- DANCE SYSTEM ---
var is_dancing = false
var dance_partner = null
var dance_center = Vector2.ZERO
var dance_angle = 0.0
var dance_speed = 2.0 
var dance_radius = 80.0 

# --- GAME LOGIC ---
var player_name = "Player"
var kill_count = 0
var has_crown = false

# --- REFERENCES ---
@onready var sprite = $Sprite2D 
@onready var camera = $Camera2D

func _enter_tree():
	set_multiplayer_authority(name.to_int())

func _ready():
	if sprite:
		sprite.modulate = Color(randf(), randf(), randf())
	
	add_to_group("players")
	
	# --- CAMERA SETUP ---
	if is_multiplayer_authority():
		if camera:
			camera.enabled = true
			camera.make_current()
	else:
		if camera:
			camera.enabled = false

func _physics_process(delta):
	# Only run logic for the local player
	if not is_multiplayer_authority():
		return
	
	# --- STATE MACHINE (Movement Lock) ---
	# If dancing, we ONLY orbit. If not, we use WASD.
	if is_dancing:
		process_dance_movement(delta)
	else:
		process_standard_movement(delta)

	# --- INPUTS ---
	if Input.is_physical_key_pressed(KEY_K):
		attempt_kill()

	# Interact (F)
	if Input.is_action_just_pressed("interact") or Input.is_physical_key_pressed(KEY_F):
		if is_dancing:
			stop_dancing()
		else:
			attempt_dance_initiation()

# --- MOVEMENT FUNCTIONS ---

func process_standard_movement(delta):
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * speed
	move_and_slide()

func process_dance_movement(delta):
	# Safety Check: If partner disappears, stop dancing
	if dance_partner == null or not is_instance_valid(dance_partner):
		stop_dancing()
		return
		
	# 1. Update Angle
	dance_angle += dance_speed * delta
	
	# 2. Calculate Target Position
	var offset = Vector2(cos(dance_angle), sin(dance_angle)) * dance_radius
	var target_pos = dance_center + offset
	
	# 3. PHYSICS MOVE (Prevents overlapping)
	var desired_velocity = (target_pos - global_position) / delta
	velocity = desired_velocity
	move_and_slide()

# --- NETWORK SYNC ---
func _process(delta):
	if is_multiplayer_authority():
		rpc("sync_transform", position, rotation)

@rpc("any_peer", "unreliable")
func sync_transform(pos: Vector2, rot: float):
	if not is_multiplayer_authority():
		position = pos
		rotation = rot

# --- DANCE LOGIC ---

func attempt_dance_initiation():
	print("Looking for dance partner...")
	var npcs = get_tree().get_nodes_in_group("npcs")
	
	var closest_npc = null
	var closest_dist = 150.0 
	
	for npc in npcs:
		var dist = global_position.distance_to(npc.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_npc = npc
	
	if closest_npc:
		print("Found partner: ", closest_npc.name)
		rpc_id(1, "request_dance_server", closest_npc.get_path())

func stop_dancing():
	# 1. Stop locally
	is_dancing = false
	dance_partner = null
	
	# 2. Tell the Server to stop the NPC too
	rpc_id(1, "request_stop_dance_server")

@rpc("any_peer", "call_local")
func request_dance_server(npc_path):
	if not multiplayer.is_server():
		return
		
	var npc = get_node(npc_path)
	var player = self 
	
	if npc:
		var center = (player.global_position + npc.global_position) / 2.0
		
		# Start the NPC
		npc.start_dancing(center, PI, player)
		
		# Start the Player (via RPC)
		player.rpc("start_dancing_client", center, 0.0, npc_path)
		
		# Server remembers the link
		player.dance_partner = npc
		player.is_dancing = true

@rpc("any_peer", "call_local")
func request_stop_dance_server():
	if not multiplayer.is_server():
		return
		
	# Check if we were dancing with someone
	if is_instance_valid(dance_partner):
		# Tell the NPC to stop
		if dance_partner.has_method("stop_dancing"):
			dance_partner.stop_dancing()
			
	# Reset server-side variables for this player
	dance_partner = null
	is_dancing = false

@rpc("call_local")
func start_dancing_client(center: Vector2, angle: float, partner_path: String):
	var partner_node = get_node(partner_path)
	is_dancing = true
	dance_center = center
	dance_angle = angle
	dance_partner = partner_node

# --- KILL LOGIC ---
func attempt_kill():
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_kill_time < kill_cooldown: return 
	last_kill_time = current_time
	
	var players = get_tree().get_nodes_in_group("players")
	for player in players:
		if player == self: continue 
		if global_position.distance_to(player.global_position) < kill_range:
			player.rpc("die")      
			rpc("add_kill")        
			break 

@rpc("any_peer", "call_local")
func die():
	# Force stop dancing if you die
	is_dancing = false
	
	# Respawn anywhere in the large map
	var spawn_x = randf_range(-1000, 1000)
	var spawn_y = randf_range(-800, 800)
	global_position = Vector2(spawn_x, spawn_y)
	
	if has_crown: has_crown = false

@rpc("any_peer", "call_local")
func add_kill():
	kill_count += 1
