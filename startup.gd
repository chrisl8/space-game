extends Node

@export var run_server_in_debug := false

var pop_up_template := preload("res://menus/pop_up/pop_up.tscn")

var pop_up: Node

# Check if this is the first instance of a debug run, so only one attempts to be the server
# https://gist.github.com/CrankyBunny/71316e7af809d7d4cf5ec6e2369a30b9
var _instance_socket: TCPServer


func _init():
	# Check if this is the first instance of a debug run, so only one attempts to be the server
	# https://gist.github.com/CrankyBunny/71316e7af809d7d4cf5ec6e2369a30b9
	if OS.is_debug_build():
		_instance_socket = TCPServer.new()
		for n in range(0, 4):
			if _instance_socket.listen(5000 + n) == OK:
				User.local_debug_instance_number = n
				break
		if User.local_debug_instance_number < 0:
			print("Unable to determine instance number. Seems like all TCP ports are in use")
		else:
			print("We are instance number ", User.local_debug_instance_number)

	if OS.get_cmdline_user_args().size() > 0:
		for arg in OS.get_cmdline_user_args():
			var arg_array = arg.split("=")
			if arg_array[0] == "server":
				print("Setting as server based on command line argument.")
				User.is_server = true


func _ready():
	User.reset.connect(connection_reset)
	User.close_popup.connect(force_close_popup)
	if OS.is_debug_build() and run_server_in_debug and User.local_debug_instance_number < 1:
		print("Setting as server based on run_server_in_debug and being first insatnce to run.")
		User.is_server = true

	if User.is_server:
		SignalingServer.start()

	force_close_popup()
	pop_up = pop_up_template.instantiate()
	pop_up.set_msg("Welcome!", Color(0, 0, 1))
	add_child(pop_up)  # add_child(main_menu.instantiate())
	start_connection()


func start_connection():
	force_close_popup()
	pop_up = pop_up_template.instantiate()
	add_child(pop_up)
	if OS.is_debug_build() and User.local_debug_instance_number > 0 and not User.is_server:
		var debug_delay = User.local_debug_instance_number
		while debug_delay > 0:
			pop_up.set_msg("Debug delay " + str(debug_delay))
			debug_delay = debug_delay - 1
			await get_tree().create_timer(1).timeout
	pop_up.set_msg("Connecting...")
	User.ready_to_connect = true


func connection_reset(delay):
#	for i in get_children():
#		i.queue_free()
	var game_scene_node := get_node_or_null("../Main/game_scene")
	if game_scene_node and is_instance_valid(game_scene_node):
		game_scene_node.queue_free()

	force_close_popup()
	pop_up = pop_up_template.instantiate()
	pop_up.set_msg(
		"Connection Interrupted!", Color(0.79215687513351, 0.26274511218071, 0.56470590829849)
	)
	add_child(pop_up)
	await get_tree().create_timer(3).timeout
	var retry_delay = delay
	while retry_delay > 0:
		pop_up.set_msg("Retrying in " + str(retry_delay))
		retry_delay = retry_delay - 1
		await get_tree().create_timer(1).timeout
	pop_up.set_msg("Connecting...")
	start_connection()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"dump_tree"):
		print(multiplayer.get_unique_id())
		get_tree().root.print_tree_pretty()


func force_close_popup():
	if pop_up and is_instance_valid(pop_up):
		pop_up.queue_free()
		pop_up = null
