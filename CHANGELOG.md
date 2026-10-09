# Changelog

## 1.3.0 — 2026-10-09

- Leaving work on shift: an employee who goes more than `Config.AutoClockOutDistance` (default 2,000 m) from every station of their business is clocked out automatically, with a message and a console log line. Set it to 0 to turn it off.

## 1.2.0 — 2026-10-09

- Shifts survive a restart of the resource (kept on the player's state bag with the minutes worked), so restarting no longer clocks everyone out silently.
- Clock-ins, clock-outs and every paycheck (or why it was skipped) are printed to the server console.
- Clocking in shows the paycheck amount and interval.
- Food and drink stay usable after restarting only this resource (QBCore keeps runtime items until a full restart).
- The boss desk no longer offers "Place stations"; admins place from `/business`, Owners only when `Config.OwnersCanPlace = true`.
- `Config.Paycheck.FromBusiness` documented: `true` pays from the business account (default), `false` lets the city pay.

## 1.1.0 — 2026-10-01

- Paychecks per rank every `Config.Paycheck.IntervalMinutes` on shift (default Trainee $1,500 / Staff $2,000 / Manager $3,000 / Owner $4,000 every 15 min), paid from the business account; shown on the boss desk Staff tab and in the money log.

## 1.0.1 — 2026-10-01

- Doors: staff lock / unlock with E; locks re-applied continuously; doors the game already registered are taken over; a locked door is also turned back to its closed heading and frozen, so it stays shut for everyone. New heading column on `vbiz_doors` (added automatically).
- Placement mode shows each door's status.

## 1.0.0 — 2026-09-30

First release.

- Businesses created in-game by server admins; six starter types (coffee shop, cat café, burger bar, pizzeria, bakery, bar).
- Placement tool: fridge, cooking stations, cash register, boss desk, clock-in point, doors (incl. double doors) and map icon.
- Own staff list with four ranks and per-rank permissions; shifts.
- Boss desk: balance, deposit / withdraw, money log, hiring, ranks, supplier orders delivered to the fridge.
- Cooking with ingredient checks, quantities and progress; interrupted cooking returns the ingredients.
- Cash register bills with cash / bank payment and employee commission.
- Door locks for business staff.
- Food and drink items with pictures; QBCore items added automatically, ox_inventory item file generated.
