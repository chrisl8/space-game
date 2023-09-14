extends Node

enum Message { USER_INFO, PLAYER_JOINED, PLAYER_LEFT, OFFER, ANSWER, ICE }

var ws: WebSocketPeer = WebSocketPeer.new()
var url: String = "wss://voidshipephemeral.space/server/"
var websocket_client_connected: bool = false
var websocket_close_reason: String = ""

signal update_title_message
signal overlay_message
signal retry_connection
signal reset
signal close_popup

var connection_list: Dictionary = {}
var ready_to_connect: bool = false
var server_message_sent: bool = false
var username_sent: bool = false
var server_id_string: String
var server_id: int = -1:
	set(value):
		server_id = value
		get_tree().get_root().get_node("Main/LevelSpawner").set_multiplayer_authority(value)
		get_tree().get_root().get_node("Main/PlayersSpawner").set_multiplayer_authority(value)
		get_tree().get_root().get_node("Main/ThingSpawner").set_multiplayer_authority(value)
var peers: Dictionary
var peer_count: int = -1
var network_initialized: bool = false
var game_started: bool = false
var game_scene_initialize_in_progress: bool = false
var game_scene_initialized: bool = false
var signalling_server_connection
var network_connection_initiated: bool = false

var player_character_template: PackedScene = preload("res://player/player.tscn")
var level_scene: PackedScene = preload("res://spaceship/spaceship.tscn")

var rtc_peer: WebSocketMultiplayerPeer

@export var player_spawn_point: Vector3 = Vector3(4, 1, -4)


func _init():
	if OS.is_debug_build():
		url = "ws://127.0.0.1:9090"


func _process(_delta) -> void:
	if not ready_to_connect:
		return

	if not network_connection_initiated:
		network_connection_initiated = true
		init_rtc_peer()

	if not network_initialized:
		return

	if peers.size() != peer_count:
		peer_count = peers.size()
		Helpers.log_print(str("New peer count is: ", peer_count))

	if not Globals.is_server:
		# Only server adds and removes objects
		return

	# Initialize the Level if it isn't yet
	if not game_scene_initialized:
		if not game_scene_initialize_in_progress:
			Helpers.log_print("Load level")
			game_scene_initialize_in_progress = true
			load_level.call_deferred(level_scene)
		elif get_node_or_null("../Main/Level/game_scene"):
			game_scene_initialized = true
		return

	Spawner.things()


func _ready():
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected_to_server)
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_server_disconnected)


func load_level(scene: PackedScene):
	Helpers.log_print("Loading Scene")
	var level_parent: Node = get_tree().get_root().get_node("Main/Level")
	for c in level_parent.get_children():
		level_parent.remove_child(c)
		c.queue_free()
	#level_parent.set_multiplayer_authority(server_id, true)
	var game_scene = scene.instantiate()
	game_scene.name = "game_scene"
	level_parent.add_child(game_scene)


func _peer_connected(id):
	Helpers.log_print(str("Peer ", id, " connected."))
	if Globals.is_server and id > 1:
		var character = player_character_template.instantiate()
		character.player = id  # Set player id.
		# Randomize character position.
		var pos: Vector2 = Vector2.from_angle(randf() * 2 * PI)
		const SPAWN_RANDOM: float = 2.0
		character.position = Vector3(
			player_spawn_point.x + (pos.x * SPAWN_RANDOM * randf()),
			player_spawn_point.y,
			player_spawn_point.z + (pos.y * SPAWN_RANDOM * randf())
		)
		character.name = str(id)
		get_node("../Main/Players").add_child(character, true)
		character.set_multiplayer_authority(character.player)


func _peer_disconnected(id) -> void:
	Helpers.log_print(str("Peer ", id, " Disconnected."))
	if not Globals.is_server:
		return
	var player_spawner_node: Node = get_node_or_null("../Main/Players")
	if player_spawner_node and player_spawner_node.has_node(str(id)):
		player_spawner_node.get_node(str(id)).queue_free()


func _connected_to_server():
	Helpers.log_print("I connected to the server!")
	close_popup.emit()


func _connection_failed():
	Helpers.log_print("My connection failed. =(")
	reset_connection()


func _server_disconnected():
	Helpers.log_print("Server Disconnected")
	reset_connection()


func reset_connection():
	network_initialized = false
	game_scene_initialized = false
	game_scene_initialize_in_progress = false
	multiplayer.multiplayer_peer = null
	rtc_peer = null
	peers.clear()
	peer_count = -1

	for connection in connection_list.values():
		connection.close()

	Globals.user_name = ""
	Globals.player_id = -1
	peers.clear()
	reset.emit(5)


func send_user_name(_name: String):
	print(
		Globals.local_debug_instance_number,
		" ",
		Globals.player_id,
		" sending user name ",
		_name,
	)

	# Every client generates a random string,
	# But only the same client that is running this signalling server
	# will have a string that matches
	if not server_id_string:
		server_id_string = Helpers.generate_random_string(32)

	send_msg(
		Message.USER_INFO, 0, JSON.stringify({"name": _name, "server_id_string": server_id_string})
	)


func send_msg(type: int, id: int, data: String) -> int:
	return ws.send_text(JSON.stringify({"type": type, "id": id, "data": data}))


func send_offer(type: String, sdp: String, id):
	send_msg(Message.OFFER, 0, type + "***" + sdp + "***" + str(id))


func send_answer(type: String, sdp: String, id):
	send_msg(Message.ANSWER, 0, type + "***" + sdp + "***" + str(id))


func send_ice(media: String, index: int, _name: String, id):
	send_msg(Message.ICE, 0, media + "***" + str(index) + "***" + _name + "***" + str(id))


func init_connections():
	# This is a client/server setup, NOT a Mesh.
	# The clients already added the server as a peer in init_rtc_peer
	# Now only the server must connect to the clients.
	if Globals.is_server:
		for peer_id in peers.keys():
			if connection_list.has(peer_id):
				continue  # This peer has already been initiated, skipping
			Helpers.log_print(str("init_connections new peer ", peer_id))
			var connection: WebRTCPeerConnection = WebRTCPeerConnection.new()
			connection.initialize({"iceServers": [{"urls": ["stun:stun.l.google.com:19302"]}]})
			connection.session_description_created.connect(session_created.bind(connection))
			connection.ice_candidate_created.connect(ice_created.bind(connection))
			connection_list[peer_id] = connection
			rtc_peer.add_peer(connection, peer_id)
			connection.create_offer()


func init_rtc_peer():
	rtc_peer = WebSocketMultiplayerPeer.new()
	# This is a client/server setup, NOT a Mesh.
	if Globals.is_server:
		rtc_peer.create_server(9090)
	else:
		var error: int = rtc_peer.create_client(url)  # WebSocket
		if error:
			Helpers.log_print(error)
		# Clients ONLY connect TO the Server, not each other, as this is a client/server
		# setup, not a Mesh.
		# var connection: WebRTCPeerConnection = WebRTCPeerConnection.new()
		# connection.initialize({"iceServers": [{"urls": ["stun:stun.l.google.com:19302"]}]})
		# connection.session_description_created.connect(session_created.bind(connection))
		# connection.ice_candidate_created.connect(ice_created.bind(connection))
		# connection_list[1] = connection
		# rtc_peer.add_peer(connection, 1)
		#connection.create_offer()
	get_tree().get_multiplayer().multiplayer_peer = rtc_peer
	close_popup.emit()
	network_initialized = true


func session_created(type: String, sdp: String, connection):
	#Helpers.log_print(str("session_created ", type, " ", sdp))
	connection.set_local_description(type, sdp)
	if type == "offer":
		send_offer(type, sdp, connection_list.find_key(connection))
	else:
		send_answer(type, sdp, connection_list.find_key(connection))


func ice_created(media: String, index: int, _name: String, connection):
	#Helpers.log_print(str("ice_created ", media, " ", index, " ", _name))
	send_ice(media, index, _name, connection_list.find_key(connection))


func _ice_received(media: String, index: int, _name: String, sender_id):
	#Helpers.log_print(str("_ice_received ", media, " ", index, " ", _name))
	if connection_list.has(sender_id):
		connection_list.get(sender_id).add_ice_candidate(media, index, _name)


func _offer_received(type: String, sdp: String, sender_id):
	#Helpers.log_print(str("_offer_received ", type, " ", sdp, " ", sender_id))
	if connection_list.has(sender_id):
		connection_list.get(sender_id).set_remote_description(type, sdp)


func _answer_received(type: String, sdp: String, sender_id):
	#Helpers.log_print(str("_answer_received ", type, " ", sdp, " ", sender_id))
	connection_list.get(sender_id).set_remote_description(type, sdp)
