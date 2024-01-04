extends Node


func log_print(text: String, color: String = "white") -> void:
	if Globals.is_server or OS.is_debug_build():
		var unique_id: int = -1
		if multiplayer.has_multiplayer_peer():
			unique_id = multiplayer.get_unique_id()
		print_rich(
			"[color=",
			color,
			"]",
			Globals.local_debug_instance_number,
			" ",
			unique_id,
			" ",
			text,
			"[/color]"
		)


func generate_random_string(length: int) -> String:
	var crypto: Crypto = Crypto.new()
	var random_bytes: PackedByteArray = crypto.generate_random_bytes(length)

	var characters: String = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_"
	var word: String = ""

	# Use randi()
	# for i in range(length):
	# 	word += characters[randi() % len(characters)]

	# Use crypto
	var cursor: int = 0
	for byte: int in random_bytes:
		cursor += byte
		word += characters[cursor % len(characters)]
	return word


func save_data_to_file(file_name: String, content: String) -> void:
	var file: FileAccess = FileAccess.open(file_name, FileAccess.WRITE)
	file.store_string(content)


func load_data_from_file(file_name: String) -> String:
	var content: String = ""
	var file: FileAccess = FileAccess.open(file_name, FileAccess.READ)
	if file:
		content = file.get_as_text()
	return content


func save_server_player_save_data_to_file() -> void:
	# Save config back out to file, even if we imported it from the file.
	save_data_to_file(
		Globals.server_player_save_data_file_name, JSON.stringify(Globals.player_save_data)
	)


func parse_thing_name(node_name: String) -> Dictionary:
	var parsed_thing_name: Dictionary = {}
	# Use the given Node name to determine the thing name and ID
	var split_node_name: PackedStringArray = node_name.split("-")
	if not split_node_name or split_node_name.size() != 2:
		printerr("Invalid thing grabbed: ", node_name)
		return parsed_thing_name
	parsed_thing_name.name = split_node_name[0]
	parsed_thing_name.id = int(split_node_name[1])
	return parsed_thing_name


func quit_gracefully() -> void:
	# Quitting in Web just stops the game but leaves it stalled in the browser window, so it really should never happen.
	if !Globals.shutdown_in_progress and OS.get_name() != "Web":
		Globals.shutdown_in_progress = true
		if Globals.is_server:
			print_rich(
				"[color=orange]Disconnecting clients and saving data before shutting down server...[/color]"
			)
			if Globals.my_camera:
				var toast: Toast = Toast.new("Disconnecting clients and shutting down server...", 2.0)
				Globals.my_camera.add_child(toast)
				toast.display()
			Network.shutdown_server()
			while Network.peers.size() > 0:
				print_rich("[color=orange]...server still clearing clients...[/color]")
				await get_tree().create_timer(1).timeout
		get_tree().quit()
