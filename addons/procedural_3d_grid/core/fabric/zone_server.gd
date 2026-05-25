# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# Minimal WebTransport zone relay server. Receives packets from clients,
# rebroadcasts to all others via QUIC datagrams.
#
# Run with:
#   godot --headless --path <project> --script res://addons/procedural_3d_grid/core/fabric/zone_server.gd
extends SceneTree

var _server: WebTransportPeer

func _fmt_validity(unix: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(unix)
	return "%04d%02d%02d%02d%02d%02d" % [d.year, d.month, d.day, d.hour, d.minute, d.second]

func _init() -> void:
	var port := 9000
	var args := OS.get_cmdline_args()
	for arg in args:
		if arg.begins_with("--zone-port="):
			port = arg.split("=", true, 1)[1].to_int()
	var crypto := Crypto.new()
	var key := crypto.generate_ecdsa()
	var now := int(Time.get_unix_time_from_system())
	var cert := crypto.generate_self_signed_certificate_san(
		key, "CN=xr-grid-zone", _fmt_validity(now), _fmt_validity(now + 13 * 86400),
		PackedStringArray(["DNS:localhost", "IP:127.0.0.1"]))
	_server = WebTransportPeer.new()
	var err := _server.create_server(port, "/wt", cert, key)
	if err != OK:
		print("Zone: failed to start on port %d (err=%d)" % [port, err])
		quit(1)
		return
	print("Zone: WebTransport listening on port %d/wt" % port)

func _process(_delta: float) -> bool:
	_server.poll()
	while _server.get_available_packet_count() > 0:
		var pkt: PackedByteArray = _server.get_packet()
		if pkt.size() == 100:
			_server.set_target_peer(0)
			_server.set_transfer_mode(MultiplayerPeer.TRANSFER_MODE_UNRELIABLE)
			_server.put_packet(pkt)
	return false
