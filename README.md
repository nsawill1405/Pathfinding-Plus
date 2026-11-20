<div align="center">

<img src="https://capsule-render.vercel.app/api?type=waving&color=0:0f2027,50:203a43,100:2c5364&height=170&section=header&text=Pathfinding%20Plus&fontSize=52&fontColor=ffffff&fontAlignY=36&desc=Reliable%2C%20crowd-aware%20pathfinding%20for%20Roblox&descAlignY=58&descSize=16" alt="Pathfinding Plus" width="100%" />

<p>
  <img src="https://img.shields.io/badge/Luau-00A2FF?style=for-the-badge&logo=roblox&logoColor=white" alt="Luau" />
  <a href="https://github.com/nsawill1405/Pathfinding-Plus/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/nsawill1405/Pathfinding-Plus/ci.yml?branch=main&style=for-the-badge&label=CI&logo=githubactions&logoColor=white" alt="CI" /></a>
  <a href="https://wally.run/package/nsawill1405/pathfinding-plus"><img src="https://img.shields.io/badge/Wally-nsawill1405%2Fpathfinding--plus-AD4646?style=for-the-badge" alt="Wally" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-2c5364?style=for-the-badge" alt="License" /></a>
</p>

<p><a href="#install">Install</a> · <a href="#quick-start">Quick Start</a> · <a href="#public-api">Public API</a> · <a href="#tuning-notes">Tuning Notes</a> · <a href="#guarantees">Guarantees</a> · <a href="#non-goals-for-v1">Non-goals for v1</a></p>

</div>

`Pathfinding Plus` is a Wally package for Roblox developers who want a more reliable pathfinding layer than raw `PathfindingService` calls.

It ships three layers:
- `Planner` for path computation and normalized results
- `Navigator` for single-humanoid movement, cancellation, stuck detection, and replans
- `Coordinator` for shared compute budgeting, staggered replans, and lightweight crowd spacing

## Install

Add the package to your `wally.toml`:

```toml
[dependencies]
PathfindingPlus = "nsawill1405/pathfinding-plus@0.1.0"
```

Then install:

```bash
wally install
```

Require it from your game:

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local PathfindingPlus = require(Packages:WaitForChild("PathfindingPlus"))
```

## Quick Start

### Single navigator

```luau
local PathfindingPlus = require(game.ReplicatedStorage.Packages.PathfindingPlus)

local navigator = PathfindingPlus.Navigator.new(workspace.NPC, {
	plannerConfig = {
		agentParameters = {
			AgentRadius = 2,
			AgentHeight = 5,
			AgentCanJump = true,
			WaypointSpacing = 4,
		},
	},
	maxReplans = 5,
	moveTimeout = 2.5,
})

navigator.Failed:Connect(function(_agent, reason)
	warn("navigation failed", reason)
end)

navigator:MoveTo(workspace.Target)
```

### Following a moving target

```luau
local navigator = PathfindingPlus.Navigator.new(workspace.NPC, {
	moveTimeout = 3,
})

navigator:MoveTo(workspace.MovingTarget, {
	followMovingGoal = true,
	movingGoalThreshold = 5,
	movingGoalRepathInterval = 0.4,
})
```

### Multiple navigators with one coordinator

```luau
local PathfindingPlus = require(game.ReplicatedStorage.Packages.PathfindingPlus)

local coordinator = PathfindingPlus.Coordinator.new({
	maxRequestsPerSecond = 12,
	perNavigatorCooldown = 0.2,
})

coordinator:SetTargetSpacing(workspace.CrowdGoal, 10, 8)

for _, npc in ipairs(workspace.CrowdNPCs:GetChildren()) do
	local navigator = PathfindingPlus.Navigator.new(npc, {
		coordinator = coordinator,
		maxReplans = 6,
	})

	navigator:MoveTo(workspace.CrowdGoal)
end
```

## Public API

### `Planner`

- `Planner.new(config?)`
- `planner:Compute(startPosition: Vector3, goal, requestOptions?) -> PlanResult`

`PlanResult` returns:
- `ok`
- `status`
- `waypoints`
- `cost`
- `computeTimeMs`
- `blockedLabels`
- `failureReason`

### `Navigator`

- `Navigator.new(agentModel: Model, options?)`
- `navigator:MoveTo(goal, moveOptions?)`
- `navigator:Cancel(reason?)`
- `navigator:Destroy()`
- `navigator:GetState()`
- `navigator:GetDebugSnapshot()`

Signals:
- `Started`
- `PathComputed`
- `WaypointAdvanced`
- `Replanned`
- `Blocked`
- `Stuck`
- `Completed`
- `Failed`
- `Cancelled`

### `Coordinator`

- `Coordinator.new(options?)`
- `coordinator:Register(navigator)`
- `coordinator:Unregister(navigator)`
- `coordinator:RequestRepath(navigator, reason?)`
- `coordinator:SetTargetSpacing(key, radius, slotCount?)`
- `coordinator:Destroy()`

## Tuning Notes

- `maxRequestsPerSecond` limits total path computations through a shared coordinator.
- `perNavigatorCooldown` stops one agent from monopolizing the queue.
- `moveTimeout` and `maxReplans` control how aggressively a navigator recovers from getting stuck.
- `followMovingGoal` makes a navigator periodically re-evaluate a moving `BasePart` or `Attachment` target.
- `movingGoalThreshold` is the target drift in studs before a moving-goal replan is requested.
- `movingGoalRepathInterval` is the minimum time between moving-goal replans.
- `SetTargetSpacing` only affects explicit spacing keys or `BasePart` / `Attachment` goals. Raw `Vector3` goals need `moveOptions.spacingKey`.

## Guarantees

- `MoveTo` is non-yielding.
- Starting a new `MoveTo` cancels the old run with reason `Replaced`.
- Blocked paths only trigger replans for waypoints ahead of the current waypoint.
- Crowd support in v1 is coordination-first: shared budgets, staggered repaths, and spacing slots.

## Non-goals for v1

- Steering-based local avoidance between moving agents
- Full crowd simulation
- Non-humanoid movement controllers

## Example Project

The root `default.project.json` syncs a demo place that mounts:
- the package under `ReplicatedStorage.Packages.PathfindingPlus`
- example scripts under `ServerScriptService.PathfindingPlusExample`

The demo script builds three scenes:
- a single-agent corridor
- a blocked-path replan demo
- a crowd chokepoint demo

## Development

Install the local toolchain:

```bash
aftman install --no-trust-check
```

Run checks:

```bash
stylua --check src test example
selene src test example
lune run test/run.luau
wally install
wally package --list
rojo build default.project.json --output PathfindingPlus.rbxlx
```

## License

[MIT](LICENSE) © William North. Issues and pull requests are welcome.

---

<div align="center">

<sub>Made by <a href="https://github.com/nsawill1405">William North</a> · <a href="https://nsawill.co.uk">nsawill.co.uk</a></sub>

<img src="https://capsule-render.vercel.app/api?type=waving&color=0:2c5364,50:203a43,100:0f2027&height=100&section=footer" alt="" width="100%" />

</div>
