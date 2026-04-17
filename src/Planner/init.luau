local PathfindingService = game:GetService("PathfindingService")

local Goal = require(script.Parent.Shared.Goal)
local NormalizeResult = require(script.NormalizeResult)

local Planner = {}
Planner.__index = Planner

local function shallowMerge(...)
	local merged = {}
	for _, source in ipairs({ ... }) do
		if source ~= nil then
			for key, value in pairs(source) do
				merged[key] = value
			end
		end
	end

	return merged
end

local function buildAgentParameters(defaultAgentParameters, requestOptions)
	local requestAgentParameters = if requestOptions then requestOptions.agentParameters else nil
	local mergedAgentParameters = shallowMerge(defaultAgentParameters, requestAgentParameters)

	if requestOptions ~= nil then
		if requestOptions.costs ~= nil then
			mergedAgentParameters.Costs = requestOptions.costs
		end

		if requestOptions.waypointSpacing ~= nil then
			mergedAgentParameters.WaypointSpacing = requestOptions.waypointSpacing
		end
	end

	return mergedAgentParameters
end

function Planner.new(config)
	local self = setmetatable({}, Planner)
	self._config = config or {}

	return self
end

function Planner:_computeInternal(startPosition, goal, requestOptions)
	local goalPosition, goalError = Goal.resolvePosition(goal)
	if goalPosition == nil then
		return NormalizeResult.fromPathData({
			startPosition = startPosition,
			status = "ComputeError",
			computeTimeMs = 0,
			waypoints = {},
			failureReason = goalError or "InvalidGoal",
		})
	end

	local mergedAgentParameters = buildAgentParameters(self._config.agentParameters, requestOptions)
	local path = PathfindingService:CreatePath(mergedAgentParameters)
	local computeStart = os.clock()
	local ok, errorMessage = pcall(function()
		path:ComputeAsync(startPosition, goalPosition)
	end)
	local computeTimeMs = (os.clock() - computeStart) * 1000

	if not ok then
		local result = NormalizeResult.fromPathData({
			startPosition = startPosition,
			status = "ComputeError",
			computeTimeMs = computeTimeMs,
			waypoints = {},
		})
		result.failureReason = "ComputeError"
		result.errorMessage = errorMessage
		return result
	end

	local status = path.Status.Name
	local result = NormalizeResult.fromPathData({
		startPosition = startPosition,
		status = status,
		computeTimeMs = computeTimeMs,
		waypoints = if status == "Success" then path:GetWaypoints() else {},
	})

	result.goalPosition = goalPosition
	result._rawPath = path

	return result
end

function Planner:Compute(startPosition, goal, requestOptions)
	return self:_computeInternal(startPosition, goal, requestOptions)
end

return Planner
