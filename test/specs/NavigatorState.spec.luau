-- selene: allow(incorrect_standard_library_use)

local StateMachine = require("../../src/Navigator/StateMachine")

local function expectEqual(actual, expected, context)
	if actual ~= expected then
		error(("%s: expected %s, got %s"):format(context, tostring(expected), tostring(actual)))
	end
end

return {
	name = "StateMachine tracks active, replanning, and cancellation flow",
	run = function()
		local machine = StateMachine.new()
		expectEqual(machine:GetState(), "Idle", "initial state")

		machine:Begin(false)
		expectEqual(machine:GetState(), "Planning", "after begin")

		machine:PathReady(false)
		expectEqual(machine:GetState(), "Moving", "after path ready")

		machine:RequestReplan("BlockedAhead")
		expectEqual(machine:GetState(), "Replanning", "after replan")

		machine:PathReady(true)
		expectEqual(machine:GetState(), "Moving", "after replan path ready")

		machine:Cancel("Replaced")
		expectEqual(machine:GetState(), "Cancelled", "after cancel")
		expectEqual(machine:GetLastReason(), "Replaced", "cancel reason")
	end,
}
