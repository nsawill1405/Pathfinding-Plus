local RequestQueue = {}
RequestQueue.__index = RequestQueue

type QueueConfig = {
	perNavigatorCooldown: number?,
}

type QueueRequest = {
	navigatorId: string,
	[string]: any,
}

type QueueEntry = {
	request: QueueRequest,
	enqueuedAt: number,
	sequence: number,
}

function RequestQueue.new(config: QueueConfig?)
	local self = setmetatable({}, RequestQueue)
	self._perNavigatorCooldown = if config and config.perNavigatorCooldown
		then config.perNavigatorCooldown
		else 0
	self._entries = {} :: { QueueEntry }
	self._lastIssuedAt = {} :: { [string]: number }
	self._sequence = 0

	return self
end

function RequestQueue:Enqueue(request: QueueRequest, now: number?)
	self._sequence += 1

	table.insert(self._entries, {
		request = request,
		enqueuedAt = now or os.clock(),
		sequence = self._sequence,
	})
end

function RequestQueue:_getReadyAt(entry: QueueEntry): number
	local lastIssuedAt = self._lastIssuedAt[entry.request.navigatorId]
	if lastIssuedAt == nil then
		return entry.enqueuedAt
	end

	return math.max(entry.enqueuedAt, lastIssuedAt + self._perNavigatorCooldown)
end

function RequestQueue:PopReady(now: number?): QueueRequest?
	local atTime = now or os.clock()
	local candidateIndex = nil
	local candidateReadyAt = nil

	for index, entry in ipairs(self._entries) do
		local readyAt = self:_getReadyAt(entry)
		if readyAt <= atTime then
			if
				candidateIndex == nil
				or readyAt < candidateReadyAt
				or (
					readyAt == candidateReadyAt
					and entry.sequence < self._entries[candidateIndex].sequence
				)
			then
				candidateIndex = index
				candidateReadyAt = readyAt
			end
		end
	end

	if candidateIndex == nil then
		return nil
	end

	local entry = table.remove(self._entries, candidateIndex)
	self._lastIssuedAt[entry.request.navigatorId] = atTime

	return entry.request
end

function RequestQueue:DropNavigator(navigatorId: string)
	local filtered = {}
	for _, entry in ipairs(self._entries) do
		if entry.request.navigatorId ~= navigatorId then
			table.insert(filtered, entry)
		end
	end

	self._entries = filtered
	self._lastIssuedAt[navigatorId] = nil
end

function RequestQueue:GetSize(): number
	return #self._entries
end

return RequestQueue
