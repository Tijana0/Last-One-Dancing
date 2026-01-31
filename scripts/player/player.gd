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

func _physics_process(delta):
	# Only control YOUR player
	if not is_multiplayer_authority():
		return
	
	# Movement handled by player_movement.gd (Person 3 will add)
	pass
