extends Node

@export var run_server_in_debug: bool = true
@export var debug_server_url: String = "ws://127.0.0.1:9090"
@export var production_server_url: String = "wss://voidshipephemeral.space/server/"

@export var capture_mouse_on_startup: bool = false  # This is actually annoying so I never turn it on.

var pop_up_template: Resource = preload("res://menus/pop_up/pop_up.tscn")

var pop_up: Node

# If you want to try running with WebRTC instead of WebSocket:
# 1. Change this variable:
var network_type: String = "WebSocket"  # WebSocket or WebRTC
# 2. Change this line in project.godot:
#Network="*res://network_websocket.gd"
# to
#Network="*res://network_webrtc.gd"
# 4. Download the WebRTC Native Plugin from https://github.com/godotengine/webrtc-native
#    and put the webrtc folder it generates in the root of this godot code folder.

# This has to be here so that it isn't removed after _init() runs,
# which will cause all instances to look like 0.
var _instance_socket: TCPServer


func _init():
	if OS.is_debug_build() and run_server_in_debug:
		Globals.url = debug_server_url
	else:
		Globals.url = production_server_url
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
			var arg_array = arg.split("=")
			if arg_array[0] == "server":
				print("Setting as server based on command line argument.")
				Globals.is_server = true


func _notification(what):
	# This catches the quit command and acts on it,
	# since we negated it in the _ready() function.
	# https://docs.godotengine.org/en/stable/tutorials/inputs/handling_quit_requests.html
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Helpers.quit_gracefully()


func _ready():
	force_open_popup()
	pop_up.set_msg("Booting Universe...")

	# Disable auto-quit so that we can catch it ourselves elsewhere
	# Note that this alone will defeat Windows X or Alt+F4
	# See helper_functions.gd quit_gracefully()
	# https://docs.godotengine.org/en/stable/tutorials/inputs/handling_quit_requests.html
	get_tree().set_auto_accept_quit(false)

	if capture_mouse_on_startup and not Globals.is_server:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if OS.is_debug_build() and OS.get_name() != "Web":
		Globals.release_mouse_text = "F1 to Release Mouse"
		Globals.how_to_end_game_text = "ESC to Close Game"

	Network.reset.connect(connection_reset)
	Network.close_popup.connect(force_close_popup)
	if (
		OS.is_debug_build()
		and run_server_in_debug
		and Globals.local_debug_instance_number < 1
		and OS.get_name() != "Web"
	):
		print(
			"Setting as server based being a debug build and run_server_in_debug and being first instance to run."
		)
		Globals.is_server = true

	if network_type == "WebRTC" and Globals.is_server:
		SignalingServer.start()

	if Globals.is_server:
		# Load or generate server config data
		var server_config_file_name: String = "user://server_config.dat"
		var server_config: Dictionary = {}
		var server_config_file_data: String = Helpers.load_data_from_file(server_config_file_name)
		if server_config_file_data == "":
			Helpers.log_print("Generating new config data for server")
			var jwt_secret: String = Helpers.generate_random_string(64)
			server_config["jwt_secret"] = jwt_secret
		else:
			var json: JSON = JSON.new()
			var error = json.parse(server_config_file_data)
			if error != OK:
				print(
					"JSON Parse Error: ",
					json.get_error_message(),
					" in ",
					server_config_file_data,
					" at line ",
					json.get_error_line()
				)
				get_tree().quit()  # Quits the game due to bad server config data

			server_config = json.data
			if typeof(server_config) != TYPE_DICTIONARY or not server_config.has("jwt_secret"):
				print("Data error in: ", server_config)
				get_tree().quit()  # Quits the game due to bad server config data

		Globals.server_config = server_config

		# Save config back out to file, even if we imported it from the file.
		Helpers.save_data_to_file(server_config_file_name, JSON.stringify(Globals.server_config))

		# Load or generate player data
		print("----------------------")
		var player_save_data: Dictionary = {}
		var player_save_data_file_data: String = Helpers.load_data_from_file(
			Globals.server_player_save_data_file_name
		)
		if player_save_data_file_data == "":
			Helpers.log_print("Generating new player save data file for server")
		else:
			var json: JSON = JSON.new()
			var error = json.parse(player_save_data_file_data)
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
				print("Data error in: ", server_config)
				get_tree().quit()  # Quits the game due to bad server config data
		Globals.player_save_data = player_save_data
		# Save config back out to file, even if we imported it from the file.
		Helpers.save_server_player_save_data_to_file()

	start_connection()


func start_connection():
	force_open_popup()
	if OS.is_debug_build() and Globals.local_debug_instance_number > 0 and not Globals.is_server:
		var debug_delay: int = Globals.local_debug_instance_number
		while debug_delay > 0:
			pop_up.set_msg("Debug delay " + str(debug_delay))
			debug_delay = debug_delay - 1
			await get_tree().create_timer(1).timeout
	pop_up.set_msg("Connecting...")
	Network.ready_to_connect = true


func connection_reset(delay):
	force_open_popup()
	pop_up.set_msg(
		Globals.connection_failed_message,
		Color(0.79215687513351, 0.26274511218071, 0.56470590829849)
	)
	if OS.is_debug_build() and OS.get_name() != "Web":
		# Exit when the server closes in debug mode
		# except in web mode, where "exit" has no meaning.
		Helpers.log_print("Closing due to server disconnecting and this running in Debug mode.")
		Helpers.quit_gracefully()

	var game_scene_node: Node = get_node_or_null("../Main/game_scene")
	if game_scene_node and is_instance_valid(game_scene_node):
		game_scene_node.queue_free()

	await get_tree().create_timer(3).timeout
	var retry_delay = delay
	while retry_delay > 0:
		pop_up.set_msg("Retrying in " + str(retry_delay))
		retry_delay = retry_delay - 1
		await get_tree().create_timer(1).timeout
	pop_up.set_msg("Connecting...")
	start_connection()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		if OS.is_debug_build():
			# ESC key closes game in debug mode
			Helpers.log_print("Closing due to ESC key.")
			Helpers.quit_gracefully()
		else:  # Releases mouse in normal build
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event.is_action_pressed(&"ui_end"):
		# END key closes the game
		Helpers.log_print("Closing due to END key.")
		Helpers.quit_gracefully()

	# Only in Debug Mode: Use F1 to both Release and Capture the mouse for testing
	if (
		not Globals.is_server
		and event.is_action_pressed(&"change_mouse_input")
		and OS.is_debug_build()
	):
		match Input.get_mouse_mode():
			Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			Input.MOUSE_MODE_VISIBLE:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if event.is_action_pressed(&"dump_tree"):
		print(multiplayer.get_unique_id())
		get_tree().root.print_tree_pretty()
	if event.is_action_pressed(&"click_mode"):
		Globals.click_mode = !Globals.click_mode
		Helpers.log_print(str("click_mode = ", Globals.click_mode))


# Capture mouse if clicked on the game
# Called when an InputEvent hasn't been consumed by _input() or any GUI item
func _unhandled_input(event: InputEvent) -> void:
	if not Globals.is_server and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not Globals.click_mode:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			await get_tree().create_timer(0.5).timeout
			#print("Mouse Mode: ", Input.get_mouse_mode())
			var text_to_toast: String = Globals.release_mouse_text
			if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
				# Browsers have a cool down on capturing the mouse.
				# https://discourse.threejs.org/t/how-to-avoid-pointerlockcontrols-error/33017/4
				# So users may click, Esc, and then Click again too fast and it does not capture the mouse
				# This will let the user know that happened
				text_to_toast = "Oops, too fast, try again"
			var toast = Toast.new(text_to_toast, 2.0)
			get_node("/root").add_child(toast)
			toast.show()


func force_open_popup():
	if not pop_up:
		pop_up = pop_up_template.instantiate()
		add_child(pop_up)


func force_close_popup():
	if pop_up and is_instance_valid(pop_up):
		pop_up.queue_free()
		pop_up = null


func _on_players_spawner_spawned(node: Node) -> void:
	Helpers.log_print(str("_on_players_spawner_spawned ", node.name))
	node.set_multiplayer_authority(str(node.name).to_int())
