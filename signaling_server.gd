extends Node

enum Message { USER_INFO, PLAYER_JOINED, PLAYER_LEFT, OFFER, ANSWER, ICE }

var server: RefCounted = TCPServer.new()
var hard_coded_port: int = 9090
var connections: Dictionary = {}
var lobbies: Array = []
var to_remove_connections: Array = []
var started: bool = false
# The server ID is always 1, as Godot likes this better.
# Strange bugs creep in if one tries to set it to something else.
var server_id: int = 1


class Connection:
	extends RefCounted
	var id: int = -1
	var ws: WebSocketPeer = WebSocketPeer.new()
	var user_name: String = ""

	func _init(connection_id: int, tcp: StreamPeer) -> void:
		id = connection_id
		var error: int = ws.accept_stream(tcp)
		if error != OK:
			Helpers.log_print(
				"Signal Server: ERROR! Can not accept stream from a connection request!"
			)
		else:
			Helpers.log_print(
				str("Signal Server: Connection connection successfully accepted for ", id)
			)

	func send_msg(type: int, msg_id: int, data: String = "") -> int:
		return (
			ws
			. send_text(
				(
					JSON
					. stringify(
						{
							"type": type,
							"id": msg_id,
							"data": data,
						}
					)
				)
			)
		)

	func is_ws_open() -> bool:
		return ws.get_ready_state() == WebSocketPeer.STATE_OPEN


func start() -> void:
	var error: int = server.listen(hard_coded_port)
	if error != OK:
		Helpers.log_print(
			"Signal Server: ERROR! Can not create signalling server! ERROR CODE = %d" % error
		)
	else:
		Helpers.log_print("Signal Server: Signalling Server created successfully!")
		started = true


func _process(_delta: float) -> void:
	if started:
		poll()
		clean_up()


func poll() -> void:
	if server.is_connection_available():
		var id: int = randi() % (1 << 31)
		connections[id] = Connection.new(id, server.take_connection())

	for p: Connection in connections.values():
		p.ws.poll()

		while p.is_ws_open() and p.ws.get_available_packet_count():
			if parse_msg(p):
				pass
			else:
				Helpers.log_print("Signal Server: Message received! ERROR can not parse! ")

		if p.ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			Helpers.log_print(
				str(
					"Signal Server: Player ",
					p.user_name,
					" ID ",
					p.id,
					" disconnected from server."
				)
			)
			to_remove_connections.push_back(p)


func parse_msg(peer: Connection) -> bool:
	var msg: String = peer.ws.get_packet().get_string_from_utf8()

	var parsed: Variant = JSON.parse_string(msg)
	if (
		not typeof(parsed) == TYPE_DICTIONARY
		or not parsed.has("type")
		or not parsed.has("id")
		or not parsed.has("data")
	):
		print(parsed)
		return false

	var accepted_msg: Dictionary = {
		"type": str(parsed.type).to_int(), "id": str(parsed.id).to_int(), "data": parsed.data
	}

	if not str(accepted_msg.type).is_valid_int() or not str(accepted_msg.id).is_valid_int():
		Helpers.log_print(parsed)
		return false

	var type: int = str(accepted_msg.type).to_int()
	#var src_id = str(accepted_msg.id).to_int()
	var data: String = str(accepted_msg.data)

	if type == Message.OFFER:
		var str_arr: PackedStringArray = data.split("***", true, 2)
		var send_to_id: int = str_arr[2].to_int()
		var receiver_peer: Variant = find_player_by_id(send_to_id)
		if receiver_peer:
			receiver_peer.send_msg(type, peer.id, data)
			Helpers.log_print("Signal Server: Sending received OFFER! to peer %d" % peer.id)
			return true
		Helpers.log_print("Signal Server: ERROR: OFFER received but ID do not match with any peer!")
		return false

	if type == Message.ANSWER:
		var str_arr: PackedStringArray = data.split("***", true, 2)
		var send_to_id: int = str_arr[2].to_int()
		var receiver_peer: Variant = find_player_by_id(send_to_id)
		if receiver_peer:
			receiver_peer.send_msg(type, peer.id, data)
			Helpers.log_print("Signal Server: Sending received ANSWER! to peer %d" % peer.id)
			return true
		Helpers.log_print(
			"Signal Server: ERROR: ANSWER received but ID do not match with any peer!"
		)
		return false

	if type == Message.ICE:
		var str_arr: PackedStringArray = data.split("***", true, 3)
		var send_to_id: int = str_arr[3].to_int()
		var receiver_peer: Variant = find_player_by_id(send_to_id)
		if receiver_peer:
			receiver_peer.send_msg(type, peer.id, data)
			Helpers.log_print("Signal Server: Sending received ICE! to peer %d" % peer.id)
			return true
		Helpers.log_print("Signal Server: ERROR: ICE received but ID do not match with any peer!")
		return false

	if type == Message.USER_INFO:
		var parsed_user_data: Variant = JSON.parse_string(data)
		if (
			not typeof(parsed_user_data) == TYPE_DICTIONARY
			or not parsed_user_data.has("name")
			or not parsed_user_data.has("server_id_string")
		):
			Helpers.log_print(parsed_user_data)
			return false

		# Every client generates a random string,
		# But only the same client that is running this signalling server
		# will have a string that matches
		if parsed_user_data.server_id_string == Network.server_id_string:
			Helpers.log_print(str("Signal Server: Player ", parsed_user_data.name, " is Server."))
			peer.id = server_id

		peer.user_name = parsed_user_data.name
		Helpers.log_print(str("Signal Server: New player ", peer.user_name, " ID ", peer.id))

		# The server ID is always 1, as Godot likes this better.
		# Strange bugs creep in if one tries to set it to something else.
		parsed_user_data.server_id = server_id

		peer.send_msg(Message.USER_INFO, peer.id, JSON.stringify(parsed_user_data))

		for p: Connection in connections.values():
			p.send_msg(Message.PLAYER_JOINED, peer.id, peer.user_name)
			peer.send_msg(Message.PLAYER_JOINED, p.id, p.user_name)

		return true

	Helpers.log_print(parsed)
	return false


func clean_up() -> void:
	var temp_arr: Array = []
	for player: Connection in to_remove_connections:
		if connections.has(player.id):
			connections.erase(player.id)
			temp_arr.push_back(player)
			Helpers.log_print(
				str(
					"Signal Server: Player ",
					player.user_name,
					" ID ",
					player.id,
					" removed from connection list."
				)
			)

	if temp_arr.size() > 0:
		for p: Connection in connections.values():
			for disconnected_player: Connection in temp_arr:
				p.send_msg(
					Message.PLAYER_LEFT, disconnected_player.id, disconnected_player.user_name
				)


func find_player_by_id(id: int) -> Variant:
	# The socket connection ID and the "player ID" are not guaranteed to be the same.
	# Currently they are the same in every case except for the server.
	for connection_id: int in connections.keys():
		if id == connections[connection_id].id:
			return connections[connection_id]
	return false
