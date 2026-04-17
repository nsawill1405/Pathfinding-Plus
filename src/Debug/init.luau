local Workspace = game:GetService("Workspace")

local Debug = {}

function Debug.visualizeWaypoints(waypoints, options)
	local settings = options or {}
	local folder = Instance.new("Folder")
	folder.Name = settings.name or "PathfindingPlusDebug"
	folder.Parent = settings.parent or Workspace

	for index, waypoint in ipairs(waypoints) do
		local marker = Instance.new("Part")
		marker.Name = ("Waypoint_%02d"):format(index)
		marker.Shape = Enum.PartType.Ball
		marker.Size = Vector3.new(0.8, 0.8, 0.8)
		marker.Material = Enum.Material.Neon
		marker.Color = if waypoint.Action == Enum.PathWaypointAction.Jump
			then Color3.fromRGB(255, 170, 0)
			else Color3.fromRGB(0, 200, 255)
		marker.Anchored = true
		marker.CanCollide = false
		marker.CFrame = CFrame.new(waypoint.Position)
		marker.Parent = folder
	end

	if settings.lifetime ~= nil then
		task.delay(settings.lifetime, function()
			if folder.Parent ~= nil then
				folder:Destroy()
			end
		end)
	end

	return folder
end

function Debug.clearVisualization(container)
	if container ~= nil and container.Parent ~= nil then
		container:Destroy()
	end
end

function Debug.snapshotNavigator(navigator)
	return navigator:GetDebugSnapshot()
end

return Debug
