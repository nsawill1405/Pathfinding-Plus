-- selene: allow(incorrect_standard_library_use)

local PositionMath = if script
	then require(script.Parent.Parent.Shared.PositionMath)
	else require("../Shared/PositionMath")

local NormalizeResult = {}

local MIN_SEGMENT_DISTANCE = 0.25

local function collectBlockedLabels(waypoints)
	local seen = {}
	local labels = {}

	for _, waypoint in ipairs(waypoints) do
		local label = waypoint.Label
		if type(label) == "string" and label ~= "" and not seen[label] then
			seen[label] = true
			table.insert(labels, label)
		end
	end

	return labels
end

local function normalizeFailureReason(status)
	if status == "Success" then
		return nil
	end

	if status == "NoPath" then
		return "NoPath"
	end

	return "ComputeError"
end

local function filterWaypoints(startPosition, waypoints)
	local filtered = {}
	local previousPosition = startPosition
	local cost = 0

	for _, waypoint in ipairs(waypoints) do
		local segment = PositionMath.distance(previousPosition, waypoint.Position)
		if segment >= MIN_SEGMENT_DISTANCE then
			cost += segment
			previousPosition = waypoint.Position
			table.insert(filtered, waypoint)
		end
	end

	return filtered, cost
end

function NormalizeResult.fromPathData(input)
	local status = input.status or "ComputeError"
	local ok = status == "Success"
	local filteredWaypoints = {}
	local cost = 0

	if ok then
		filteredWaypoints, cost = filterWaypoints(input.startPosition, input.waypoints or {})
	end

	return {
		ok = ok,
		status = status,
		waypoints = filteredWaypoints,
		cost = cost,
		computeTimeMs = input.computeTimeMs or 0,
		blockedLabels = collectBlockedLabels(filteredWaypoints),
		failureReason = input.failureReason or normalizeFailureReason(status),
	}
end

return NormalizeResult
