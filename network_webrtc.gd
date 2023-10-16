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
var game_scene_initialize_in_progress: bool = false
var game_scene_initialized: bool = false
var signalling_server_connection

var player_character_template: PackedScene = preload("res://player/player.tscn")
var level_scene: PackedScene = preload("res://spaceship/spaceship.tscn")

var rtc_peer: WebRTCMultiplayerPeer

@export var player_spawn_point: Vector3 = Vector3(4, 1, -4)


func _init() -> void:
	if OS.is_debug_build():
		url = "ws://127.0.0.1:9090"


func _process(_delta: float) -> void:
	if not ready_to_connect:
		return

	if signalling_server_connection == null:
		signalling_server_connection = ws.connect_to_url(url)
		return

	ws.poll()
	var state: int = ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		websocket_close_reason = ""
		while ws.get_available_packet_count():
			parse_msg()
		if not websocket_client_connected:
			Helpers.log_print("Websocket just connected.")
		websocket_client_connected = true
	elif state == WebSocketPeer.STATE_CLOSING:
		# Keep polling to achieve proper close.
		pass
	elif state == WebSocketPeer.STATE_CLOSED:
		var code: int = ws.get_close_code()
		var reason: String = ws.get_close_reason()
		print("WebSocket closed with code: %d, reason %s. Clean: %s" % [code, reason, code != -1])
		update_title_message.emit("Server Socket Connection failed.")
		overlay_message.emit("Connection Failed", "e6223c", 2)
		websocket_close_reason = reason
		set_process(false)  # Stop processing.
		websocket_client_connected = false
		reset_connection()
		await get_tree().create_timer(3).timeout
		retry_connection.emit()

	if not websocket_client_connected:
		return

	if not username_sent:
		username_sent = true
		if Globals.is_server:
			send_user_name("Server")
		else:
			# In the future we can have per-player names if we want to.
			send_user_name("Nobody")
		return

	if Globals.player_id < 0:
		return

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


func _ready() -> void:
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
	peers.clear()
	reset.emit(5)


func parse_msg() -> bool:
	var parsed = JSON.parse_string(ws.get_packet().get_string_from_utf8())

	if (
		not typeof(parsed) == TYPE_DICTIONARY
		or not parsed.has("type")
		or not parsed.has("id")
		or not parsed.has("data")
	):
		return false

	var msg: Dictionary = {
		"type": str(parsed.type).to_int(), "id": str(parsed.id).to_int(), "data": parsed.data
	}

	if not str(msg.type).is_valid_int() or not str(msg.id).is_valid_int():
		return false

	var type: int = str(msg.type).to_int()
	var id: int = str(msg.id).to_int()
	var data: String = str(msg.data)

	if type == Message.USER_INFO:
		var parsed_user_data = JSON.parse_string(data)
		if (
			not typeof(parsed_user_data) == TYPE_DICTIONARY
			or not parsed_user_data.has("name")
			or not parsed_user_data.has("server_id")
		):
			print(parsed_user_data)
			return false
		Globals.user_name = parsed_user_data.name
		Globals.player_id = id
		server_id = parsed_user_data.server_id
		Helpers.log_print(
			str(
				"Received User name: ",
				Globals.user_name,
				", Received player_id: ",
				id,
				", Server player_id: ",
				server_id
			)
		)
		init_rtc_peer()
		return true

	if type == Message.ICE:
		var str_arr = data.split("***", true, 3)
		var media: String = str_arr[0]
		var index: int = int(str_arr[1])
		var _name: String = str_arr[2]
		var sender_id = id
		_ice_received(media, index, _name, sender_id)
		return true

	if type == Message.ANSWER:
		var str_arr = data.split("***", true, 2)
		var _type: String = str_arr[0]
		var sdp: String = str_arr[1]
		var sender_id = id
		#print("ANSWER from ", id)
		_answer_received(_type, sdp, sender_id)
		return true

	if type == Message.OFFER:
		var str_arr = data.split("***", true, 2)
		var _type: String = str_arr[0]
		var sdp: String = str_arr[1]
		var sender_id = id
		#print("OFFER from ", id)
		_offer_received(_type, sdp, sender_id)
		return true

	if type == Message.PLAYER_JOINED:
		if id != multiplayer.get_unique_id() and !peers.has(id):
			peers[id] = data
			Helpers.log_print(
				"Peer name: %s with player_id # %s added to the peer list." % [peers[id], id]
			)
			init_connections()
		return true

	if type == Message.PLAYER_LEFT:
		# There seems to be a delay between a websocket disconnect sending and the WebRTC disconnect,
		# so we run this now instead of waiting so other player bodies don't linger.
		_peer_disconnected(id)
		if peers.has(id):
			peers.erase(id)
			Helpers.log_print("Peer name: %s with player_id # %s erased from the list" % [data, id])
		return true

	return false


func send_user_name(_name: String):
	Helpers.log_print(str(" sending user name ", _name))
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
	rtc_peer = WebRTCMultiplayerPeer.new()
	# This is a client/server setup, NOT a Mesh.
	if Globals.is_server:
		rtc_peer.create_server()
	else:
		rtc_peer.create_client(multiplayer.get_unique_id())
		# Clients ONLY connect TO the Server, not each other, as this is a client/server
		# setup, not a Mesh.
		var connection: WebRTCPeerConnection = WebRTCPeerConnection.new()
		connection.initialize({"iceServers": [{"urls": ["stun:stun.l.google.com:19302"]}]})
		connection.session_description_created.connect(session_created.bind(connection))
		connection.ice_candidate_created.connect(ice_created.bind(connection))
		connection_list[1] = connection
		rtc_peer.add_peer(connection, 1)
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
