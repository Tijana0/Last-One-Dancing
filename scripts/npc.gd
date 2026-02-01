extends CharacterBody2D

# --- STATE VARIABLES ---
var is_dancing = false
var dance_partner = null
var dance_center = Vector2.ZERO
var dance_angle = 0.0
var dance_speed = 2.0   
var dance_radius = 80.0 # Increased for spacing

# --- SETUP ---
func _ready():
	add_to_group("npcs")
	
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		sprite.modulate = Color(randf(), randf(), randf())

# --- MOVEMENT LOOP (Server Only) ---
func _physics_process(delta):
	if not multiplayer.is_server():
		return

	if is_dancing:
		process_dance_movement(delta)

# --- NETWORK SYNC ---
func _process(delta):
	if multiplayer.is_server():
		rpc("sync_npc_transform", position, rotation)

@rpc("authority", "call_remote", "unreliable")
func sync_npc_transform(pos: Vector2, rot: float):
	position = pos
	rotation = rot

# --- DANCE LOGIC ---
func start_dancing(center: Vector2, start_angle: float, partner_node):
	is_dancing = true
	dance_center = center
	dance_angle = start_angle
	dance_partner = partner_node
	
	# Disable collision with partner to prevent jitter
	if partner_node and partner_node is CollisionObject2D:
		add_collision_exception_with(partner_node)

func stop_dancing():
	is_dancing = false
	dance_partner = null

func process_dance_movement(delta):
	if not is_instance_valid(dance_partner):
		stop_dancing()
		return
		
	# 1. Update Angle
	dance_angle += dance_speed * delta
	
	# 2. Calculate Target
	var offset = Vector2(cos(dance_angle), sin(dance_angle)) * dance_radius
	var target_pos = dance_center + offset
	
	# 3. PHYSICS MOVE
	var desired_velocity = (target_pos - global_position) / delta
	velocity = desired_velocity
	move_and_slide()
