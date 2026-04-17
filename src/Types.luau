local Types = {
	NavigatorState = {
		Idle = "Idle",
		Planning = "Planning",
		Moving = "Moving",
		Replanning = "Replanning",
		Completed = "Completed",
		Failed = "Failed",
		Cancelled = "Cancelled",
	},
	FailureReason = {
		NoPath = "NoPath",
		ComputeError = "ComputeError",
		BlockedAhead = "BlockedAhead",
		AgentStuck = "AgentStuck",
		InvalidGoal = "InvalidGoal",
		MissingHumanoid = "MissingHumanoid",
		Timeout = "Timeout",
		Cancelled = "Cancelled",
		Replaced = "Replaced",
	},
	Events = {
		Started = "Started",
		PathComputed = "PathComputed",
		WaypointAdvanced = "WaypointAdvanced",
		Replanned = "Replanned",
		Blocked = "Blocked",
		Stuck = "Stuck",
		Completed = "Completed",
		Failed = "Failed",
		Cancelled = "Cancelled",
	},
}

export type Goal = Vector3 | BasePart | Attachment

export type PlanResult = {
	ok: boolean,
	status: string,
	waypoints: { PathWaypoint },
	cost: number,
	computeTimeMs: number,
	blockedLabels: { string },
	failureReason: string?,
}

export type DebugSnapshot = {
	navigatorId: string,
	state: string,
	computeCount: number,
	replanCount: number,
	lastReason: string?,
	lastPlanStatus: string?,
	activeSpacingKey: any,
}

return Types
