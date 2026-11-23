-- WOWClassHelper: stat weights per spec, level and talents, and stat caps
--
-- The score of an item is the sum of (stat value x weight). Weights are
-- relative; each class profile (Classes/*.lua, table `weights`) says what
-- 1.0 is (e.g. one point of spell damage, or one point of Strength). They are
-- computed for the player's current level and learned talents:
--
--   1. ROLE: what a stat is worth at max level in the spec's role (raids and
--      dungeons), before talents.
--   2. Questing(spec, level): what a stat is worth while leveling solo, from
--      the game mechanics at the player's level.
--   3. The mix: at level 10 and below only questing counts, at max level only
--      ROLE; in between it moves in a straight line (level 35: half each).
--   4. ApplyTalents: talents the player has learned in the WoW Forever talent
--      tree change some values (Weights.TALENTS lists them per class).
--
-- Stat keys are normalized names (see Core/ItemData.lua), e.g. the game's
-- ITEM_MOD_INTELLECT_SHORT becomes INTELLECT and RESISTANCE0_NAME becomes ARMOR.
-- Spell damage can be given per school: DAMAGE is the value of +1 damage to
-- all schools and SHARE_<SCHOOL> the part of the damage dealt with that
-- school; Weights.SpellSchools turns them into HOLY_DAMAGE, SHADOW_DAMAGE, ...,
-- SPELL_DAMAGE and SPELL_POWER (= SPELL_DAMAGE + HEALING).
local _, ns = ...

local Weights = {}
ns.Weights = Weights

-- Helpers for class profiles ---------------------------------------------------

local function Lerp(a, b, t) return a + (b - a) * t end
local function Clamp(x) return math.max(0, math.min(1, x)) end
Weights.Lerp, Weights.Clamp = Lerp, Clamp

-- Spells learned below level 20 get less from spell power: 3.75% less per
-- level below 20 (classic rule). The best ranks you cast at a level were
-- learned about 3 levels earlier.
function Weights.SpellPowerFactor(level)
    if level >= 23 then return 1 end
    return math.max(0.25, 1 - (23 - level) * 0.0375)
end

Weights.SCHOOLS = { "HOLY", "FIRE", "NATURE", "FROST", "SHADOW", "ARCANE" }

-- Turns DAMAGE and SHARE_<SCHOOL> into <SCHOOL>_DAMAGE, SPELL_DAMAGE and
-- SPELL_POWER. mult: optional { SCHOOL = factor } from talents. Weights.Get
-- calls it after ApplyTalents if the profile didn't.
function Weights.SpellSchools(w, mult)
    local damage, total = w.DAMAGE or 0, 0
    for _, school in ipairs(Weights.SCHOOLS) do
        local share = w["SHARE_" .. school]
        if share then
            local v = damage * share * (mult and mult[school] or 1)
            w[school .. "_DAMAGE"] = v
            total = total + v
            w["SHARE_" .. school] = nil
        end
    end
    w.SPELL_DAMAGE = (w.SPELL_DAMAGE or 0) + total
    w.HEALING = w.HEALING or 0
    w.SPELL_POWER = w.SPELL_DAMAGE + w.HEALING
    w.DAMAGE = nil
end

-- Questing model for classes that level with damage spells (and a wand).
-- Q: the profile's QUESTING assumptions (see Classes/Priest.lua), schools:
-- { SCHOOL = share } of the damage dealt at this level.
-- 1.0 = one point of spell damage at full value.
function Weights.CasterQuesting(spec, level, Q, schools)
    local unit = Q.CAST_SHARE * Q.DAMAGE_PER_CAST_SECOND     -- damage/sec from 1 spell power
    local spf = Weights.SpellPowerFactor(level)
    local w = {
        DAMAGE = spf, HEALING = (Q.HEALING and Q.HEALING[spec] or 0.2) * spf,
        SPIRIT = Q.SPIRIT_REGEN * Q.REGEN_SHARE * Q.MANA_DAMAGE / unit,
        MANA_REGENERATION = 0.2 * Q.MANA_DAMAGE / unit,          -- 1 mana per 5 sec
        -- the mana pool, refilled at each drink, plus the Legacy perk's share
        -- of the pool on every kill
        INTELLECT = Q.MANA_PER_INTELLECT * Q.MANA_DAMAGE
            * (1 / Q.DRINK_SECONDS + Weights.LegacyRank() / 100 / Q.KILL_SECONDS) / unit,
        STAMINA = Q.STAMINA, ARMOR = Q.ARMOR or 0.01,
        CRIT = 0.3, SPELL_CRIT = 0.3, HIT = 0.3, SPELL_HIT = 0.3,
        HASTE = 0.3, MASTERY = 0.2, VERSATILITY = 0.2,
    }
    if Q.WAND_SHARE_LOW then
        -- 1 wand DPS for the wanding part of each fight, against spell power
        -- for the casting part
        local wand = Lerp(Q.WAND_SHARE_LOW, Q.WAND_SHARE_HIGH, Clamp((level - 20) / 40))
        w.WAND_DPS = wand / (1 - wand) / Q.DAMAGE_PER_CAST_SECOND
            * (1 - (Q.WAND_START_DELAY or 0) / Q.WAND_SECONDS)
    end
    for school, share in pairs(schools) do w["SHARE_" .. school] = share end
    return w
end

-- Stat caps ---------------------------------------------------------------------
-- Class profiles list caps per spec in CAPS:
--   cap: percentage (or skill points for DEFENSE) above which the stat is
--        worth nothing, as a number or function(level, maxLevel) returning
--        a number or nil
--   rating: the game's combat rating constant used to convert item ratings
--        into percent at the current level. Without a known conversion (no
--        client API, no RATING_PER_PERCENT entry) item stats are taken as percent.
--   modifier: percent from sources other than rating (talents, racials,
--        buffs), added to the rating bonus: an API function name, or
--        "UnitDefenseBonus" for the character sheet's defense bonus minus the
--        rating part (Core/Character.lua).
--
-- !! Check these against WoW Forever - they are classic-style assumptions. !!

function Weights.SpellHitCap(level, maxLevel)
    if level >= maxLevel then return 16 end   -- raid bosses (+3 levels): 83% base, 99% max
    return 3                                  -- same-level mobs while questing: 96% base
end

function Weights.MeleeHitCap(level, maxLevel)
    if level >= maxLevel then return 9 end    -- raid bosses (+3 levels)
    return 5                                  -- same-level mobs while questing
end

function Weights.DefenseCap(level, maxLevel)
    if level < maxLevel then return nil end   -- no crit-immunity target while leveling
    return 140                                -- +140 over base = 440 at 60, crit immune vs raid bosses
end

function Weights.HasteCap()
    return 50   -- GCD floor: beyond this haste no longer shortens the global cooldown (VERIFY)
end

-- Ready-made cap definitions for the profiles
Weights.CAP = {
    SPELL_HIT  = { cap = Weights.SpellHitCap, rating = "CR_HIT_SPELL",  modifier = "GetSpellHitModifier" },
    MELEE_HIT  = { cap = Weights.MeleeHitCap, rating = "CR_HIT_MELEE",  modifier = "GetHitModifier" },
    RANGED_HIT = { cap = Weights.MeleeHitCap, rating = "CR_HIT_RANGED", modifier = "GetHitModifier" },
    DEFENSE    = { cap = Weights.DefenseCap,  rating = "CR_DEFENSE_SKILL", modifier = "UnitDefenseBonus" },
    SPELL_HASTE  = { cap = Weights.HasteCap, rating = "CR_HASTE_SPELL" },
    MELEE_HASTE  = { cap = Weights.HasteCap, rating = "CR_HASTE_MELEE" },
    RANGED_HASTE = { cap = Weights.HasteCap, rating = "CR_HASTE_RANGED" },
}

-- Rating needed for 1% at level 60, used when the client can't convert
-- ratings itself (e.g. no rating on gear yet). From Forever item data:
-- Lionheart Helm (2% hit, 2% crit in Classic) has 20 hit and 28 crit rating;
-- Neltharion's Tear (2% spell hit) has 20 hit rating, Virtuous Crown (1%
-- spell crit) 14 crit rating. Haste is a guess (VERIFY). Defense, dodge,
-- parry and block have no Forever reference item yet, so they stay
-- unconverted unless the client converts them.
-- Below level 60 a rating point is worth more: x (level - 8) / 52.
Weights.DEFAULT_RATING_PER_PERCENT = {
    CR_HIT_MELEE = 10, CR_HIT_SPELL = 10, CR_HIT_RANGED = 10,
    CR_CRIT_MELEE = 14, CR_CRIT_SPELL = 14, CR_CRIT_RANGED = 14,
    CR_HASTE_MELEE = 10, CR_HASTE_SPELL = 10, CR_HASTE_RANGED = 10,
}

-- Ratings read from the client for percent set bonuses even without an
-- estimate (dodge, parry, block, defense)
Weights.READ_RATINGS = { "CR_DEFENSE_SKILL", "CR_DODGE", "CR_PARRY", "CR_BLOCK" }

-- Class selection -----------------------------------------------------------------

local profile = {}
local cache = {}
local mainCache = {}   -- spec -> set of main stats, see Weights.MainStats

local function Merge(a, b)
    local t = {}
    for k, v in pairs(a or {}) do t[k] = v end
    for k, v in pairs(b or {}) do t[k] = v end
    return t
end

function Weights.Select(class)
    profile = class.weights or {}
    Weights.ROLE = profile.ROLE or {}
    Weights.ROLE_REGEN_SHARE = profile.ROLE_REGEN_SHARE or {}
    Weights.QUESTING = profile.QUESTING or {}
    Weights.TALENTS = profile.TALENTS or {}
    Weights.CAPS = profile.CAPS or {}
    Weights.RATING_PER_PERCENT = Merge(Weights.DEFAULT_RATING_PER_PERCENT, profile.RATING_PER_PERCENT)
    Weights.SET_EFFECTS = profile.SET_EFFECTS or {}
    Weights.SET_EFFECT_TEXTS = profile.SET_EFFECT_TEXTS or {}
    Weights.UNRATED_SET_EFFECT = profile.UNRATED_SET_EFFECT or 5
    cache = {}
    mainCache = {}
end

-- Questing values of the selected class at a level
function Weights.Questing(spec, level)
    return profile.Questing and profile.Questing(spec, level) or {}
end

-- Talents ---------------------------------------------------------------------
-- Weights.TALENTS[name] = { spell = spell ID, ranks = max ranks, spec = optional }
-- `spec` limits an effect to the weights of one spec (e.g. healing crits only
-- matter for the healer).

-- Learned share of a talent for a spec's weights, 0..1
function Weights.Talent(name, spec)
    local t = Weights.TALENTS[name]
    if not t then error("unknown talent " .. tostring(name), 2) end
    if t.spec and t.spec ~= spec then return 0 end
    return math.min(1, ns.Spec.TalentRank(t.spell) / t.ranks)
end

-- Multiplies a weight if it exists
function Weights.Mul(w, stat, factor)
    if w[stat] then w[stat] = w[stat] * factor end
end

-- Spirit is only worth its regeneration outside the five-second rule;
-- talents like Meditation let `share` of it continue while casting.
function Weights.RegenWhileCasting(w, share, regenShare)
    Weights.Mul(w, "SPIRIT", 1 + share * (1 - regenShare) / regenShare)
end

-- Legacy perk ------------------------------------------------------------
-- Thrill of Adventure ("Abenteuerlust" in German clients), Adventure tree: a
-- killing blow on a non-trivial enemy restores 1-5% of health and mana over
-- 10 sec (not in dungeons, raids or battlegrounds). The client shows perk
-- ranks only in the Legacy window, so the rank is set by hand.

function Weights.LegacyRank()
    local legacy = ns.db and ns.db.legacy
    return legacy and tonumber(legacy.adventure) or 0
end

-- Changes whenever something the weights depend on changes (for caches)
function Weights.Signature()
    return ns.Spec.TalentSignature() .. ":" .. Weights.LegacyRank()
end

ns:RegisterCommand("legacy", "[0-5]", "rank of the Legacy perk Thrill of Adventure (health and mana on kills)", function(arg)
    arg = strtrim(arg or "")
    if arg ~= "" then
        local rank = tonumber(arg)
        if not rank then
            ns.Print(("use a rank from 0 to 5, e.g. %s legacy 3"):format(ns.SLASH))
            return
        end
        ns.db.legacy.adventure = math.max(0, math.min(5, math.floor(rank)))
    end
    local rank = Weights.LegacyRank()
    ns.Print(("Legacy perk Thrill of Adventure (Abenteuerlust): rank %d/5 - %d%% of health and mana back per kill while questing"):format(rank, rank))
end)

-- Stat caps lookup ---------------------------------------------------------

-- Returns the cap value at the current level and the cap definition, or nil
function Weights.GetCap(spec, stat)
    local def = Weights.CAPS[spec] and Weights.CAPS[spec][stat]
    if not def then return nil end
    local cap = def.cap
    if type(cap) == "function" then
        cap = cap(ns.Spec.GetLevel(), ns.Spec.GetMaxLevel())
    end
    if not cap then return nil end
    return cap, def
end

-- Combat rating a spec's generic percent values use ("CR_HIT_*" -> CR_HIT_MELEE
-- for melee specs), see Spec INFO.attack
function Weights.RatingName(spec, name)
    if not name or not name:find("%*$") then return name end
    local info = ns.Spec.INFO[spec]
    return (name:gsub("%*$", info and info.attack or "SPELL"))
end

-- Lookup -------------------------------------------------------------------

-- Primary stats the game can combine into one key, e.g. STRENGTH_AGILITY_INTELLECT
Weights.PRIMARY = { STRENGTH = true, AGILITY = true, INTELLECT = true }

-- How far the mix has moved from questing (0) to ROLE (1)
function Weights.RoleShare(level, maxLevel)
    if level >= maxLevel then return 1 end
    return Clamp((level - 10) / (maxLevel - 10))
end

-- Returns the weight table for a spec at the player's level and talents.
function Weights.Get(spec)
    local level, maxLevel = ns.Spec.GetLevel(), ns.Spec.GetMaxLevel()
    local cacheKey = spec .. ":" .. level .. ":" .. maxLevel .. ":" .. Weights.Signature()
    if cache[cacheKey] then return cache[cacheKey] end

    local t = Weights.RoleShare(level, maxLevel)
    local role, questing = Weights.ROLE[spec] or {}, Weights.Questing(spec, level)
    local w = {}
    for stat, v in pairs(role) do w[stat] = v * t end
    for stat, v in pairs(questing) do w[stat] = (w[stat] or 0) + v * (1 - t) end
    local regenShare = Lerp(Weights.QUESTING.REGEN_SHARE or 0.5, Weights.ROLE_REGEN_SHARE[spec] or 0.3, t)
    if profile.ApplyTalents then profile.ApplyTalents(w, spec, t, regenShare) end
    if w.DAMAGE then Weights.SpellSchools(w) end
    if (w.SPELL_DAMAGE or w.HEALING) and not w.SPELL_POWER then
        w.SPELL_POWER = (w.SPELL_DAMAGE or 0) + (w.HEALING or 0)
    end
    for stat, v in pairs(w) do w[stat] = math.max(0, v) end
    cache[cacheKey] = w
    return w
end

-- Which weights are used, for display: "max level" or "level 13: questing 94%"
function Weights.BandText(spec)
    local level, maxLevel = ns.Spec.GetLevel(), ns.Spec.GetMaxLevel()
    local t = Weights.RoleShare(level, maxLevel)
    if t >= 1 then return "max level" end
    return ("level %d: questing %d%%"):format(level, math.floor((1 - t) * 100 + 0.5))
end

-- Main stats ------------------------------------------------------------------
-- The stats a spec is built around. An item that loses main stats compared
-- with your gear is at best "equal" (Core/Compare.lua), however much
-- Stamina, Armor or resistances it adds, and the tooltip lists main stats
-- first. Defaults by role (healers, tanks) or attack type (damage specs); a
-- spec in a class profile adds its own with `mainExtra = { ... }`.
Weights.MAIN_STATS = {
    Healer = { "HEALING", "SPELL_POWER", "INTELLECT", "SPIRIT", "MANA_REGENERATION" },
    Tank   = { "STAMINA", "ARMOR", "DEFENSE", "DODGE", "PARRY", "BLOCK", "BLOCK_VALUE" },
    SPELL  = { "SPELL_DAMAGE", "SPELL_POWER", "HOLY_DAMAGE", "FIRE_DAMAGE", "NATURE_DAMAGE",
               "FROST_DAMAGE", "SHADOW_DAMAGE", "ARCANE_DAMAGE", "INTELLECT" },
    MELEE  = { "STRENGTH", "AGILITY", "ATTACK_POWER", "DPS" },
    RANGED = { "AGILITY", "RANGED_ATTACK_POWER", "ATTACK_POWER", "RANGED_DPS" },
}

-- Set of a spec's main stats
function Weights.MainStats(spec)
    local set = mainCache[spec]
    if set then return set end
    local info = ns.Spec.INFO[spec] or {}
    set = {}
    for _, stat in ipairs(Weights.MAIN_STATS[info.role] or Weights.MAIN_STATS[info.attack or "SPELL"] or {}) do
        set[stat] = true
    end
    for _, stat in ipairs(info.mainExtra or {}) do set[stat] = true end
    mainCache[spec] = set
    return set
end

-- Is the stat key a main stat of the spec? Combined keys
-- (STRENGTH_AGILITY_INTELLECT) count if one part is.
function Weights.IsMainStat(spec, stat)
    local set = Weights.MainStats(spec)
    if set[stat] then return true end
    if stat:find("_") and not stat:find("_DAMAGE$") then
        for part in stat:gmatch("[^_]+") do
            if Weights.PRIMARY[part] and set[part] then return true end
        end
    end
    return false
end

-- Weight of a single stat key; handles combined primary stat keys.
function Weights.Of(weights, stat)
    local w = weights[stat]
    if w then return w end
    if stat:find("_") then
        local best = 0
        for part in stat:gmatch("[^_]+") do
            if Weights.PRIMARY[part] and (weights[part] or 0) > best then
                best = weights[part]
            end
        end
        return best
    end
    return 0
end
