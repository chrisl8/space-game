extends Control

var in_lobby_menu_template = preload("res://Scenes/in_lobby_menu/in_lobby_menu.tscn")

func _init():
	User.client.lobby_list_received.connect(lobby_list_received)
	User.client.join_lobby.connect(_join_lobby)

## Hack to force a refresh of lobby list soon after joining
func _ready():
	# TODO: This is where we should either try to be the server
	if User.server_password != "" and User.is_server:
		User.client.send_server_msg(User.server_password)
	else:
		User.client.request_lobby_list()

func _join_lobby(lobby_name : String):
	User.current_lobby_name = lobby_name
	print("joined lobby %s !" %lobby_name)
	get_parent().add_child(in_lobby_menu_template.instantiate())
	queue_free()

func lobby_list_received(lobby_list : PackedStringArray):
	for i in lobby_list:
		# Hack to just join the first lobby we receive
		if User.current_lobby_name == "" and not User.is_server:
			# This sends a message to the Websocket server asking to JOIN this lobby.
			User.client.request_join_lobby(i)
