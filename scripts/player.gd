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
@onready var animated_sprite = $AnimatedSprite 
@onready var hud = $HUD
@onready var lives_container = $HUD/LivesContainer
@onready var game_over_layer = $GameOverLayer
@onready var inventory_container = $HUD/InventoryContainer
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
	if animated_sprite:
		animated_sprite.modulate = Color(randf(), randf(), randf())
		animated_sprite.play("idle")
	
	add_to_group("players")
	
	# HUD VISIBILITY LOGIC
	if hud:
		if is_multiplayer_authority() and not is_npc:
			hud.visible = true
		else:
			hud.visible = false
	
	update_lives_ui()
	
	if dance_indicator:
		dance_indicator.visible = false
	
	if is_multiplayer_authority():
		var camera = Camera2D.new()
		add_child(camera)
		camera.enabled = true
		camera.position_smoothing_enabled = true
		camera.make_current()
		
	if game_over_layer:
		game_over_layer.visible = false

# --- UI UPDATES ---
func update_lives_ui():
	if lives_container:
		var hearts = lives_container.get_children()
		for i in range(hearts.size()):
			hearts[i].visible = i < lives

# --- MOVEMENT LOOP ---
func _physics_process(delta):
	if not is_multiplayer_authority():
		return
		
	if is_npc:
		return
	
	# Can't move while dancing
	if is_dancing:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	# Movement
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * speed
	
	# ANIMATION BASED ON MOVEMENT
	if animated_sprite and not is_dancing:
		if velocity.length() > 0:
			if animated_sprite.animation != "walk":
				animated_sprite.play("walk")
		else:
			if animated_sprite.animation != "idle":
				animated_sprite.play("idle")
	
	move_and_slide()
	
	# F KEY: DANCE
	if Input.is_physical_key_pressed(KEY_F):
		attempt_dance()
	
	# K KEY: KILL
	if Input.is_physical_key_pressed(KEY_K):
		attempt_kill()
	
	# SPACE: INTERACT (Crown pickup / Items)
	if Input.is_physical_key_pressed(KEY_SPACE):
		attempt_interact()

# --- NETWORK SYNC ---
func _process(delta):
	if is_multiplayer_authority():
		rpc("sync_transform", position)
	
	# Update dance timer
	if is_dancing:
		dance_timer -= delta
		if dance_timer <= 0:
			end_dance()

@rpc("any_peer", "unreliable")
func sync_transform(pos: Vector2):
	if not is_multiplayer_authority():
		position = pos

# --- INTERACT SYSTEM (Space) ---
func attempt_interact():
	print("--- ATTEMPTING INTERACT ---")
	
	if Input.is_action_just_pressed("ui_accept") or true:
		pass
	
	# 1. Crown (Priority)
	var pickups = get_tree().get_nodes_in_group("crown_pickups")
	for pickup in pickups:
		if global_position.distance_to(pickup.global_position) < 100.0:
			print("Picking up crown!")
			var game_manager = get_tree().current_scene.get_node_or_null("GameManager")
			if game_manager:
				game_manager.rpc("trigger_victory", name.to_int())
			return

	# 2. Items
	var items = get_tree().get_nodes_in_group("pickups")
	for item in items:
		if global_position.distance_to(item.global_position) < 60.0:
			if inventory.size() < 3:
				pickup_item(item)
				return

# --- DANCE SYSTEM (F key) ---
func attempt_dance():
	print("--- ATTEMPTING DANCE ---")
	
	if is_dancing:
		print("Already dancing!")
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_kill_time < 0.5:
		print("Dance cooldown active")
		return
	
	last_kill_time = current_time
	
	var targets = []
	targets.append_array(get_tree().get_nodes_in_group("players"))
	targets.append_array(get_tree().get_nodes_in_group("npcs"))
	
	print("Found ", targets.size(), " potential dance partners")
	
	for target in targets:
		if target == self:
			continue
		
		var distance = global_position.distance_to(target.global_position)
		print("Checking ", target.name, " | Distance: ", distance)
		
		if distance < dance_range:
			print("!!! DANCE STARTED with ", target.name, " !!!")
			
			start_dance.rpc()
			
			# If target is a player, call its RPC
			if target.has_method("start_dance"):
				target.rpc("start_dance")
			
			dance_partner = target
			return
	
	print("No one close enough to dance with")

@rpc("any_peer", "call_local")
func start_dance():
	is_dancing = true
	dance_timer = dance_duration
	
	if dance_indicator:
		dance_indicator.visible = true
	
	if animated_sprite:
		if animated_sprite.animation != "dance":
			animated_sprite.play("dance")
		animated_sprite.modulate = Color.YELLOW

func end_dance():
	print(name, " stopped dancing")
	is_dancing = false
	dance_partner = null
	
	if dance_indicator:
		dance_indicator.visible = false
	
	# Back to idle and random color
	if animated_sprite:
		animated_sprite.play("idle")
		animated_sprite.modulate = Color(randf(), randf(), randf())

# --- KILL SYSTEM ---
func attempt_kill():
	print("--- ATTEMPTING KILL ---")
	
	if is_dancing:
		print("Can't kill while dancing!")
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_kill_time < kill_cooldown:
		print("Failed: Cooldown active")
		return 
	
	last_kill_time = current_time
	
	var players = get_tree().get_nodes_in_group("players")
	print("Found ", players.size(), " players in group.")
	
	for player in players:
		if player == self:
			continue 
		
		var distance = global_position.distance_to(player.global_position)
		print("Checking target: ", player.name, " | Distance: ", distance)
		
		if distance < kill_range:
			print("!!! HIT CONFIRMED on ", player.name, " !!!")
			player.rpc_id(player.get_multiplayer_authority(), "request_damage", name.to_int())      
			return
			
	print("Failed: No one close enough")

# --- DAMAGE & HEALTH SYNC ---
@rpc("any_peer", "call_local")
func request_damage(attacker_id: int):
	print("DEBUG: request_damage called on ", name)
	
	if not is_multiplayer_authority():
		print("DEBUG: Ignored (Not Authority)")
		return
	
	lives -= 1
	print("DEBUG: ", name, " lives decreased to: ", lives)
	
	rpc("sync_lives", lives, attacker_id)

@rpc("authority", "call_local")
func sync_lives(new_lives: int, killer_id: int):
	print("DEBUG: sync_lives - ", name, " now has ", new_lives, " lives")
	lives = new_lives
	update_lives_ui()

	if lives > 0:
		# Respawn
		var screen_size = get_viewport_rect().size
		global_position = Vector2(
			randf_range(50, screen_size.x - 50), 
			randf_range(50, screen_size.y - 50)
		)
		
		# Flash effect
		if animated_sprite:
			animated_sprite.modulate.a = 0.3
			await get_tree().create_timer(0.5).timeout
			if lives > 0:
				animated_sprite.modulate.a = 1.0
	else:
		# Death
		print(name, " ELIMINATED!")
		
		visible = false
		$CollisionShape2D.set_deferred("disabled", true)
		set_physics_process(false)
		
		if is_multiplayer_authority() and game_over_layer and not is_npc:
			game_over_layer.visible = true
		
		remove_from_group("players")
		
		# --- CHECK GAME STATE ---
		var game_manager = get_tree().current_scene.get_node_or_null("GameManager")
		
		if has_crown:
			become_crown_pickup()
		else:
			# A regular player died. Check if it's time to spawn the Boss.
			if game_manager and multiplayer.is_server():
				game_manager.check_survivors()

func become_crown_pickup():
	print("Crown dropped at ", global_position)
	
	if animated_sprite:
		animated_sprite.play("idle")  # Stop animating
		animated_sprite.modulate = Color(1, 0.8, 0)  # Gold
		animated_sprite.scale = Vector2(0.5, 0.5)
	
	add_to_group("crown_pickups")
	$CollisionShape2D.set_deferred("disabled", true)
	
	var label = Label.new()
	label.text = "PRESS SPACE"
	label.position = Vector2(-50, -80)
	add_child(label)

# --- ITEM SYSTEM ---

func pickup_item(item):
	print("Picked up item type: ", item.type)
	inventory.append(item.type)
	update_inventory_ui()
	
	# Destroy item globally
	var game_manager = get_tree().current_scene.get_node_or_null("GameManager")
	if game_manager:
		game_manager.rpc("destroy_item", item.name)

func update_inventory_ui():
	if not inventory_container: return
	
	for i in range(3):
		var slot_name = "Slot" + str(i+1)
		var slot = inventory_container.get_node(slot_name)
		var icon_node = slot.get_node("Icon")
		
		# Clear previous drawing
		for child in icon_node.get_children():
			child.queue_free()
			
		if i < inventory.size():
			var type = inventory[i]
			var shape = Polygon2D.new()
			shape.color = Color.WHITE
			
			if type == 0: # TRIANGLE
				shape.polygon = PackedVector2Array([Vector2(0, -10), Vector2(10, 10), Vector2(-10, 10)])
			elif type == 1: # CIRCLE
				var circle_points = []
				for d in range(12):
					var angle = deg_to_rad(d * 30)
					circle_points.append(Vector2(cos(angle)*10, sin(angle)*10))
				shape.polygon = PackedVector2Array(circle_points)
			elif type == 2: # SQUARE
				shape.polygon = PackedVector2Array([Vector2(-10, -10), Vector2(10, -10), Vector2(10, 10), Vector2(-10, 10)])
			
			icon_node.add_child(shape)

@rpc("any_peer", "call_local")
func add_kill():
	kill_count += 1
	print("My Kill Count: ", kill_count)
