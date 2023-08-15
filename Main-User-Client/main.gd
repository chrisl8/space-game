extends Node

@export var run_server_in_debug := false
@export var server_password := ""
var local_server_password := ""

var pop_up_template = preload("res://menus/pop_up/pop_up.tscn")
var main_menu = preload("res://menus/main menu/main_menu.tscn")

# Check if this is the first instance of a debug run, so only one attempts to be the server
# https://gist.github.com/CrankyBunny/71316e7af809d7d4cf5ec6e2369a30b9
var _instance_num := -1
var _instance_socket: TCPServer

func _init():
	# Check if this is the first instance of a debug run, so only one attempts to be the server
	# https://gist.github.com/CrankyBunny/71316e7af809d7d4cf5ec6e2369a30b9
	if OS.is_debug_build():
		_instance_socket = TCPServer.new()
		for n in range(0,4):
			if _instance_socket.listen(5000 + n) == OK:
				_instance_num = n
				break
		if _instance_num < 0:
			print("Unable to determine instance number. Seems like all TCP ports are in use")
		else:
			print("We are instance number ", _instance_num)

	# https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_dedicated_servers.html
	if OS.has_feature("server"):
		print("Setting as server instance due to being run headless.")
		User.is_server = true

	if OS.get_cmdline_user_args().size() > 0:
		for arg in OS.get_cmdline_user_args():
			var arg_array = arg.split("=")
			if arg_array[0] == "password":
				print("Setting server password from command line.")
				local_server_password = arg_array[1]
			if arg_array[0] == "server":
				print("Setting as server based on command line argument.")
				User.is_server = true

func _ready():
	if local_server_password == "":
		local_server_password = server_password
	User.server_password = local_server_password
	if OS.is_debug_build() and run_server_in_debug and _instance_num < 1:
		print("Setting as server based on run_server_in_debug and being first insatnce to run.")
		User.is_server = true
	add_child(main_menu.instantiate())
	User.reset.connect(connection_reset)

func _process(_delta):
	pass

func connection_reset():
	for i in get_children():
		i.queue_free()

	add_child(main_menu.instantiate())

	var pop_up = pop_up_template.instantiate()
	pop_up.set_msg("Connection Interrupted!", Color(0.79215687513351, 0.26274511218071, 0.56470590829849))
	add_child(pop_up)
	await get_tree().create_timer(3).timeout
	if is_instance_valid(pop_up):
		pop_up.queue_free()
