local Janitor = require(script.Parent.Parent.Shared.Janitor)
local Goal = require(script.Parent.Parent.Shared.Goal)
local PositionMath = require(script.Parent.Parent.Shared.PositionMath)
local RequestQueue = require(script.RequestQueue)
local SpacingPolicy = require(script.SpacingPolicy)

local Coordinator = {}
Coordinator.__index = Coordinator

function Coordinator.new(options)
	local self = setmetatable({}, Coordinator)
	self._options = options or {}
	self._navigatorCooldown = self._options.perNavigatorCooldown or 0.15
	self._maxRequestsPerSecond = self._options.maxRequestsPerSecond or 20
	self._pollInterval = self._options.pollInterval or 0.03
	self._queue = RequestQueue.new({
		perNavigatorCooldown = self._navigatorCooldown,
	})
	self._spacing = SpacingPolicy.new()
	self._janitor = Janitor.new()
	self._registered = {}
	self._destroyed = false
	self._loopRunning = false
	self._nextGlobalIssueAt = 0
	self._requestInterval = 1 / self._maxRequestsPerSecond

	return self
end

function Coordinator:Register(navigator)
	self._registered[navigator] = true
	navigator:_BindCoordinator(self)
	return navigator
end

function Coordinator:Unregister(navigator)
	self._registered[navigator] = nil
	self._queue:DropNavigator(navigator._navigatorId)
	self:_ReleaseSpacing(navigator)
	navigator:_BindCoordinator(nil)
end

function Coordinator:SetTargetSpacing(key, radius, slotCount)
	self._spacing:SetTarget(key, radius, slotCount)
end

function Coordinator:_ensureLoop()
	if self._loopRunning or self._destroyed then
		return
	end

	self._loopRunning = true

	task.spawn(function()
		while not self._destroyed do
			local now = os.clock()

			if now >= self._nextGlobalIssueAt then
				local request = self._queue:PopReady(now)
				if request ~= nil then
					self._nextGlobalIssueAt = now + self._requestInterval
					local ok, result = pcall(request.execute)
					request.callback(ok, result)
				elseif self._queue:GetSize() == 0 then
					self._loopRunning = false
					return
				end
			end

			task.wait(self._pollInterval)
		end

		self._loopRunning = false
	end)
end

function Coordinator:Compute(navigator, planner, startPosition, goal, requestOptions)
	local bindable = Instance.new("BindableEvent")
	local resultValue = nil
	local errorValue = nil

	self._queue:Enqueue({
		navigatorId = navigator._navigatorId,
		execute = function()
			return planner:_computeInternal(startPosition, goal, requestOptions)
		end,
		callback = function(ok, result)
			if ok then
				resultValue = result
			else
				errorValue = result
			end

			bindable:Fire()
		end,
	}, os.clock())

	self:_ensureLoop()
	bindable.Event:Wait()
	bindable:Destroy()

	if errorValue ~= nil then
		error(errorValue)
	end

	return resultValue
end

function Coordinator:_ResolveSpacing(navigator, goal, moveOptions)
	local basePosition, goalError = Goal.resolvePosition(goal)
	if basePosition == nil then
		return nil, nil, goalError
	end

	local spacingKey = Goal.resolveSpacingKey(goal, moveOptions and moveOptions.spacingKey)
	if spacingKey == nil then
		self:_ReleaseSpacing(navigator)
		return basePosition, nil, nil
	end

	local assignment = self._spacing:Acquire(spacingKey, navigator._navigatorId)
	navigator._activeSpacingKey = spacingKey

	return basePosition + PositionMath.toOffsetVector(assignment.offset), spacingKey, nil
end

function Coordinator:ResolveGoal(navigator, goal, moveOptions)
	return self:_ResolveSpacing(navigator, goal, moveOptions)
end

function Coordinator:_ReleaseSpacing(navigator)
	if navigator._activeSpacingKey == nil then
		return
	end

	self._spacing:Release(navigator._activeSpacingKey, navigator._navigatorId)
	navigator._activeSpacingKey = nil
end

function Coordinator:RequestRepath(navigator, reason)
	if self._registered[navigator] ~= true then
		return
	end

	navigator:_RequestCoordinatorRepath(reason or "BlockedAhead")
end

function Coordinator:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true

	for navigator in pairs(self._registered) do
		navigator:_BindCoordinator(nil)
	end

	self._registered = {}
	self._janitor:Destroy()
end

return Coordinator
