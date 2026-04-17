-- selene: allow(incorrect_standard_library_use)

local PrepareReplan = require("../../src/Navigator/PrepareReplan")

local function expectEqual(actual, expected, context)
	if actual ~= expected then
		error(("%s: expected %s, got %s"):format(context, tostring(expected), tostring(actual)))
	end
end

return {
	name = "Navigator replan preparation consumes the pending reason",
	run = function()
		local run = {
			replanReason = "BlockedAhead",
		}

		local explicitReason = PrepareReplan.consume(run)
		expectEqual(explicitReason, "BlockedAhead", "returned explicit reason")
		expectEqual(run.replanReason, nil, "cleared explicit reason")

		local defaultedReason = PrepareReplan.consume(run)
		expectEqual(defaultedReason, "BlockedAhead", "defaulted reason")
		expectEqual(run.replanReason, nil, "reason stays cleared")
	end,
}
