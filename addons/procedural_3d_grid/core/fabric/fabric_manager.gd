# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
extends Node

signal entity_received(packet: PackedByteArray)
signal connection_state_changed(state: int)

enum State { DISCONNECTED, CONNECTING, CONNECTED }

var state: int = State.DISCONNECTED
var local_player_id: int = 0
var frame_counter: int = 0
var hlc_counter: int = 0

func _ready() -> void:
	print("FabricManager: autoload ready")

var _enet: ENetMultiplayerPeer = null

func connect_to_zone(address: String, port: int) -> void:
	_enet = ENetMultiplayerPeer.new()
	var err := _enet.create_client(address, port)
	if err != OK:
		push_error("ENet create_client failed: %d" % err)
		state = State.DISCONNECTED
		return
	state = State.CONNECTING
	connection_state_changed.emit(state)
	print("FabricManager: connecting to %s:%d" % [address, port])

func send_entity(packet: PackedByteArray) -> void:
	if _enet == null or state != State.CONNECTED:
		return
	_enet.set_target_peer(0)
	_enet.set_transfer_channel(0)
	_enet.set_transfer_mode(MultiplayerPeer.TRANSFER_MODE_UNRELIABLE)
	_enet.put_packet(packet)

func _process(_delta: float) -> void:
	if _enet == null:
		return
	_enet.poll()
	if state == State.CONNECTING:
		var status: int = _enet.get_connection_status()
		if status == MultiplayerPeer.CONNECTION_CONNECTED:
			local_player_id = _enet.get_unique_id()
			state = State.CONNECTED
			connection_state_changed.emit(state)
			print("FabricManager: connected (player_id=%d)" % local_player_id)
	if state != State.CONNECTED:
		return
	frame_counter += 1
	hlc_counter = 0
	while _enet.get_available_packet_count() > 0:
		var pkt: PackedByteArray = _enet.get_packet()
		if pkt.size() == 100:
			entity_received.emit(pkt)
			if frame_counter % 300 == 0:
				print("FabricManager: received entity (frame %d)" % frame_counter)
