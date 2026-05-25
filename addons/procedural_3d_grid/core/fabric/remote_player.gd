# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
class_name RemotePlayer
extends Node3D

var remote_player_id: int = 0
var _syncs: Array[FabricTransformSync] = []

func _ready() -> void:
	var color: Color = _color_from_id(remote_player_id)
	for i in 3:
		var part := Node3D.new()
		part.name = ["head", "hand_left", "hand_right"][i]
		add_child(part)
		var mesh_inst := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.04 if i == 0 else 0.03
		sphere.height = sphere.radius * 2.0
		mesh_inst.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color if i > 0 else color.darkened(0.3)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh_inst.material_override = mat
		part.add_child(mesh_inst)
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

static func _color_from_id(pid: int) -> Color:
	var hue: float = fmod(pid * 0.618033988749895, 1.0)
	return Color.from_hsv(hue, 0.7, 0.9)
