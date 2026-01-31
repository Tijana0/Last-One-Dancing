extends CharacterBody2D

@export var speed = 300.0
var player_name = "Player"
var kill_count = 0
var has_crown = false

@onready var name_label = $NameLabel
@onready var camera = $Camera2D
@onready var sprite = $Body

func _ready():
	# Set up name label
	name_label.text = player_name
	name_label.position = Vector2(-50, -60)  # Above player
	
	# Only enable camera for local player
	if is_multiplayer_authority():
		camera.enabled = true
	else:
		camera.enabled = false
	
	# Set a random color for testing (Person 4 will replace with sprites)
	sprite.modulate = Color(randf(), randf(), randf())

func _enter_tree():
	# This helps the MultiplayerSpawner find this node
	var id = name.to_int()
	if id == 0:
		id = 1
	set_multiplayer_authority(id)

func _physics_process(delta):
	# Debug print (remove later)
	# print("Name: ", name, " Auth: ", is_multiplayer_authority(), " ID: ", multiplayer.get_unique_id())

	# Only control YOUR player
	if not is_multiplayer_authority():
		return
	
	# Basic movement
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direction != Vector2.ZERO:
		print("Moving: ", direction)
	velocity = direction * speed
	move_and_slide()

# Call this to kill another player
@rpc("any_peer", "call_local")
func die():
	print(player_name, " died!")
	
	# Remove crown if had it
	if has_crown:
		has_crown = false
		# Notify game manager
	
	# Respawn at random position
	position = Vector2(randf_range(-400, 400), randf_range(-300, 300))
	
	# Visual feedback
	sprite.modulate.a = 0.5  # Semi-transparent
	await get_tree().create_timer(0.5).timeout
	sprite.modulate.a = 1.0

@rpc("any_peer", "call_local")
func add_kill():
	kill_count += 1
	print(player_name, " now has ", kill_count, " kills")

# Sync variables across network
func _process(delta):
	if is_multiplayer_authority():
		# Send position to other clients
		rpc("sync_transform", position, rotation)

@rpc("any_peer", "unreliable")
func sync_transform(pos: Vector2, rot: float):
	if not is_multiplayer_authority():
		position = pos
		rotation = rot
