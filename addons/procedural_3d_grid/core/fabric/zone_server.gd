# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# Minimal zone relay server. Receives CH_PLAYER packets from clients,
# rebroadcasts them to all other clients on CH_INTEREST.
#
# Run with:
#   godot --headless --path <project> --script res://addons/procedural_3d_grid/core/fabric/zone_server.gd
extends SceneTree

var _server: ENetMultiplayerPeer
var _tick: int = 0

func _init() -> void:
	var port := 9000
	var args := OS.get_cmdline_args()
	for arg in args:
		if arg.begins_with("--zone-port="):
			port = arg.split("=", true, 1)[1].to_int()
	_server = ENetMultiplayerPeer.new()
	var err := _server.create_server(port)
	if err != OK:
		print("Zone: failed to start on port %d (err=%d)" % [port, err])
		quit(1)
		return
	print("Zone: listening on port %d" % port)

func _process(delta: float) -> bool:
	_server.poll()
	_tick += 1
	while _server.get_available_packet_count() > 0:
		var sender: int = _server.get_packet_peer()
		var pkt: PackedByteArray = _server.get_packet()
		if pkt.size() == 100:
			_server.set_target_peer(0)
			_server.set_transfer_channel(0)
			_server.set_transfer_mode(MultiplayerPeer.TRANSFER_MODE_UNRELIABLE)
			_server.put_packet(pkt)
			if _tick % 600 == 0:
				print("Zone: relayed %d-byte packet from peer %d" % [pkt.size(), sender])
	return false
