extends Control

var pop_up_template = preload("res://menus/pop_up/pop_up.tscn")
var control_flag : bool = false
var user_text: String = ""

func _ready():
	if OS.is_debug_build() and User.local_debug_instance_number > 0 and not User.is_server:
		var debug_delay = User.local_debug_instance_number
		while debug_delay > 0:
			$VBoxContainer/Title.text = "Debug delay " + str(debug_delay)
			debug_delay = debug_delay - 1
			await get_tree().create_timer(1).timeout
	User.delete_main_menu.connect(_delete_main_menu)
	User.init_connection()
	#_on_play_pressed()

func _on_play_pressed():
	if control_flag: # Prevents prssing button repeatedly
		return
	user_text = $VBoxContainer/Username.text
	if User.is_server:
		user_text = "Metatron"
	if user_text == "" or user_text.contains(" "):
		var pop_up = pop_up_template.instantiate()
		pop_up.set_msg("You must enter a name.\nSpaces are not allowed.")
		add_child(pop_up)
		return
	else:
		$VBoxContainer/Title.text = "Reaching out into the void..."
		if User.client and is_instance_valid(User.client):
			User.client.queue_free()
		User.client = Client.new()
		get_parent().add_child(User.client)
		control_flag = true
		User.client.client_just_connected.connect(_send_user_name)
		User.client.update_title_message.connect(_update_title_message)
		User.client.overlay_message.connect(_overlay_message)
		User.client.retry_connection.connect(retry_connection)

func _send_user_name():
	$VBoxContainer/Title.text = "2"
	User.client.user_name_feedback_received.connect(start_connetion_listening)
	if User.client.is_connection_valid():
		User.client.send_user_name(user_text, User.is_server, User.server_password)

func start_connetion_listening():
	$VBoxContainer/Title.text = "Stand by, projecting your essence into the void..."
	User.client.lobby_list_received.connect(lobby_list_received)
	User.client.join_lobby.connect(_join_lobby)
	User.client_listener_init()
	if User.server_password != "" and User.is_server:
		User.client.send_server_msg(User.server_password)
	else:
		User.client.request_lobby_list()

func _join_lobby(lobby_name : String):
	User.current_lobby_name = lobby_name
	print("joined lobby %s !" %lobby_name)
	User.client.other_user_joined_lobby.connect(_other_user_joined_lobby)
	User.delete_main_menu.connect(_delete_main_menu)
	User.init_connection()

func lobby_list_received(lobby_list : PackedStringArray):
	for i in lobby_list:
		# Hack to just join the first lobby we receive
		if User.current_lobby_name == "" and not User.is_server:
			# This sends a message to the Websocket server asking to JOIN this lobby.
			User.client.request_join_lobby(i)

func retry_connection():
	var retry_in = 10
	while retry_in > 0:
		$VBoxContainer/Title.text = "Retrying in " + str(retry_in)
		retry_in = retry_in - 1
		await get_tree().create_timer(1).timeout
	User.reset_connection()

func _delete_main_menu():
	queue_free()

func _other_user_joined_lobby():
	if User.is_server:
		User.client.send_game_starting()

func _update_title_message(text):
	$VBoxContainer/Title.text = text

func _overlay_message(text, color, timeout):
	$"Overlay Message/Label".set("text", text)
	$"Overlay Message/Label".set("theme_override_colors/font_color", color)
	$"Overlay Message".show()
	await get_tree().create_timer(timeout).timeout
	$"Overlay Message".hide()

func _on_username_text_submitted(_new_text):
	_on_play_pressed()

func _on_quit_pressed():
	get_tree().quit(0)
