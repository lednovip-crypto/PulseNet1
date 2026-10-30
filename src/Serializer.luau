--!strict
--!optimize 2
--[=[
    PulseNet - Fast Buffer Serializer
    Encodes and decodes network payloads using Roblox Luau buffers for maximum throughput.
]=]

local Serializer = {}

-- Binary Types
local TYPE_NIL = 0
local TYPE_BOOL_FALSE = 1
local TYPE_BOOL_TRUE = 2
local TYPE_U8 = 3
local TYPE_U16 = 4
local TYPE_U32 = 5
local TYPE_I32 = 6
local TYPE_F32 = 7
local TYPE_F64 = 8
local TYPE_STRING = 9
local TYPE_VECTOR3 = 10

export type Serializer = typeof(Serializer)

function Serializer.packVector3(v: Vector3): buffer
	local b = buffer.create(13)
	buffer.writeu8(b, 0, TYPE_VECTOR3)
	buffer.writef32(b, 1, v.X)
	buffer.writef32(b, 5, v.Y)
	buffer.writef32(b, 9, v.Z)
	return b
end

function Serializer.unpackVector3(b: buffer, offset: number?): Vector3
	local off = offset or 0
	local tag = buffer.readu8(b, off)
	if tag ~= TYPE_VECTOR3 then
		error("Buffer does not contain Vector3 at offset " .. tostring(off))
	end
	local x = buffer.readf32(b, off + 1)
	local y = buffer.readf32(b, off + 5)
	local z = buffer.readf32(b, off + 9)
	return Vector3.new(x, y, z)
end

function Serializer.packNumber(n: number): buffer
	local b = buffer.create(9)
	buffer.writeu8(b, 0, TYPE_F64)
	buffer.writef64(b, 1, n)
	return b
end

function Serializer.unpackNumber(b: buffer, offset: number?): number
	local off = offset or 0
	local tag = buffer.readu8(b, off)
	if tag ~= TYPE_F64 then
		error("Buffer does not contain f64 number at offset " .. tostring(off))
	end
	return buffer.readf64(b, off + 1)
end

function Serializer.packString(str: string): buffer
	local len = #str
	local b = buffer.create(1 + 2 + len)
	buffer.writeu8(b, 0, TYPE_STRING)
	buffer.writeu16(b, 1, len)
	buffer.writestring(b, 3, str, len)
	return b
end

function Serializer.unpackString(b: buffer, offset: number?): (string, number)
	local off = offset or 0
	local tag = buffer.readu8(b, off)
	if tag ~= TYPE_STRING then
		error("Buffer does not contain string at offset " .. tostring(off))
	end
	local len = buffer.readu16(b, off + 1)
	local str = buffer.readstring(b, off + 3, len)
	return str, off + 3 + len
end

return Serializer
