extends Node

const KILLS_TO_WIN = 3
var crown_holder_id = -1

func _ready():
	# Only server manages game state
	if not multiplayer.is_server():
		return
	
	# Spawn crown after 2 seconds
	await get_tree().create_timer(2.0).timeout
	spawn_crown()

func spawn_crown():
	var crown_scene = load("res://prefabs/crown.tscn")
	var crown = crown_scene.instantiate()
	crown.position = Vector2(randf_range(-400, 400), randf_range(-300, 300))
	get_parent().add_child(crown)

@rpc("any_peer", "call_local")
func check_win_condition(player_id: int, kills: int):
	if kills >= KILLS_TO_WIN:
		announce_winner.rpc(player_id)

@rpc("any_peer", "call_local")
func announce_winner(player_id: int):
	var player_name = NetworkManager.players.get(player_id, "Unknown")
	print(player_name, " WINS!")
	# Pe
