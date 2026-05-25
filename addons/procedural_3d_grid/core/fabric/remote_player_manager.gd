# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
class_name RemotePlayerManager
extends Node

const TIMEOUT_SEC := 10.0

var _players: Dictionary = {}  # player_id → RemotePlayer
var _last_seen: Dictionary = {}  # player_id → float (time)

func _ready() -> void:
	var mgr: Node = get_node_or_null("/root/FabricManager")
	if mgr:
		mgr.entity_received.connect(_on_entity_received)

func _process(delta: float) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	var expired: Array = []
	for pid: int in _last_seen:
		if now - _last_seen[pid] > TIMEOUT_SEC:
			expired.append(pid)
	for pid: int in expired:
		if _players.has(pid):
			_players[pid].queue_free()
			_players.erase(pid)
		_last_seen.erase(pid)

func _on_entity_received(packet: PackedByteArray) -> void:
	var decoded: Dictionary = EntityPacket.decode(packet)
	if decoded.is_empty():
		return
	var gid: int = decoded["global_id"]
	if gid < EntityPacket.PLAYER_ENTITY_BASE:
		return
	var offset: int = gid - EntityPacket.PLAYER_ENTITY_BASE
	var remote_pid: int = offset / 3
	var mgr: Node = get_node_or_null("/root/FabricManager")
	if mgr:
		var local_safe: int = mgr.local_player_id % EntityPacket.MAX_PLAYER_ID
		if remote_pid == local_safe:
			return
	_last_seen[remote_pid] = Time.get_ticks_msec() / 1000.0
	if not _players.has(remote_pid):
		var rp := RemotePlayer.new()
		rp.remote_player_id = remote_pid
		rp.name = "RemotePlayer_%d" % remote_pid
		add_child(rp)
		_players[remote_pid] = rp
		print("RemotePlayerManager: spawned player %d (gid=%d pos=%s)" % [remote_pid, gid, str(decoded["position"])])
	_players[remote_pid].apply_packet(decoded)
