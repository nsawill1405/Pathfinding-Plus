-- selene: allow(incorrect_standard_library_use)

local NormalizeResult = require("../../src/Planner/NormalizeResult")

local function expectEqual(actual, expected, context)
	if actual ~= expected then
		error(("%s: expected %s, got %s"):format(context, tostring(expected), tostring(actual)))
	end
end

return {
	name = "NormalizeResult filters tiny segments and labels failures",
	run = function()
		local result = NormalizeResult.fromPathData({
			startPosition = { x = 0, y = 0, z = 0 },
			status = "Success",
			computeTimeMs = 12.5,
			waypoints = {
				{ Position = { x = 0, y = 0, z = 0 }, Action = "Walk", Label = "" },
				{ Position = { x = 0.05, y = 0, z = 0.04 }, Action = "Walk", Label = "" },
				{ Position = { x = 5, y = 0, z = 0 }, Action = "Jump", Label = "Ladder" },
			},
		})

		expectEqual(result.ok, true, "success flag")
		expectEqual(#result.waypoints, 1, "tiny first segment filtered")
		expectEqual(result.waypoints[1].Label, "Ladder", "label preserved")
		expectEqual(math.floor(result.cost), 5, "distance cost")

		local failed = NormalizeResult.fromPathData({
			startPosition = { x = 0, y = 0, z = 0 },
			status = "NoPath",
			computeTimeMs = 3,
			waypoints = {},
		})

		expectEqual(failed.ok, false, "failed flag")
		expectEqual(failed.failureReason, "NoPath", "no path reason")

		local invalidGoal = NormalizeResult.fromPathData({
			startPosition = { x = 0, y = 0, z = 0 },
			status = "ComputeError",
			computeTimeMs = 1,
			waypoints = {},
			failureReason = "InvalidGoal",
		})

		expectEqual(invalidGoal.failureReason, "InvalidGoal", "explicit failure reason")
	end,
}
