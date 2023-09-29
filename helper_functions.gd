extends Node


func log_print(text) -> void:
	if Globals.is_server or OS.is_debug_build():
		print(Globals.local_debug_instance_number, " ", multiplayer.get_unique_id(), " ", text)


func generate_random_string(length) -> String:
	var characters: String = "abcdefghijklmnopqrstuvwxyz0123456789"
	var word: String = ""
	var n_char: int = len(characters)
	for i in range(length):
		word += characters[randi() % n_char]
	return word


func save_data_to_file(file_name: String, content: String):
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
