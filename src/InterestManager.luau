--!strict
--[[
	InterestManager — per-player AllowedSet for fog-of-war / interest replication.

	Defensive sketch only. Server-authoritative: recompute who each player may
	"know" (range ∪ LOS ∪ gameplay rules ∪ max N), then spawn/update proxies
	only for that set. Entities never admitted to a client's AllowedSet never
	reach that client's DataModel / render pipeline.

	Does not detect or block external cheats; it reduces what those tools can see.
]]

local InterestManager = {}
InterestManager.__index = InterestManager

export type Config = {
	NearbyStuds: number,
	MaxPlayers: number,
	RequireLOS: boolean,
	LosRayHeight: number,
}

export type Subject = {
	UserId: number,
	Position: Vector3,
	-- Optional: team id, alive flag, etc.
	TeamId: number?,
	Alive: boolean?,
}

local DEFAULT_CONFIG: Config = {
	NearbyStuds = 120,
	MaxPlayers = 8,
	RequireLOS = true,
	LosRayHeight = 2,
}

function InterestManager.new(config: Config?)
	local self = setmetatable({}, InterestManager)
	self.Config = config or table.clone(DEFAULT_CONFIG)
	self._rayParams = RaycastParams.new()
	self._rayParams.FilterType = Enum.RaycastFilterType.Exclude
	return self
end

local function horizontalDistance(a: Vector3, b: Vector3): number
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

function InterestManager:_hasLOS(fromPos: Vector3, toPos: Vector3, ignore: { Instance }): boolean
	local origin = fromPos + Vector3.new(0, self.Config.LosRayHeight, 0)
	local target = toPos + Vector3.new(0, self.Config.LosRayHeight, 0)
	local delta = target - origin
	self._rayParams.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(origin, delta, self._rayParams)
	if result == nil then
		return true
	end
	-- Hit something before reaching target — treat as occluded.
	return (result.Position - target).Magnitude < 1.5
end

--[[
	Recompute AllowedSet for observer among subjects.
	Returns list of Subject sorted by priority (closer first), capped at MaxPlayers.
	Caller is responsible for syncing replication / proxies to this set.
]]
function InterestManager:ComputeAllowedSet(
	observer: Subject,
	subjects: { Subject },
	ignoreInstances: { Instance }?
): { Subject }
	local cfg = self.Config
	local ignore = ignoreInstances or {}
	local candidates: { { subject: Subject, dist: number } } = {}

	for _, other in subjects do
		if other.UserId == observer.UserId then
			continue
		end
		if other.Alive == false then
			continue
		end
		-- Teammates: policy choice — often always allowed; keep gated here for fog-of-war PvP.
		local dist = horizontalDistance(observer.Position, other.Position)
		if dist > cfg.NearbyStuds then
			continue
		end
		if cfg.RequireLOS and not self:_hasLOS(observer.Position, other.Position, ignore) then
			continue
		end
		table.insert(candidates, { subject = other, dist = dist })
	end

	table.sort(candidates, function(a, b)
		return a.dist < b.dist
	end)

	local allowed: { Subject } = {}
	for i = 1, math.min(cfg.MaxPlayers, #candidates) do
		table.insert(allowed, candidates[i].subject)
	end
	return allowed
end

--[[
	Diff helper: which userIds to open vs close interest for.
]]
function InterestManager.DiffSets(previous: { number }, nextSet: { Subject }): ( { number }, { number } )
	local nextIds: { [number]: boolean } = {}
	for _, s in nextSet do
		nextIds[s.UserId] = true
	end
	local prevIds: { [number]: boolean } = {}
	for _, id in previous do
		prevIds[id] = true
	end

	local opened: { number } = {}
	local closed: { number } = {}
	for id in nextIds do
		if not prevIds[id] then
			table.insert(opened, id)
		end
	end
	for id in prevIds do
		if not nextIds[id] then
			table.insert(closed, id)
		end
	end
	return opened, closed
end

return InterestManager
