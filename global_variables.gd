extends Node

var server_config: Dictionary = {}
var server_player_save_data_file_name: String = "user://server_player_data.dat"
var player_save_data: Dictionary = {}
var is_server: bool = false
var user_name: String = ""
var local_debug_instance_number: int = -1
var intro_music_has_played: bool = false
var url: String
