extends Node3D


func _ready() -> void:
	# Play our scene soundtrack, but only once, in case we restarted or something
	if not Globals.is_server and not Globals.intro_music_has_played:
		Globals.intro_music_has_played = true
		$AudioStreamPlayer.play()
	display_how_to_quit_toast()
	print(Globals.player_save_data.size())


func display_how_to_quit_toast() -> void:
	# Tell player how to exit the game. Alt+F4 works too of course
	if OS.get_name() != "Web":
		await get_tree().create_timer(5).timeout
		var toast: Toast = Toast.new(Globals.how_to_end_game_text, 2.0)
		get_node("/root").add_child(toast)
		toast.show()


func set_room_01_screen_text(text: String) -> void:
	get_node("Room 01").get_node("Screen Text").text = text
