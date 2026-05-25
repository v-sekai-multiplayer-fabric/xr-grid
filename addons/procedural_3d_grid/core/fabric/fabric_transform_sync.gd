# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
class_name FabricTransformSync
extends Node

@export var entity_class: int = 1
@export var sub_index: int = 0
@export var send_rate_hz: float = 30.0
@export var is_local: bool = true

var _target: Node3D = null
var _global_id: int = 0
var _send_timer: float = 0.0
var _send_count: int = 0

func _ready() -> void:
	_target = get_parent() as Node3D
	assert(_target != null, "FabricTransformSync must be a child of Node3D")

func _process(delta: float) -> void:
	if not is_local:
		return
	var mgr: Node = get_node_or_null("/root/FabricManager")
	if mgr == null or mgr.state != mgr.State.CONNECTED:
		return
	_send_timer += delta
	var interval: float = 1.0 / send_rate_hz
	if _send_timer < interval:
		return
	_send_timer -= interval
	var pid_safe: int = mgr.local_player_id % EntityPacket.MAX_PLAYER_ID
	_global_id = EntityPacket.PLAYER_ENTITY_BASE + pid_safe * 3 + sub_index
	var t: Transform3D = _target.global_transform
	var pkt: PackedByteArray = EntityPacket.encode(
		_global_id,
		t.origin,
		Vector3.ZERO,
		t.basis.get_rotation_quaternion(),
		entity_class,
		mgr.local_player_id,
		mgr.frame_counter,
		mgr.hlc_counter,
		sub_index)
	mgr.hlc_counter += 1
	mgr.send_entity(pkt)
	_send_count += 1
	if _send_count == 1 or _send_count % 300 == 0:
		print("FabricTransformSync[%d]: sent %d (pos=%s)" % [sub_index, _send_count, str(t.origin)])

func apply_remote(decoded: Dictionary) -> void:
	if _target == null:
		return
	_target.global_position = decoded["position"]
	_target.global_transform.basis = Basis(decoded["rotation"])
