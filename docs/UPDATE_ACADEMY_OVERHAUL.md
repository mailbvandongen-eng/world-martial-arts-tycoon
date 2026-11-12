# Update: Academy Overhaul & Gameplay Expansion (place version 16)

Date: 2026-11-12. This document answers the 14 deliverables of the overhaul brief.
"Tested" below always says how; **nothing in this update has been played in Roblox Studio
by me** — the owner played earlier versions on a phone and PC (version 7–15), the
remaining checks are offline (see section 14).

## 1. Summary of changes

- **Academy building rebuilt (Phase 1).** Plot 150×200 → 192×284 studs. A 20-stud central hall
  with in/out lanes, 10-stud walkways in front of every room row, a reception of 88×40 with glass
  front, check-in desk and queue rails, lounge, register and trophies. Room cells 40×36 (were 28×24).
  Rooms have their own base size per type and **grow with every upgrade** (e.g. karate dojo 30×26 →
  40×36). City architecture now changes the building: facade material and height, hall floor, and a
  distinct entrance per city (classic, gabled Amsterdam, industrial Rotterdam, brick towers London,
  torii Tokyo, Thai gold-roof Bangkok, hanok Seoul, glass New York, golden arch Dubai, neon Las Vegas).
- **Training stations.** Every room type has predefined training positions with the equipment
  placed on them: heavy bags, speed bags, the ring/octagon sparring pair, pad work with the trainer,
  makiwara, kick targets, wooden dummies, BOB dummies, throw and grappling dummies, partner pairs on
  the tatami, the dohyo bout pair and a shiko circle around it, teppo posts, treadmills, bikes,
  rowers, benches, squat racks, pull-up bars, dumbbell and kettlebell racks, lockers, showers, toilet
  stalls, massage tables, ice baths, bar stools and shop shelves.
- **Reservations.** One station per seat per class session (server), so two students never share a
  spot; the next class waits in a waiting area outside the door until the previous class has left.
  Partner drills only run when the partner seat is actually taken.
- **New UI (Phase 2).** Mobile-first HUD, reusable window framework with a fixed header and a 44-px
  close button, open/close animation, toggle-to-close, Esc / gamepad B / keyboard shortcuts,
  safe-area insets. New panels: More, Students, Tournaments, Training; Academy Management redesigned
  (Rooms / Disciplines / Business); Statistics got an Achievements tab.
- **Active gameplay (Phase 3).** 5 training challenges (mini-games), scheduled server tournaments with
  a boulevard arena, student profiles with belts and graduations, 16 achievements, 9 new missions,
  recruitment tokens.

## 2. Created and modified files

Created: `src/shared/Modules/Stations.lua`, `src/shared/Config/Activities.lua`,
`src/server/Domain/Activities.lua`, `src/server/Services/TournamentService.lua`,
`src/client/UI/Panels/{More,Students,Tournaments,Training}.lua`, `tests/render_room.lua`,
`docs/UPDATE_ACADEMY_OVERHAUL.md`, `docs/images/training_rooms.png`.

Modified: `src/shared/Modules/{Layout,Visits,Formulas,Poses,Rig,Remotes}.lua`,
`src/shared/Config/{Rooms,Quests,Disciplines}.lua`, `src/server/World/{RoomBuilder,PlotBuilder,Props,WorldBuilder}.lua`,
`src/server/Domain/{Schema,Simulation,Progress,TrainerGen}.lua`,
`src/server/Services/{PlotService,PlayerService,ActionService,LeaderboardService}.lua`, `src/server/Main.server.lua`,
`src/client/Controllers/{NPCController,State,EffectsController}.lua`, `src/client/Main.client.lua`,
`src/client/UI/{UI,HUD}.lua`, `src/client/UI/Panels/{Academy,Stats,Leaderboards}.lua`,
`tests/{run,roblox_stub,render_plot}.lua`, `tools/render_scene.py`.

## 3. The new academy layout

```
ENTRANCE (city gate) → RECEPTION (queue → desk) → CENTRAL HALL (inbound lane x=-4)
  → WALKWAY of the row (inbound lane) → ROOM DOOR → entry lane inside the room → STATION
  ... class ...
  STATION → entry lane → DOOR → WALKWAY (outbound lane) → HALL (outbound lane x=+4) → EXIT
```
Every door opens onto a walkway, so nobody crosses another room. The first 4 studs of every room
(the entry lane) never holds equipment, so doors are never blocked. 5 rows × 4 columns = 20 slots;
cities offer 6–16 of them (+4 with the Extra Slots pass).

## 4. Training behaviour per discipline

| Discipline | What students do (stations) | Trainer |
|---|---|---|
| Karate | Formation facing the kamiza/trainer performing the same kihon/kata technique in sync; kumite pairs in later periods (punch vs block); makiwara posts along the walls | Demonstrates kata, counts |
| Boxing | Heavy-bag combos along both walls, speed bags on the back wall, sparring pair in the ring, pad work with the coach, shadow boxing / footwork in the middle | Holds mitts for the pad-work student |
| Judo | Partner pairs on the tatami (throw / breakfall, grip fighting, groundwork), uchikomi on throw dummies | Demonstrates throws |
| Sumo | Bout practice (push / tachi-ai) on the raised dohyo, shiko circle around it facing the centre, teppo on the posts | Oyakata watches from the back |
| Fitness rooms | Mats (push-ups, squats, jumping jacks, lunges), dumbbell/kettlebell racks; strength: squat racks, bench press (lying), pull-up bars; cardio: treadmills (running), bikes (seated pedalling), rowers | Optional |
| Others | Striking template (kickboxing, Muay Thai, MMA) or grappling template (BJJ, wrestling) or formation template (taekwondo, kung fu, Krav Maga) with their own equipment and moves | |

Amenities: lockers (changing), showers (inside the stall), restrooms (new room type), recovery
(massage tables, ice baths), juice bar (sitting at the bar with a drink), merch shop (browsing shelves).

## 5. NPC navigation system

Deterministic waypoint navigation (no PathfindingService): the server plans each visit once
(queue, desk, room, station, session, amenity, exit) and every client derives the identical
route from the plan (`Modules/Visits`, `Modules/Stations`). Routes only use the hall lanes,
walkways, doorways and each room's entry lane, so NPCs cannot walk through walls or equipment and
cannot get stuck; there is nothing to recover from and no per-frame path computation. Why not
PathfindingService: NPCs are client-side anchored models without Humanoids (no physics cost), and a
fixed layout with known doors gives exact, cheap and identical routes on every client. Stations are
reserved per class session by the server (seat = station), waiting areas are in the walkway outside
each door, and partner stations know their partner.

## 6. New UI

Top: cash, gems, level + XP, reputation, current city (opens the map), boosts.
Left: Missions, Daily, Events, next objective. Right: Build, Academy, Students, Trainers,
Tournaments (badge while registration is open), Shop, More. Bottom (centred, clear of the thumbstick
and jump button): earnings per hour, Collect/Claim, Train. More: World Map, Inventory, Martial Arts,
Mastery, Statistics, Achievements, Leaderboards, Visit Players, Settings, Rebirth.
Shortcuts: B build, C collect, R training, T trainers, G academy, N students, U tournaments,
M map, Q missions, P shop, Tab more, Esc close.

## 7. Mini-games (Training Challenges)

Kata Challenge (karate), Heavy Bag Combos (boxing), Throw Practice (judo: grip → balance → throw),
Dohyo Balance (sumo), Workout Rush (fitness). Prompts are generated by the server; the client sends
its taps with timestamps; the server scores (perfect ≤ 0.15 s, good ≤ 0.35 s), validates the timing
window and grants XP, mastery, a little cash and event points. Cooldown 25 s, full rewards for the
first 15 plays per UTC day, 20% after that.

## 8. Missions and tournaments

New daily missions: train 10 karate students, complete 5 boxing classes, train 10 judo students,
complete 3 training challenges (+1 recruitment token), complete a fitness challenge, enter a
tournament. New weekly: win a tournament (+2 tokens), promote 5 students (+1 token), score 80+ in 10
challenges. Missions for locked disciplines are not rolled.
Tournaments: every 8 minutes, rotating Karate Championship, Boxing Tournament, Judo Championship,
International Martial Arts Cup, Kickboxing Cup, Sumo Challenge, Muay Thai Fight Night, Taekwondo
Open. 150 s registration (entry fee), 8-academy bracket filled with rival academies, three rounds
revealed 35 s apart, featured match fought in the boulevard Tournament Arena, prizes for winner,
runner-up, semi- and quarter-finalists, wins on the leaderboard.

## 9. DataStore changes and migrations

Save version 3 → 4. New fields with defaults: `students`, `nextStudentId`, `achievements`,
`discStats`, `tokens.scout`, `minigame {day, plays, lastAt, best}`, `tournament.key`,
`stats.{miniGames, tournamentWins, tournamentsPlayed, graduations}`. Migration 3 → 4 only adds;
validation repairs student entries. Nothing is reset. Room records are unchanged (slot keys stay
the same; rooms simply appear in the new, larger layout).

## 10. Configuration requiring manual setup

Unchanged from before: Game Pass / Developer Product ids (`Config/Monetization.lua`), audio asset
ids (`Config/Audio.lua`, files in `assets/audio`). Clothing ids are filled in already.

## 11. Animation IDs / assets still required

None required: all 100+ moves are procedural (`Modules/Poses`) and work on the game's own NPC rig;
player emotes use `Motor6D.Transform`. Optional upgrade: replace procedural moves with Roblox
Animation assets for smoother motion (would need uploads).

## 12. Studio steps that cannot be automated

Set the experience public when Roblox's new-creator waiting period ends; create passes/products;
upload audio; test with several players.

## 13. Known bugs / incomplete features

- Not verified in Roblox yet: lighting and readability inside the larger rooms, the new HUD on very
  small phones, the arena fight camera distance, ProximityPrompt reach in bigger rooms.
- Visitors walk through each other in the hall at busy moments (no avoidance; lanes reduce it).
- Rhythm timing is measured on the client; a cheater can send perfect timings. Rewards are capped
  (cooldown + daily limit) so the impact on the economy is small.
- Tournaments are simulated (no real-time combat); "friendly challenges" between players are not
  implemented.
- Event-specific missions and event leaderboards are not implemented (events give bonuses, points
  and exclusive rewards).
- Dynamic room sizes are per room type and level within a fixed grid cell (max 40×36), not freely
  placed buildings.

## 14. Testing results

**Actually tested (offline, this session):**
- `python3 tools/check.py`: 80 files parse, Luau-compatible syntax, all requires resolve, all
  remotes/actions/panels/props/materials exist.
- `lua5.4 tests/run.lua`: **53,091 checks, 0 failures**, including: every room type × 5 levels —
  stations inside the walls, out of the entry lane, ≥ 2.4 studs apart, not on another station's
  equipment, not inside the ring/octagon/dohyo unless they belong there, clear of the trainer,
  enough stations for the room's capacity; visitor timelines continuous; challenges scored by the
  server (perfect = 100, wrong/duplicate/NaN answers = 0, early submissions refused, daily cap);
  tournaments (schedule, entry rules, stronger academies win more but not always, prizes); students
  (roster bound, rank capped by academy mastery, graduations happen in a played simulation);
  achievements unlock once; save v1 → v4 migration; economy bot (3 h: level 12, second city).
- Renders of the real builders with posed NPCs (`tests/render_room.lua`, `tests/render_plot.lua`):
  `docs/images/training_rooms.png`, `docs/images/academy_*.png`.
- Place version 16 published to the private experience.

**Not tested:** anything that needs the Roblox engine (rendering, input, mobile layout, DataStores,
multiplayer, performance). Please play it and send screenshots / F9 console output.

## TODO

1. Owner playtest of version 16 on phone and PC (rooms, HUD, challenges, a tournament).
2. Tune challenge timing windows after feedback.
3. Friendly academy challenges between players.
4. Event missions and event leaderboard.
5. Optional: Animation assets, audio uploads, monetisation ids.
