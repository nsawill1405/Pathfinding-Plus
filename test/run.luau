-- selene: allow(incorrect_standard_library_use)

local specs = {
	require("./specs/RequestQueue.spec"),
	require("./specs/SpacingPolicy.spec"),
	require("./specs/NormalizeResult.spec"),
	require("./specs/NavigatorState.spec"),
	require("./specs/NavigatorReplan.spec"),
	require("./specs/MovingGoalPolicy.spec"),
}

local passed = 0

for _, spec in ipairs(specs) do
	local ok, err = pcall(spec.run)
	if ok then
		passed += 1
		print(("PASS %s"):format(spec.name))
	else
		warn(("FAIL %s\n%s"):format(spec.name, tostring(err)))
	end
end

if passed ~= #specs then
	error(("Test run failed: %d/%d passing"):format(passed, #specs))
end

print(("All %d specs passed."):format(passed))
