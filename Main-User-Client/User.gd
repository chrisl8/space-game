extends Node

# Check if this is the first instance of a debug run, so only one attempts to be the server
# https://gist.github.com/CrankyBunny/71316e7af809d7d4cf5ec6e2369a30b9
var instance_num               := -1
var client: Client
var user_name: String          =  ""
var host_name: String          =  ""
var current_lobby_name: String =  ""
var current_lobby_list: String =  ""
var is_host: bool              =  false
var ID                         :=  -1
var peers: Dictionary
var peer_count := -1
var game_scene_initialized: bool = false
var game_scene_template        :=  preload("res://spaceship.tscn")
var player_character_template  :=  preload("res://player/player.tscn")
var is_server: bool            =  false
var server_name: String = ""
var server_id := -1
var server_password: String    =  ""
var local_debug_instance_number := -1
# TODO: I THINK is_host and is_server is the same, and one is better direved than the other, so replace it, and also do that in other places?

var connection_list: Dictionary = {}
var rtc_peer: WebRTCMultiplayerPeer
signal reset
signal delete_main_menu


func _process(_delta):
	if peers.size() != peer_count:
		peer_count = peers.size()
		print("New peer count is: ", peer_count)

	if peer_count > 0 and game_scene_initialized:
		spawn_things()


func client_listener_init():
	client.offer_received.connect(_offer_received)
	client.answer_received.connect(_answer_received)
	client.ice_received.connect(_ice_received)
	client.reset_connection.connect(reset_connection)
	client.game_start_received.connect(_game_start_received)


func init_connection():
	rtc_peer = WebRTCMultiplayerPeer.new()
	rtc_peer.create_mesh(ID)
	print("WebRTCMultiplayerPeer mesh id ", ID)

	connection_list.clear()

	for peer_id in peers.keys():
		var connection = WebRTCPeerConnection.new()
		connection.initialize({"iceServers": [ { "urls": ["stun:stun.l.google.com:19302"]}]})
		connection.session_description_created.connect(session_created.bind(connection))
		connection.ice_candidate_created.connect(ice_created.bind(connection))
		connection_list[peer_id] = connection
		rtc_peer.add_peer(connection, peer_id)

	for peer_id in peers.keys():
		print("PEER LIST: Name: %s with ID# %d" %[peers.get(peer_id), peer_id])

	rtc_peer.peer_connected.connect(_peer_connected)
	rtc_peer.peer_disconnected.connect(_peer_disconnected)
	get_tree().get_multiplayer().multiplayer_peer = rtc_peer


func session_created(type: String, sdp: String, connection):
	connection.set_local_description(type, sdp)
	if type == "offer":
		client.send_offer(type, sdp, connection_list.find_key(connection))
	else:
		client.send_answer(type, sdp, connection_list.find_key(connection))


func ice_created(media: String, index: int, _name: String, connection):
	client.send_ice(media, index, _name, connection_list.find_key(connection))


func _ice_received(media: String, index: int, _name: String, sender_id):
	connection_list.get(sender_id).add_ice_candidate(media, index, _name)


func _offer_received(type: String, sdp: String, sender_id):
	connection_list.get(sender_id).set_remote_description(type, sdp)


func _answer_received(type: String, sdp: String, sender_id):
	connection_list.get(sender_id).set_remote_description(type, sdp)


func _peer_connected(peer_id: int):
	delete_main_menu.emit()

	var game_scene_node = get_node_or_null("../game_scene")
	if not game_scene_node:
		var game_scene = game_scene_template.instantiate()
		game_scene.set_multiplayer_authority(User.ID)
		game_scene.name = "game_scene"
		get_parent().add_child(game_scene)

	game_scene_node = get_node("../game_scene")

	if not User.is_server:
		# Add ME if I don't exist already
		var my_player = game_scene_node.get_node_or_null("%s" %ID)
		# (Note case of ID variable.)
		if not my_player:
			var player_character = player_character_template.instantiate()
			player_character.set_multiplayer_authority(User.ID)
			player_character.name = str(User.ID)
			game_scene_node.add_child(player_character)

	# Add OTHER players if they don't already exist.
	# (Note case of peer_id variable.)
	if peer_id != User.server_id:
		var other_player = game_scene_node.get_node_or_null("%s" %peer_id)
		if not other_player:
			var player_character = player_character_template.instantiate()
			player_character.set_multiplayer_authority(peer_id)
			player_character.name = str(peer_id)
			game_scene_node.add_child(player_character)

	game_scene_initialized = true

	for connection in connection_list.values():
		print("Peer connected with id %d" %connection_list.find_key(connection))


func spawn_things():
	var thing_name_to_spawn = "b0rp"
	var game_scene_node = get_node("../game_scene")
	var beach_ball = preload("res://things/beach_ball.tscn")
	var existing_thing = game_scene_node.get_node_or_null(thing_name_to_spawn)
	if not existing_thing:
		var new_thing = beach_ball.instantiate()
		new_thing.set_multiplayer_authority(User.server_id)
		new_thing.name = str(thing_name_to_spawn)
		game_scene_node.add_child(new_thing)


func _peer_disconnected(peer_id: int):
	print("Peer disconnected with peer_id %d" %peer_id)
	connection_list.erase(peer_id)
	var other_player = get_node_or_null("../game_scene/%s" %peer_id)
	if other_player:
		other_player.queue_free()


func _game_start_received(peer_ids: String):
	var arr = peer_ids.split("***", false)
	for id_string in arr:
		User.connection_list.get(id_string.to_int()).create_offer()


func reset_connection():
	for connection in connection_list.values():
		connection.close()

	client.queue_free()
	#client = Client.new()
	user_name = ""
	is_host = false
	current_lobby_list = ""
	current_lobby_name = ""
	host_name = ""
	print("User reset!")
	ID = -1
	peers.clear()
	var game_scene_node = get_node_or_null("../game_scene")
	if game_scene_node and is_instance_valid(game_scene_node):
		game_scene_node.queue_free()
	reset.emit()

