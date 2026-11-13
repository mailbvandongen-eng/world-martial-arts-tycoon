# QA audit (place version 19 → fixes published as version 20)

Date: 2026-11-12. The brief called the build "version 16". The live place was version 19
(16 + developer menu v17 + HUD fix v18 + phase B fighting v19); this audit covers what is live.

## How this audit was done (and what it could not do)

**Roblox Studio is not available here.** The game has never been run by me in Studio or in a
live server. Everything below comes from code inspection, offline tests (stock Lua 5.4 running
the real modules), a geometry audit of the real built rooms, and renders made from the real
building code. The owner has played earlier versions on a phone and PC (v7–v15) and reported
bugs, which were fixed; v16–v19 have not been played by anyone yet as far as I know.

### Test evidence (kept separate on purpose)

| Kind | What | Result |
|---|---|---|
| Studio / live play | none possible here | **not performed** |
| Automated: `tests/run.lua` | 27 suites, 126,460 checks | pass. **The count is not meaningful:** 74,207 checks are per-event checks of the bout engine and 46,955 are pairwise distance checks between training spots. Small suites (economy 11, purchases 14, security 13 checks) carry most of the real logic coverage. |
| Automated: `tests/data_safety.lua` (new) | real DataService against a fake DataStore: save/reload of every kind of progress, DataStore failures, session locks, old saves, sandbox, storable data after 1 h of simulated play | 55 checks pass. Fails on the old code (proves it catches the sandbox defect). |
| Automated: `tests/audit_geometry.lua` (new) | every room type × level 1–5 built with the real RoomBuilder; every NPC route checked against the real built equipment, equipment vs walls and doorway | **851 findings before fixes** (443 after fixing a bug in the audit itself), **0 after fixes** |
| Static | `tools/check.py`: Lua 5.4 syntax, Luau subset, requires, remotes, actions, panels, notify kinds, props | pass |
| Manual code review | DataService, MonetizationService, ActionService (all 43 actions), PlayerService join/leave, prompts, UI window framework, HUD layout maths | findings below |
| Renders | competition hall with a posed bout, sumo and strength rooms with posed NPCs | looked correct after fixes |

## Defects found

| # | Severity | System | Defect | Root cause | Status |
|---|---|---|---|---|---|
| 1 | **Major** | NPC navigation (fitness, cardio, strength, recovery rooms) | NPCs walked straight through the treadmills, bikes, rowers, racks, benches, massage tables and ice baths of the stations in front of them | the walking lane of a machine station was its own column (`lane = x`), which runs through every machine in that column | **fixed**: lanes run between columns; strength room columns 7.4 studs apart because racks and benches are 5.5 wide. Geometry audit: 0 route problems |
| 2 | **Major** | Sumo room | shiko spots on the diagonals stood *inside* the 0.9-stud square base of the dohyo (legs in the clay); spots behind the dohyo walked through it | spots placed on a 9.2 radius circle, the base is a 16×16 square | **fixed**: corner spots stand on the base (y 0.9), spots behind are reached around the side |
| 3 | **Major** (developer only, real money) | DataService / Monetization | a Robux purchase made while a developer was in sandbox mode went into the test data and was thrown away; also no autosave at all during the sandbox (session lock could expire after 10 min) | `save()` returned early in the sandbox; ProcessReceipt used the sandbox data | **fixed**: the sandbox saves the *real* data; purchases and pass grants always go to the real data. Covered by `data_safety.lua` |
| 4 | **Major** (regression from v18) | HUD on phones | the right-hand column of 7 menu buttons reached the bottom of a landscape phone screen, over the Roblox jump button | v18 moved the column to the top; on a ~844×390 phone the column ends at y≈572 of 604 while the jump button starts at ≈330 | **fixed**: on touch screens the 7 buttons are a 3×3 block top-right (ends at ≈276). PC unchanged |
| 5 | Minor | UI windows | window size was computed from the full screen, not the area below the Roblox top bar | `UI.viewport()` ignored the GUI inset | **fixed** |
| 6 | Minor | Kumite (own bout) | no way to leave a running bout; the player stayed frozen on the mat until it ended | missing cancel path | **fixed**: "Leave bout" (counts as a loss) |
| 7 | Minor | Tournaments UI | did not say matches are simulated; the arena replay could look like a live fight | wording | **fixed**: panel states matches are simulated by the server from academy strength |
| 8 | Minor | BJJ / wrestling | lying grapple dummies stuck 0.5 stud through the side walls | dummy 4.6 long, placed 2.6 from the wall | **fixed** |
| 9 | Minor | Restrooms | stall doors stood half closed in the walking line | door rotated −25° | **fixed**: door open against the stall side |
| 10 | Minor | Showers / restrooms Lv 5 | level-5 trophy case stood on a walking route | decoration placed in every room type | **fixed**: not in amenity rooms |

## Release gates

| Gate | Result | Evidence / reason |
|---|---|---|
| A Building | **NOT VERIFIED** (offline: pass) | geometry audit 0 problems for 120 room/level combinations; layout tests; but player walking and collisions never observed in Roblox |
| B NPCs | **NOT VERIFIED** (offline: pass) | routes, reservations (capacity tests), timelines tested; animations only seen in offline renders; never observed moving in Roblox |
| C Gameplay | **PASS with limitations** (logic only) | server scores every challenge/kumite/exam/tournament; rewards server-side, capped (cooldown, 15 full plays/day). Limitations below |
| D Controls | **NOT VERIFIED** | every panel uses one window framework with a fixed 44 px ✕ (header never scrolls); layout maths checked for phone/tablet/PC; never seen on a device after v18 |
| E Data & security | **PASS offline, NOT VERIFIED live** | data safety tests; all 43 actions use the caller's own data, validate input, are rate limited; developer actions server-checked. Real DataStore never tested |

## System status

| System | Files | Status | Notes |
|---|---|---|---|
| Player data / DataStore | DataService, Schema | WORKING WITH LIMITATIONS | tested against a fake store incl. failures, locks, migration, sandbox. Not tested on real DataStores |
| Academy ownership / plots | PlotService, ActionService | WORKING WITH LIMITATIONS | ownership is implicit (server uses the caller's own plot); prompts on others' plots only act on your own data |
| Building, upgrades, room growth | Academy, RoomBuilder, Layout | WORKING WITH LIMITATIONS | tested + geometry audit; props have no collision (players walk through equipment) |
| NPC spawn / routes / stations / reservations | Simulation, Visits, Stations, NPCController | WORKING WITH LIMITATIONS | deterministic waypoints (no PathfindingService, no recalculation needed: routes cannot be blocked). Never observed live |
| Discipline animations & outfits | Poses, Rig, Appearance, Disciplines | WORKING WITH LIMITATIONS | procedural, primitive-built; looked right in renders |
| Students, belt exams, sparring | Activities, Competition | WORKING WITH LIMITATIONS | logic tested; client playback not observed |
| Trainers | TrainerGen | WORKING WITH LIMITATIONS | tested |
| Economy, collection, salaries | Economy, Academy, Simulation | WORKING WITH LIMITATIONS | tested; balance tuned earlier on owner feedback |
| Missions, daily, events, achievements | Progress, Activities | WORKING WITH LIMITATIONS | tested |
| Training challenges (5) | Activities, Training panel | PARTIALLY IMPLEMENTED as skill games | all five are the **same rhythm-tap mechanic** with different labels; sumo has no real balance or ring boundary, boxing no defence. Timing does decide the score. Exit = close the window |
| Own kumite | Competition, KumiteHUD | WORKING WITH LIMITATIONS | timing-based, levels 1–20; not played on a device |
| Tournaments | TournamentService, Activities | WORKING (server simulation) | server-simulated from academy strength, replayed in the arena; rewards once per tournament, server-only |
| World map / cities | Map panel, Academy | WORKING WITH LIMITATIONS | tested |
| Shop / monetisation | MonetizationService, Store | **NOT IMPLEMENTED live** | all 26 pass/product ids are 0; store shows "coming soon". Receipt handling tested offline |
| Inventory / cosmetics | Progress, CosmeticService | WORKING WITH LIMITATIONS | the "no face" report (v18 fix) not yet confirmed by the owner |
| Leaderboards | LeaderboardService | NOT TESTABLE HERE | OrderedDataStore |
| Multiplayer | all services | NOT TESTABLE HERE | 8 plots; designed per player |
| Audio | AudioController, Config/Audio | WORKING WITH LIMITATIONS | 18 sounds uploaded (v21, tools/upload_audio.py); Roblox moderation and playback not yet confirmed in game |
| Developer menu | Dev panel, DevTools | WORKING WITH LIMITATIONS | tested offline |

## Known limitations that remain

1. Nothing has been run in Roblox since v15; v16–v20 need a play session (checklist in TESTING.md / DEV_MENU.md).
2. Training challenges are one shared rhythm mechanic; they can be botted with perfect timing (the client knows the prompts). Rewards are capped, so the damage is limited.
3. Tournament entry fee is lost if the player leaves the server before the results.
4. Props have no collision: players can walk through equipment (NPCs no longer do).
5. Sumo spots on the dohyo base pop up 0.9 studs when the NPC arrives (no step animation).
6. No audio (ids 0) and no Robux products/passes (ids 0).
7. Performance: no measurements exist. NPC cap per setting (12/32/60), distance culling and lower update rates for far NPCs are in the code; mobile performance unverified.
8. Real DataStore behaviour (throttling, budgets, real JSON encoder) only testable in a place with API access.

## Recommendation

**NOT READY FOR RELEASE. READY FOR A LIMITED PLAYTEST** (owner + a few testers, private).
The logic is well covered offline and the defects found here are fixed, but v16–v20 have not been
seen running, the game has no sound and no working store. Next step: one play session on a phone
and a PC following the checklist, then fix what that shows.
