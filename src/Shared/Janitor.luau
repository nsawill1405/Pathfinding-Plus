local Janitor = {}
Janitor.__index = Janitor

function Janitor.new()
	local self = setmetatable({}, Janitor)
	self._tasks = {}

	return self
end

function Janitor:Add(task, methodName)
	table.insert(self._tasks, {
		task = task,
		methodName = methodName,
	})

	return task
end

function Janitor:Cleanup()
	for index = #self._tasks, 1, -1 do
		local item = self._tasks[index]
		local task = item.task
		local taskType = typeof(task)

		if taskType == "RBXScriptConnection" then
			task:Disconnect()
		elseif taskType == "Instance" then
			task:Destroy()
		elseif type(task) == "function" then
			task()
		elseif item.methodName ~= nil and task[item.methodName] ~= nil then
			task[item.methodName](task)
		end

		self._tasks[index] = nil
	end
end

function Janitor:Destroy()
	self:Cleanup()
end

return Janitor
