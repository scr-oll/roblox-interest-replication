# Architecture: interest-managed replication

## Trust boundaries

| Layer | Role | Trust |
| --- | --- | --- |
| Server world | True poses, inventory, match state, hits | Authoritative |
| InterestManager | Per-player `AllowedSet` (LOS ∪ range ∪ rules ∪ max N) | Authoritative policy |
| CombatResolver | Validate fire/hit from server poses | Authoritative outcomes |
| Client DataModel | Only entities in that player’s `AllowedSet` | Untrusted for combat |
| Client camera / cursor | UX / claimed POV | Never ground truth for damage |

## Data flow

```
Server (true poses)
  → InterestManager: AllowedSet(player)
  → replicate / spawn proxies only for AllowedSet
  → CombatResolver: accept/reject hits
Client
  → GPU / memory cheats only see local AllowedSet
  → fire remotes as claims (server validates)
```

## Primary strategies

1. **Proxy parts** — lightweight stand-ins when interest opens; destroy when closed.
2. **Custom characters** — avoid stock Workspace character replication for opponents.
3. **Hybrid** — stock for teammates / short range; proxies for contested fog-of-war.

Default `Players` characters in a shared Workspace remain the weak point for render-hook ESP.

## Mitigations by impact

1. Interest-managed replication (highest vs wallhacks)
2. Server-authoritative hits (highest vs aimlock payoff)
3. LOS / occlusion gates before precise transforms
4. Delayed / quantized / LOD transforms
5. Aim anomaly scoring + rate limits
6. Decoys (only with #2)
7. Client-only “anti-ESP” LocalScripts — low value vs driver hooks
