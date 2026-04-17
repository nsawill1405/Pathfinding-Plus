local SpacingPolicy = {}
SpacingPolicy.__index = SpacingPolicy

type Offset = {
	x: number,
	y: number,
	z: number,
}

type SlotAssignment = {
	slotIndex: number,
	offset: Offset,
}

type TargetSpec = {
	radius: number,
	slotCount: number,
	assignments: { [string]: number },
}

local function buildOffset(radius: number, slotCount: number, slotIndex: number): Offset
	local angle = ((slotIndex - 1) / slotCount) * math.pi * 2
	return {
		x = math.cos(angle) * radius,
		y = 0,
		z = math.sin(angle) * radius,
	}
end

function SpacingPolicy.new()
	local self = setmetatable({}, SpacingPolicy)
	self._targets = {} :: { [string]: TargetSpec }

	return self
end

function SpacingPolicy:SetTarget(key: string, radius: number, slotCount: number?)
	self._targets[key] = {
		radius = radius,
		slotCount = slotCount or 6,
		assignments = self._targets[key] and self._targets[key].assignments or {},
	}
end

function SpacingPolicy:_getTarget(key: string): TargetSpec
	local target = self._targets[key]
	if target == nil then
		target = {
			radius = 0,
			slotCount = 1,
			assignments = {},
		}
		self._targets[key] = target
	end

	return target
end

function SpacingPolicy:Acquire(key: string, navigatorId: string): SlotAssignment
	local target = self:_getTarget(key)
	local existingSlot = target.assignments[navigatorId]
	if existingSlot ~= nil then
		return {
			slotIndex = existingSlot,
			offset = buildOffset(target.radius, target.slotCount, existingSlot),
		}
	end

	local used = {}
	for _, slotIndex in pairs(target.assignments) do
		used[slotIndex] = true
	end

	local chosenSlot = 1
	while chosenSlot <= target.slotCount and used[chosenSlot] do
		chosenSlot += 1
	end

	if chosenSlot > target.slotCount then
		chosenSlot = (#target.assignments % target.slotCount) + 1
	end

	target.assignments[navigatorId] = chosenSlot

	return {
		slotIndex = chosenSlot,
		offset = buildOffset(target.radius, target.slotCount, chosenSlot),
	}
end

function SpacingPolicy:Release(key: string, navigatorId: string)
	local target = self._targets[key]
	if target == nil then
		return
	end

	target.assignments[navigatorId] = nil
end

return SpacingPolicy
