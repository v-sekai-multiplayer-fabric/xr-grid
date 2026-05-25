# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
class_name SwingTwistCodec
extends RefCounted

const QUANTIZE_SCALE := 32767.0

static func swing_twist_to_quat(vec: Vector3) -> Quaternion:
	var x: float = vec.x
	var y: float = vec.y
	var z: float = vec.z
	var yz: float = sqrt(y * y + z * z)
	var sinc: float = 0.5 if abs(yz) < 1e-8 else sin(yz / 2.0) / yz
	var swing_w: float = cos(yz / 2.0)
	var twist_w: float = cos(x / 2.0)
	var twist_x: float = sin(x / 2.0)
	return Quaternion(
		swing_w * twist_x,
		(z * twist_x + y * twist_w) * sinc,
		(z * twist_w - y * twist_x) * sinc,
		swing_w * twist_w)

static func quat_to_swing_twist(q: Quaternion) -> Vector3:
	var a: float = q.x
	var b: float = q.y
	var c: float = q.z
	var d: float = q.w
	var twist_x: float = 0.0
	var denom: float = a * a + d * d
	if not is_zero_approx(denom):
		twist_x = sqrt(a * a / denom)
	twist_x = minf(twist_x, 1.0)
	if a < 0:
		twist_x *= -1
	if d < 0:
		twist_x *= -1
	var twist_w: float = sqrt(1.0 - twist_x * twist_x)
	var swing_w: float
	if is_zero_approx(twist_x):
		swing_w = d / twist_w if not is_zero_approx(twist_w) else 1.0
	else:
		swing_w = a / twist_x
	var x: float = asin(clampf(twist_x, -1.0, 1.0)) * 2.0
	var yz: float = acos(clampf(swing_w, -1.0, 1.0)) * 2.0
	var sinc: float = 0.5 if abs(yz) < 1e-8 else sin(yz / 2.0) / yz
	var safe_twist_x: float = 1e-8 if is_zero_approx(twist_x) else twist_x
	var safe_twist_w: float = 1e-8 if is_zero_approx(twist_w) else twist_w
	var y: float = (b / safe_twist_x - c / safe_twist_w) / (safe_twist_w / safe_twist_x + safe_twist_x / safe_twist_w) / sinc
	var z: float = (b / safe_twist_w + c / safe_twist_x) / (safe_twist_x / safe_twist_w + safe_twist_w / safe_twist_x) / sinc
	return Vector3(x, y, z)

static func encode_rotation_i16(q: Quaternion) -> PackedInt32Array:
	var v: Vector3 = quat_to_swing_twist(q.normalized())
	var result := PackedInt32Array()
	result.resize(3)
	result[0] = int(clampf(v.x / PI, -1.0, 1.0) * QUANTIZE_SCALE)
	result[1] = int(clampf(v.y / PI, -1.0, 1.0) * QUANTIZE_SCALE)
	result[2] = int(clampf(v.z / PI, -1.0, 1.0) * QUANTIZE_SCALE)
	return result

static func decode_rotation_i16(twist_x_i16: int, swing_y_i16: int, swing_z_i16: int) -> Quaternion:
	var v := Vector3(
		(twist_x_i16 / QUANTIZE_SCALE) * PI,
		(swing_y_i16 / QUANTIZE_SCALE) * PI,
		(swing_z_i16 / QUANTIZE_SCALE) * PI)
	return swing_twist_to_quat(v)
