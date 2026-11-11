# Architecture

## Principles

- **Server-authoritative.** The server owns all game state. Clients send intentions
  ("upgrade slot 3"), never amounts. Every request is validated and rate limited.
- **Config-driven.** Disciplines, rooms, cities, trainers, customers, missions, events,
  cosmetics and store items are data in `src/shared/Config`. A new discipline is one entry
  in `Disciplines.lua` (its room, ranks, classes, outfits, moves and trainers follow).
- **Pure domain layer.** All rules (economy, construction, simulation, missions, rebirth,
  purchases) live in `src/server/Domain` without Roblox APIs, so they run in the offline
  test suite. Services are thin adapters around them.
- **Cheap NPCs.** Visitors are simulated on the server as data. The server sends one small
  message per visitor (its plan); every client builds, animates and removes the model locally.

## Runtime overview

```
Client                                   Server
------                                   ------
UI / prompts ──Action(RemoteFunction)──▶ ActionService ─▶ Domain (validate + mutate)
                                              │                 │
State controller ◀──State (owner only)── PlayerService ◀────────┘ (4 Hz loop)
NPCController   ◀──Visitors (all)──────── Simulation plans / rank-ups / championships
NPCController   ◀──Plots (all)─────────── PlotService (room layout, trainers)
EffectsController ◀─Notify────────────── toasts, level-ups, purchases …
EmoteController ◀──Emote────────────────▶ CosmeticService (validates ownership)
                                         DataService (DataStores, session locks)
                                         MonetizationService (ProcessReceipt, passes)
                                         LeaderboardService (OrderedDataStores)
```

## Server

| Module | Responsibility |
|---|---|
| `Main.server.lua` | creates remotes, starts services in order |
| `Services/DataService` | DataStore load/save, session locking (lock with JobId, expires after 10 min), retries with exponential backoff and request-budget waiting, autosave every 90 s, save + release on leave (called by PlayerService after its cleanup), `BindToClose`, in-memory fallback in Studio, permanent receipt store |
| `Services/PlotService` | world + 8 plots, claiming, building the active city's academy, rebuilding single rooms, register display, broadcasting plot layouts |
| `Services/PlayerService` | per-player runtime and the 4 Hz game loop: construction completion, visitor spawning and settlement, business day (rent, salaries, maintenance, dues, passive income of other branches), automation, championships, missions/event tracking, state pushes (max 2/s, only when dirty), offline earnings |
| `Services/ActionService` | the only client→server entry: 32 actions with validation (`Domain/Validate`) and token-bucket rate limits (`Domain/RateLimiter`) |
| `Services/MonetizationService` | Game Pass verification (on join, after purchase), ProcessReceipt with three-layer idempotency, Studio-only test grants |
| `Services/LeaderboardService` | 7 OrderedDataStore boards, plaza boards, in-server rankings |
| `Services/CosmeticService` | outfit overlays welded on R15/R6 avatars, auras, title billboard, emote validation |
| `Domain/*` | `Schema` (defaults, migrations v1→v3, validation), `Economy`, `Academy`, `TrainerGen`, `Simulation`, `Progress`, `Purchases`, `ReceiptLedger`, `RateLimiter`, `Validate` |
| `World/*` | `WorldBuilder` (boulevard, spawn, boards, flags, lighting), `PlotBuilder` (ground, facade, gate, reception, city architecture, decorations), `RoomBuilder` (floors, walls, signs, equipment by level, premium finishes, construction sites), `Props` (≈90 primitive-built props) |

### The visitor simulation

1. `Simulation.step` spawns visitors at an interval set by reception level, reputation,
   members and boosts (capped by capacity for performance).
2. `Simulation.planVisit` decides everything up front: category (reputation-gated, city
   weighted), interest (city demand; unserved disciplines still appear = "demand"), the best
   room (VIP/coaching preferences), reception queue time, the next class session with a free
   seat (classes are scheduled sessions; capacity per session), satisfaction (trainer, room
   level, amenities, premium equipment, waiting, picky categories), payment, mastery XP, an
   optional amenity/shop visit and the exit time.
3. The plan goes to all clients once. `Modules/Visits` turns it into a timeline of walk/stay
   segments on both sides, so the client animation and the server's accounting agree.
4. When the class ends, `Simulation.settle` pays into the register, adds XP, reputation,
   mastery, trainer XP, memberships, event points and mission progress.

## Client

| Module | Responsibility |
|---|---|
| `Controllers/State` | latest state snapshot, plot layouts, `State.call(action, payload)` |
| `Controllers/NPCController` | visitors (lazy models, render distance 260, NPC cap from settings, far NPCs updated every 3rd frame), trainers teaching in sync with the class, receptionists, championship fighters, rank-up celebrations, move sounds |
| `Controllers/WorldController` | which prompts are usable (own plot only), what they open, construction progress boards, animated gym lighting, per-city lighting/atmosphere |
| `Controllers/EffectsController` | notifications → toasts, banners, cash popups, particles, sounds |
| `Controllers/AudioController` | 2D and 3D sounds, loops; ids of 0 are skipped |
| `Controllers/EmoteController` | procedural emotes on R15/R6 avatars via `Motor6D.Transform` |
| `UI/UI` | ScreenGui, UIScale for screen size, toasts, banners, confirm dialog, panel manager, gamepad bindings |
| `UI/HUD` | top bar, left/right buttons, objective, bottom bar |
| `UI/Panels/*` | build, room, trainers, academy, map, mastery, quests, daily, store, inventory, stats, leaderboards, players, settings, rebirth |

## Characters and animation

- `Modules/Appearance` turns (seed, discipline, role, rank, category, rarity) into a full
  description: body type (incl. sumo, kid, heavy, athletic), skin tone, face, hair, and
  discipline clothing (gi + lapels + rank belt, judogi, dobok, mawashi + sagari + topknot,
  boxing gloves/wraps, Thai shorts + prajiad, shin guards, singlet, kung fu frog buttons +
  sash, rash guards, tracksuits, mitts, Thai pads, VIP sunglasses …). Deterministic per seed.
- `Modules/Rig` builds a 15-part model plus clothing parts and poses it with forward
  kinematics; feet are auto-grounded; parts are anchored and moved with `BulkMoveTo`.
- `Modules/Poses` is the animation library: 85+ original keyframe moves, a separate set per
  discipline (no boxing moves reused for judo or sumo), plus coaching, fitness, walking,
  queueing, rank-up and emote moves. Students in one class perform the same drill in sync;
  partner disciplines alternate solo drills with paired throws/sweeps/pushes.

## Data model (save version 3)

`Domain/Schema.defaults()` is the reference. Main fields: `cash, gems, level, xp, reputation,
rebirths, register, automation, activeCity, cities{cityId → {rooms{slot → room}, members}},
disciplines, mastery, trainers{uid → trainer}, boosts, cosmetics{owned, equipped}, quests,
daily, event, purchases{passes, receipts, products}, ratings, stats, flags, settings`.
Room slots are string keys ("0" = reception) because DataStores store JSON.
Migrations: v1 (single academy) → v2 (cities) → v3 (trainer assignment stored on rooms).
