extends Area2D

enum ItemType { TRIANGLE, CIRCLE, SQUARE }
var type = ItemType.TRIANGLE

func _ready():
	add_to_group("pickups")
	
	# Randomize type if not set
	type = ItemType.values().pick_random()
	update_visuals()

func update_visuals():
	queue_redraw()

func _draw():
	var color = Color.CYAN
	if type == ItemType.CIRCLE:
		draw_circle(Vector2.ZERO, 15, Color.MAGENTA)
	elif type == ItemType.SQUARE:
		draw_rect(Rect2(-15, -15, 30, 30), Color.GREEN)
	else: # TRIANGLE
		var points = PackedVector2Array([Vector2(0, -20), Vector2(20, 15), Vector2(-20, 15)])
		draw_colored_polygon(points, Color.CYAN)
