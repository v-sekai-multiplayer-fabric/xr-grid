# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
extends Node

signal entity_received(packet: PackedByteArray)
signal connection_state_changed(state: int)

enum State { DISCONNECTED, CONNECTING, CONNECTED }

const CH_INTEREST := 2
const CH_PLAYER := 3

var peer: FabricMultiplayerPeer = null
var state: int = State.DISCONNECTED
var local_player_id: int = 0
var frame_counter: int = 0
var hlc_counter: int = 0

func connect_to_zone(address: String, port: int) -> void:
	if peer != null:
		peer = null
	peer = FabricMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		push_error("FabricMultiplayerPeer.create_client failed: %d" % err)
		state = State.DISCONNECTED
		return
	state = State.CONNECTING
	connection_state_changed.emit(state)
	print("FabricManager: connecting to %s:%d" % [address, port])

func host_zone(port: int, max_clients: int = 32) -> void:
	if peer != null:
		peer = null
	peer = FabricMultiplayerPeer.new()
	var err := peer.create_server(port, max_clients)
	if err != OK:
		push_error("FabricMultiplayerPeer.create_server failed: %d" % err)
		state = State.DISCONNECTED
		return
	state = State.CONNECTED
	local_player_id = 1
	connection_state_changed.emit(state)
	print("FabricManager: hosting zone on port %d" % port)

func send_entity(packet: PackedByteArray) -> void:
	if peer == null or state != State.CONNECTED:
		return
	peer.broadcast_to_zones(CH_INTEREST, packet)

func _process(_delta: float) -> void:
	if peer == null:
		return
	if state == State.CONNECTING:
		var peer_id: int = peer.get_unique_id()
		if peer_id > 0 and peer_id != 1:
			local_player_id = peer_id
			state = State.CONNECTED
			connection_state_changed.emit(state)
			print("FabricManager: connected (player_id=%d)" % local_player_id)
	if state != State.CONNECTED:
		return
	frame_counter += 1
	hlc_counter = 0
	var packets: Array = peer.drain_channel(CH_INTEREST)
	for pkt: PackedByteArray in packets:
		entity_received.emit(pkt)
