# Implementation status

See also the QA audit [QA_AUDIT.md](QA_AUDIT.md) (version 20) and the latest updates: [UPDATE_ACADEMY_OVERHAUL.md](UPDATE_ACADEMY_OVERHAUL.md) (version 16) , [DEV_MENU.md](DEV_MENU.md) (developer menu, version 17) and [UPDATE_PHASE_B_FIGHTING.md](UPDATE_PHASE_B_FIGHTING.md) (fighting, version 19).

Legend: **Implemented** = code written and wired end-to-end, covered by offline checks where
possible · **Needs Studio test** = implemented, but only verifiable in Roblox · **Asset
needed** = works, but a Roblox upload/id is required · **Not implemented**.

None of the features has been run in Roblox Studio yet (see [TESTING.md](TESTING.md)), so
every Roblox-facing item carries *Needs Studio test*.

## Acceptance criteria (first playable release)

| # | Criterion | Status |
|---|---|---|
| 1 | A player can claim an academy | Implemented, needs Studio test (claim pads + auto-claim after 45 s + HUD button) |
| 2 | A player can construct rooms | Implemented, needs Studio test (build pads, Build panel, construction sites) |
| 3 | Students physically enter the academy | Implemented, needs Studio test (client-side NPCs walk server-planned routes) |
| 4 | Students have appropriate martial arts appearances | Implemented; verified offline by tests and renders (`docs/images/disciplines.png`) |
| 5 | Students choose relevant disciplines | Implemented; tested (interest by city demand → matching room or they leave) |
| 6 | Instructors teach classes | Implemented, needs Studio test (trainers animate teaching moves during sessions) |
| 7 | Classes generate revenue | Implemented; tested (settlement → register → collect) |
| 8 | Rooms can be upgraded | Implemented; tested + visual levels 1–5 rendered |
| 9 | Trainers can be recruited | Implemented; tested (scouting with odds, gem market) |
| 10 | Player data persists between sessions | Implemented (DataStore, session lock, autosave, BindToClose, migrations); tested offline; **needs Studio/live test** |
| 11 | Players can unlock additional disciplines | Implemented; tested |
| 12 | The store displays properly | Implemented, needs Studio test (layout on real screens) |
| 13 | Purchase processing is secure | Implemented; idempotency tested offline; **needs live test with real ids** |
| 14 | Multiplayer players can visit each other's academies | Implemented, needs Studio test |

## Features by section of the brief

| Section | Status | Notes |
|---|---|---|
| 1 Core loop | Implemented | build → equip → recruit → visitors → classes → revenue → satisfaction → upgrade → reputation → disciplines → cities |
| 2 Twelve disciplines | Implemented | environments, outfits, ranks/levels, 5 classes each, discipline-specific animations |
| 3 Character generation | Implemented | modular procedural appearance (body types incl. sumo/kid, 10 skin tones, faces, 10 hair styles, discipline clothing, belts, gloves, shin guards, equipment) |
| 4 Customers & memberships | Implemented | 8 categories, reception queue, room choice, sessions, capacity, waiting, satisfaction, memberships with dues and churn, amenity/shop visits, unserved demand |
| 5 Construction | Implemented | 24 room types with cost, 5 levels, equipment, capacity, revenue, specialisation and visual upgrades; construction sites with progress; effects/sounds |
| 6 Trainer collection | Implemented | 6 rarities, specialisations, abilities, XP/levels, training, 12 named masters, 3D previews |
| 7 Mastery | Implemented | belts (karate, judo, TKD, BJJ), sashes (kung fu), banzuke (sumo), levels/grades for others; tiers unlock by rank; rank-up notifications + student celebration |
| 8 Cities | Implemented | 10 cities with own architecture props, lighting, rent, build cost, demographics, income, prestige, speciality, requirements; one branch per city; passive income |
| 9 Economy | Implemented | income: classes, private coaching, VIP, memberships, shop/drinks, championships, events; expenses: salaries, maintenance, rent; stats panel with hourly/daily/expenses/net/members/reputation; automation upgrades; offline earnings |
| 10 Monetisation | Implemented, asset needed | 18 passes, 7 products, store tabs (featured, passes, boosts, cash, premium equipment, bundles, cosmetics), seasonal bundle; ids must be created on Roblox |
| 11 Progression & rebirth | Implemented | levels 1–100, XP from all listed sources, milestones, rebirth with clear reset/keep lists |
| 12 Missions, daily, events | Implemented | 8 daily + 7 weekly mission types, 7-day login track, 6 seasonal events + default festival with exclusive rewards |
| 13 Multiplayer & social | Implemented | shared server with 8 plots, visit, inspect, rate, 7 leaderboards (global + server), announcements. Tournaments between players: **not implemented** (future) |
| 14 UI | Implemented, needs Studio test | dark/gold theme, HUD layout as specified, 15 panels, UIScale for screen size, gamepad bindings |
| 15 Art direction | Implemented (primitive-built) | everything is built from Roblox parts in code; no meshes or textures. A professional art pass (meshes, textures, decals, logos) would raise quality |
| 16 Audio & animation | Animation implemented; audio asset needed | 85+ original procedural animations; 18 original synthesised sounds in `assets/audio` must be uploaded and their ids configured |
| 17 Data & security | Implemented, needs live test | see ARCHITECTURE.md and MONETIZATION.md |
| 18 Architecture | Implemented | Rojo layout; services/controllers/config as described. Strict typing: deliberately not used so the code runs under stock Lua 5.4 for offline testing (see Known limitations) |
| 19 Performance | Implemented, needs Studio test | client-side NPCs, one message per visitor, render distance, NPC cap setting, distance-based update rate, anchored BulkMoveTo, StreamingEnabled |

## Known limitations

1. **Not run in Roblox yet.** UI positions, ProximityPrompt behaviour, StreamingEnabled
   edge cases, DataStore/Marketplace behaviour and performance with 8 players are untested.
   Expect a round of Studio fixes.
2. **No strict Luau typing.** Kept out so `luac5.4`/`lua5.4` can parse and run the code here.
   Can be added later with `--!strict` once Luau tooling (luau-lsp, Rojo, selene) is available.
3. **Visual style is primitive-based.** NPCs are blocky 15-part figures; balls render as
   spheres in Roblox but there are no meshes, textures or real logos. Sumo/robe bodies are
   boxes rather than rounded shapes.
4. **Player-avatar outfits** are welded overlay parts, not Roblox Shirt/Pants assets; they can
   look bulky on some avatar body types. Emotes on avatars use `Motor6D.Transform` in
   `Stepped`; if the default Animate script overrides them on some avatars, convert the
   poses to Animation assets.
5. **Audio ids are 0** until the generated sounds are uploaded.
6. **Monetisation ids are 0** until passes/products are created.
7. **Inactive branches** earn a passive estimate (50%) instead of simulating visitors.
8. **Leaderboards** refresh every 2 minutes and show nothing global in Studio without API access.
9. **Player-vs-player tournaments** are not implemented (marked future-ready in the brief).
10. Player counts above 8 per server are not supported (8 plots).
