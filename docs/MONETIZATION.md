# Monetisation setup

All items are defined in `src/shared/Config/Monetization.lua`. Every entry has `id = 0`
until you create the item on Roblox and paste its id. Prices shown in the store come live
from `MarketplaceService:GetProductInfo`; the `robux` field is only a fallback for display.

## Game Passes (Creator Dashboard → your experience → Monetization → Passes)

| key | Name | Suggested R$ | Effect (server-side) |
|---|---|---|---|
| vip_owner | VIP Owner | 399 | VIP title, golden owner suit, golden gate decoration |
| double_cash | Double Cash | 499 | ×2 class, shop and membership income |
| extra_slot | Extra Academy Slots | 249 | +4 room slots in every city |
| auto_collect | Auto Collect | 199 | register empties every 5 s |
| premium_trainer | Premium Trainer | 349 | Mythic trainer Grandmaster Kaito Arashi |
| elite_owner | Elite Owner | 799 | elite title, legendary aura, neon signage (cosmetic) |
| golden_ring | Golden Boxing Ring | 299 | gold rings, +10% boxing revenue |
| diamond_octagon | Diamond MMA Octagon | 299 | diamond octagons, +10% MMA revenue |
| premium_dojo | Premium Karate Dojo | 249 | lacquered dojo, +10% karate revenue |
| luxury_sumo | Luxury Sumo Arena | 299 | hanging roof over dohyo, +10% sumo revenue |
| platinum_judo | Platinum Judo Mats | 249 | platinum tatami, +10% judo revenue |
| carbon_equipment | Carbon Fibre Equipment | 399 | carbon bags, +5 satisfaction |
| gym_lighting | Exclusive Gym Lighting | 149 | colour-changing spotlights (cosmetic) |
| premium_decor | Premium Academy Decorations | 199 | statues at reception, +3 satisfaction |
| bundle_starter | Starter Bundle | 99 | once: 25,000 cash, 300 gems, a Rare trainer |
| bundle_striker | Striker Cosmetic Bundle | 199 | MMA fight gear outfit |
| bundle_grappler | Grappler Cosmetic Bundle | 199 | black BJJ gi outfit |
| bundle_traditional | Traditional Masters Bundle | 249 | kung fu suit, crane pose, sakura garden (spring collection, Mar–May) |

## Developer Products (Monetization → Developer Products)

| key | Name | Suggested R$ | Effect |
|---|---|---|---|
| cash_small | Small Cash Pack | 49 | 10 min of current income (min 5,000) — exact amount shown before buying |
| cash_medium | Medium Cash Pack | 149 | 40 min of income (min 25,000) |
| cash_large | Large Cash Pack | 399 | 2 h of income (min 100,000) |
| boost_cash | Double Cash (30 min) | 79 | ×2 income, time stacks |
| boost_training | Training Boost (30 min) | 59 | classes 50% faster, ×2 mastery XP |
| boost_customers | Customer Rush (30 min) | 59 | +75% visitors |
| instant_build | Instant Construction | 25 | finishes all construction; kept as a credit if nothing is building |

## How purchases are secured

- **Game Passes:** ownership is checked with `UserOwnsGamePassAsync` on join and after
  `PromptGamePassPurchaseFinished`. On live servers the saved pass list is replaced by the
  verified set, so Studio test grants or refunds never stick.
- **Developer Products:** granted only inside `ProcessReceipt`:
  1. player not in server or data not loaded → `NotProcessedYet` (Roblox retries);
  2. permanent receipt DataStore already has the PurchaseId → `PurchaseGranted` without granting;
     store unreachable → `NotProcessedYet`;
  3. grant once via `ReceiptLedger` (server memory + last 50 ids in the save);
  4. save the player's data; only if the save succeeds, record the receipt and return
     `PurchaseGranted`, otherwise `NotProcessedYet`.
- The client never reports purchases; the store only opens Roblox's own purchase prompts.

## Fairness and policy

- Every item states exactly what it gives; cash packs show the exact amount beforehand.
- Random results are never sold directly for Robux. Trainer scouting costs in-game cash
  (which can also come from cash packs), so its odds per rarity are always shown on the
  scouting screen before you pay. The gem trainer market sells fixed trainers at fixed
  prices. Gems are only sold inside the one-time Starter Bundle.
- Revenue bonuses from premium equipment are +5–10% on one discipline — free players reach
  everything (the balance test bot never buys anything).
- Cosmetics never affect income.
