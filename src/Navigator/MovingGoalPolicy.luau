-- selene: allow(incorrect_standard_library_use)

local PositionMath = if script
	then require(script.Parent.Parent.Shared.PositionMath)
	else require("../Shared/PositionMath")

local MovingGoalPolicy = {}

function MovingGoalPolicy.shouldRepath(input)
	if input.enabled ~= true then
		return false
	end

	if input.goalType ~= "Instance" then
		return false
	end

	if input.lastGoalPosition == nil or input.currentGoalPosition == nil then
		return false
	end

	if input.lastRepathAt ~= nil and (input.now - input.lastRepathAt) < input.interval then
		return false
	end

	return PositionMath.distance(input.lastGoalPosition, input.currentGoalPosition)
		>= input.threshold
end

return MovingGoalPolicy
