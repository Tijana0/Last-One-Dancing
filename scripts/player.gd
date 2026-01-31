extends CharacterBody2D

@export var speed = 300.0

func _physics_process(delta):
	# Get input direction
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# Set velocity
	velocity = direction * speed
	
	# Move
	move_and_slide()
