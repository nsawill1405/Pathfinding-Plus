local Signal = {}
Signal.__index = Signal

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

function Signal.new()
	local self = setmetatable({}, Signal)
	self._listeners = {}
	self._destroyed = false

	return self
end

function Signal:Connect(callback)
	assert(type(callback) == "function", "Signal:Connect expects a function")

	if self._destroyed then
		error("cannot connect to a destroyed signal")
	end

	local connection = {
		Connected = true,
	}

	function connection.Disconnect(selfConnection)
		if not selfConnection.Connected then
			return
		end

		selfConnection.Connected = false
	end

	self._listeners[connection] = callback

	return connection
end

function Signal:Fire(...)
	if self._destroyed then
		return
	end

	for connection, callback in pairs(self._listeners) do
		if connection.Connected then
			task.spawn(callback, ...)
		else
			self._listeners[connection] = nil
		end
	end
end

function Signal:Destroy()
	self._destroyed = true

	for connection in pairs(self._listeners) do
		connection:Disconnect()
		self._listeners[connection] = nil
	end
end

return Signal
