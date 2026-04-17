-- selene: allow(incorrect_standard_library_use)

local SpacingPolicy = require("../../src/Coordinator/SpacingPolicy")

local function expectEqual(actual, expected, context)
	if actual ~= expected then
		error(("%s: expected %s, got %s"):format(context, tostring(expected), tostring(actual)))
	end
end

local function expectTruthy(value, context)
	if not value then
		error(("%s: expected truthy value"):format(context))
	end
end

return {
	name = "SpacingPolicy assigns stable unique slots",
	run = function()
		local policy = SpacingPolicy.new()
		policy:SetTarget("goal:bridge", 10, 4)

		local first = policy:Acquire("goal:bridge", "npc-1")
		local second = policy:Acquire("goal:bridge", "npc-2")
		local again = policy:Acquire("goal:bridge", "npc-1")

		expectEqual(first.slotIndex, 1, "first slot")
		expectEqual(second.slotIndex, 2, "second slot")
		expectEqual(again.slotIndex, 1, "stable slot reuse")
		expectTruthy(
			first.offset.x ~= second.offset.x or first.offset.z ~= second.offset.z,
			"unique offset"
		)
		expectEqual(math.floor(first.offset.x + 0.5), 10, "radius projected on x axis")

		policy:Release("goal:bridge", "npc-1")
		local recycled = policy:Acquire("goal:bridge", "npc-3")
		expectEqual(recycled.slotIndex, 1, "released slot recycled")
	end,
}
