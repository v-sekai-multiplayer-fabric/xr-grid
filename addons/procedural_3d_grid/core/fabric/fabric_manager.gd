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

func _ready() -> void:
	print("FabricManager: autoload ready")

func _make_enet_client(host: String, port: int) -> MultiplayerPeer:
	var p := ENetMultiplayerPeer.new()
	p.create_client(host, port)
	return p

func _make_enet_server(port: int) -> MultiplayerPeer:
	var p := ENetMultiplayerPeer.new()
	p.create_server(port)
	return p

func connect_to_zone(address: String, port: int) -> void:
	if peer != null:
		peer = null
	peer = FabricMultiplayerPeer.new()
	peer.client_factory = _make_enet_client
	peer.server_factory = _make_enet_server
	var err := peer.create_client(address, port)
	if err != OK:
		push_error("FabricMultiplayerPeer.create_client failed: %d" % err)
		state = State.DISCONNECTED
		return
	state = State.CONNECTING
	connection_state_changed.emit(state)
	print("FabricManager: connecting to %s:%d" % [address, port])

func host_zone(port: int) -> void:
	if peer != null:
		peer = null
	peer = FabricMultiplayerPeer.new()
	peer.client_factory = _make_enet_client
	peer.server_factory = _make_enet_server
	var err := peer.create_server(port)
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

var _connect_elapsed: float = 0.0
const _CONNECT_GRACE_SEC := 1.0

func _process(delta: float) -> void:
	if peer == null:
		return
	peer.poll()
	if state == State.CONNECTING:
		_connect_elapsed += delta
		if _connect_elapsed >= _CONNECT_GRACE_SEC:
			local_player_id = randi_range(100, 999999)
			state = State.CONNECTED
			connection_state_changed.emit(state)
			print("FabricManager: connected (player_id=%d)" % local_player_id)
	if state != State.CONNECTED:
		return
	frame_counter += 1
	hlc_counter = 0
	var packets: Array = peer.drain_channel(CH_INTEREST)
	if packets.size() > 0 and frame_counter % 300 == 0:
		print("FabricManager: received %d packets (frame %d)" % [packets.size(), frame_counter])
	for pkt: PackedByteArray in packets:
		entity_received.emit(pkt)
