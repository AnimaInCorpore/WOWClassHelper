# WOWClassHelper notes

## History

- **2026-11-14 / 15:** WOWPriest (`C:\Arbeit\WOWPriest`) and WOWPaladin
  (`C:\Arbeit\WOWPaladin`) were built as two addons with the same structure.
  WOWPaladin's `NOTES-from-WOWPriest.md` tracked what was ported between them:
  rating conversion without hit on gear, talent hit in percent, decimal
  percent set texts, the "Not counted" line, the verdict tooltip placement
  below the comparison tooltips, the compact tooltip with "best items seen",
  and spec detection from the Forever talent tree. Holy Power doesn't exist
  in Forever (power types: mana, rage, focus, energy, combo points,
  happiness), so WOWPaladin's Holy Power bar was removed.
- **2026-11-15:** both merged into WOWClassHelper. The engine is shared
  (Core/, UI/), each class is a profile in Classes/. What came from where:
  - from WOWPriest: tooltip layout and "Not counted" line, mana bar with
    five-second-rule timer, wand DPS, caster questing model (now
    `Weights.CasterQuesting`), Priest weights and set effects, the strict
    smoke-test harness with secret values
  - from WOWPaladin: defense cap (`UnitDefenseBonus`), melee hit with
    `GetHitModifier`, talent-hit rows in `/stats`, tank set texts (dodge,
    parry, block), "Can't wear Plate yet", zero formatting in the tooltip,
    the melee questing model, Paladin weights, and its smoke-test checks
  - new: profiles for the other seven classes, generated talent trees for all
    classes (`tools/Export-Talents.ps1`, checked: the Priest and Paladin node
    lists match the hand-written ones exactly), level-gated proficiencies,
    dual wield with half off-hand DPS, ranged weapon DPS (`RANGED_DPS`),
    per-character spec override and bag contents, import of the old
    knowledge bases, school damage set texts for every school
  - Paladin labels are now "Retribution (Damage)" (spec first) like all other
    classes; the tooltip still uses Tank / Healer / Damage as short names.
- **2026-11-23:** two-handers are compared with one-hander + off hand pairs
  (`Compare.Plan`, `Compare.BestPartner`). Against a worn two-hander, a
  hovered one-hander or off hand is paired with the best fitting item from
  bags and bank; the weapons list ranks one-handers as pairs with the best
  off hand seen. Fixed on the way: an off-hand-only weapon compared against
  a two-hander halved the two-hander's DPS too; now only the off-hand
  weapon's DPS counts half.
- **2026-11-23:** longevity while leveling (`Compare.LIFESPAN`,
  `Compare.LONGEVITY_PER_LEVEL`), main stats per spec that an item can't
  trade away for minor stats (`Weights.MAIN_STATS`, `mainExtra` in the
  profiles), "Do not take/sell" instead of "Sell", long item names cut in the
  tooltip (UTF-8 aware), and item sources (quest, dungeon, raid, crafted,
  vendor, drop) in the knowledge base and tooltip.

## Open points (sources and longevity)

- The quest log, quest dialog and profession frame names
  (`QuestFrame`, `QuestLogFrame`, `QuestInfoFrame`, `TradeSkillFrame`) and the
  APIs `GetTitleText`, `GetQuestItemLink`, `GetTradeSkillItemLink`,
  `GetLootRollItemLink`, `IsInInstance` are the classic ones; check in game
  that WoW Forever has them (missing ones are skipped, not errors).
- The lifespans per quality (green 7, blue 11, epic 16 levels) and the 3% per
  level are estimates; tune them in `Core/Compare.lua`.

## Sources

Battle.net Game Data API, `static-forever-eu` (build 1.60.1_70399): classes,
specs (Forever spec IDs are the classic skill line IDs, e.g. Fury 256,
Protection 257), talent trees, items, item sets.

classicwowforever.com (live client build 1.60.1.70862, read 15 Nov 2026):

- `/talents/` and the class talent pages: talent ranks and max-rank values
  used in the class profiles; 51 points, levels 10-60; Legacy perk
  "Thrill of Adventure" (1-5% health and mana per kill while questing) and
  "Talented" (first point at level 5). The talent counts per class match the
  API data (e.g. Hunter 51 after removing the duplicate Lightning Reflexes).
- `/talents/updates/`: value changes since the API build, e.g. Lethality
  2 ranks 10/20%, Flurry (Warrior) 3 ranks to 30%, Ice Barrier 3% + 3%.
- `/updates/november-10-patch-notes/`: Mental Dexterity 33/66/100% of
  Intellect, Stormstrike 100% weapon damage on 8 sec.
- `/class-changes/`: Warrior basic-attack crits give 100% more Rage and
  Whirlwind hits with both weapons; Bloom heals for 100% of Spirit; Holy
  Shield back to 30% block; Divine Aegis; Arcane Blast and Ice Barrier
  scaling; Shamans get two-handed axes and maces.
- `/weapons/`: 14 attack power per weapon DPS, slower main hands slightly
  preferred, polearms from level 20, Druid forms use the equipped weapon's
  DPS (confirmed by Blizzard), Rogues (Combat, Subtlety) use one-handed axes,
  Assassination needs daggers, Paladin tank spell power 0.25 questing / 0.5
  AoE tanking.
- `/class-guides/<class>/`: Arms levels with the slowest two-hander; Arcane
  Intellect scaling. The guides give no stat priorities or caps.
- The Priest page confirms the wand change: since 15 Oct you stand still
  half a second before the wand fires.

## Open points

- **The seven new class profiles are untested in game.** Their role weights
  are classic-style estimates adjusted to the facts above. Check them with
  `/wch debug` (section "Weights for ...") and real items.
- Caps are classic assumptions (VERIFY): spell hit 16% / melee hit 9% at max
  level, 3% / 5% while questing, defense +140, haste 50%.
- Rating per 1% at 60 (hit 10, crit 14, haste 10) comes from Forever items;
  defense, dodge, parry and block have no reference item yet.
- The 0.5 sec wand delay is documented for Priests; Mages and Warlocks assume
  the same (VERIFY).
- Whether Forever Shamans dual wield is unknown; the profile says no.
- Weapon speed isn't read (`GetItemStats` has no speed), so the site's "slower
  main hands" preference is only a higher DPS weight for Arms and
  Enhancement. Reading the speed from the tooltip would fix that.
- Feral is one spec with cat and bear stats mixed; a separate bear weight set
  would need a way to tell which form the player tanks in.
- The talent values in `Data/Talents.lua` comments are from the older API
  build; regenerate with `tools/Export-Talents.ps1` when the API catches up,
  and re-check the site's updates page for changes.
- WOWPriest is still linked into `Interface\AddOns` (junction checked
  2026-11-15); WOWClassHelper isn't linked yet.
