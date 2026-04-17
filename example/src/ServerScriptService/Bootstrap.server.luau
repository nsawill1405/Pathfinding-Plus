local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local PathfindingPlus = require(Packages:WaitForChild("PathfindingPlus"))

local coordinator = PathfindingPlus.Coordinator.new({
	maxRequestsPerSecond = 10,
	perNavigatorCooldown = 0.2,
})

local function createWall(parent, size, position)
	local part = Instance.new("Part")
	part.Name = "Wall"
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = Color3.fromRGB(70, 70, 70)
	part.Material = Enum.Material.Concrete
	part.Parent = parent
	return part
end

local function createFloor(parent, size, position, color)
	local part = Instance.new("Part")
	part.Name = "Floor"
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = color or Color3.fromRGB(120, 120, 120)
	part.Material = Enum.Material.Slate
	part.Parent = parent
	return part
end

local function createGoal(parent, name, position, color)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(2, 2, 2)
	part.Position = position
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Parent = parent
	return part
end

local function createNPC(parent, name, position, color)
	local model = Players:CreateHumanoidModelFromDescription(
		Instance.new("HumanoidDescription"),
		Enum.HumanoidRigType.R6
	)
	model.Name = name

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.WalkSpeed = 10
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	model.Parent = parent
	model:PivotTo(CFrame.new(position))

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Color = if descendant.Name == "Head"
				then color:Lerp(Color3.new(1, 1, 1), 0.25)
				else color
		end
	end

	return model
end

local function buildSingleAgentScene(parent)
	local folder = Instance.new("Folder")
	folder.Name = "SingleAgent"
	folder.Parent = parent

	createFloor(
		folder,
		Vector3.new(60, 1, 18),
		Vector3.new(-140, 0, 0),
		Color3.fromRGB(99, 112, 124)
	)
	createWall(folder, Vector3.new(60, 12, 1), Vector3.new(-140, 6, -9))
	createWall(folder, Vector3.new(60, 12, 1), Vector3.new(-140, 6, 9))
	createWall(folder, Vector3.new(1, 12, 18), Vector3.new(-170, 6, 0))
	createWall(folder, Vector3.new(1, 12, 7), Vector3.new(-120, 6, -5.5))
	createWall(folder, Vector3.new(1, 12, 7), Vector3.new(-120, 6, 5.5))

	local goal = createGoal(folder, "Goal", Vector3.new(-112, 2, 0), Color3.fromRGB(0, 255, 180))
	local npc =
		createNPC(folder, "NavigatorNPC", Vector3.new(-165, 3, 0), Color3.fromRGB(87, 170, 255))
	local navigator = PathfindingPlus.Navigator.new(npc, {
		maxReplans = 4,
		moveTimeout = 2.5,
	})

	task.delay(1, function()
		navigator:MoveTo(goal)
	end)
end

local function buildBlockedScene(parent)
	local folder = Instance.new("Folder")
	folder.Name = "BlockedReplan"
	folder.Parent = parent

	createFloor(folder, Vector3.new(100, 1, 40), Vector3.new(0, 0, 0), Color3.fromRGB(89, 91, 99))
	createWall(folder, Vector3.new(100, 12, 1), Vector3.new(0, 6, -20))
	createWall(folder, Vector3.new(100, 12, 1), Vector3.new(0, 6, 20))
	createWall(folder, Vector3.new(1, 12, 40), Vector3.new(-50, 6, 0))
	createWall(folder, Vector3.new(1, 12, 40), Vector3.new(50, 6, 0))
	createWall(folder, Vector3.new(18, 12, 8), Vector3.new(0, 6, 0))

	local movingBlock = Instance.new("Part")
	movingBlock.Name = "DynamicBlocker"
	movingBlock.Anchored = true
	movingBlock.Size = Vector3.new(8, 8, 8)
	movingBlock.Position = Vector3.new(-18, 40, -8)
	movingBlock.Color = Color3.fromRGB(255, 99, 71)
	movingBlock.Material = Enum.Material.Metal
	movingBlock.Parent = folder

	local goal = createGoal(folder, "Goal", Vector3.new(40, 2, -8), Color3.fromRGB(255, 210, 80))
	local npc =
		createNPC(folder, "BlockedNPC", Vector3.new(-40, 3, -8), Color3.fromRGB(255, 146, 60))
	local navigator = PathfindingPlus.Navigator.new(npc, {
		coordinator = coordinator,
		maxReplans = 6,
		moveTimeout = 4,
		repathDelay = 0.25,
	})

	task.delay(1, function()
		navigator:MoveTo(goal)
	end)

	task.delay(1.8, function()
		if movingBlock.Parent == nil then
			return
		end

		movingBlock.Position = Vector3.new(-18, 4, -8)
		coordinator:RequestRepath(navigator, "BlockedAhead")
	end)
end

local function buildCrowdScene(parent)
	local folder = Instance.new("Folder")
	folder.Name = "Crowd"
	folder.Parent = parent

	createFloor(
		folder,
		Vector3.new(90, 1, 40),
		Vector3.new(140, 0, 0),
		Color3.fromRGB(96, 104, 118)
	)
	createWall(folder, Vector3.new(90, 14, 1), Vector3.new(140, 7, -20))
	createWall(folder, Vector3.new(90, 14, 1), Vector3.new(140, 7, 20))
	createWall(folder, Vector3.new(1, 14, 40), Vector3.new(95, 7, 0))
	createWall(folder, Vector3.new(1, 14, 40), Vector3.new(185, 7, 0))
	createWall(folder, Vector3.new(12, 14, 1), Vector3.new(140, 7, -6))
	createWall(folder, Vector3.new(12, 14, 1), Vector3.new(140, 7, 6))
	createWall(folder, Vector3.new(1, 14, 10), Vector3.new(146, 7, -11))
	createWall(folder, Vector3.new(1, 14, 10), Vector3.new(146, 7, 11))

	local target =
		createGoal(folder, "CrowdGoal", Vector3.new(175, 2, 0), Color3.fromRGB(118, 255, 123))
	coordinator:SetTargetSpacing(target, 10, 8)

	for index = 1, 6 do
		local zOffset = -10 + ((index - 1) * 4)
		local npc = createNPC(
			folder,
			("CrowdNPC_%d"):format(index),
			Vector3.new(105, 3, zOffset),
			Color3.fromRGB(120 + index * 10, 140, 255 - index * 12)
		)
		local navigator = PathfindingPlus.Navigator.new(npc, {
			coordinator = coordinator,
			maxReplans = 6,
			moveTimeout = 2.5,
		})

		task.delay(index * 0.2, function()
			navigator:MoveTo(target)
		end)
	end
end

local existing = Workspace:FindFirstChild("PathfindingPlusDemo")
if existing ~= nil then
	existing:Destroy()
end

local demoFolder = Instance.new("Folder")
demoFolder.Name = "PathfindingPlusDemo"
demoFolder.Parent = Workspace

buildSingleAgentScene(demoFolder)
buildBlockedScene(demoFolder)
buildCrowdScene(demoFolder)
