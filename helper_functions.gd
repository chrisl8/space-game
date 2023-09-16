extends Node


func log_print(text) -> void:
	if Globals.is_server or OS.is_debug_build():
		print(Globals.local_debug_instance_number, " ", Globals.player_id, " ", text)


func generate_random_string(length) -> String:
	var characters: String = "abcdefghijklmnopqrstuvwxyz0123456789"
	var word: String = ""
	var n_char: int = len(characters)
	for i in range(length):
		word += characters[randi() % n_char]
	return word
