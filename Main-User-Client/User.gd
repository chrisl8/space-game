extends Node

# Check if this is the first instance of a debug run, so only one attempts to be the server
# https://gist.github.com/CrankyBunny/71316e7af809d7d4cf5ec6e2369a30b9
var instance_num                            := -1
var client: Client
var user_name: String                       =  ""
var host_name: String                       =  ""
var current_lobby_name: String              =  ""
var current_lobby_list: String              =  ""
var is_host: bool                           =  false
var ID                                      := -1
var peers: Dictionary
var peer_count                              := -1
var network_initialized: bool               =  false
var game_started: bool                      =  false
var game_scene_initialize_in_progress: bool =  false
var game_scene_initialized: bool            =  false
var players_initialized: bool               =  false
var player_character_template               := preload("res://player/player.tscn")
var level_scene                             := preload("res://spaceship.tscn")
var is_server: bool                         =  false
var server_name: String                     =  ""
var server_password: String                 =  ""
var local_debug_instance_number             := -1
var mult: SceneMultiplayer                  =  null
var connection_list: Dictionary             =  {}
#var rtc_peer: ENetMultiplayerPeer # ENet
var rtc_peer: WebSocketMultiplayerPeer # WebSocket
signal reset
signal delete_main_menu


func _process(_delta) -> void:
	if not network_initialized:
		return

	if peers.size() != peer_count:
		peer_count = peers.size()
		print(multiplayer.get_unique_id(), " New peer count is: ", peer_count)

	if not User.is_server:
		# Only server adds and removes objects
		return

	# Initialize the Level if it isn't yet
	if not game_scene_initialized:
		if not game_scene_initialize_in_progress:
			game_scene_initialize_in_progress = true
			load_level.call_deferred(level_scene)
		elif get_node_or_null("../Main/Level/game_scene"):
			game_scene_initialized = true
		return

	spawn_things()

func _enter_tree():
	print("%d: Enter Tree" % [multiplayer.get_unique_id()])

func _spawn_custom():
	print("%d: Spawn Custom" % [multiplayer.get_unique_id()])

func load_level(scene: PackedScene):
	print("%d Loading Scene" % [multiplayer.get_unique_id()])
	var level_parent := get_tree().get_root().get_node("Main/Level")
	for c in level_parent.get_children():
		level_parent.remove_child(c)
		c.queue_free()
	#level_parent.set_multiplayer_authority(server_id, true)
	var game_scene = scene.instantiate()
	game_scene.name = "game_scene"
	level_parent.add_child(game_scene)


func client_listener_init():
	client.offer_received.connect(_offer_received)
	client.answer_received.connect(_answer_received)
	client.ice_received.connect(_ice_received)
	client.reset_connection.connect(reset_connection)
	client.game_start_received.connect(_game_start_received)

func _peer_connected(id):
	print("%d: Peer %d connected." % [multiplayer.get_unique_id(), id])
	if User.is_server and id > 1:
		var character = player_character_template.instantiate()
		character.player = id # Set player id.
		# Randomize character position.
		var pos := Vector2.from_angle(randf() * 2 * PI)
		const SPAWN_RANDOM := 2.0
		character.position = Vector3(pos.x * SPAWN_RANDOM * randf(), 0, pos.y * SPAWN_RANDOM * randf())
		character.name = str(id)
		#$Players.add_child(character, true)
		get_node("../Main/Players").add_child(character, true)

#		var players_node := get_node("../Main/Players")
#		var this_player_exists := players_node.get_node_or_null("%s" % [peer])
#		if not this_player_exists:
#			print("%d: Initializing New Player ID %d" % [multiplayer.get_unique_id(), peer])
#			var player_character = player_character_template.instantiate()
#			player_character.name = str(peer)
#			#player_character.owner_id = peer
#			# Randomize initial position to avoid spawning inside other players
#			player_character.position = Vector3(randf_range(-2.5, 2.5), randf_range(-2.5, 2.5), 0.0)
#			# Note the owner_id SHOULD do this inside of the player, but it don't.
#			#player_character.set_multiplayer_authority(peer)
#			players_node.add_child(player_character)
##players_node.get_node("%s" % [peer]).set_multiplayer_authority(peer)

func _peer_disconnected(id) -> void:
	print("%d: Peer %d Disconnected." % [multiplayer.get_unique_id(), id])
	if not User.is_server:
		return
	var player_spawner_node = get_node_or_null("../Main/Players")
	if player_spawner_node and player_spawner_node.has_node(str(id)):
		player_spawner_node.get_node(str(id)).queue_free()
#
#	# connection_list.erase(peer_id) # TODO: Do we need this?
#	# Remove other player from game.
#	var other_player := get_node_or_null("../Main/Players/%s" % [multiplayer.get_unique_id()])
#	if other_player:
#		other_player.queue_free()

func _connected_to_server():
	print("%d: I connected to the server!" % [multiplayer.get_unique_id()])
	delete_main_menu.emit()

func _connection_failed():
	print("%d: My connection failed. =(" % [multiplayer.get_unique_id()])

func _server_disconnected():
	print("%d: Server Disconnected" % [multiplayer.get_unique_id()])

func init_connection():
	print("Connecting!")
	#rtc_peer = ENetMultiplayerPeer.new() # ENet
	rtc_peer = WebSocketMultiplayerPeer.new() # WebSocket

	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected_to_server)
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_server_disconnected)

	multiplayer.multiplayer_peer = null
	if User.is_server:
		rtc_peer.create_server(8080)
		# Server is born ready
		network_initialized = true
		delete_main_menu.emit()
	else:
		#rtc_peer.create_client('127.0.0.1', 8080) # ENet
		var error = rtc_peer.create_client('ws://localhost:8080') # WebSocket
		if error:
			print(error)
	multiplayer.multiplayer_peer = rtc_peer


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


#func _peer_connected(peer_id: int):
#	if not User.is_server:
#		return
#	print(User.ID, " ", "_peer_connected ", peer_id)
#	# Add OTHER players if they don't already exist.
#	var players_node := get_node("../Main/Players")
#	if peer_id != User.server_id:
#		var other_player := players_node.get_node_or_null("%s" %peer_id)
#		if not other_player:
#			print(User.ID, " Initializing Player ", peer_id)
#			var player_character = player_character_template.instantiate()
#			player_character.name = str(peer_id)
#			player_character.owner_id = peer_id
#			player_character.set_multiplayer_authority(peer_id)
#			players_node.add_child(player_character)


func spawn_things():
	var thing_name_to_spawn := "b0rp"
	var things_spawning_node := get_node("../Main/Things")
	var beach_ball := preload("res://things/beach_ball/beach_ball.tscn")
	var existing_thing := things_spawning_node.get_node_or_null(thing_name_to_spawn)
	if not existing_thing:
		print("BALL!")
		var new_thing = beach_ball.instantiate()
		#new_thing.set_multiplayer_authority(User.server_id)
		new_thing.name = str(thing_name_to_spawn)
		things_spawning_node.add_child(new_thing)


#func _peer_disconnected(peer_id: int):
#	if not User.is_server:
#		return
#	print("Peer disconnected with peer_id %d" %peer_id)
#	connection_list.erase(peer_id)
#	var other_player := get_node_or_null("../Main/Players/%s" %peer_id)
#	if other_player:
#		other_player.queue_free()


func _game_start_received(peer_ids: String):
	var arr = peer_ids.split("***", false)
	for id_string in arr:
		# NOTE: This errors sometimtes, I'm not sure why.
		# My guess is it is just trying to connect.
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
	var game_scene_node := get_node_or_null("../Main/game_scene")
	if game_scene_node and is_instance_valid(game_scene_node):
		game_scene_node.queue_free()
	reset.emit()

