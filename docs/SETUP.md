# Roblox Studio setup and publishing

## 1. Get the place into Studio

- **Without tools:** `python3 tools/build_rbxlx.py`, then in Studio *File → Open from File*
  and pick `build/WorldMartialArtsTycoon.rbxlx`.
- **With Rojo 7:** `rojo serve default.project.json` and connect from the Rojo plugin, or
  `rojo build default.project.json -o WMAT.rbxlx`.

The scripts build the whole world at runtime (boulevard, 8 plots, rooms, props), so the
place file only contains scripts. Press **Play** to see the world.

## 2. Studio settings

| Setting | Where | Value |
|---|---|---|
| Lighting technology | Lighting → Technology | `Future` (the place builder cannot set enums) |
| Streaming | Workspace → StreamingEnabled | `true` (already set) |
| API access | Game Settings → Security → *Enable Studio Access to API Services* | on, to test saving in Studio |
| Max players | Game Settings (Creator Dashboard) → Places → Server size | **8** (there are 8 plots) |
| Avatar | Game Settings → Avatar | R15 recommended (R6 also works for cosmetics/emotes) |

Without API access the server prints a warning and keeps data in memory only (the Stats
panel shows "STUDIO MODE – Not saving").

## 3. Audio (optional but recommended)

1. `python3 tools/gen_audio.py` (already done: `assets/audio/*.wav`, 18 original sounds).
2. Upload them in the Creator Dashboard (*Creations → Development Items → Audio*).
3. Put each asset id into `src/shared/Config/Audio.lua` (`id = 0` → the real id).
Sounds with id 0 are skipped, so the game runs silently until then.

## 4. Monetisation

Create the Game Passes and Developer Products and paste their ids into
`src/shared/Config/Monetization.lua`. Full list and policy notes: [MONETIZATION.md](MONETIZATION.md).
In Studio, items with id 0 show a *Test (Studio)* button that grants the item directly
(server checks `RunService:IsStudio()`), so you can try every effect before publishing.

## 5. Test in Studio

- *Play* (one player): claim a plot at a gold pad (or wait 45 s), collect, build, recruit.
- *Test → Clients and Servers → 2–3 players*: visiting, inspecting, rating, leaderboards,
  server announcements.
- Device emulator: phone, tablet, console layouts.
- Checklist with expected results: [TESTING.md](TESTING.md#manual-test-plan-roblox-studio).

## 6. Publish

1. *File → Publish to Roblox*.
2. Creator Dashboard: set server size 8, genre *Tycoon*, description, icon and thumbnails
   (the images in `docs/images` are renders from the code, not real screenshots — take
   real screenshots in Studio for the store page).
3. Enable *Allow HTTP Requests* is **not** needed. DataStores are enabled automatically for
   published games.
4. Questionnaire / experience guidelines: the game contains martial arts training
   (non-graphic, no blood), so expect a mild violence descriptor.
