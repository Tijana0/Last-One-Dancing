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

# Preload textures for UI
const TEX_POTION = preload("res://assets/Potion.PNG")
const TEX_GUN = preload("res://assets/gun.PNG")
const TEX_MASK = preload("res://assets/gold_mask.png")
const TEX_CROWN = preload("res://assets/crown.PNG")
const TEX_HEART_FULL = preload("res://assets/heart_full.PNG")
const TEX_HEART_EMPTY = preload("res://assets/heart_empty.PNG")

# ...
# --- UI UPDATES ---
func update_lives_ui():
	if lives_container:
		var hearts = lives_container.get_children()
		for i in range(hearts.size()):
			# Set texture based on current lives
			if i < lives:
				hearts[i].texture = TEX_HEART_FULL
			else:
				hearts[i].texture = TEX_HEART_EMPTY
			
			# Ensure they are always visible (just swapping textures)
			hearts[i].visible = true

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
		
	# E KEY: USE ITEM (Potion)
	if Input.is_physical_key_pressed(KEY_E):
		use_potion()

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
	
	# Check for Gun (Type 1)
	var damage = 1
	var gun_index = inventory.find(1)
	if gun_index != -1:
		damage = 2
		print("USING GUN! Damage: 2")
		inventory.remove_at(gun_index)
		update_inventory_ui()
	
	var targets = []
	targets.append_array(get_tree().get_nodes_in_group("players"))
	targets.append_array(get_tree().get_nodes_in_group("npcs"))
	
	print("Found ", targets.size(), " potential kill targets")
	
	for target in targets:
		if target == self:
			continue 
		
		var distance = global_position.distance_to(target.global_position)
		print("Checking target: ", target.name, " | Distance: ", distance)
		
		if distance < kill_range:
			print("!!! HIT CONFIRMED on ", target.name, " !!!")
			# Pass calculated damage
			target.rpc_id(target.get_multiplayer_authority(), "request_damage", name.to_int(), damage)      
			return
			
	print("Failed: No one close enough")

# --- DAMAGE & HEALTH SYNC ---
@rpc("any_peer", "call_local")
func request_damage(attacker_id: int, damage_amount: int = 1):
	print("DEBUG: request_damage called on ", name)
	
	if not is_multiplayer_authority():
		print("DEBUG: Ignored (Not Authority)")
		return
	
	lives -= damage_amount
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
		
		# SHOW LOSE SCREEN instead of game_over_layer
		if is_multiplayer_authority() and not is_npc:
			show_lose_screen(killer_id)
		
		remove_from_group("players")
		
		# --- CHECK GAME STATE ---
		var game_manager = get_tree().current_scene.get_node_or_null("GameManager")
		
		if has_crown:
			become_crown_pickup()
		else:
			# A regular player died. Check if it's time to spawn the Boss.
			if game_manager and multiplayer.is_server():
				game_manager.check_survivors()

func show_lose_screen(killer_id: int):
	# Find killer name
	var killer_name = "Unknown"
	if has_node("/root/NetworkManager"):
		var network_manager = get_node("/root/NetworkManager")
		if network_manager.players.has(killer_id):
			killer_name = network_manager.players[killer_id]
	
	# Wait before showing screen
	await get_tree().create_timer(2.0).timeout
	
	var lose_scene = load("res://scenes/lose_screen.tscn")
	if lose_scene:
		var lose_screen = lose_scene.instantiate()
		
		# Pass stats
		lose_screen.player_kills = kill_count
		# lose_screen.player_dances = 0 # Need to track dances if we want this stat
		lose_screen.killer_name = killer_name
		
		# Add to root (covering everything)
		get_tree().root.add_child(lose_screen)
		
		# Hide HUD
		if hud: hud.visible = false

func become_crown_pickup():
	print("Crown dropped at ", global_position)
	
	# Ensure parent is visible (it was hidden in sync_lives)
	visible = true
	
	# Hide player body sprite
	if animated_sprite:
		animated_sprite.visible = false
		
	# Show Crown Sprite
	var crown_sprite = Sprite2D.new()
	crown_sprite.texture = TEX_CROWN
	crown_sprite.scale = Vector2(0.15, 0.15) # Made smaller
	add_child(crown_sprite)
	
	add_to_group("crown_pickups")
	$CollisionShape2D.set_deferred("disabled", true)

# --- ITEM SYSTEM ---

func pickup_item(item):
	print("Picked up item type: ", item.type)
	
	# TYPE 0: POTION (Extra Life)
	if item.type == 0:
		# STRICT CHECK: Can only pick up if injured
		if lives >= 3:
			print("Lives full! Potion left on ground.")
			return
			
		# 1. Instant Heal Effect
		lives += 1
		update_lives_ui()
		print("Instant Heal! Lives: ", lives)
		rpc("sync_lives", lives, 0)
			
		# 2. Add to Inventory (Reserve)
		if inventory.size() < 3:
			inventory.append(item.type)
			update_inventory_ui()
		else:
			print("Inventory full! Healed but no reserve stored.")
	else:
		# TYPE 1 (GUN) or TYPE 2 (MASK) -> Add to inventory
		if inventory.size() < 3:
			inventory.append(item.type)
			update_inventory_ui()
		else:
			print("Inventory full! Item left on ground.")
			return # Return early if inventory full
	
	# Destroy item globally
	var game_manager = get_tree().current_scene.get_node_or_null("GameManager")
	if game_manager:
		game_manager.rpc("destroy_item", item.name)

func use_potion():
	# Find first potion (type 0) in inventory
	var potion_index = inventory.find(0)
	
	if potion_index != -1:
		if lives < 3:
			print("Using Potion...")
			lives += 1
			inventory.remove_at(potion_index)
			update_lives_ui()
			update_inventory_ui()
			# Sync life gain to others
			rpc("sync_lives", lives, 0)
		else:
			print("Lives full! Can't use potion.")
	else:
		print("No potion in inventory.")

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
			var inv_sprite = Sprite2D.new()
			inv_sprite.centered = true
			inv_sprite.position = Vector2.ZERO # Center relative to Icon node (40,40)
			
			if type == 0: # POTION
				inv_sprite.texture = TEX_POTION
				inv_sprite.scale = Vector2(0.06, 0.06)
			elif type == 1: # GUN
				inv_sprite.texture = TEX_GUN
				inv_sprite.scale = Vector2(0.05, 0.05) # Even smaller
			elif type == 2: # MASK
				inv_sprite.texture = TEX_MASK
				inv_sprite.scale = Vector2(0.2, 0.2)
			
			icon_node.add_child(inv_sprite)

@rpc("any_peer", "call_local")
func add_kill():
	kill_count += 1
	print("My Kill Count: ", kill_count)