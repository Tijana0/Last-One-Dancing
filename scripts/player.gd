extends CharacterBody2D

# --- PROPERTIES ---
@export var speed = 300.0
@export var mask_index: int = 1  # 1–5 selects which mask sprite set; 0 keeps scene default

# --- KILL SYSTEM PROPERTIES ---
@export var kill_range = 150.0
@export var kill_cooldown = 1.5 # Increased to give more escape time
var last_kill_time = 0.0

# --- DAMAGE & INVULNERABILITY ---
@export var invulnerability_duration = 2.0
@export var knockback_strength = 500.0
@export var recoil_strength = 300.0 # New property for attacker recoil
var is_invulnerable = false
var knockback_velocity = Vector2.ZERO

# --- KILL ANIMATION ---
var is_killing: bool = false
var last_facing: Vector2 = Vector2.DOWN

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
var current_mask_type = 0 # 0 = None, 1 = Mask 1, etc.

# SpriteFrames resources for each mask (index matches mask_index 1–5)
const MASK_FRAMES: Array = [
	null,  # index 0: no mask, keeps the scene default
	preload("res://assets/sprites/masks/mask1_frames.tres"),
	preload("res://assets/sprites/masks/mask2_frames.tres"),
	preload("res://assets/sprites/masks/mask3_frames.tres"),
	preload("res://assets/sprites/masks/mask4_frames.tres"),
	preload("res://assets/sprites/masks/mask5_frames.tres"),
]

# Preload textures for UI
const TEX_POTION = preload("res://assets/Potion.PNG")
const TEX_GUN = preload("res://assets/gun.PNG")
const TEX_MASK = preload("res://assets/gold_mask.png")
const TEX_CROWN = preload("res://assets/crown.PNG")
const TEX_HEART_FULL = preload("res://assets/heart_full.PNG")
const TEX_HEART_EMPTY = preload("res://assets/heart_empty.PNG")

# --- REFERENCES ---
@onready var animated_sprite = $AnimatedSprite 
@onready var hud = $HUD
@onready var lives_container = $HUD/LivesContainer
@onready var mask_display = $HUD/MaskDisplay
@onready var game_over_layer = $GameOverLayer
@onready var inventory_container = $HUD/InventoryContainer
@onready var dance_indicator = $DanceIndicator
var main_camera: Camera2D = null

# --- SETUP ---
func _enter_tree():
	var id = name.to_int()
	if id == 0:
		set_multiplayer_authority(1)
	else:
		set_multiplayer_authority(id)

func _ready():
	print("PLAYER READY (Lives: ", lives, ") - ", player_name)

	# Load mask-specific SpriteFrames and set initial animation
	if animated_sprite:
		if mask_index >= 1 and mask_index <= 5:
			animated_sprite.sprite_frames = MASK_FRAMES[mask_index]
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
	update_mask_ui()

	if dance_indicator:
		dance_indicator.visible = false

	if is_multiplayer_authority():
		main_camera = Camera2D.new()
		add_child(main_camera)
		main_camera.enabled = true
		main_camera.position_smoothing_enabled = true
		main_camera.make_current()

	if game_over_layer:
		game_over_layer.visible = false
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

func update_mask_ui():
	if not mask_display: return
	
	var icon_node = mask_display.get_node_or_null("MaskIcon")
	if not icon_node: return
	
	# Clear previous
	for child in icon_node.get_children():
		child.queue_free()
	
	# If we have a mask, show it
	if current_mask_type > 0:
		var mask_texture = TextureRect.new()
		mask_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mask_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mask_texture.custom_minimum_size = Vector2(70, 70)
		
		# For now, just using the golden mask texture as default
		mask_texture.texture = TEX_MASK
		
		mask_texture.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		
		# Offset to match inventory style if needed
		mask_texture.position.x -= 20
		mask_texture.position.y -= 20
		
		icon_node.add_child(mask_texture)

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

	# Block input while kill animation plays
	if is_killing:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	# Movement
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# Optional: Slight push away from items to prevent overlapping
	var items = get_tree().get_nodes_in_group("pickups")
	for item in items:
		if global_position.distance_to(item.global_position) < 40.0:
			var push_dir = (global_position - item.global_position).normalized()
			direction = (direction + push_dir * 0.3).normalized()

	# Apply knockback friction
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 1500.0 * delta)
	
	velocity = (direction * speed) + knockback_velocity
	
	# ANIMATION BASED ON MOVEMENT DIRECTION
	if animated_sprite and not is_dancing and not is_killing:
		if velocity.length() > 0:
			var norm = velocity.normalized()
			last_facing = norm
			var anim = get_walk_anim(norm)
			if mask_index >= 3:
				animated_sprite.flip_h = (anim == "walk_side" and norm.x < 0)
			else:
				animated_sprite.flip_h = false
			if animated_sprite.animation != anim:
				animated_sprite.play(anim)
		else:
			animated_sprite.flip_h = false
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

func get_walk_anim(norm: Vector2) -> String:
	if mask_index == 1 or mask_index == 2:
		if abs(norm.x) > abs(norm.y):
			return "walk_right" if norm.x > 0 else "walk_left"
		elif norm.y < 0 and mask_index == 1:
			return "walk_back"
		else:
			return "walk_front"
	else:
		if abs(norm.x) > abs(norm.y):
			return "walk_side"
		else:
			return "walk_front"

func get_kill_anim() -> String:
	if mask_index == 1:
		if abs(last_facing.x) > abs(last_facing.y):
			return "kill_right" if last_facing.x > 0 else "kill_left"
		elif last_facing.y < 0:
			return "kill_back"
		else:
			return "kill_front"
	else:
		return "kill"

func play_kill_animation() -> void:
	if not animated_sprite:
		return
	is_killing = true
	animated_sprite.play(get_kill_anim())
	await animated_sprite.animation_finished
	is_killing = false
	if animated_sprite and animated_sprite.animation != "idle":
		animated_sprite.play("idle")

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

			# APPLY RECOIL TO SELF (The Attacker)
			var recoil_dir = (global_position - target.global_position).normalized()
			knockback_velocity = recoil_dir * recoil_strength

			# Play kill animation locally (fire-and-forget coroutine)
			play_kill_animation()

			# Pass calculated damage and our position for knockback
			target.rpc_id(target.get_multiplayer_authority(), "request_damage", name.to_int(), damage, global_position)
			return
			
	print("Failed: No one close enough")

# --- DAMAGE & HEALTH SYNC ---
@rpc("any_peer", "call_local")
func request_damage(attacker_id: int, damage_amount: int = 1, attacker_pos: Vector2 = Vector2.ZERO):
	print("DEBUG: request_damage called on ", name)
	
	if not is_multiplayer_authority():
		print("DEBUG: Ignored (Not Authority)")
		return

	if is_invulnerable:
		print("DEBUG: Ignored (Is Invulnerable)")
		return
	
	# Calculate Knockback
	if attacker_pos != Vector2.ZERO:
		var knockback_dir = (global_position - attacker_pos).normalized()
		knockback_velocity = knockback_dir * knockback_strength
	
	# Trigger Shake
	shake_camera(0.3, 10.0)
	
	lives -= damage_amount
	print("DEBUG: ", name, " lives decreased to: ", lives)
	
	rpc("sync_lives", lives, attacker_id)

func shake_camera(duration: float, intensity: float):
	if not main_camera: return
	
	var timer = 0.0
	while timer < duration:
		var offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		main_camera.offset = offset
		await get_tree().create_timer(0.02).timeout
		timer += 0.02
	
	main_camera.offset = Vector2.ZERO

@rpc("authority", "call_local")
func sync_lives(new_lives: int, killer_id: int):
	print("DEBUG: sync_lives - ", name, " now has ", new_lives, " lives")
	
	var was_damaged = new_lives < lives
	lives = new_lives
	update_lives_ui()

	if lives > 0:
		if was_damaged:
			start_invulnerability()
	else:
		# Death
		print(name, " ELIMINATED!")

		$CollisionShape2D.set_deferred("disabled", true)
		set_physics_process(false)

		# Play kill animation before hiding
		if animated_sprite and animated_sprite.sprite_frames:
			var kanim = get_kill_anim()
			if animated_sprite.sprite_frames.has_animation(kanim):
				animated_sprite.play(kanim)
				await animated_sprite.animation_finished

		visible = false

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

func start_invulnerability():
	is_invulnerable = true
	
	# Visual flicker loop
	var flicker_count = 10
	var interval = invulnerability_duration / (flicker_count * 2)
	
	for i in range(flicker_count):
		if animated_sprite:
			animated_sprite.modulate.a = 0.3
		await get_tree().create_timer(interval).timeout
		if animated_sprite:
			animated_sprite.modulate.a = 1.0
		await get_tree().create_timer(interval).timeout
	
	is_invulnerable = false
	if animated_sprite:
		animated_sprite.modulate.a = 1.0

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
			var item_texture = TextureRect.new()

			# UI Centering Logic
			item_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			item_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

			if type == 0: # POTION
				item_texture.texture = TEX_POTION
				item_texture.custom_minimum_size = Vector2(100, 100)
			elif type == 1: # GUN
				item_texture.texture = TEX_GUN
				item_texture.custom_minimum_size = Vector2(80, 80)
			elif type == 2: # MASK
				item_texture.texture = TEX_MASK
				item_texture.custom_minimum_size = Vector2(70, 70)

			# Center the TextureRect inside the Icon (Control) node
			item_texture.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
			
			# MANUAL OFFSET: Move higher and to the left to fit assets
			var offset_x = -50
			var offset_y = -50
			
			if type == 0: # POTION
				offset_y = -60 
			elif type == 1: # GUN
				offset_x = -40
				offset_y = -40
			elif type == 2: # MASK
				offset_x = -35 
				offset_y = -35
			
			item_texture.position.x += offset_x
			item_texture.position.y += offset_y
			
			icon_node.add_child(item_texture)
@rpc("any_peer", "call_local")
func add_kill():
	kill_count += 1
	print("My Kill Count: ", kill_count)
