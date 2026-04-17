-- selene: allow(incorrect_standard_library_use)

local RequestQueue = require("../../src/Coordinator/RequestQueue")

local function expectEqual(actual, expected, context)
	if actual ~= expected then
		error(("%s: expected %s, got %s"):format(context, tostring(expected), tostring(actual)))
	end
end

return {
	name = "RequestQueue schedules ready work fairly",
	run = function()
		local queue = RequestQueue.new({
			perNavigatorCooldown = 1,
		})

		queue:Enqueue({
			navigatorId = "alpha",
			label = "first-alpha",
		}, 0)

		queue:Enqueue({
			navigatorId = "alpha",
			label = "second-alpha",
		}, 0.05)

		queue:Enqueue({
			navigatorId = "beta",
			label = "first-beta",
		}, 0.1)

		local first = queue:PopReady(0)
		expectEqual(first.label, "first-alpha", "first ready item")

		local second = queue:PopReady(0.1)
		expectEqual(second.label, "first-beta", "second ready item")

		local noneReady = queue:PopReady(0.5)
		expectEqual(noneReady, nil, "cooldown gate")

		local third = queue:PopReady(1.01)
		expectEqual(third.label, "second-alpha", "deferred item")
	end,
}
