# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# 7-pointed orientation orb debug visualization.
# Renders a transform as 1 origin + 6 basis axis endpoint spheres,
# matching the many_bone_ik effector heading representation.
class_name OrientationOrb
extends Node3D

const AXIS_RADIUS := 0.08
const SPHERE_RADIUS := 0.015
const AXIS_COLORS: Array[Color] = [
	Color.RED, Color(0.5, 0, 0),
	Color.GREEN, Color(0, 0.5, 0),
	Color.BLUE, Color(0, 0, 0.5),
]

var _spheres: Array[MeshInstance3D] = []
var _lines: MeshInstance3D
var _player_color: Color = Color.WHITE

func setup(player_color: Color) -> void:
	_player_color = player_color
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = SPHERE_RADIUS
	sphere_mesh.height = SPHERE_RADIUS * 2.0
	# Point 0: origin
	var origin_sphere := MeshInstance3D.new()
	origin_sphere.mesh = sphere_mesh
	var origin_mat := StandardMaterial3D.new()
	origin_mat.albedo_color = player_color
	origin_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	origin_sphere.material_override = origin_mat
	add_child(origin_sphere)
	_spheres.append(origin_sphere)
	# Points 1-6: ±X, ±Y, ±Z
	for i in 6:
		var s := MeshInstance3D.new()
		s.mesh = sphere_mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = AXIS_COLORS[i]
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		s.material_override = mat
		add_child(s)
		_spheres.append(s)
	# Axis lines
	_lines = MeshInstance3D.new()
	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = player_color.lightened(0.3)
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_mat.albedo_color.a = 0.5
	_lines.material_override = line_mat
	add_child(_lines)

func update_from_basis(b: Basis) -> void:
	if _spheres.size() < 7:
		return
	_spheres[0].position = Vector3.ZERO
	for axis in 3:
		var col: Vector3 = b.get_column(axis) * AXIS_RADIUS
		_spheres[1 + axis * 2].position = col
		_spheres[2 + axis * 2].position = -col
	# Rebuild axis lines
	var im := ImmediateMesh.new()
	for axis in 3:
		var col: Vector3 = b.get_column(axis) * AXIS_RADIUS
		im.surface_begin(Mesh.PRIMITIVE_LINES)
		im.surface_add_vertex(-col)
		im.surface_add_vertex(col)
		im.surface_end()
	_lines.mesh = im
