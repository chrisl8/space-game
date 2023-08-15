extends Control

func _init():
	User.client.lobby_list_received.connect(lobby_list_received)
	User.client.join_lobby.connect(_join_lobby)

func _ready():
	if User.server_password != "" and User.is_server:
		User.client.send_server_msg(User.server_password)
	else:
		User.client.request_lobby_list()

func _join_lobby(lobby_name : String):
	User.current_lobby_name = lobby_name
	print("joined lobby %s !" %lobby_name)
	User.client.other_user_joined_lobby.connect(_other_user_joined_lobby)
	User.delete_in_lobby_menu.connect(_delete_in_lobby_menu)
	User.init_connection()

func lobby_list_received(lobby_list : PackedStringArray):
	for i in lobby_list:
		# Hack to just join the first lobby we receive
		if User.current_lobby_name == "" and not User.is_server:
			# This sends a message to the Websocket server asking to JOIN this lobby.
			User.client.request_join_lobby(i)

func _delete_in_lobby_menu():
	queue_free()

func _other_user_joined_lobby():
	if User.is_server:
		User.client.send_game_starting()
