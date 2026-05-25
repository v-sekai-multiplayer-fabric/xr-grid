# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
class_name RemotePlayer
extends Node3D

var remote_player_id: int = 0
var _syncs: Array[FabricTransformSync] = []
const OrientationOrbScript = preload("res://addons/procedural_3d_grid/core/fabric/orientation_orb.gd")
var _orbs: Array = []

func _ready() -> void:
	var color: Color = _color_from_id(remote_player_id)
	for i in 3:
		var part := Node3D.new()
		part.name = ["head", "hand_left", "hand_right"][i]
		add_child(part)
		var orb: Node3D = OrientationOrbScript.new()
		orb.setup(color if i > 0 else color.darkened(0.3))
		part.add_child(orb)
		_orbs.append(orb)
		var sync := FabricTransformSync.new()
		sync.is_local = false
		sync.sub_index = i
		sync.entity_class = 1
		part.add_child(sync)
		_syncs.append(sync)

func apply_packet(decoded: Dictionary) -> void:
	var si: int = decoded["sub_index"]
	if si >= 0 and si < _syncs.size():
		_syncs[si].apply_remote(decoded)
		_orbs[si].update_from_basis(Basis(decoded["rotation"]))

static func _color_from_id(pid: int) -> Color:
	var hue: float = fmod(pid * 0.618033988749895, 1.0)
	return Color.from_ok_hsl(hue, 0.8, 0.7)
