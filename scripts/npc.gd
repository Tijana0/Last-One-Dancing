extends CharacterBody2D

# --- SETTINGS ---
@export var move_speed = 100.0      # Slower than players (makes them easier to spot if observing closely)
@export var wander_time = 2.0       # How long to walk before stopping
@export var dance_time = 3.0        # How long to stop (dance) before walking
@export var mask_index: int = 1     # 1–5; assigned by GameManager at spawn

# --- MASK FRAMES ---
const MASK_FRAMES: Array = [
	null,  # index 0: no mask
	preload("res://assets/sprites/masks/mask1_frames.tres"),
	preload("res://assets/sprites/masks/mask2_frames.tres"),
	preload("res://assets/sprites/masks/mask3_frames.tres"),
	preload("res://assets/sprites/masks/mask4_frames.tres"),
	preload("res://assets/sprites/masks/mask5_frames.tres"),
]

# --- STATE ---
var move_direction = Vector2.ZERO
var time_until_change = 0.0
var is_dancing = false
var forced_dance = false
var is_dying = false
var last_facing: Vector2 = Vector2.DOWN

@onready var sprite = $Body
@onready var animated_sprite = $AnimatedSprite

func _ready():
	if sprite:
		sprite.visible = false  # hide legacy Sprite2D placeholder

	if animated_sprite and mask_index >= 1 and mask_index <= 5:
		animated_sprite.sprite_frames = MASK_FRAMES[mask_index]
		animated_sprite.play("idle")

	add_to_group("npcs")

	# Stagger start times so NPCs don't all move in sync
	time_until_change = randf_range(0, wander_time)

func _physics_process(delta):
	# CRITICAL: Only the Server thinks for NPCs.
	# Clients just watch what the server tells them.
	if not multiplayer.is_server():
		return

	# Override: dying or forced dance stops all movement
	if forced_dance or is_dying:
		velocity = Vector2.ZERO
		return

	# Timer Logic
	time_until_change -= delta
	if time_until_change <= 0:
		decide_next_move()

	# Apply Movement
	if not is_dancing:
		# Item avoidance (simple)
		var items = get_tree().get_nodes_in_group("pickups")
		for item in items:
			if global_position.distance_to(item.global_position) < 80.0:
				var push_dir = (global_position - item.global_position).normalized()
				move_direction = (move_direction + push_dir * 0.5).normalized()
				time_until_change = 0.5  # Re-evaluate soon

		velocity = move_direction * move_speed
		move_and_slide()

		# Directional walk animation
		if animated_sprite:
			if velocity.length() > 0:
				var norm = move_direction.normalized()
				last_facing = norm
				var anim = get_walk_anim(norm)
				animated_sprite.flip_h = false
				if animated_sprite.animation != anim:
					animated_sprite.play(anim)
			else:
				animated_sprite.flip_h = false
				if animated_sprite.animation != "idle":
					animated_sprite.play("idle")
	else:
		# Dancing: stand still
		velocity = Vector2.ZERO

# --- INTERACTION ---
@rpc("any_peer", "call_local")
func start_dance():
	print(name, " forced to dance!")
	forced_dance = true
	is_dancing = true

	if animated_sprite:
		animated_sprite.modulate = Color.YELLOW
		animated_sprite.play("dance")

	velocity = Vector2.ZERO

	if multiplayer.is_server():
		await get_tree().create_timer(3.0).timeout
		end_forced_dance()

func end_forced_dance():
	forced_dance = false
	is_dancing = false
	time_until_change = 0  # Force new decision immediately


# --- DAMAGE & DEATH ---
@rpc("any_peer", "call_local")
func request_damage(attacker_id: int, damage_amount: int = 1, attacker_pos: Vector2 = Vector2.ZERO):
	# Only the server processes NPC damage
	if not multiplayer.is_server():
		return
	die_rpc.rpc()

@rpc("authority", "call_local")
func die_rpc():
	if is_dying:
		return
	is_dying = true
	remove_from_group("npcs")
	$CollisionShape2D.set_deferred("disabled", true)

	if animated_sprite and animated_sprite.sprite_frames:
		var kanim = get_kill_anim()
		if animated_sprite.sprite_frames.has_animation(kanim):
			animated_sprite.play(kanim)
			await animated_sprite.animation_finished

	queue_free()

# --- AI LOGIC (Server Only) ---
func decide_next_move():
	# Toggle between Moving and Dancing
	is_dancing = !is_dancing

	if is_dancing:
		# State: DANCE (Stop moving)
		time_until_change = randf_range(2.0, dance_time)
		move_direction = Vector2.ZERO
		if animated_sprite and animated_sprite.animation != "idle":
			animated_sprite.play("idle")
	else:
		# State: WANDER (Pick a random direction)
		time_until_change = randf_range(1.0, wander_time)
		var angle = randf() * TAU  # TAU is 2*PI (360 degrees)
		move_direction = Vector2(cos(angle), sin(angle))

func get_walk_anim(norm: Vector2) -> String:
	if abs(norm.x) > abs(norm.y):
		return "walk_right" if norm.x > 0 else "walk_left"
	elif norm.y < 0:
		return "walk_back"
	else:
		return "walk_front"

func get_kill_anim() -> String:
	if abs(last_facing.x) > abs(last_facing.y):
		return "kill_right" if last_facing.x > 0 else "kill_left"
	elif last_facing.y < 0:
		return "kill_back"
	else:
		return "kill_front"

# --- NETWORK SYNC ---
func _process(delta):
	if multiplayer.is_server():
		rpc("sync_npc_transform", position)

@rpc("authority", "unreliable")  # "authority" means only server can call this
func sync_npc_transform(pos: Vector2):
	# Clients update their NPC position to match the server
	position = pos
