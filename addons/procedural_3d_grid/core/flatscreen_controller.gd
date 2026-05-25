# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# Steam Deck / flatscreen gamepad controller. Replaces XR tracking with
# dual-stick camera + simulated hand positions. Attach to XROrigin3D;
# drives camera and hand transforms when OpenXR is unavailable.
#
# Left stick: move (WASD / left stick)
# Right stick: look (mouse / right stick)
# Triggers: draw (left trigger = left hand, right trigger = right hand)
extends Node

const MOVE_SPEED := 3.0
const TURN_SPEED := 2.0
const MOUSE_SENS := 0.002
const HAND_OFFSET_L := Vector3(-0.3, -0.3, -0.5)
const HAND_OFFSET_R := Vector3(0.3, -0.3, -0.5)

var _cam: Camera3D
var _hand_l: Node3D
var _hand_r: Node3D
var _yaw: float = 0.0
var _pitch: float = 0.0
var _active: bool = false

func _ready() -> void:
	var origin: Node3D = get_parent()
	_cam = origin.get_node_or_null("XRCamera3D")
	_hand_l = origin.get_node_or_null("hand_left")
	_hand_r = origin.get_node_or_null("hand_right")
	var xr: XRInterface = XRServer.find_interface("OpenXR")
	_active = xr == null or not xr.is_initialized()
	if _active:
		print("FlatscreenController: active (no XR)")
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseMotion:
		_yaw -= event.relative.x * MOUSE_SENS
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENS, -PI / 2.0, PI / 2.0)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	if not _active:
		return
	var origin: Node3D = get_parent()
	# Right stick look
	var look_x: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var look_y: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if abs(look_x) > 0.1:
		_yaw -= look_x * TURN_SPEED * delta
	if abs(look_y) > 0.1:
		_pitch = clampf(_pitch - look_y * TURN_SPEED * delta, -PI / 2.0, PI / 2.0)
	# Apply rotation to camera
	var cam_basis := Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, _pitch)
	if _cam:
		_cam.transform.basis = cam_basis
	# Left stick move
	var move_x: float = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var move_y: float = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	if Input.is_key_pressed(KEY_W):
		move_y -= 1.0
	if Input.is_key_pressed(KEY_S):
		move_y += 1.0
	if Input.is_key_pressed(KEY_A):
		move_x -= 1.0
	if Input.is_key_pressed(KEY_D):
		move_x += 1.0
	var move_dir := Vector3(move_x, 0, move_y)
	if move_dir.length() > 0.1:
		move_dir = move_dir.normalized()
		var forward := cam_basis * Vector3.FORWARD
		forward.y = 0
		forward = forward.normalized()
		var right := cam_basis * Vector3.RIGHT
		right.y = 0
		right = right.normalized()
		origin.position += (forward * -move_dir.z + right * move_dir.x) * MOVE_SPEED * delta
	# Position hands relative to camera
	if _hand_l:
		_hand_l.transform = Transform3D(cam_basis, cam_basis * HAND_OFFSET_L + Vector3(0, 1.7, 0))
	if _hand_r:
		_hand_r.transform = Transform3D(cam_basis, cam_basis * HAND_OFFSET_R + Vector3(0, 1.7, 0))
