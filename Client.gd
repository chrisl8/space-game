extends Node
class_name Client

# TODO: LOBBY_MESSAGE is not used
# TODO: NEW_LOBBY is not used
enum Message {USER_INFO, LOBBY_LIST , NEW_LOBBY, JOIN_LOBBY, LEFT_LOBBY, LOBBY_MESSAGE, \
START_GAME, OFFER, ANSWER, ICE, GAME_STARTING, HOST, PING, PONG, SERVER}

# START_GAME is used by send_start_game which does not appear to ever be used

# Message list that corresponds to example.
#enum Message {JOIN, ID, PEER_CONNECT, PEER_DISCONNECT, OFFER, ANSWER, CANDIDATE, SEAL}


var rtc_mp := WebRTCMultiplayerPeer.new()
var ws := WebSocketPeer.new()
var url := "ws://127.0.0.1:9080"
#var url := "wss://godot-test.voidshipephemeral.space/server/"
var client_connected : bool = false

var websocket_close_reason : String = ""

signal join_lobby(lobby_name : String)
signal lobby_list_received(lobby_list : PackedStringArray)
signal other_user_joined_lobby(user_name : String)
signal offer_received(type: String, sdp: String)
signal answer_received(type: String, sdp: String)
signal ice_received(media: String, index: int, _name: String)
signal game_start_received(arr : String)
signal user_name_feedback_received
signal reset_connection
signal client_just_connected
signal update_title_message
signal overlay_message
signal retry_connection

func _init():
	if not OS.is_debug_build():
		# NEVER use local IP in release
		url = "wss://godot-test.voidshipephemeral.space/server/"
	var error = ws.connect_to_url(url)
	if error != OK:
		print ("ERROR: Can not connect to url!")

func is_connection_valid() -> bool:
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var error = send_msg(Message.PING, 0, "")
		if error == OK:
			print("Connection seems OK! (But no server feedback at this point!)")
			return true
		else:
			print("ERROR: Connection failed!")

	return false

func _process(_delta):
	ws.poll()
	var state = ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		websocket_close_reason = ""
		while ws.get_available_packet_count():
			parse_msg()
		if not client_connected:
			client_just_connected.emit()
		client_connected = true
	elif state == WebSocketPeer.STATE_CLOSING:
			# Keep polling to achieve proper close.
		pass
	elif state == WebSocketPeer.STATE_CLOSED:
		var code = ws.get_close_code()
		var reason = ws.get_close_reason()
		print("WebSocket closed with code: %d, reason %s. Clean: %s" % [code, reason, code != -1])
		update_title_message.emit("Server Socket Connection failed.")
		overlay_message.emit("Connection Failed", "e6223c", 2)
		websocket_close_reason = reason
		set_process(false) # Stop processing.
		client_connected = false
		reset_connection.emit()
		await get_tree().create_timer(3).timeout
		retry_connection.emit()

func parse_msg():
	var parsed = JSON.parse_string(ws.get_packet().get_string_from_utf8())

	if not typeof(parsed) == TYPE_DICTIONARY \
	or not parsed.has("type") \
	or not parsed.has("id") \
	or not parsed.has("data"):
		return false

	var msg = {
		"type": str(parsed.type).to_int(),
		"id": str(parsed.id).to_int(),
		"data": parsed.data
	}

	if not str(msg.type).is_valid_int() \
	or not str(msg.id).is_valid_int():
		return false

	var type := str(msg.type).to_int()
	var id := str(msg.id).to_int()
	var data : String = str(msg.data)

	if type == Message.USER_INFO:
		User.user_name = data
		User.ID = id
		print("Received User name = %s ID# %s" %[data, id])
		user_name_feedback_received.emit()
		return

	if type == Message.HOST:
		print("Host Info: ", data, " ", id)
		User.server_id = id
		User.server_name = data
		User.host_name = data # TODO: Is this used anywhere?
		if id == User.ID and data == User.user_name:
			# TODO: Is this necesary/required/useful?
			User.is_host = true
			print("I ", User.server_name ," am host id ", User.server_id)
		else:
			User.is_host = false # TODO: Is this necesary/required/useful?
		return

	if type == Message.ICE:
		var str_arr = data.split("***", true , 3)
		var media : String = str_arr[0]
		var index : int = int(str_arr[1])
		var _name : String = str_arr[2]
		var sender_id = id
		ice_received.emit(media, index, _name, sender_id)
		return

	if type == Message.ANSWER:
		var str_arr = data.split("***", true , 2)
		var _type : String = str_arr[0]
		var sdp : String = str_arr[1]
		var sender_id = id
		#print("ANSWER from ", id)
		answer_received.emit(_type, sdp, sender_id)
		return

	if type == Message.OFFER:
		var str_arr = data.split("***", true , 2)
		var _type : String = str_arr[0]
		var sdp : String = str_arr[1]
		var sender_id = id
		#print("OFFER from ", id)
		offer_received.emit(_type, sdp, sender_id)
		return

	if type == Message.JOIN_LOBBY:
		if data.contains("LOBBY_NAME"):
			join_lobby.emit(data.right(-10))
			return
		if data.contains("NEW_JOINED_USER_NAME"):
			if id != User.ID and id not in User.peers:
				User.peers[id] = data.right(-20)
				other_user_joined_lobby.emit()
				print("Peer name: %s with ID # %s added to the list by NEW_JOINED_USER_NAME." %[data.right(-20), id])
				User.init_connection()
			return
		if data.contains("EXISTING_USER_NAME"):
			if id != User.ID and id not in User.peers:
				User.peers[id] = data.right(-18)
				other_user_joined_lobby.emit()
				print("Peer name: %s with ID # %s added to the list by EXISTING_USER_NAME." %[data.right(-18), id])
				User.init_connection()
			return
		return

	if type == Message.LOBBY_LIST:
		if data == "":
			var e : PackedStringArray = []
			print("Lobby list is empty!")
			lobby_list_received.emit(e)
		else:
			var lobby_list_arr = data.split(" ", false)
			print("Lobby list received:", lobby_list_arr)
			lobby_list_received.emit(lobby_list_arr)
		return

	if type == Message.LEFT_LOBBY:
		if User.peers.has(id):
			User.peers.erase(id)
			print("Peer name: %s with ID # %s erased from the list" %[data, id])
		return

	if type == Message.GAME_STARTING:
		print("GAME_STARTING")
		var string = data.get_slice(str(User.ID), 1)
		if not string == "":
			game_start_received.emit(string)
		return
	return false

func is_client_connected() -> bool:
	return client_connected

func send_user_name(_name : String):
	send_msg(Message.USER_INFO, 0, _name)

func request_lobby_list():
	send_msg(Message.LOBBY_LIST, 0, "")

func request_join_lobby(lobby_id : String):
	send_msg(Message.JOIN_LOBBY, 0, lobby_id)

func send_server_msg(server_password):
	send_msg(Message.SERVER, 0, server_password)

func send_msg(type: int, id:int, data:String) -> int:
	return ws.send_text(JSON.stringify({"type": type, "id": id, "data": data}))

func send_left_info(lobby_name : String):
	send_msg(Message.LEFT_LOBBY, 0, lobby_name)

# TODO: I don't think this is ever used.
# TODO: Anything else?
func send_start_game(lobby_name : String):
	send_msg(Message.START_GAME, 0, lobby_name)

func send_offer(type: String, sdp: String, id):
	send_msg(Message.OFFER, 0, type + "***" + sdp + "***" + str(id))

func send_answer(type: String, sdp: String, id):
	send_msg(Message.ANSWER, 0, type + "***" + sdp + "***" + str(id))

func send_ice(media: String, index: int, _name: String, id):
	send_msg(Message.ICE, 0, media + "***" + str(index) + "***" + _name + "***" + str(id))

func send_game_starting():
	send_msg(Message.GAME_STARTING, User.ID, "")
