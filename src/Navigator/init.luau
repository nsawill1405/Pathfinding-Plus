local Planner = require(script.Parent.Planner)
local Janitor = require(script.Parent.Shared.Janitor)
local Signal = require(script.Parent.Shared.Signal)
local Goal = require(script.Parent.Shared.Goal)
local MovingGoalPolicy = require(script.MovingGoalPolicy)
local PrepareReplan = require(script.PrepareReplan)
local StateMachine = require(script.StateMachine)

local Navigator = {}
Navigator.__index = Navigator

local navigatorCounter = 0

local DEFAULTS = {
	maxReplans = 4,
	moveTimeout = 3,
	pollInterval = 0.05,
	waypointReachThreshold = 2.5,
	stuckDistanceThreshold = 0.75,
	repathDelay = 0.05,
	movingGoalThreshold = 4,
	movingGoalRepathInterval = 0.4,
}

local EVENT_NAMES = {
	"Started",
	"PathComputed",
	"WaypointAdvanced",
	"Replanned",
	"Blocked",
	"Stuck",
	"Completed",
	"Failed",
	"Cancelled",
}

local function mergeOptions(base, overrides)
	local merged = table.clone(base)

	if overrides ~= nil then
		for key, value in pairs(overrides) do
			merged[key] = value
		end
	end

	return merged
end

function Navigator.new(agentModel, options)
	navigatorCounter += 1

	local self = setmetatable({}, Navigator)
	self._model = agentModel
	self._options = mergeOptions(DEFAULTS, options or {})
	self._planner = self._options.planner or Planner.new(self._options.plannerConfig)
	self._stateMachine = StateMachine.new()
	self._janitor = Janitor.new()
	self._currentRun = nil
	self._coordinator = nil
	self._navigatorId = ("navigator-%d"):format(navigatorCounter)
	self._activeSpacingKey = nil
	self._debug = {
		computeCount = 0,
		replanCount = 0,
		lastReason = nil,
		lastPlanStatus = nil,
	}

	for _, eventName in ipairs(EVENT_NAMES) do
		local signal = Signal.new()
		self[eventName] = signal
		self._janitor:Add(signal, "Destroy")
	end

	self:_refreshAgentReferences()

	if self._options.coordinator ~= nil then
		self._options.coordinator:Register(self)
	end

	return self
end

function Navigator:_refreshAgentReferences()
	self._humanoid = if self._model then self._model:FindFirstChildOfClass("Humanoid") else nil
	self._rootPart = if self._model
		then (
			self._model.PrimaryPart
			or self._model:FindFirstChild("HumanoidRootPart")
			or self._model:FindFirstChildWhichIsA("BasePart")
		)
		else nil
end

function Navigator:_BindCoordinator(coordinator)
	self._coordinator = coordinator
end

function Navigator:_RequestCoordinatorRepath(reason)
	local run = self._currentRun
	if run == nil or run.finished then
		return
	end

	run.replanReason = reason or "BlockedAhead"
end

function Navigator:GetState()
	return self._stateMachine:GetState()
end

function Navigator:GetDebugSnapshot()
	return {
		navigatorId = self._navigatorId,
		state = self._stateMachine:GetState(),
		computeCount = self._debug.computeCount,
		replanCount = self._debug.replanCount,
		lastReason = self._debug.lastReason,
		lastPlanStatus = self._debug.lastPlanStatus,
		activeSpacingKey = self._activeSpacingKey,
	}
end

function Navigator:_finishRun(run, outcome, reason, payload)
	if run.finished then
		return
	end

	run.finished = true
	run.janitor:Destroy()

	if self._coordinator ~= nil then
		self._coordinator:_ReleaseSpacing(self)
	end

	if self._currentRun == run then
		self._currentRun = nil
	end

	self._debug.lastReason = reason

	if outcome == "Completed" then
		self._stateMachine:Complete()
		self.Completed:Fire(self._model, payload)
	elseif outcome == "Cancelled" then
		self._stateMachine:Cancel(reason)
		self.Cancelled:Fire(self._model, reason)
	else
		self._stateMachine:Fail(reason)
		self.Failed:Fire(self._model, reason, payload)
	end
end

function Navigator:Cancel(reason)
	local run = self._currentRun
	if run == nil then
		return
	end

	self:_finishRun(run, "Cancelled", reason or "Cancelled")
end

function Navigator:_resolveGoal(run)
	if self._coordinator ~= nil then
		local position, _, goalError =
			self._coordinator:ResolveGoal(self, run.goal, run.moveOptions)
		return position, goalError
	end

	return Goal.resolvePosition(run.goal)
end

function Navigator:_computePlan(run, startPosition, goalPosition)
	local requestOptions = run.moveOptions
	if self._coordinator ~= nil then
		return self._coordinator:Compute(
			self,
			self._planner,
			startPosition,
			goalPosition,
			requestOptions
		)
	end

	return self._planner:_computeInternal(startPosition, goalPosition, requestOptions)
end

function Navigator:_shouldRepathForMovingGoal(run, now)
	local currentGoalPosition, goalError = self:_resolveGoal(run)
	if currentGoalPosition == nil then
		return false, goalError
	end

	local shouldRepath = MovingGoalPolicy.shouldRepath({
		enabled = run.moveOptions.followMovingGoal == true,
		goalType = typeof(run.goal),
		lastGoalPosition = run.lastGoalPosition,
		currentGoalPosition = currentGoalPosition,
		threshold = run.moveOptions.movingGoalThreshold or self._options.movingGoalThreshold,
		now = now,
		lastRepathAt = run.lastMovingGoalRepathAt,
		interval = run.moveOptions.movingGoalRepathInterval
			or self._options.movingGoalRepathInterval,
	})

	run.lastObservedGoalPosition = currentGoalPosition

	if shouldRepath then
		run.lastMovingGoalRepathAt = now
		run.replanReason = "GoalMoved"
	end

	return shouldRepath, nil
end

function Navigator:_waitForWaypoint(run, waypoint)
	self:_refreshAgentReferences()
	if self._humanoid == nil or self._rootPart == nil then
		return "MissingHumanoid"
	end

	local moveResult = nil
	local startedAt = os.clock()
	local startPosition = self._rootPart.Position
	local connection = self._humanoid.MoveToFinished:Connect(function(reached)
		moveResult = reached
	end)

	while not run.finished do
		if run.replanReason ~= nil then
			connection:Disconnect()
			return "Replan"
		end

		if moveResult ~= nil then
			break
		end

		local shouldRepathForGoalMove, goalError = self:_shouldRepathForMovingGoal(run, os.clock())
		if goalError ~= nil then
			return goalError
		end

		if shouldRepathForGoalMove then
			connection:Disconnect()
			return "Replan"
		end

		local currentRoot = self._rootPart
		if
			currentRoot ~= nil
			and (currentRoot.Position - waypoint.Position).Magnitude
				<= self._options.waypointReachThreshold
		then
			moveResult = true
			break
		end

		if os.clock() - startedAt >= self._options.moveTimeout then
			break
		end

		task.wait(self._options.pollInterval)
	end

	connection:Disconnect()

	if run.finished then
		return "Cancelled"
	end

	if run.replanReason ~= nil then
		return "Replan"
	end

	if moveResult == true then
		return "Reached"
	end

	local finalPosition = if self._rootPart ~= nil then self._rootPart.Position else startPosition
	if (finalPosition - startPosition).Magnitude <= self._options.stuckDistanceThreshold then
		return "Timeout"
	end

	return "BlockedAhead"
end

function Navigator:_followPlan(run, plan)
	local waypoints = plan.waypoints
	if #waypoints == 0 then
		return "Completed"
	end

	local pathJanitor = Janitor.new()
	local rawPath = plan._rawPath
	if rawPath ~= nil then
		pathJanitor:Add(rawPath.Blocked:Connect(function(blockedWaypointIndex)
			if run.finished then
				return
			end

			if blockedWaypointIndex >= (run.nextWaypointIndex or 1) then
				run.replanReason = "BlockedAhead"
				self.Blocked:Fire(
					self._model,
					blockedWaypointIndex,
					waypoints[blockedWaypointIndex]
				)
			end
		end))
	end

	for index, waypoint in ipairs(waypoints) do
		if run.finished then
			pathJanitor:Destroy()
			return "Cancelled"
		end

		if run.replanReason ~= nil then
			pathJanitor:Destroy()
			return "Replan"
		end

		self:_refreshAgentReferences()
		if self._humanoid == nil or self._rootPart == nil then
			pathJanitor:Destroy()
			return "MissingHumanoid"
		end

		run.nextWaypointIndex = index

		if waypoint.Action == Enum.PathWaypointAction.Jump or waypoint.Action == "Jump" then
			self._humanoid.Jump = true
		end

		self._humanoid:MoveTo(waypoint.Position)
		local waitResult = self:_waitForWaypoint(run, waypoint)

		if waitResult == "Reached" then
			self.WaypointAdvanced:Fire(self._model, waypoint, index, #waypoints)
		elseif waitResult == "Replan" then
			pathJanitor:Destroy()
			return "Replan"
		elseif waitResult == "Cancelled" then
			pathJanitor:Destroy()
			return "Cancelled"
		else
			self.Stuck:Fire(self._model, waypoint, waitResult)
			run.replanReason = if waitResult == "MissingHumanoid"
				then "MissingHumanoid"
				else "AgentStuck"
			pathJanitor:Destroy()
			return "Replan"
		end
	end

	pathJanitor:Destroy()
	return "Completed"
end

function Navigator:_runNavigation(run)
	while not run.finished do
		self:_refreshAgentReferences()
		if self._humanoid == nil or self._rootPart == nil then
			self:_finishRun(run, "Failed", "MissingHumanoid")
			return
		end

		local goalPosition, goalError = self:_resolveGoal(run)
		if goalPosition == nil then
			self:_finishRun(run, "Failed", goalError or "InvalidGoal")
			return
		end

		if run.replanCount == 0 then
			self._stateMachine:Begin(false)
		else
			local replanReason = PrepareReplan.consume(run)
			self._stateMachine:RequestReplan(replanReason)
			self.Replanned:Fire(self._model, replanReason, run.replanCount)
		end

		local plan = self:_computePlan(run, self._rootPart.Position, goalPosition)
		if run.finished then
			return
		end

		self._debug.computeCount += 1
		self._debug.lastPlanStatus = plan.status
		run.lastPlan = plan
		run.lastGoalPosition = goalPosition
		run.lastObservedGoalPosition = goalPosition

		if not plan.ok then
			self:_finishRun(run, "Failed", plan.failureReason or "ComputeError", plan)
			return
		end

		self._stateMachine:PathReady(run.replanCount > 0)
		self.PathComputed:Fire(self._model, plan)

		local followResult = self:_followPlan(run, plan)
		if followResult == "Completed" then
			self:_finishRun(run, "Completed", nil, plan.waypoints[#plan.waypoints])
			return
		end

		if followResult == "Cancelled" then
			return
		end

		if followResult == "MissingHumanoid" then
			self:_finishRun(run, "Failed", "MissingHumanoid")
			return
		end

		run.replanCount += 1
		self._debug.replanCount = run.replanCount

		if run.replanCount > self._options.maxReplans then
			local terminalReason = if run.replanReason == "AgentStuck"
					or run.replanReason == "GoalMoved"
				then "Timeout"
				else (run.replanReason or "Timeout")
			self:_finishRun(run, "Failed", terminalReason)
			return
		end

		task.wait(self._options.repathDelay)
	end
end

function Navigator:MoveTo(goal, moveOptions)
	if self._currentRun ~= nil then
		self:Cancel("Replaced")
	end

	local run = {
		goal = goal,
		moveOptions = moveOptions or {},
		finished = false,
		replanReason = nil,
		replanCount = 0,
		nextWaypointIndex = 1,
		lastGoalPosition = nil,
		lastObservedGoalPosition = nil,
		lastMovingGoalRepathAt = nil,
		janitor = Janitor.new(),
	}

	self._currentRun = run
	self.Started:Fire(self._model, goal, run.moveOptions)

	task.spawn(function()
		self:_runNavigation(run)
	end)

	return true
end

function Navigator:Destroy()
	self:Cancel("Cancelled")

	if self._coordinator ~= nil then
		self._coordinator:Unregister(self)
	end

	self._janitor:Destroy()
end

return Navigator
