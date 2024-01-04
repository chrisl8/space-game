extends Node

@export var run_server_in_debug: bool = true
@export var debug_server_url: String = "ws://127.0.0.1:9090"
@export var production_server_url: String = "wss://voidshipephemeral.space/server/"

@export var capture_mouse_on_startup: bool = false  # This is actually annoying so I never turn it on.

var pop_up_template: Resource = preload("res://menus/pop_up/pop_up.tscn")

var pop_up: Node

var server_config_file_name: String = "user://server_config.dat"

# This has to be here so that it isn't removed after _init() runs,
# which will cause all instances to look like 0.
var _instance_socket: TCPServer


func _init() -> void:
	if OS.is_debug_build():
		# Check if this is the first instance of a debug run, so only one attempts to be the server
		# It also provides us with a unique "instance number" for each debug instance of the game run by the editor
		# https://gist.github.com/CrankyBunny/71316e7af809d7d4cf5ec6e2369a30b9
		_instance_socket = TCPServer.new()
		for n in range(0, 4):  # Godot Editor only creates up to 4 instances maximum.
			if _instance_socket.listen(5000 + n) == OK:
				Globals.local_debug_instance_number = n
				break
		# if Globals.local_debug_instance_number < 0:
		# 	print("Unable to determine instance number. Seems like all TCP ports are in use")
		# else:
		# 	print("We are instance number ", Globals.local_debug_instance_number)

	if OS.get_cmdline_user_args().size() > 0:
		for arg in OS.get_cmdline_user_args():
			var arg_array: Array = arg.split("=")
			if arg_array[0] == "server":
				print_rich("[color=green]Setting as server based on command line argument.[/color]")
				Globals.is_server = true
			if arg_array[0] == "client":
				print_rich(
					"[color=green]Forcing to be client based on command line argument.[/color]"
				)
				Globals.is_server = false
				Globals.force_client = true
			if arg_array[0] == "shutdown_server":
				print_rich("[color=green]This client will tell the server to shut down.[/color]")
				Globals.is_server = false
				Globals.shutdown_server = true
				# Load server password from local data file
				var server_config_file_data: String = Helpers.load_data_from_file(
					server_config_file_name
				)
				Globals.server_config = parse_server_config_file_data(server_config_file_data)


func _notification(what: int) -> void:
	# This catches the quit command and acts on it,
	# since we negated it in the _ready() function.
	# https://docs.godotengine.org/en/stable/tutorials/inputs/handling_quit_requests.html
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Helpers.quit_gracefully()


func generate_server_config_data() -> Dictionary:
	var server_config: Dictionary = {}
	Helpers.log_print("Generating new config data for server", "green")
	var jwt_secret: String = Helpers.generate_random_string(64)
	server_config["jwt_secret"] = jwt_secret
	var server_password: String = Helpers.generate_random_string(64)
	server_config["server_password"] = server_password
	return server_config


func parse_server_config_file_data(server_config_file_data: String) -> Dictionary:
	var server_config: Dictionary = {}
	var json: JSON = JSON.new()
	var error: int = json.parse(server_config_file_data)
	if error != OK:
		printerr(
			"JSON Parse Error: ",
			json.get_error_message(),
			" in ",
			server_config_file_data,
			" at line ",
			json.get_error_line()
		)
		get_tree().quit()  # Quits the game due to bad server config data

	server_config = json.data
	if (
		typeof(server_config) != TYPE_DICTIONARY
		or not server_config.has("jwt_secret")
		or not server_config.has("server_password")
	):
		server_config = generate_server_config_data()
	return server_config


func _ready() -> void:
	force_open_popup()
	pop_up.set_msg("Booting Universe...")

	# Disable auto-quit so that we can catch it ourselves elsewhere
	# Note that this alone will defeat Windows X or Alt+F4
	# See helper_functions.gd quit_gracefully()
	# https://docs.godotengine.org/en/stable/tutorials/inputs/handling_quit_requests.html
	get_tree().set_auto_accept_quit(false)

	if OS.is_debug_build() and run_server_in_debug:
		Globals.url = debug_server_url
	else:
		Globals.url = production_server_url

	Network.reset.connect(connection_reset)
	Network.close_popup.connect(force_close_popup)
	if (
		!Globals.force_client
		and OS.is_debug_build()
		and run_server_in_debug
		and Globals.local_debug_instance_number < 1
		and OS.get_name() != "Web"
	):
		print_rich(
			"[color=green]Setting as server based being a debug build and run_server_in_debug and being first instance to run.[/color]"
		)
		Globals.is_server = true

	if Globals.is_server:
		# Load or generate server config data
		var server_config: Dictionary = {}
		var server_config_file_data: String = Helpers.load_data_from_file(server_config_file_name)
		if server_config_file_data == "":
			server_config = generate_server_config_data()
		else:
			server_config = parse_server_config_file_data(server_config_file_data)
		Globals.server_config = server_config

		# Save config back out to file, even if we imported it from the file.
		Helpers.save_data_to_file(server_config_file_name, JSON.stringify(Globals.server_config))

		# Load or generate player data
		var player_save_data: Dictionary = {}
		var player_save_data_file_data: String = Helpers.load_data_from_file(
			Globals.server_player_save_data_file_name
		)
		if player_save_data_file_data == "":
			Helpers.log_print("Generating new player save data file for server", "green")
		else:
			var json: JSON = JSON.new()
			var error: int = json.parse(player_save_data_file_data)
			if error != OK:
				print(
					"JSON Parse Error: ",
					json.get_error_message(),
					" in ",
					player_save_data_file_data,
					" at line ",
					json.get_error_line()
				)
				get_tree().quit()  # Quits the game due to bad server config data
			player_save_data = json.data
			if typeof(player_save_data) != TYPE_DICTIONARY:
				printerr("Data error in: ", server_config)
				get_tree().quit()  # Quits the game due to bad server config data
		Globals.player_save_data = player_save_data
		# Save config back out to file, even if we imported it from the file.
		Helpers.save_server_player_save_data_to_file()

	if capture_mouse_on_startup and not Globals.is_server:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if OS.is_debug_build() and OS.get_name() != "Web":
		Globals.release_mouse_text = "F1 to Release Mouse"
		if Globals.is_server:
			Globals.how_to_end_game_text = "This is the server window. You cannot interact with it.\nYou must run at least 2 game instances to play.\nPress ESC to close Server and all Clients."
		else:
			Globals.how_to_end_game_text = "ESC to Close this Client"

	start_connection()


func start_connection() -> void:
	force_open_popup()
	if OS.is_debug_build() and Globals.local_debug_instance_number > 0 and not Globals.is_server:
		var debug_delay: int = Globals.local_debug_instance_number
		while debug_delay > 0:
			pop_up.set_msg("Debug delay " + str(debug_delay))
			debug_delay = debug_delay - 1
			await get_tree().create_timer(1).timeout
	pop_up.set_msg("Connecting...")
	Network.ready_to_connect = true


func connection_reset(delay: int) -> void:
	force_open_popup()
	pop_up.set_msg(
		Globals.connection_failed_message,
		Color(0.79215687513351, 0.26274511218071, 0.56470590829849)
	)
	if OS.is_debug_build() and OS.get_name() != "Web":
		# Exit when the server closes in debug mode
		# except in web mode, where "exit" has no meaning.
		Helpers.log_print(
			"Closing due to server disconnecting and this running in Debug mode.", "green"
		)
		Helpers.quit_gracefully()

	var game_scene_node: Node = get_node_or_null("../Main/game_scene")
	if game_scene_node and is_instance_valid(game_scene_node):
		game_scene_node.queue_free()

	await get_tree().create_timer(3).timeout
	var retry_delay: int = delay
	while retry_delay > 0:
		pop_up.set_msg("Retrying in " + str(retry_delay))
		retry_delay = retry_delay - 1
		await get_tree().create_timer(1).timeout
	if OS.get_name() == "Web":
		# Force browser refresh in case there are updates to the game code to download
		JavaScriptBridge.eval("location.reload();")
	start_connection()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		if OS.is_debug_build():
			# ESC key closes game in debug mode
			Helpers.log_print("Closing due to ESC key.", "green")
			Helpers.quit_gracefully()
		else:  # Releases mouse in normal build
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event.is_action_pressed(&"ui_end"):
		# END key closes the game
		Helpers.log_print("Closing due to END key.", "green")
		Helpers.quit_gracefully()


func force_open_popup() -> void:
	if not pop_up:
		pop_up = pop_up_template.instantiate()
		add_child(pop_up)


func force_close_popup() -> void:
	if pop_up and is_instance_valid(pop_up):
		pop_up.queue_free()
		pop_up = null


func _on_players_spawner_spawned(node: Node) -> void:
	Helpers.log_print(str("_on_players_spawner_spawned ", node.name), "green")
	node.set_multiplayer_authority(str(node.name).to_int())


# Called when an InputEvent has not been consumed by _input() or any GUI item
func _unhandled_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
		and Globals.my_camera
	):
		var text_to_toast: String = Globals.how_to_end_game_text
		var text_duration: float = 2.0
		if Globals.is_server:
			text_duration = 10.0
		if text_to_toast != "" and text_to_toast != Globals.last_toast:
			# Set it to an empty string to signal that we don't want to display anything this time.
			Globals.last_toast = text_to_toast
			var toast: Toast = Toast.new(text_to_toast, text_duration)
			Globals.my_camera.add_child(toast)
			toast.display()
