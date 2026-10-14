# Studio-side countermeasures for driver-level ESP / aim assist

Research draft for Roblox experiences facing cheats that hijack graphics (e.g. DX11 Present hooks, shared GPU memory reads) or inject into the client to extract other players’ world positions for wallhacks and aim lock.

**Design reference:** Chronicle-style client streaming — especially “only record what this client already has” (`VisiblePlayers`) vs a server world stream that holds the full match.

**Framing:** Defensive Studio / game-server design only. No reverse-engineering, reproduction, or instructions to build or use cheats.

---

## 1. Threat model

### Attacker capability

| Layer | What the cheater can do |
| --- | --- |
| **GPU / driver hooks** | Read draw calls, constant buffers, or depth/world matrices for anything the **local client already instantiated for rendering**. Positions of characters that exist in that client’s DataModel / render pipeline are readable regardless of Luau obfuscation. |
| **Memory / injector** | Same class of problem: if a HumanoidRootPart (or custom proxy) is replicated to the client, its CFrame is available offline of Studio scripts. |
| **Input / aim lock** | Once positions are known, the cheat synthesizes mouse/camera or fires remotes with perfect aim. Studio can challenge **outcomes** (hits, rates) more than the hook itself. |
| **Not assumed** | Full Roblox server compromise, or access to other players’ machines. |

### Known cheat brands (public, high-level only)

Names that appear in public community discussion of third-party Roblox clients / injectors. **Class and typical marketing claims only** — not internals, not how-to, not endorsement.

| Name (public) | Typical public class | Claims often associated (marketing / community) |
| --- | --- | --- |
| **DX-9** | Client injector / executor lineage (DirectX-era naming) | Script execution in the Roblox client; sometimes bundled visual / combat “features” in community listings |
| **Matcha** | Third-party executor / cheat client | Lua injection; ESP / aim-style scripts run *after* injection |
| **Velocity** | Third-party executor | Script hub / injection; user-loaded scripts for ESP, aim, movement |
| **Volt** | Third-party executor | Same class: inject then run community scripts |
| **Xeno** | Third-party executor | Same class: client-side script execution |

**Studio implication:** Brand does not change the defense. If enemy transforms are on the victim client, GPU- or memory-class tools in this family can surface them. Mitigations are **interest-managed replication** and **server-authoritative combat**, not detecting a specific product name.

### What the cheater already sees vs what authority can withhold

| Pipeline | Analogy in a live game | Cheater with GPU / injector tools |
| --- | --- | --- |
| **Server world stream** | Default Roblox replication: every character in Workspace for everyone | **Sees all of it.** Anything replicated for rendering is fair game. |
| **Client view** (`VisiblePlayers`: viewport ∪ nearby, max N) | Interest / fog-of-war replication: only entities this player “should know” | **Sees only the filtered set** (plus anything else the engine still replicates). |
| Client camera / cursor | Local aim/camera | Trusted only as claims; cheater can spoof before any RemoteEvent. |

**Bottom line:** Driver-level ESP is mostly outside Studio’s reach **once** enemy transforms are on the victim client. Studio’s high-leverage work is **shrinking and distorting that local set**, and **validating combat on the server**.

---

## 2. What Studio / game-server Luau can and cannot do

### Can (practical levers)

1. Keep authoritative state on the server — clients propose intent; server resolves.
2. Interest management / fog-of-war replication — custom proxies or shells only when LOS / radar / range allow.
3. Delayed / LOD replication — far or occluded players get stale or quantized CFrames.
4. Fake / decoy entities — only with server hit validation.
5. Aim / input validation — server raycasts from last known server pose.
6. Rate limits on fire / hit claim remotes.
7. Anomaly detection — headshot %, snap angular velocity, pre-aim before reveal.
8. Treat each client’s allowed entity set as a **capability** (Heartbeat / LOS ticks).

### Cannot (non-goals for Studio alone)

| Non-goal | Why |
| --- | --- |
| Stop DX11 / Vulkan / graphics-driver hooks | Outside the DataModel; needs platform client integrity. |
| Hide entities that are still fully replicated & rendered | ESP reads the same buffers the GPU uses. |
| Trust client cursor / camera | Forgeable. |
| Patch other players’ cheats remotely from Luau | No Studio API for foreign-process protection. |
| Detect a named executor by string / brand from Luau | Unreliable theater; wrong layer. |

---

## 3. Mitigations ranked by impact

| Rank | Mitigation | Impact on ESP / aimlock |
| --- | --- | --- |
| **1** | Interest-managed replication | Highest vs wallhacks |
| **2** | Server-authoritative hits / projectiles | Highest vs aimlock payoff |
| **3** | LOS / occlusion gates before precise transforms | High |
| **4** | Delayed / quantized / LOD transforms | Medium–high |
| **5** | Aim anomaly scoring + rate limits | Medium (friction) |
| **6** | Decoys / ghost swarms | Medium (noise); needs #2 |
| **7** | Client-side “anti-ESP” LocalScripts | Low vs driver hooks |
| **8** | Obfuscating remotes / renaming | Negligible vs GPU ESP |

---

## 4. Explicit non-goals

- Defeating graphics-driver / kernel-level cheats from Studio Luau alone.
- Shipping instructions, PoCs, or reproductions of injectors or aim/ESP tools.
- Claiming client-side LocalScripts can “detect DX11 hooks.”
- Relying on remote name secrecy as primary defense.

Platform-level needs (Roblox client integrity, OS AC, hardware bans) sit **outside** this Studio plan; Studio work should assume those are incomplete and minimize the value of a successful hook.
