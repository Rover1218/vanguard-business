# Vanguard Business — implementation plan

Spec: `2026-09-30-vanguard-business-design.md` (approved 2026-09-30). Execution: native, one review pass at the end (user asked to build straight away).

## Global constraints

- QBCore / Qbox / ESX; qb-inventory (QBCore only) or ox_inventory; oxmysql. No ox_lib dependency.
- MIT © 2026 Rover. Resource name `vanguard-business`, command `/business`, ACE `vanguard.business.admin`.
- Every server handler validates its input and re-checks station distance, staff rank, permission and shift.
- Balances change only through `UPDATE … WHERE balance + ? >= 0`.
- Item pictures `images/vb_<item>.png` from Microsoft Fluent Emoji (MIT), credited in README.
- No coordinates for any specific building ship with the resource.

## Review focus (inputs no happy-path test covers)

1. Malformed numbers (NaN, inf, 2.5, "10", negatives, huge) for amounts / quantity / rank / target → rejected (`Rules.wholeNumber`, tests).
2. Cart abuse: unknown item, item twice, 0 or too many packs, empty cart → rejected (`Rules.cartTotal`, tests).
3. Cooking interrupted: finish twice, finish early, cancel, expire, disconnect → ingredients returned once, product never twice (`Pending`, tests + in-game).
4. Bills: second bill to same customer, answer after expiry, answer twice → one outcome only (`Pending`, tests + in-game).
5. Two staff spending the same balance at once → never negative (atomic SQL; in-game checklist).

## Tasks

1. Skeleton: manifest, license, gitignore, package.json, test runner (fengari), syntax checker (luaparse).
2. `shared/rules.lua` + tests (wholeNumber, cleanText, coords, rank rules, missingIngredients, cartTotal, splitBill).
3. `shared/pending.lua` + tests (start/finish/cancel/expire/each).
4. `config.lua`, `shared/types.lua` + data-integrity tests (every recipe cookable and suppliable within its type).
5. Server core: bridge, db, businesses, staff, stations, access, router, main.
6. Admin + placement handlers; client core, world zones, placement tool.
7. Boss desk: money, staff, supplier; fridge; clock-in.
8. Cooking server + client.
9. Doors server + client.
10. Register / bills.
11. Items: QBCore registration, eat/drink, ox_inventory item file generator, pictures.
12. NUI panel (home/admin, boss, cook, register, bill, progress, placement bar) with browser preview.
13. README, CHANGELOG, review, install on Rover's server.
