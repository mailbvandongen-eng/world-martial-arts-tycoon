# Developer menu (place version 17)

Only developers see the red **🛠 DEV** button (top left) and the *Developer* item in the
More menu. Who counts as a developer: the user ids in `src/shared/Config/Dev.lua`, the
experience owner, and anyone in Roblox Studio. The server checks this for **every**
developer action (`ActionService` → `handlers.dev`); other players get "not allowed".

## Sandbox

The first developer action switches on sandbox mode. Your real save is copied aside and
**nothing is written to the DataStore** while the sandbox is on. "Sandbox OFF (restore)"
or leaving the game puts your real progress back. The DEV button shows a dot (•) while the
sandbox is active.

## What you can start directly

| Section | Options |
|---|---|
| Scenarios | New player, Early game, Mid game, Late game, Full karate dojo, Tournament ready |
| Values | cash, gems, level, reputation, register |
| Cities | every city (earlier cities are unlocked too) |
| Disciplines | unlock one/all, mastery rank 1–9 or max |
| Rooms | any room type, any slot, level 1–5; all rooms → level; fill academy; clear; finish construction |
| Trainers | add trainer of any discipline and rarity; staff every room |
| Students & visitors | +5/+20 students at a rank; visitor burst +10/+30; visitor rate ×1/×3/×10 |
| Activities | every challenge (cooldown reset), every tournament (20 s registration, rounds every 12 s), championship |
| Missions & events | complete, reroll, reset daily/cooldowns; force any event or follow the calendar |
| Purchases | grant any game pass or product effect (passes not really bought are removed on the next live join) |
| Teleport | own academy, arena |

## Test status

- **Automated:** scenarios build valid saves that survive schema validation, keep trainers
  consistent and get visitors training; room placement, city unlock order, NaN input.
- **Technically checked:** static checker (actions, panels, requires), config fields used by
  the panel.
- **Not yet played in Roblox:** panel layout on phone/PC, sandbox restore on leave.
