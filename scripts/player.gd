extends CharacterBody2D

# --- PROPERTIES ---
@export var speed = 300.0

# These will be used later for the game logic
var player_name = "Player"
var kill_count = 0
var has_crown = false

# We need references to our visual nodes
# IMPORTANT: Make sure your Sprite node is named "Sprite2D" in the scene tree!
@onready var sprite = $Sprite2D 

# --- SETUP ---
func _enter_tree():
	# This helps the MultiplayerSpawner find this node
	set_multiplayer_authority(name.to_int())

func _ready():
	# Give every player a random color so we can tell them apart for now
	sprite.modulate = Color(randf(), randf(), randf())

# --- MOVEMENT LOOP ---
func _physics_process(delta):
	# CRITICAL: If this player node does not belong to me, STOP.
	# This prevents me from controlling other people's characters.
	#if not is_multiplayer_authority():
	#	return
	
	# Get input
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * speed
	move_and_slide()

# --- NETWORK SYNC ---
# This part sends your position to everyone else
func _process(delta):
	if is_multiplayer_authority():
		# If I am me, send my position to the server/others
		rpc("sync_transform", position, rotation)

# This function receives the position data from the network
@rpc("any_peer", "unreliable")
func sync_transform(pos: Vector2, rot: float):
	# If I am NOT the authority (meaning this is someone else's player),
	# update their position on my screen.
	if not is_multiplayer_authority():
		position = pos
		rotation = rot
