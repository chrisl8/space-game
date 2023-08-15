extends Control

#var lobby_menu_template = preload("res://Scenes/lobby_menu/lobby_menu.tscn")
var pop_up_template = preload("res://Scenes/pop_up/pop_up.tscn")
var control_flag : bool = false
var user_text: String = ""
var lobby_menu

func _ready():
	if OS.is_debug_build() and not User.is_server:
		var debug_delay = randi_range(1, 4)
		while debug_delay > 0:
			$VBoxContainer/Title.text = "Debug delay " + str(debug_delay)
			debug_delay = debug_delay - 1
			await get_tree().create_timer(1).timeout
	_on_play_pressed()

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
		if User.client:
			User.client.queue_free()
		User.client = Client.new()
		get_parent().add_child(User.client)
		control_flag = true
		User.client.client_just_connected.connect(_send_user_name)
		User.client.update_title_message.connect(_update_title_message)
		User.client.overlay_message.connect(_overlay_message)

func _send_user_name():
	$VBoxContainer/Title.text = "2"
	User.client.user_name_feedback_received.connect(go_to_lobby_menu)
	if User.client.is_connection_valid():
		User.client.send_user_name(user_text)

# TODO: What shoudl we do with this?
func check_if_connected():
	await get_tree().create_timer(2).timeout
	if User.client.is_client_connected():
		$Loading.hide()
		return
	else:
		var reason = User.client.websocket_close_reason
		if lobby_menu:
			lobby_menu.queue_free()
		User.client.queue_free()
		User.client = null # So that we do not try to free it again.
		control_flag = false
		$Loading.hide()
		# TODO: Display this message on the menu screen so we can see it
		# rather than it dissearing right away,
		# and so it works better with long messages.
		if (reason != ""):
			$"Cannot Connect/Label".text = reason
		$"Cannot Connect".show()
		await get_tree().create_timer(1).timeout
		$"Cannot Connect".hide()
		$"Cannot Connect/Label".text = "Failed to Connect!.."
	$Loading.hide()

# Change function name
func go_to_lobby_menu():
	$VBoxContainer/Title.text = "Stand by, projecting your essence into the void..."
#	lobby_menu = lobby_menu_template.instantiate()
	User.after_main_menu_init()
	#$Loading.hide()
	#$Connected.show()
#	await get_tree().create_timer(1).timeout
#	get_parent().add_child(lobby_menu)
#	queue_free()
	User.client.lobby_list_received.connect(lobby_list_received)
	User.client.join_lobby.connect(_join_lobby)
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
