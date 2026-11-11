# Testing report

Date: 2026-11-12. Environment: Linux server, no Roblox Studio, no Rojo/Luau binaries
(downloading third-party tool binaries was not permitted in this environment).

**Most important limitation: the game has not been run in Roblox Studio or on Roblox.**
Everything below was verified offline. Roblox-only behaviour (physics, rendering, UI layout
on real screens, DataStores, MarketplaceService, replication, StreamingEnabled) still needs
the manual test plan at the end of this document.

## How the code was verified without Roblox

The code base is written in the common subset of Luau and Lua 5.4 (no type annotations,
no `+=`, no `continue`), so stock Lua tooling can check and run it.

| Check | Command | Result |
|---|---|---|
| Static checks | `python3 tools/check.py` | passed: 71 files parse; no Lua-5.4-only syntax; 289 `require` paths resolve in the Rojo tree; all remote names, 32 server actions, 15 panels, Notify kinds, 93 prop keys and materials referenced in code/config exist. The checker was itself tested by injecting 7 deliberate mistakes (all 7 reported). |
| Unit and simulation tests | `lua5.4 tests/run.lua` | **4,622 checks passed, 0 failed** |
| Place file | `python3 tools/build_rbxlx.py` | `build/WorldMartialArtsTycoon.rbxlx`, 71 scripts, well-formed XML, script count matches source |
| Character/pose renders | `lua5.4 tests/render_poses.lua` + `tools/render_poses.py` | `docs/images/disciplines.png`, `docs/images/keyframes.png` |
| Academy renders | `lua5.4 tests/render_plot.lua` + `tools/render_scene.py` | `docs/images/academy_*.png` |

The test harness (`tests/harness.lua`) fakes `game:GetService`, `script.Parent` and
`require` on instances, so the real ModuleScripts load unchanged. `tests/roblox_stub.lua`
adds CFrame/Vector3 maths and a generic Instance so `Rig`, `RoomBuilder`, `PlotBuilder` and
`Props` run too (their parts are exported and drawn).

### What the test suite covers

- **Config integrity:** 12 disciplines with 5 class tiers, ranks, outfits, room equipment,
  and every move name present in the animation library; a unique move set per discipline;
  24 room types; 10 cities in ascending requirements with valid references; rarity odds add
  up to 100%; all cosmetics, events, passes and daily rewards reference existing items;
  89 well-formed animations.
- **Layout:** 20 room slots never overlap and stay inside the plot; every student spot is
  inside its room; the 8 plots don't overlap.
- **Visitor timelines:** continuous segments; positions/phases at given times match the plan.
- **Save data:** defaults valid; migration of a v1 save to v3; corrupt data repaired (NaN,
  negative, out-of-range, unknown rooms/cities/trainers, unowned equipped cosmetics);
  existing rosters do not get default trainers injected.
- **Academy rules:** locked disciplines, level requirements, occupied/out-of-range/fractional
  slots, one reception, unique amenities, construction timing, upgrade pricing, trainer
  discipline matching, class tiers gated by mastery and room level, city order and
  requirements, register cap and collection, room removal refund.
- **Economy:** XP/level-ups, Double Cash pass + boost stacking, boost expiry, premium
  equipment applies to its discipline only, city specialities, rejection of negative/NaN spends.
- **Trainers:** observed rarity odds over 20,000 rolls match the published odds; scouting
  needs the discipline; deterministic daily market; no double buying; training improves
  stats; level cap; roster limit; premium trainer can't be released.
- **Simulation:** sessions never exceed room capacity; satisfaction 0–100; positive pay;
  visitors leave when nothing fits; business day pays dues, charges expenses and never
  makes cash negative.
- **Progress:** daily/weekly missions roll, track, claim once; daily login streak and reset;
  event rewards; cosmetics purchase/equip rules; objective guide; rebirth resets exactly the
  documented fields and keeps the rest, grants rewards.
- **Purchases:** receipt idempotency (duplicate PurchaseId not granted again, also after a
  "server restart" via save data), unknown products not granted, boosts, one-time starter
  bundle, premium trainer granted once, VIP cosmetics.
- **Security helpers:** rate limiter bursts/refill/per-player; validation of strings,
  integers (fractions, NaN, huge), ids (unknown, `__index`, tables).
- **Appearance:** for 40 seeds per discipline: karate/judo/taekwondo wear gi + lapels +
  belt, sumo has sumo body + mawashi + sagari + topknot, boxers wear boxing gloves, Muay Thai
  prajiad + Thai shorts, kickboxing shin guards, wrestlers singlets, kung fu frog buttons +
  sash; trainers are adults, legendary trainers glow; karate master wears a black gi;
  ≥25 of 40 karate students are visibly distinct; deterministic per seed; VIP/celebrity markers.
- **Poses:** sampling, looping, one-shot hold, airborne keys.
- **Forward kinematics** (manual check with `tests/roblox_stub.lua`): arm/leg forward is
  −Z, left is −X, knees bend backward, leaning moves the head forward, yaw turns left.

### Balance test (bot that never spends Robux)

`tests/run.lua` plays the game for 3 simulated hours with a simple strategy (collect every
30 s, unlock disciplines, build one room each with a common trainer, upgrade, save up for
the next city). `BOT_HOURS=16 BOT_VERBOSE=1 lua5.4 tests/run.lua` gives:

| Time | Level | Reputation | Lifetime earnings | City |
|---|---|---|---|---|
| 1 h | 8 | 961 | $26.8K | Small Town |
| 1.5 h | 10 | | | → Amsterdam |
| 4.1 h | 14 | | | → Rotterdam |
| 9.7 h | 20 | | | → London |
| 16 h | 24 | 14,078 | $2.72M | London |

Real players also earn from missions, daily rewards, events, championships, better trainers
and scouting, so they progress faster than this bot. Balance problems found and fixed during
testing: income too low (×2 class pay), city multipliers too flat (now 1 → 90), visitors
leaving too often early on (unserved demand weight 0.25 → 0.1), base satisfaction too low
for memberships (52 → 60), and new branches bankrupting players with full rent (rent now
scales with used floor space).

## Manual test plan (Roblox Studio)

Not yet executed. Expected results in brackets.

1. **Start:** Play solo. [World builds: boulevard, 8 plots with gold "Claim" pads, 4
   leaderboards, flags. HUD shows $300, ◆50, Level 1. Daily reward panel opens.]
2. **Claim:** walk to a gold pad, hold E. [Teleported to own gate; plot rebuilt with your
   name; karate dojo with Sensei Kenji Mori; receptionist; visitors start arriving.]
3. **Visitors:** watch 2 min. [Visitors in gi with coloured belts walk in, queue at the desk,
   wait outside the dojo, train in sync with the sensei, some visit the juice bar later, then
   leave. Register at reception fills.]
4. **Collect:** HUD Collect button and the register pad. [Cash pop + balance increases.]
5. **Build:** Academy → Disciplines → unlock Boxing at level 2; walk to an empty slot, E →
   build Boxing Room. [Scaffolding + progress board, then a boxing gym with ring and bags.]
6. **Recruit:** Trainers → Recruit → Scout Boxing; Room panel → Assign. [Boxer coach with
   mitts appears; boxers with gloves arrive.]
7. **Upgrade:** Room panel → Upgrade. [Construction, then more equipment, trim, stars.]
8. **Data persistence:** enable API access, play, leave, play again. [Same cash, rooms,
   trainers; "Welcome back" offline earnings after >2 min.]
9. **City:** with enough level/rep/cash, Map → open Amsterdam → Manage. [Plot rebuilds in
   Amsterdam style, lighting changes, old branch shows passive income.]
10. **Store:** each tab; with id 0 use *Test (Studio)*. [Effects apply: Double Cash doubles
    income; golden ring appears; premium trainer in roster; instant construction finishes.]
11. **Real purchase:** after configuring ids, buy a Developer Product with a test account in
    a published place. [Granted once; rejoin does not grant again.]
12. **Multiplayer:** Test with 3 clients. [Each sees the others' visitors and trainers;
    Players → Visit teleports; Inspect shows stats + 3D trainers; Rate once per day;
    leaderboards list all three; announcements appear for city unlocks.]
13. **Mobile/console:** device emulator phone + tablet; gamepad. [HUD scales; buttons
    reachable; B closes panels, Y collects, prompts usable with X.]
14. **Performance:** 8 players with full academies. [Frame rate stays playable; lower
    "Visitors shown" in Settings if not.]
