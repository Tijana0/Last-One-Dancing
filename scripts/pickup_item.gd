extends Area2D

enum ItemType { POTION, GUN, MASK }
var type = ItemType.POTION

@onready var sprite = $Sprite2D

# Preload textures
const TEX_POTION = preload("res://assets/Potion.PNG")
const TEX_GUN = preload("res://assets/gun.PNG")
const TEX_MASK = preload("res://assets/gold_mask.png")

func _ready():
	add_to_group("pickups")
	update_visuals()

func update_visuals():
	if not sprite: return
	
	if type == ItemType.POTION:
		sprite.texture = TEX_POTION
		sprite.scale = Vector2(0.12, 0.12)
	elif type == ItemType.GUN:
		sprite.texture = TEX_GUN
		sprite.scale = Vector2(0.12, 0.12)
	else:
		sprite.texture = TEX_MASK
		sprite.scale = Vector2(0.25, 0.25)

# Removed _draw() as we use sprites now
