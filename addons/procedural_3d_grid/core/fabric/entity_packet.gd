# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
class_name EntityPacket
extends RefCounted

const PACKET_SIZE := 100
const PLAYER_ENTITY_BASE := 2_000_000
const STROKE_ENTITY_BASE := 1_000_000

static func encode(
	global_id: int,
	pos: Vector3,
	vel: Vector3,
	quat: Quaternion,
	entity_class: int,
	owner_id: int,
	hlc_frame: int,
	hlc_counter: int,
	sub_index: int = 0
) -> PackedByteArray:
	var buf := StreamPeerBuffer.new()
	buf.big_endian = false
	buf.resize(PACKET_SIZE)
	buf.seek(0)
	# Bytes 0-3: global_id
	buf.put_u32(global_id)
	# Bytes 4-27: position (3x f64)
	buf.put_double(pos.x)
	buf.put_double(pos.y)
	buf.put_double(pos.z)
	# Bytes 28-33: velocity (3x i16)
	buf.put_16(_quantize_vel(vel.x))
	buf.put_16(_quantize_vel(vel.y))
	buf.put_16(_quantize_vel(vel.z))
	# Bytes 34-39: acceleration (3x i16, zero)
	buf.put_16(0)
	buf.put_16(0)
	buf.put_16(0)
	# Bytes 40-43: HLC
	buf.put_u32(((hlc_frame & 0xFFFFFF) << 8) | (hlc_counter & 0xFF))
	# Bytes 44-47: payload[0] = class(8b high) | flags(8b) | owner(16b low)
	buf.put_u32((entity_class << 24) | (owner_id & 0xFFFF))
	# Bytes 48-51: payload[1] = sub_index(16b high) | 0
	buf.put_u32(sub_index << 16)
	# Bytes 52-59: payload[2-3] = rotation swing-twist
	var rot := SwingTwistCodec.encode_rotation_i16(quat)
	buf.put_u32(_pack_two_i16(rot[1], rot[2]))  # swing_y | swing_z
	buf.put_u32(_pack_two_i16(rot[0], 0))        # twist_x | reserved
	# Bytes 60-99: payload[4-13] = zeros (already zeroed by resize)
	return buf.data_array

static func decode(data: PackedByteArray) -> Dictionary:
	if data.size() < PACKET_SIZE:
		return {}
	var buf := StreamPeerBuffer.new()
	buf.big_endian = false
	buf.data_array = data
	buf.seek(0)
	var global_id: int = buf.get_u32()
	var pos := Vector3(buf.get_double(), buf.get_double(), buf.get_double())
	var vel := Vector3(
		_dequantize_vel(buf.get_16()),
		_dequantize_vel(buf.get_16()),
		_dequantize_vel(buf.get_16()))
	buf.get_16(); buf.get_16(); buf.get_16()  # skip acceleration
	var hlc_raw: int = buf.get_u32()
	var hlc_frame: int = (hlc_raw >> 8) & 0xFFFFFF
	var hlc_counter: int = hlc_raw & 0xFF
	var p0: int = buf.get_u32()
	var entity_class: int = (p0 >> 24) & 0xFF
	var owner_id: int = p0 & 0xFFFF
	var p1: int = buf.get_u32()
	var sub_index: int = (p1 >> 16) & 0xFFFF
	var p2: int = buf.get_u32()
	var p3: int = buf.get_u32()
	var swing_y_i16: int = _unpack_lo_i16(p2)
	var swing_z_i16: int = _unpack_hi_i16(p2)
	var twist_x_i16: int = _unpack_lo_i16(p3)
	var rotation: Quaternion = SwingTwistCodec.decode_rotation_i16(twist_x_i16, swing_y_i16, swing_z_i16)
	return {
		"global_id": global_id,
		"position": pos,
		"velocity": vel,
		"rotation": rotation,
		"entity_class": entity_class,
		"owner_id": owner_id,
		"sub_index": sub_index,
		"hlc_frame": hlc_frame,
		"hlc_counter": hlc_counter,
	}

static func _quantize_vel(v: float) -> int:
	return int(clampf(v * 1000.0, -32767.0, 32767.0))

static func _dequantize_vel(v: int) -> float:
	return v / 1000.0

static func _pack_two_i16(lo: int, hi: int) -> int:
	return (lo & 0xFFFF) | ((hi & 0xFFFF) << 16)

static func _unpack_lo_i16(v: int) -> int:
	var raw: int = v & 0xFFFF
	return raw - 0x10000 if raw >= 0x8000 else raw

static func _unpack_hi_i16(v: int) -> int:
	var raw: int = (v >> 16) & 0xFFFF
	return raw - 0x10000 if raw >= 0x8000 else raw
