--!strict
--[[
	AnomalyScore — soft telemetry for aim / interest abuse signals.

	Does not ban by itself. Accumulates friction scores for server policies
	(queue delay, forced bloom, review flags). All inputs should be
	server-observed (AllowedSet membership, CombatResolver reject reasons).
]]

local AnomalyScore = {}
AnomalyScore.__index = AnomalyScore

export type Weights = {
	FireUnseen: number,
	AngleReject: number,
	BlockedLOS: number,
	DecayPerSecond: number,
}

local DEFAULT_WEIGHTS: Weights = {
	FireUnseen = 8,
	AngleReject = 2,
	BlockedLOS = 1.5,
	DecayPerSecond = 0.15,
}

function AnomalyScore.new(weights: Weights?)
	local self = setmetatable({}, AnomalyScore)
	self.Weights = weights or table.clone(DEFAULT_WEIGHTS)
	self._score: { [number]: number } = {}
	self._lastUpdate: { [number]: number } = {}
	return self
end

function AnomalyScore:_decay(userId: number, now: number)
	local last = self._lastUpdate[userId]
	local score = self._score[userId] or 0
	if last then
		local dt = math.max(0, now - last)
		score = math.max(0, score - dt * self.Weights.DecayPerSecond)
	end
	self._score[userId] = score
	self._lastUpdate[userId] = now
	return score
end

function AnomalyScore:ObserveReject(userId: number, reason: string, now: number)
	self:_decay(userId, now)
	local w = self.Weights
	local add = 0
	if reason == "not_in_allowed_set" then
		add = w.FireUnseen
	elseif reason == "angle" then
		add = w.AngleReject
	elseif reason == "blocked_los" then
		add = w.BlockedLOS
	end
	self._score[userId] = (self._score[userId] or 0) + add
end

function AnomalyScore:Get(userId: number, now: number): number
	return self:_decay(userId, now)
end

--[[
	Example soft action thresholds — tune per experience.
]]
function AnomalyScore:SuggestedAction(userId: number, now: number): string
	local s = self:Get(userId, now)
	if s >= 40 then
		return "review_flag"
	elseif s >= 25 then
		return "forced_delay"
	elseif s >= 12 then
		return "bloom"
	end
	return "none"
end

return AnomalyScore
