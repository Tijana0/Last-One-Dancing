extends Area2D

enum ItemType { POTION, GUN, MASK }
var type = ItemType.POTION

func _ready():
	add_to_group("pickups")
	update_visuals()

func update_visuals():
	queue_redraw()

func _draw():
	if type == ItemType.POTION: # Green Circle
		draw_circle(Vector2.ZERO, 15, Color.GREEN)
	elif type == ItemType.GUN: # Gray/Black Square
		draw_rect(Rect2(-15, -10, 30, 20), Color.DIM_GRAY)
	else: # MASK - Gold Triangle
		var points = PackedVector2Array([Vector2(0, -20), Vector2(20, 15), Vector2(-20, 15)])
		draw_colored_polygon(points, Color.GOLD)
