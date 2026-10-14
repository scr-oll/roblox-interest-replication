# Place spike

Use a blank Roblox Place (not committed as `.rbxl` here) to validate the modules under `src/`.

## Suggested setup

1. `ServerScriptService`
   - `InterestManager` (ModuleScript) ← `src/InterestManager.luau`
   - `CombatResolver` (ModuleScript) ← `src/CombatResolver.luau`
   - `AnomalyScore` (ModuleScript) ← `src/AnomalyScore.luau`
   - `Bootstrap` (Script) — require modules, Heartbeat recompute, wire one RemoteEvent for fire claims
2. Spawn 8 dummy NPC models on the server only (not parented into a shared replicated folder until interest opens).
3. For each player, maintain a folder under `PlayerGui` or a per-player container that only that client receives (or drive visuals via remotes + client LocalScript). Prefer patterns that **do not** put all enemy `HumanoidRootPart`s in Workspace for everyone.

## Success criteria

- An enemy outside range/LOS is **absent** from the observing client’s DataModel (or present only as a non-precise proxy).
- A forged “perfect aim” remote without AllowedSet + server LOS deals **no** damage.
- Footsteps / audio / killfeed tuned so they do not re-leak precise transforms for hidden enemies.
