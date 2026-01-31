extends Node

const KILLS_TO_WIN = 3
var crown_holder_id = -1

func _ready():
	print("GameManager ready")
	
	# Only server manages game state
	if not multiplayer.is_server():
		return
	
	# Spawn crown after players are spawned
	await get_tree().create_timer(2.0).timeout
	spawn_crown()

func spawn_crown():
	if not multiplayer.is_server():
		return
		
	print("Spawning crown...")
	var crown_scene = load("res://prefabs/crown.tscn")
	
	if not crown_scene:
		print("ERROR: Crown scene not found!")
		return
		
	var crown = crown_scene.instantiate()
	crown.position = Vector2(randf_range(-400, 400), randf_range(-300, 300))
	get_parent().add_child(crown)
	print("Crown spawned at ", crown.position)

@rpc("any_peer", "call_local")
func check_win_condition(player_id: int, kills: int):
	if kills >= KILLS_TO_WIN:
		announce_winner.rpc(player_id)

@rpc("any_peer", "call_local")
func announce_winner(player_id: int):
	var network_manager = get_node("/root/NetworkManager")
	var player_name = network_manager.players.get(player_id, "Unknown")
	print(player_name, " WINS!")
	# TODO: Person 5 will show UI here
