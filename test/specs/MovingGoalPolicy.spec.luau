-- selene: allow(incorrect_standard_library_use)

local MovingGoalPolicy = require("../../src/Navigator/MovingGoalPolicy")

local function expectEqual(actual, expected, context)
	if actual ~= expected then
		error(("%s: expected %s, got %s"):format(context, tostring(expected), tostring(actual)))
	end
end

return {
	name = "MovingGoalPolicy triggers only for enabled drifting instance goals",
	run = function()
		local disabled = MovingGoalPolicy.shouldRepath({
			enabled = false,
			goalType = "Instance",
			lastGoalPosition = { x = 0, y = 0, z = 0 },
			currentGoalPosition = { x = 10, y = 0, z = 0 },
			threshold = 2,
			now = 10,
			lastRepathAt = 0,
			interval = 0.5,
		})
		expectEqual(disabled, false, "disabled mode")

		local vectorGoal = MovingGoalPolicy.shouldRepath({
			enabled = true,
			goalType = "Vector3",
			lastGoalPosition = { x = 0, y = 0, z = 0 },
			currentGoalPosition = { x = 10, y = 0, z = 0 },
			threshold = 2,
			now = 10,
			lastRepathAt = 0,
			interval = 0.5,
		})
		expectEqual(vectorGoal, false, "vector goal")

		local belowThreshold = MovingGoalPolicy.shouldRepath({
			enabled = true,
			goalType = "Instance",
			lastGoalPosition = { x = 0, y = 0, z = 0 },
			currentGoalPosition = { x = 1, y = 0, z = 0 },
			threshold = 2,
			now = 10,
			lastRepathAt = 0,
			interval = 0.5,
		})
		expectEqual(belowThreshold, false, "below threshold")

		local tooSoon = MovingGoalPolicy.shouldRepath({
			enabled = true,
			goalType = "Instance",
			lastGoalPosition = { x = 0, y = 0, z = 0 },
			currentGoalPosition = { x = 5, y = 0, z = 0 },
			threshold = 2,
			now = 0.2,
			lastRepathAt = 0,
			interval = 0.5,
		})
		expectEqual(tooSoon, false, "interval gate")

		local shouldRepath = MovingGoalPolicy.shouldRepath({
			enabled = true,
			goalType = "Instance",
			lastGoalPosition = { x = 0, y = 0, z = 0 },
			currentGoalPosition = { x = 5, y = 0, z = 0 },
			threshold = 2,
			now = 10,
			lastRepathAt = 0,
			interval = 0.5,
		})
		expectEqual(shouldRepath, true, "moved enough")
	end,
}
