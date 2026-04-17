local PositionMath = {}

local function extractComponents(value)
	if typeof(value) == "Vector3" then
		return value.X, value.Y, value.Z
	end

	if type(value) ~= "table" then
		error(("expected Vector3 or position table, got %s"):format(typeof(value)))
	end

	local x = value.x or value.X or 0
	local y = value.y or value.Y or 0
	local z = value.z or value.Z or 0

	return x, y, z
end

function PositionMath.distance(a, b)
	local ax, ay, az = extractComponents(a)
	local bx, by, bz = extractComponents(b)
	local dx = bx - ax
	local dy = by - ay
	local dz = bz - az

	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function PositionMath.toOffsetVector(offset)
	return Vector3.new(offset.x, offset.y, offset.z)
end

function PositionMath.extractComponents(value)
	return extractComponents(value)
end

return PositionMath
