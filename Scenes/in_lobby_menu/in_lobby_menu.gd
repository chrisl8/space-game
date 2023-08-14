extends Control

var pop_up_template = preload("res://Scenes/pop_up/pop_up.tscn")

func _ready():
	User.client.other_user_joined_lobby.connect(_other_user_joined_lobby)
	User.delete_in_lobby_menu.connect(_delete_in_lobby_menu)
	User.init_connection()

func _delete_in_lobby_menu():
	queue_free()

func _other_user_joined_lobby(username : String):
	# Moved to Client so it runs even after game starts.
	#User.init_connection()

	# Hack to start game when lobby has people in it
	if User.is_server:
		User.client.send_game_starting()
