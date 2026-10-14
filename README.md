# Roblox interest-managed replication (Studio research)

Defensive research into **Studio-side** mitigations for client-side ESP / aim assist that read local render or memory state (e.g. graphics Present hooks, injectors). This is **not** a client integrity product and does **not** reverse-engineer or reproduce third-party cheats.

## Goals

1. **Shrink the local enemy set** — only replicate / instantiate entities a player is allowed to know (`VisiblePlayers`-style interest / fog-of-war).
2. **Server-authoritative combat** — hits and damage resolve from server poses and rules, not client aim claims.
3. **Document threat class** — high-level public notes on how driver/injector ESP works against fully replicated characters.

## Non-goals

- Stopping graphics-driver or external process hooks from Luau alone.
- Building, distributing, or instructing how to use cheats or injectors.
- Reverse-engineering proprietary cheat binaries.
- Claiming client LocalScripts can detect DX11 / Present hooks.

## Layout

```
docs/architecture.md          # Threat model + mitigation ranking
docs/research.md              # Full research write-up
src/InterestManager.luau      # Per-player AllowedSet policy sketch
src/CombatResolver.luau       # Server-authoritative hit validation sketch
src/AnomalyScore.luau         # Soft telemetry / friction sketch
place/README.md               # How to wire a blank Place spike
```

## Quick start (Studio)

1. Create a blank Place; enable Server Scripts.
2. Drop `InterestManager` and `CombatResolver` under `ServerScriptService` (ModuleScripts).
3. Drive `InterestManager:Recompute(player)` on a Heartbeat or fixed tick; only spawn/update enemy proxies for `AllowedSet`.
4. Route weapon remotes through `CombatResolver` — never apply damage from raw client “I hit X” without server ray / sim.

## Security framing

Anything that exists in a victim client’s DataModel / render pipeline can be read by GPU- or memory-class tools. Studio’s high-leverage work is **withholding and validating**, not obfuscating remotes.

See `docs/research.md` for the full threat model and mitigation table.
