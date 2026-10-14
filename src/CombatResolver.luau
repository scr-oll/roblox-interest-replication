--!strict
--[[
	CombatResolver — server-authoritative hit validation.

	Clients may claim fire intent (origin hint, look direction, target id).
	Damage applies only when the server's last known poses + weapon rules agree.

	Defensive: reduces payoff of aim assist / ESP even when the cheater can see
	a target that was (mistakenly) replicated.
]]

local CombatResolver = {}
CombatResolver.__index = CombatResolver

export type WeaponRules = {
	MaxRange: number,
	MaxAngleDeg: number, -- max deviation from server look / muzzle forward
	RequiresLOS: boolean,
	CooldownSeconds: number,
}

export type FireClaim = {
	ShooterUserId: number,
	TargetUserId: number?,
	ClientLook: Vector3?, -- untrusted hint
	ClientOrigin: Vector3?, -- untrusted hint
	Timestamp: number,
}

export type Pose = {
	UserId: number,
	Position: Vector3,
	Look: Vector3, -- unit
	Alive: boolean,
}

export type ResolveResult = {
	Accepted: boolean,
	Reason: string,
	Damage: number?,
}

local DEFAULT_WEAPON: WeaponRules = {
	MaxRange = 200,
	MaxAngleDeg = 12,
	RequiresLOS = true,
	CooldownSeconds = 0.12,
}

function CombatResolver.new(weapon: WeaponRules?)
	local self = setmetatable({}, CombatResolver)
	self.Weapon = weapon or table.clone(DEFAULT_WEAPON)
	self._lastFire: { [number]: number } = {}
	self._rayParams = RaycastParams.new()
	self._rayParams.FilterType = Enum.RaycastFilterType.Exclude
	return self
end

function CombatResolver:IsInAllowedSet(targetUserId: number, allowedUserIds: { number }): boolean
	for _, id in allowedUserIds do
		if id == targetUserId then
			return true
		end
	end
	return false
end

function CombatResolver:_hasLOS(fromPos: Vector3, toPos: Vector3, ignore: { Instance }): boolean
	local origin = fromPos + Vector3.new(0, 1.5, 0)
	local target = toPos + Vector3.new(0, 1.5, 0)
	local delta = target - origin
	self._rayParams.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(origin, delta, self._rayParams)
	if result == nil then
		return true
	end
	return (result.Position - target).Magnitude < 2
end

--[[
	Resolve a fire claim using server poses and the shooter's current AllowedSet.
	`damage` is applied by the caller only when Accepted.
]]
function CombatResolver:Resolve(
	claim: FireClaim,
	shooter: Pose,
	target: Pose?,
	allowedTargetIds: { number },
	ignoreInstances: { Instance }?,
	baseDamage: number
): ResolveResult
	local now = claim.Timestamp
	local last = self._lastFire[claim.ShooterUserId]
	if last and (now - last) < self.Weapon.CooldownSeconds then
		return { Accepted = false, Reason = "cooldown" }
	end

	if not shooter.Alive then
		return { Accepted = false, Reason = "shooter_dead" }
	end

	if claim.TargetUserId == nil or target == nil then
		-- Miss / environmental shot — accept as no-damage fire for rate accounting.
		self._lastFire[claim.ShooterUserId] = now
		return { Accepted = true, Reason = "no_target", Damage = 0 }
	end

	if not target.Alive then
		return { Accepted = false, Reason = "target_dead" }
	end

	if not self:IsInAllowedSet(claim.TargetUserId, allowedTargetIds) then
		-- Pre-aim / fire on unseen target — strong anomaly signal for callers.
		return { Accepted = false, Reason = "not_in_allowed_set" }
	end

	local delta = target.Position - shooter.Position
	local dist = delta.Magnitude
	if dist > self.Weapon.MaxRange or dist < 1e-3 then
		return { Accepted = false, Reason = "out_of_range" }
	end

	local toTarget = delta.Unit
	local look = shooter.Look.Magnitude > 0 and shooter.Look.Unit or toTarget
	local dot = math.clamp(look:Dot(toTarget), -1, 1)
	local angleDeg = math.deg(math.acos(dot))
	if angleDeg > self.Weapon.MaxAngleDeg then
		return { Accepted = false, Reason = "angle" }
	end

	if self.Weapon.RequiresLOS then
		local ignore = ignoreInstances or {}
		if not self:_hasLOS(shooter.Position, target.Position, ignore) then
			return { Accepted = false, Reason = "blocked_los" }
		end
	end

	self._lastFire[claim.ShooterUserId] = now
	return { Accepted = true, Reason = "ok", Damage = baseDamage }
end

return CombatResolver
