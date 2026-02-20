extends Node

signal connected
signal disconnected
signal message_received(type, data)

var socket := WebSocketPeer.new()
var url := "ws://127.0.0.1:8080"

var _was_open := false

# keeps history of network activity
var log: Array[String] = []


func _process(_delta):
	socket.poll()
	_update_connection_state()
	_read_packets()


# -------------------- public API --------------------

func connect_to_server(to_connect_to = url):
	var state := socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		_log("connect ignored (already connected)")
		return
	if state == WebSocketPeer.STATE_CONNECTING:
		_log("connect ignored (already connecting)")
		return
	_log("attempting connection to " + to_connect_to)
	socket.connect_to_url(to_connect_to)


func disconnect_from_server():
	var state := socket.get_ready_state()

	if state == WebSocketPeer.STATE_CLOSED:
		_log("disconnect ignored (already closed)")
		return

	if state == WebSocketPeer.STATE_CLOSING:
		_log("disconnect ignored (already closing)")
		return
	_log("disconnect requested")
	socket.close()


func send(type:String, data:Dictionary = {}):
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		_log("send failed (not connected)")
		return

	var packet = {
		"type": type,
		"data": data
	}

	var text := JSON.stringify(packet)
	_log("send: " + text)
	socket.send_text(text)


# -------------------- internal --------------------

func _update_connection_state():
	match socket.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _was_open:
				_was_open = true
				_log("connected")
				connected.emit()

		WebSocketPeer.STATE_CLOSED:
			if _was_open:
				_was_open = false
				_log("disconnected")
				disconnected.emit()


func _read_packets():
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return

	while socket.get_available_packet_count() > 0:
		var raw := socket.get_packet().get_string_from_utf8()
		_log("recv: " + raw)

		var json = JSON.parse_string(raw)
		if typeof(json) != TYPE_DICTIONARY:
			_log("invalid packet")
			continue

		message_received.emit(json.get("type"), json.get("data", {}))


func _log(text:String):
	var line := "[" + Time.get_time_string_from_system() + "] " + text
	log.append(line)
	print(line)
