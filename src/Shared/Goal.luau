local Goal = {}

function Goal.resolvePosition(goal)
	local goalType = typeof(goal)

	if goalType == "Vector3" then
		return goal
	end

	if goalType == "Instance" then
		if goal:IsA("BasePart") then
			return goal.Position
		end

		if goal:IsA("Attachment") then
			return goal.WorldPosition
		end
	end

	return nil, "InvalidGoal"
end

function Goal.resolveSpacingKey(goal, explicitSpacingKey)
	if explicitSpacingKey ~= nil then
		return explicitSpacingKey
	end

	local goalType = typeof(goal)
	if goalType == "Instance" and (goal:IsA("BasePart") or goal:IsA("Attachment")) then
		return goal
	end

	return nil
end

return Goal
