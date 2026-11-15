# WOWClassHelper

A gear advisor addon for **WoW Forever**, for every class and spec, written in
plain Lua with no libraries. It replaces the class-specific addons
**WOWPriest** and **WOWPaladin** (both deprecated): their engine is now shared,
and each class is a profile in [Classes/](Classes/). All nine Forever classes
and their 27 specs are covered.

When you hover over an item (or click an item link in chat), a compact verdict
tooltip appears below the item tooltip. It compares the item with what you're
wearing, for every spec of your class, and shows the best items you've seen
for that slot:

```
[check] Equip now                       +60.1 (+109%)
vs. [Virtuous Crown]                          Holy 60
[icon] Disc [check] +63.9    [icon] Shadow [cross] -16.7
Healing +75                           Spell Power -11
Crit -14                                    Spirit +6
Vestments of Faith 1/9 with this, bonus at 2
Best head items seen                     this #1 of 3
> 1. [Circlet of Faith]               115 seen  +60.1
   2. [Virtuous Crown]                        55 worn
   3. [Silk Cap]                         6 bags  -49.2
```

| Line | Content |
|---|---|
| 1 | Main action for your current spec, and its score change (percent hidden if the replaced item is nearly worthless) |
| 2 | Reason, only when there is one ("Requires level 60", "Plate can be worn from level 40", "Priests can't use Leather", "Upgrade for Shadow (Damage)") |
| 3 | What the item replaces, your spec and level |
| 4 | The other two specs: icon, short name, verdict icon and score change |
| 5-6 | Biggest stat changes for your spec, two per line |
| not counted | Grey: the item's stats that are worth nothing for your spec, e.g. "Not counted: Spell Power +20" on a staff for a Warrior |
| sets | Set bonuses that switch on or off with their value, otherwise the set progress in one line |
| note | Grey: slot note ("Fills your empty off hand (dual wield, off-hand damage counts half)"), the level mix while leveling ("level 13: questing 94%"), "spec set manually", or "no spec found" |
| list | Best items seen for the slot, see below |

Unusable and already equipped items show only the action, reason and list.

The verdict tooltip sits below the item tooltip and also below the "currently
equipped" comparison tooltips beside it, so they don't overlap. If there is no
room at the bottom of the screen, it goes above the item tooltip.

### Colors and texts

| Tone | Color | Icon | Main action (bags / merchant / loot) |
|---|---|---|---|
| Take it now | bright green | check mark | Equip now / Buy & equip / Take & equip |
| Keep it | soft green | check mark | Keep for level N, Keep (set piece), Keep for Shadow / Buy ... / Take ... |
| Neutral | yellow | question mark | Equal - your choice / Optional / Optional |
| Get rid of it | red | cross | Sell or Drop / Skip / Loot & sell or Leave it |
| Info | grey | - | Can't use - sell / Can't use - skip / Currently equipped |

Colors, icons and limits are defined at the top of
[UI/VerdictTooltip.lua](UI/VerdictTooltip.lua).

### Best items seen and rank

The bottom of the tooltip lists the three best items from the knowledge base
for the hovered item's slot group (head, rings, trinkets, weapons, off hands,
ranged weapons or wands, relics, ...), scored for your current spec. Only
items you can use at your current level are listed. The header shows the
hovered item's rank: `this #2 of 14`, or `this #1 at level 60` for items that
need a higher level. The right column shows the item's own score, where it is
(`worn`, `bags`, `bank`, `vendor`, `loot`, `chat`, `seen`) and its improvement
over your current gear, the same number as in the first line when you hover
that item. `/wch best <slot>` shows the same in chat.

## How the suggestion works

### Which spec is used

Forever classes have one talent tree with three spec sections side by side,
like the classic talent window. The section with the most talent points is
your spec. The addon reads the points from the talent config (`C_Traits`) or,
failing that, from the talent spells you know; the talent nodes of all classes
are in the generated [Data/Talents.lua](Data/Talents.lua). Only without
talent points (below level 10, or a tie) does it ask the client's
specialization API (Forever and Retail spec IDs are both accepted), then the
classic talent tabs. If nothing is found, it uses the class's leveling spec
and the tooltip says "no spec found". `/wch spec` shows the spec, its source
and your points per section; `/wch spec <name>` sets it by hand (per
character), `/wch spec auto` goes back to automatic.

### Scoring

For each spec of your class:

1. **Replaced items:** the item is compared with the equipped item in the same
   slot. For rings and trinkets it replaces the weaker one, a two-hander
   replaces main hand + off hand, and for classes that dual wield (Warriors
   and Hunters from 20, Rogues) a one-hander replaces the weaker hand weapon
   or fills an empty off hand. **Off-hand weapon DPS counts half** (off-hand
   attacks deal half damage).
2. **Stat score:** stat changes x spec weights, computed for your **level**
   and **learned talents** (see below).
3. **Caps based on current stats:** for capped stats (hit for damage specs,
   defense for tanks at max level, haste), only the part up to the cap
   counts. The cap is checked against your **current totals**: rating from
   gear plus hit or defense from talents (Precision, Shadow Focus,
   Anticipation, ...). Item ratings are converted to percent at your
   **current level**.
4. **Set bonuses:** set pieces you wear are counted. If the item turns a set
   bonus on or off, its value is added or subtracted. Bonus texts like
   "+20 Stamina", "Increases damage done by Shadow spells ... by up to 29" or
   "Improves your chance to hit by 1.0%" are parsed (percent is converted to
   rating, melee/ranged/spell by spec). Procs have hand-set values per class;
   others get a default value.
5. **Verdict:** Upgrade, Keep for later (level too low, or the armor/weapon
   type is learned later), Keep (set piece you're collecting), Equal, Scrap,
   Can't use, Equipped. An item whose stats are all "not counted" for your
   spec is scrap, not "equal". If the item is no upgrade for your current
   spec but is for another one, it says "Keep for <spec>".

### Stat weights: level, talents and what saturates

Weights are worked out for your exact level and the talents you've learned:

- **Questing** (solo leveling), from the game mechanics of the class at your
  level: casters weigh wand DPS against spell power by the time spent
  wanding, Spirit by its regeneration outside the five-second rule, Intellect
  by the mana pool; melee classes count 1 weapon DPS as 14 attack power (the
  same rule classicwowforever.com's weapon guide uses).
- **Role** at max level (raid healing, tanking, damage against raid bosses).
- **The mix:** questing only up to level 10, role only at max level, a
  straight line in between (level 35: half each). The tooltip shows it.
- **Talents** you've learned, with their Forever values, e.g. Mental
  Dexterity (Shaman: Intellect becomes attack power), Careful Aim (Hunter),
  Arcane Blast and Arcane Wrath (Mage: Intellect becomes spell damage), Bloom
  (Druid: Spirit becomes healing), Flurry and Two-Handed Weapon
  Specialization (Warrior). `/wch debug` lists the talents it counted.
- **Legacy perk Thrill of Adventure** ("Abenteuerlust"): a kill restores 1-5%
  of health and mana while questing, so Intellect (mana classes) or Stamina
  is worth more. The game shows perk ranks only in the Legacy window, so set
  yours with `/wch legacy 0-5`.

Classic-style stats have few true diminishing returns, but these effects make
stats saturate or lose value as you level, and all of them are modeled:

| Effect | What happens |
|---|---|
| Hit cap | Hit above the cap (5% melee / 3% spell vs. same-level mobs, 9% / 16% vs. raid bosses) is worth nothing; your talent hit is added first |
| Defense cap | Tanks at max level: defense above +140 (crit immunity) is worth nothing |
| Rating per percent | A rating point is worth more % at low level (x (level - 8) / 52); the client's own conversion is used when it has one |
| Low spell ranks | Spells learned below level 20 get less from spell power (3.75% per level) |
| Questing to role | Wand DPS, Spirit and Stamina matter most while leveling; healing, crit and hit take over towards max level |

### Usable gear

Each class profile lists the armor and weapon types the class can ever use,
and from which level: plate for Warriors and Paladins and mail for Hunters
and Shamans from 40, polearms from 20 (site). Before that level an item of
that type is scored like an item with a higher required level ("Keep for
level 40") instead of "Can't use". Types you could use but haven't trained
show "not learned yet - visit a weapon master". Forever changes taken over
from classicwowforever.com: Rogues can use one-handed axes, Shamans
two-handed axes and maces, and Druid forms use the equipped weapon's DPS.

## Classes

| Class | Specs | Profile |
|---|---|---|
| Priest | Discipline, Holy, Shadow | from WOWPriest, values cross-checked in game and with the site |
| Paladin | Protection, Holy, Retribution | from WOWPaladin; site: tank spell power 0.25 questing / 0.5 at 60, block worth more (Holy Shield 30%) |
| Warrior | Arms, Fury, Protection | new; Fury crits give double rage, Whirlwind hits with both weapons |
| Rogue | Assassination, Combat, Subtlety | new; one-handed axes allowed |
| Hunter | Beast Mastery, Marksmanship, Survival | new; Survival scored as a melee spec (Forever) |
| Mage | Arcane, Fire, Frost | new; Arcane Intellect scaling (Arcane Blast, Arcane Wrath) |
| Warlock | Affliction, Demonology, Destruction | new; Life Tap makes Stamina worth more |
| Druid | Balance, Feral, Restoration | new; forms use weapon DPS, Bloom makes Spirit worth more |
| Shaman | Elemental, Enhancement, Restoration | new; two-handers baseline, Mental Dexterity at 100% (10 Nov hotfix) |

The seven new profiles are first drafts that have not been checked in game.
Each file starts with the Forever facts it is based on; tune the numbers
there. [Classes/Priest.lua](Classes/Priest.lua) explains every field.

## Mana bar with five-second-rule timer

WoW Forever has no secondary resource like Holy Power. Classes with mana get
an optional draggable **mana bar** (off by default, because the player frame
already shows mana): turn it on with `/wch toggle` or the compartment menu.
Below it, a thin timer runs down for five seconds (orange) after every spell
that costs mana. When it turns green, full Spirit regeneration is active
again. Shoot, Auto Shot, Throw and Auto Attack don't start the timer.

## Knowledge base

Every item you see is stored in `WOWClassHelperDB.kb`, shared by all
characters of the account (an item a Warrior saw shows up in a Mage's list if
the Mage can use it). That includes items you hover over, loot, see at a
merchant (with price and vendor), carry in your bags, store in your bank, see
in loot chat messages, or wear. What's in your bags and bank is stored per
character (`WOWClassHelperCharDB`), as is the spec override.

**Taking over the old knowledge bases:** if WOWPriest or WOWPaladin is still
enabled when you log in, their saved items and Legacy perk rank are copied
over once (chat says how many). After that, disable or delete the old addon.

## AddOn compartment button

WOWClassHelper adds an entry to the AddOn compartment, the button below the
minimap that collects addons. Mouse-over shows class, spec, level mix,
knowledge base size and tooltip state; a click opens a menu to pick the spec,
turn tooltip parts and the mana bar on or off, and open the stats, knowledge
base or debug report.

## Commands

| Command | Purpose |
|---|---|
| `/wch spec [auto\|<spec>]` | show or override the spec used for suggestions (per character) |
| `/wch legacy [0-5]` | show or set your rank of the Legacy perk Thrill of Adventure |
| `/wch stats` | your stat totals, caps, mana regeneration and set pieces |
| `/wch best <slot> [<spec>]` | best known items for a slot (`ranged`/`wand`, `relic`/`libram`, ...) |
| `/wch kb [wipe]` | knowledge base summary, or delete it |
| `/wch tooltip` | verdict tooltip on/off |
| `/wch debug [slot]` | diagnostics report in a copy window |
| `/wch toggle` | mana bar on/off (mana classes) |
| `/wch lock` / `unlock` / `reset` | lock, unlock (drag to move) or reset the mana bar |
| `/wch timer` | five-second-rule timer on/off |

Spec names are the spec name or its short form (`disc`, `prot`, `bm`,
`resto`, ...) or a role word the class profile allows (`tank`, `healer`,
`dps`). `/wch` alone lists the commands with your class's spec names.

## Files

| Path | Purpose |
|---|---|
| `WOWClassHelper.toc` | Addon manifest: interface version, saved variables, load order |
| `Core/Core.lua` | Namespace, saved-variable defaults, class registry, import of the old addons, slash commands |
| `Core/Spec.lua` | Spec and level detection from the Forever talent tree |
| `Core/Weights.lua` | Weight engine: level/role mix, talents, caps, Legacy perk, helpers for profiles |
| `Core/ItemData.lua` | Item parsing, stat normalization, wand/ranged DPS, usability by class and level |
| `Core/Character.lua` | Equipped gear, stat totals, rating conversion, caps, `/wch stats` |
| `Core/SetBonus.lua` | Set bonus parsing and valuation |
| `Core/KnowledgeBase.lua` | Item memory and scanners, `/wch kb` |
| `Core/Compare.lua` | Scoring per spec, verdicts, rankings, `/wch best` |
| `Classes/<Class>.lua` | **Tune here:** one profile per class: specs, usable gear, weights, talents, caps, set effects |
| `UI/VerdictTooltip.lua` | The separate verdict tooltip |
| `UI/ManaBar.lua` | Mana bar with five-second-rule timer |
| `UI/Compartment.lua` | AddOn compartment entry with mouse-over info and click menu |
| `UI/Debug.lua` | `/wch debug` diagnostics report |
| `Data/Items.lua` | **Generated** item data (`ns.Items`), a fallback when the game returns no stats |
| `Data/Sets.lua` | **Generated** item sets of all classes with bonuses (`ns.SetData`) |
| `Data/Talents.lua` | **Generated** talent trees of all classes (`ns.TalentData`) |
| `tools/` | Export scripts, Lua check, smoke test, packaging |
| `docs/NOTES.md` | History of the merge, sources and open points |
| `dist/` | **Generated** zips for sharing |

## Installing for development

The game only loads addons from its `Interface\AddOns` folder. The folder name
there must be `WOWClassHelper`, the same as the `.toc` filename. A directory
link (junction) makes edits show up in game right away; no admin rights are
needed, only an NTFS game drive:

```powershell
New-Item -ItemType Junction `
  -Path "I:\Spiele\World of Warcraft\_forever_\Interface\AddOns\WOWClassHelper" `
  -Target "C:\Arbeit\WOWClassHelper"
```

Log in once with WOWPriest still enabled to import its knowledge base, then
remove its junction (`Interface\AddOns\WOWPriest`), so the two verdict
tooltips don't show up together. After changing Lua files, type `/reload` in
game; after changing the `.toc` file or adding files, restart the client.
Turn on Lua error display with `/console scriptErrors 1`.

### Sharing the addon

```powershell
pwsh tools/Build-Package.ps1
```

This builds `dist/WOWClassHelper-<version>.zip` from the files in the TOC plus
this README, after the Lua check and the smoke test (`-SkipCheck` skips
them). The receiver unzips it into `World of Warcraft\<Forever folder>\Interface\AddOns\`.
For a new release, raise `## Version:` in the TOC first.

### First test in game: `/wch debug`

Run `/wch debug` out of combat. It opens a copyable report (Ctrl+A, Ctrl+C):
client version, which APIs exist, talent points per section and the talents
counted in the weights, proficiencies, mana and the five-second-rule timer,
combat ratings and the cap calculation, the weights for your spec, and the raw
stats of one equipped item (`/wch debug mainhand`, `/wch debug 11`, ...). It is
also saved as `lastDebug` in `WTF\Account\<account>\SavedVariables\WOWClassHelper.lua`.

### Checking the code before starting the game

`pwsh tools/Check-Lua.ps1` syntax-checks all Lua files (Lua 5.1 grammar, as used
by WoW) and reports unexpected global variables. It uses Node.js and luaparse
from msys64. Install luaparse once with:

```powershell
C:\msys64\ucrt64\bin\npm.cmd install --prefix C:\msys64\opt\luaparse luaparse@0.3.1
```

### Smoke test outside the game

`pwsh tools/Smoke-Test.ps1` runs the addon in plain Lua 5.1 with a stubbed WoW
API ([tools/smoke-test.lua](tools/smoke-test.lua)). It carries over all checks
of the WOWPriest and WOWPaladin smoke tests and adds checks for every class:
profile consistency with the talent data, weights at every level with and
without talents, spec detection from each class's talent tree, a verdict and
tooltip for a set of items at levels 12, 35 and 60, usable gear and level
gates, dual wield, ranged and Feral weapon DPS, talent effects, and the import
of the old knowledge bases. The stubs are strict: unknown frame methods,
events and script names, `SetBackdrop` without `BackdropTemplate`, and any
calculation with a *secret value* raise errors. `-ShowTooltips` prints every
rendered verdict tooltip, `-ShowChat` what the addon writes to chat. It needs
Lua 5.1 from msys2:

```powershell
C:\msys64\usr\bin\bash.exe -lc "pacman -S --noconfirm --needed mingw-w64-ucrt-x86_64-lua51"
```

The smoke test can't tell whether the real WoW Forever client behaves like
the stubs, so `/wch debug` in game is still the real test.

## Generated data

Data comes from the Battle.net Game Data API, using the **WoW Forever**
dataset only (`namespace=static-forever-eu`). Store an API client's ID and
secret from https://develop.battle.net in the user environment variables
`BNET_CLIENT_ID` and `BNET_CLIENT_SECRET`.

- `pwsh tools/Export-Talents.ps1` writes the talent trees of all classes
  (node ID, spell ID, ranks, and the max-rank text as a comment).
- `pwsh tools/Export-Sets.ps1` writes all item sets. Keep the default `en_US`
  locale, because the addon parses the English bonus texts.
- `pwsh tools/Export-Items.ps1` exports the IDs in `tools/items.txt` (optional:
  the addon reads live item data from the game).

The API dataset (build 1.60.1_70399) is older than the live client. The talent
values the weights use were taken from the talent pages of
[classicwowforever.com](https://classicwowforever.com/talents/) (client build
1.60.1.70862, read 8 and 15 Nov 2026) and its 10 Nov patch notes; where they
differ from the API text, the class profile says so. See
[docs/NOTES.md](docs/NOTES.md) for the sources.

## Notes on Midnight-era restrictions

WoW Forever uses the Midnight addon rules. In combat, some values may be
*secret values*: they can be displayed, but not compared or calculated with.
The addon reads character stats and talents only out of combat and keeps the
last snapshot during combat. The mana bar passes mana values straight to the
status bar and never calculates with them.
