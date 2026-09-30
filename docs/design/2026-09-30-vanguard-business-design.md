# Vanguard Business — design

Date: 2026-09-30 · Status: draft for review · License: MIT © Rover

## 1. Purpose

A universal FiveM resource that turns any building into a player-run food business
(café, burger bar, pizzeria, bakery, bar): shared fridge, cooking stations, a boss
desk for staff and money, supplier orders, door locks, a cash register and edible
items. Everything is placed in-game, so it works in any interior — base game or
add-on — without coordinates in files. Published on GitHub next to Vanguard Admin.

**Success looks like:** a server owner installs it, creates "Cat Café" in-game, places
the stations, hands it to a player, and that player can hire staff, order stock,
cook, bill customers and lock the doors — with no file editing after install.

## 2. Decisions already made

| Topic | Decision |
|---|---|
| Who works | Hired employees only; each business has a boss. |
| Job system | The script's own staff list (database), not framework jobs. Works the same on every framework; a player can work at a café alongside their main job. |
| Ingredients | Bought from a supplier via the boss desk with business money; delivered to the fridge. |
| UI | Own NUI panel (Vanguard style); ox_target / qb-target when present, otherwise [E] prompts. No ox_lib dependency. |
| Doors | Built-in door locks for business staff (framework door scripts only know framework jobs). |
| Scope | Phase 1 and phase 2 (register/bills, eating & drinking) are both in this spec. |
| Name | Vanguard Business — folder `vanguard-business`, command `/business`. |

## 3. Requirements

- **Frameworks:** QBCore, Qbox, ESX — auto-detected. Standalone is **not** supported
  (no items or money to work with); the resource prints a clear message and stays idle.
- **Inventories:** qb-inventory (QBCore), ox_inventory (Qbox, ESX). ESX without
  ox_inventory is not supported (the default ESX inventory has no stashes).
- **Database:** oxmysql. Tables are created automatically on first start.
- **Optional:** ox_target or qb-target (auto-detected). Fuel/keys etc. not involved.

## 4. Roles and permissions

### Server admin
ACE `vanguard.business.admin` (`add_ace group.admin vanguard.business.admin allow`).
Can create/rename/delete businesses, set or change the Owner, open placement mode for
any business, and teleport to a business. Owners **cannot** place stations unless
`Config.OwnersCanPlace = true` (default false — stops players building fridges in
the street on public servers).

### Business ranks (fixed four, labels configurable)

| # | Rank | Default permissions |
|---|---|---|
| 1 | Trainee | cook, fridge, doors |
| 2 | Staff | + register |
| 3 | Manager | + supplier orders, hire/fire/promote ranks 1–2, view money log |
| 4 | Owner | everything: hire/fire/promote ranks 1–3, withdraw |

- Permission per rank lives in `Config.RankPermissions`.
- You can only hire, fire or promote people **below** your own rank, and never change
  your own rank. There is exactly one Owner; only a server admin changes it.
- Anyone on the staff list may deposit money.
- A player may be staff at several businesses; they can be on shift at one at a time.

### Getting hired
Server admin creates the business and sets the Owner (online player by server ID).
The Owner hires from the boss desk (nearby player list or server ID) and picks a rank.
Managers hire Trainees/Staff. Players ask the Owner in roleplay.

## 5. Shifts (duty)

- Clock in/out at a **clock-in** station of your business.
- On shift is required for: cook, fridge, register (`Config.RequireDuty`, default true).
  Doors and the boss desk work off shift.
- Shift state is kept in server memory; it ends on disconnect or resource restart.
- On-shift staff counts are shown on the boss desk overview.

## 6. Stations (placed in-game)

| Kind | What it does |
|---|---|
| `fridge` | Opens the business storage (one shared stash per business, all fridges open the same one; supplier deliveries arrive here). |
| `coffee`, `grill`, `fryer`, `oven`, `drinks`, `prep` | Cooking stations; each cooks only the recipes tagged with its kind. Kinds are defined in config and can be extended. |
| `register` | Create bills for nearby customers. |
| `boss` | Boss desk panel. |
| `clockin` | Start/end shift. |
| `blip` | (Optional, one per business) map icon position; sprite/colour from the business type. |

A business **type** (coffee shop, burger, pizza, bakery, bar) decides which station
kinds, recipes, supplier catalogue and blip style it gets. Types are config tables;
server owners can add their own.

Every interaction is checked on the server: player within `Config.InteractDistance`
(default 2.5 m) of that station's saved coordinates, is staff of that business, has
the rank permission, and is on shift where required.

## 7. Placement tool (admin)

- `/business` → admin panel lists businesses → **Place** opens placement mode for one.
- Camera raycast shows a coloured marker where you aim; scroll rotates; click places
  the selected station kind; an info bar lists the keys.
- Existing stations of that business are shown with labels; aim + Delete removes one;
  "Move" picks it up again.
- **Doors:** choose "Door", aim at a door, click → the door's model and position are
  saved. Click a second door right after to link a double door (toggles together).
- Saved immediately to the database and pushed to every client.

## 8. Cooking

Recipe (config):
```lua
{ id = 'latte', label = 'Latte', station = 'coffee', time = 6000, amount = 1,
  ingredients = { coffee_beans = 1, milk = 1 }, anim = 'coffee' }
```
Flow (prevents duplication and instant crafting):
1. Client asks to cook recipe × quantity (1–10).
2. Server checks station/rank/shift and that the player has all ingredients for the
   whole quantity; removes them; stores a pending job (player, recipe, qty, start time).
3. Client plays animation + panel progress bar for `time × qty`.
4. Client reports done → server checks the job exists, enough time has passed and the
   player is still at the station → gives the items.
5. Cancel, walking away, death or disconnect → pending job dropped and ingredients
   returned (disconnect: returned to the fridge, since the player is gone).

The cooking panel shows each recipe with ingredients you have / need, highlights what is
missing, and lets you pick a quantity.

## 9. Supplier orders

- Catalogue per business type in config: `{ item, label, price, pack }`
  (e.g. 10 × coffee beans for $40).
- Boss desk → Supplier: add to cart, see total, **Order** (needs rank permission).
- Server: validates cart, takes money with one atomic statement
  (`UPDATE … SET balance = balance - ? WHERE id = ? AND balance >= ?`), then adds items
  to the fridge stash. Anything that doesn't fit is refunded and reported.
- Logged in the money log.

## 10. Money

- Business balance stored in `vbiz_businesses.balance` (whole dollars).
- Deposit (from the player's cash), withdraw (to cash, Owner only). Both atomic.
- Money log: last 50 entries (type, amount, who, note, time) on the boss desk.
- Limits: `Config.MaxTransaction` (default $1,000,000) per action.

## 11. Register and bills (phase 2)

- Staff with `register` permission at a register station: pick a customer from players
  within 5 m, enter amount ($1–`Config.MaxBill`) and an optional note.
- Customer gets a popup: pay with cash or bank, or decline. Expires after 60 s.
  One open bill per customer.
- Paid: money leaves the customer, goes to the business balance; the employee who billed
  gets `Config.CommissionPercent` (default 10 %) of it, taken from that payment.
- Logged in the money log.

## 12. Food and drink (phase 2)

- Every product item is usable: plays an eat/drink animation with a prop, then
  restores hunger/thirst (and optional stress relief) from config.
- QBCore/Qbox: metadata `hunger`/`thirst` + `hud:client:UpdateNeeds` (same as
  qb-smallresources). ESX: `esx_status:add`.
- Items already defined on the server (e.g. `water_bottle`, `coffee`) are reused, not
  overwritten.

## 13. Items and pictures

- Default items: ~20 ingredients + ~25 products across the five types.
- **QBCore:** added at start with `exports['qb-core']:AddItem` for each item not already
  present (no items.lua edits). Usable via `CreateUseableItem`.
- **Qbox / ox_inventory:** README gives a ready-to-paste block for `ox_inventory/data/items.lua`
  (ox reads items from that file only).
- **Pictures:** PNGs from Microsoft Fluent Emoji (MIT, credited in README) shipped in
  `images/`. Install step: copy them into the inventory's picture folder
  (`qb-inventory/html/images` or `ox_inventory/web/images`) — inventories only load
  pictures from their own folder.

## 14. Door locks

- Doors registered with the game's door system (`AddDoorToSystem`) on every client;
  locked state synced from the server and saved in the database. Doors start locked.
- Any staff member of that business (on or off shift) within 2.5 m can toggle via
  target/[E]. Server checks distance to the saved door position and staff membership.
- Linked doors toggle together.

## 15. Architecture

```
vanguard-business/
  fxmanifest.lua  config.lua  README.md  LICENSE  CHANGELOG.md
  shared/rules.lua        -- pure logic: rank checks, recipe checks, cart totals, bill math
  shared/types.lua        -- default business types, recipes, supplier catalogues, items
  bridge/server.lua       -- framework + inventory adapter (qb / qbx / esx; qb-inventory / ox)
  bridge/client.lua       -- target adapter (ox_target / qb-target / [E] prompt), notify
  server/db.lua           -- table creation, queries
  server/businesses.lua   -- business cache, admin actions, money, log
  server/staff.lua        -- staff list, ranks, shifts
  server/stations.lua     -- stations, doors, sync to clients
  server/cooking.lua      -- pending cook jobs
  server/supplier.lua     -- orders
  server/register.lua     -- bills
  server/items.lua        -- item registration, usable food
  client/main.lua         -- panel plumbing, requests
  client/interact.lua     -- station zones / prompts
  client/placement.lua    -- placement mode
  client/doors.lua        -- door system
  client/consume.lua      -- eat/drink animation
  html/                   -- panel: admin, boss desk (overview, staff, supplier, log),
                          --        cooking, register, bill popup, progress, placement bar
  images/                 -- item pictures
```

Each server module exposes a small table (`Businesses`, `StaffList`, `Stations`, …);
`bridge` is the only place that knows framework names. Client → server requests go
through one request/response event like Vanguard Admin, every handler validates input
(types, ranges, lengths) before touching data.

### Database tables (prefix `vbiz_`)

| Table | Columns |
|---|---|
| `vbiz_businesses` | id, name, type, balance, blip (JSON), created_at |
| `vbiz_staff` | business_id, identifier, name, rank — PK (business_id, identifier) |
| `vbiz_stations` | id, business_id, kind, x, y, z, heading |
| `vbiz_doors` | id, business_id, model, x, y, z, pair_id, locked |
| `vbiz_transactions` | id, business_id, kind, amount, actor, note, created_at |

The Owner is the `vbiz_staff` row with rank 4. Identifier = character id
(`citizenid` on QBCore/Qbox, `identifier` on ESX).

## 16. Error handling

- Every failed action returns a plain message shown in the panel ("You need 1 more milk",
  "The business can't afford this order").
- Missing framework/inventory/oxmysql at start → one clear console line, resource idles.
- Database errors are logged to the server console with the action name; the player sees
  "Something went wrong, try again".
- Pending cook jobs and open bills are cleaned up on disconnect and resource stop.

## 17. Testing

- Pure logic in `shared/rules.lua` (rank rules, ingredient checks for a quantity, cart
  totals, commission math, input validation) gets automated tests run on Node with a
  Lua VM (`fengari`), dev-only and not shipped. Target ≥ 80 % of that file.
- Syntax check of every Lua file (luaparse) and JS (`node --check`).
- Browser preview: `html/index.html#boss`, `#cook`, `#register`, `#bill`, `#admin`
  with sample data; screenshots for the README.
- Security review agent pass on the server handlers before release.
- In-game checklist for Rover_Op (create business, place, hire, order, cook, bill, doors,
  eat) — the only way to test game natives.

## 18. Build order

1. Skeleton, bridge, database, admin panel (create business, set Owner).
2. Placement tool + stations + interaction.
3. Staff, ranks, shifts, boss desk (overview, staff).
4. Fridge + supplier + money + log.
5. Cooking.
6. Door locks.
7. Register and bills.
8. Items, pictures, eating/drinking.
9. README, preview screenshots, review, install on Rover's server.

## 19. Not included (YAGNI)

Paychecks/salaries, NPC customers, delivery missions, creating new items in-game,
job applications, framework-job integration, Standalone mode, ready-made coordinates
for any specific building or MLO.
