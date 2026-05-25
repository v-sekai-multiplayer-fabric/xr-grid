# Copyright (c) 2023-present. This file is part of V-Sekai https://v-sekai.org/.
# K. S. Ernest (Fire) Lee & Contributors (see .all-contributorsrc).
# xr_origin.gd
# SPDX-License-Identifier: MIT

extends Node3D

var interface: XRInterface = null
var vr_supported: bool = false


func _ready() -> void:
	interface = XRServer.find_interface("OpenXR")
	if interface and interface.is_initialized():
		print_verbose("OpenXR initialised successfully")
		var vp: Viewport = get_viewport()
		vp.use_xr = true
		print_verbose(vp.size)
	var args := OS.get_cmdline_args()
	var zone_addr := "127.0.0.1"
	var zone_port := 9000
	for arg in args:
		if arg.begins_with("--fabric-server="):
			var parts := arg.split("=", true, 1)[1].split(":")
			zone_addr = parts[0]
			if parts.size() > 1:
				zone_port = parts[1].to_int()
	FabricManager.connect_to_zone(zone_addr, zone_port)
