extends Control

var lobby_menu_template = preload("res://Scenes/lobby_menu/lobby_menu.tscn")
var pop_up_template = preload("res://Scenes/pop_up/pop_up.tscn")
var control_flag : bool = false
var lobby_menu


func _on_play_pressed():
	if get_child_count() > 5:
		return
	if control_flag:
		return

	var user_text = $VBoxContainer/Username.text
	if User.is_server:
		user_text = "Metatron"

	if user_text == "" or user_text.contains(" "):
		var pop_up = pop_up_template.instantiate()
		pop_up.set_msg("You must enter a name!\nSpaces are not allowed!")
		add_child(pop_up)
		return

	else:
		if User.client:
			User.client.queue_free()
		User.client = Client.new()
		get_parent().add_child(User.client)
		control_flag = true
		User.client.user_name_feedback_received.connect(go_to_lobby_menu)
		$Loading.show()
		await get_tree().create_timer(2).timeout

		if User.client.is_connection_valid():
			User.client.send_user_name(user_text)
			lobby_menu = lobby_menu_template.instantiate()


	check_if_connected()

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

func go_to_lobby_menu():
	User.after_main_menu_init()
	$Loading.hide()
	$Connected.show()
	await get_tree().create_timer(1).timeout
	get_parent().add_child(lobby_menu)
	queue_free()

func _on_username_text_submitted(_new_text):
	_on_play_pressed()

func _on_quit_pressed():
	get_tree().quit(0)

# Hack to bypass waiting on input for testing
# Note that you must put a default text in the Main Menu->VBoxContainer->Username->Text field for this to work.
func _ready():
	if not User.is_server:
		await get_tree().create_timer(randi_range(1, 4)).timeout
	_on_play_pressed()
