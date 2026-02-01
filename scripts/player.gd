extends CharacterBody2D

# --- PROPERTIES ---
@export var speed = 300.0

# --- KILL SYSTEM PROPERTIES ---
@export var kill_range = 150.0
@export var kill_cooldown = 1.0
var last_kill_time = 0.0

# --- DANCE SYSTEM PROPERTIES ---
@export var dance_range = 150.0
var is_dancing = false
var dance_duration = 3.0
var dance_timer = 0.0
var dance_partner = null

# --- GAME LOGIC VARIABLES ---
var player_name = "Player"
var lives = 3
var kill_count = 0
var has_crown = false
var is_npc = false
var inventory = []

# --- REFERENCES ---
# IMPORTANT: Make sure your Sprite node is named "Sprite2D" in the scene tree!
@onready var sprite = $Sprite2D 
@onready var lives_container = $LivesContainer
@onready var game_over_layer = $GameOverLayer
@onready var inventory_container = $InventoryContainer
@onready var dance_indicator = $DanceIndicator

# --- SETUP ---
func _enter_tree():
	var id = name.to_int()
	if id == 0:
		set_multiplayer_authority(1)
	else:
		set_multiplayer_authority(id)

func _ready():
	print("PLAYER READY (Lives: ", lives, ") - ", player_name)

	# Random color for each player
	if sprite:
		sprite.modulate = Color(randf(), randf(), randf())
		# sprite.play("idle")  # Disabled: Using Sprite2D
	
	add_to_group("players")
	update_lives_ui()
	
	if dance_indicator:
		dance_indicator.visible = false
	
	if is_multiplayer_authority():
		var camera = Camera2D.new()
		add_child(camera)
		camera.enabled = true
		
	if game_over_layer:
		game_over_layer.visible = false
# ...
# ANIMATION BASED ON MOVEMENT
	if sprite and not is_dancing:
		if velocity.length() > 0:
			pass # sprite.play("walk")
		else:
			pass # sprite.play("idle")
		# print("Current animation:", sprite.animation)

	move_and_slide()
# ...
@rpc("any_peer", "call_local")
func start_dance():
	is_dancing = true
	dance_timer = dance_duration
	
	if dance_indicator:
		dance_indicator.visible = true
	
	if sprite:
		# sprite.play("dance")
		sprite.modulate = Color.YELLOW


func end_dance():
	print(name, " stopped dancing")
	is_dancing = false
	dance_partner = null
	
	if dance_indicator:
		dance_indicator.visible = false
	
	# Back to idle and random color
	if sprite:
		# sprite.play("idle")
		sprite.modulate = Color(randf(), randf(), randf())
# ...
		# Flash effect
		if sprite:
			sprite.modulate.a = 0.3
			await get_tree().create_timer(0.5).timeout
			if lives > 0:
				sprite.modulate.a = 1.0
# ...
func become_crown_pickup():
	print("Crown dropped at ", global_position)
	
	if sprite:
		# sprite.play("idle")  # Stop animating
		sprite.modulate = Color(1, 0.8, 0)  # Gold
		sprite.scale = Vector2(0.5, 0.5)
	
	add_to_group("crown_pickups")	
	
