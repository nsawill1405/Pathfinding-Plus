local StateMachine = {}
StateMachine.__index = StateMachine

function StateMachine.new()
	local self = setmetatable({}, StateMachine)
	self._state = "Idle"
	self._lastReason = nil

	return self
end

function StateMachine:Begin(isReplan: boolean)
	self._state = if isReplan then "Replanning" else "Planning"
end

function StateMachine:PathReady(_fromReplan: boolean)
	self._state = "Moving"
end

function StateMachine:RequestReplan(reason: string?)
	self._lastReason = reason
	self._state = "Replanning"
end

function StateMachine:Complete()
	self._state = "Completed"
end

function StateMachine:Fail(reason: string?)
	self._lastReason = reason
	self._state = "Failed"
end

function StateMachine:Cancel(reason: string?)
	self._lastReason = reason
	self._state = "Cancelled"
end

function StateMachine:Reset()
	self._lastReason = nil
	self._state = "Idle"
end

function StateMachine:GetState(): string
	return self._state
end

function StateMachine:GetLastReason(): string?
	return self._lastReason
end

return StateMachine
