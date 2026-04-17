local PrepareReplan = {}

function PrepareReplan.consume(run)
	local reason = run.replanReason
	run.replanReason = nil

	return reason or "BlockedAhead"
end

return PrepareReplan
