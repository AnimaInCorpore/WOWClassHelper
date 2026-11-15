-- WOWClassHelper: set bonus valuation
--
-- Set data comes from Data/Sets.lua (exported from the Forever dataset, all
-- classes). Bonus texts are parsed into stats where possible ("+20 Stamina",
-- "Increases healing done by up to 44 and damage done by up to 15 ...");
-- effects that can't be parsed (procs) use Weights.SET_EFFECTS,
-- Weights.SET_EFFECT_TEXTS (both from the class profile) or a small default
-- value, so collecting set pieces still counts.
--
-- Forever set bonus texts still use percent ("by 1.0%") while items give
-- ratings, so percent bonuses are converted to rating at the current level.
local _, ns = ...

local SetBonus = {}
ns.SetBonus = SetBonus

-- "+N <name>" texts
local NAMED_STATS = {
    ["strength"] = "STRENGTH", ["agility"] = "AGILITY", ["stamina"] = "STAMINA",
    ["intellect"] = "INTELLECT", ["spirit"] = "SPIRIT", ["armor"] = "ARMOR",
    ["attack power"] = "ATTACK_POWER", ["ranged attack power"] = "RANGED_ATTACK_POWER",
    ["defense"] = "DEFENSE", ["spell power"] = "SPELL_POWER", ["block value"] = "BLOCK_VALUE",
    ["all resistances"] = "ALL_RESISTANCES",
}

local SCHOOL_NAMES = {
    holy = "HOLY", fire = "FIRE", nature = "NATURE", frost = "FROST", shadow = "SHADOW", arcane = "ARCANE",
}

-- Longer sentence patterns. Each capture fills the stat at the same position;
-- "@SCHOOL" takes a school name capture ("Shadow") and makes it SHADOW_DAMAGE.
-- rating = combat rating the percent value is converted with; "CR_HIT_*" uses
-- the spec's attack type (melee, ranged or spell, see the class profiles).
local NUM = "([%d%.]+)"
local PATTERNS = {
    { "^Increases healing done by up to " .. NUM .. " and damage done by up to " .. NUM
        .. " for all magical spells and effects%.?$", { "HEALING", "SPELL_DAMAGE" } },
    { "^Increases damage and healing done by magical spells and effects by up to " .. NUM .. "%.?$", { "SPELL_POWER" } },
    { "^Increases healing done by spells and effects by up to " .. NUM .. "%.?$", { "HEALING" } },
    { "^Increases damage done by (%a+) spells and effects by up to " .. NUM .. "%.?$", { "@SCHOOL", "" } },
    { "^Improves your chance to get a critical strike with spells by " .. NUM .. "%%%.?$", { "SPELL_CRIT" }, "CR_CRIT_SPELL" },
    { "^Improves your chance to get a critical strike with melee attacks by " .. NUM .. "%%%.?$", { "CRIT" }, "CR_CRIT_MELEE" },
    { "^Improves your chance to get a critical strike with missile weapons by " .. NUM .. "%%%.?$", { "CRIT" }, "CR_CRIT_RANGED" },
    { "^Improves your chance to get a critical strike with ranged weapons by " .. NUM .. "%%%.?$", { "CRIT" }, "CR_CRIT_RANGED" },
    { "^Improves your chance to get a critical strike by " .. NUM .. "%%%.?$", { "CRIT" }, "CR_CRIT_*" },
    { "^Improves your chance to hit with spells by " .. NUM .. "%%%.?$", { "SPELL_HIT" }, "CR_HIT_SPELL" },
    { "^Improves your chance to hit by " .. NUM .. "%%%.?$", { "HIT" }, "CR_HIT_*" },
    { "^Restores " .. NUM .. " mana per 5 sec%.?$", { "MANA_REGENERATION" } },
    { "^Increases attack power by " .. NUM .. "%.?$", { "ATTACK_POWER" } },
    { "^Increases ranged attack power by " .. NUM .. "%.?$", { "RANGED_ATTACK_POWER" } },
    { "^%+" .. NUM .. " Attack Power when fighting [%a ]+%.?$", { "ATTACK_POWER" } },
    { "^Increased Defense %+" .. NUM .. "%.?$", { "DEFENSE" } },
    { "^Increases your chance to dodge an attack by " .. NUM .. "%%%.?$", { "DODGE" }, "CR_DODGE" },
    { "^Increases your chance to parry an attack by " .. NUM .. "%%%.?$", { "PARRY" }, "CR_PARRY" },
    { "^Increases your chance to block attacks with a shield by " .. NUM .. "%%%.?$", { "BLOCK" }, "CR_BLOCK" },
    { "^Increases the block value of your shield by " .. NUM .. "%.?$", { "BLOCK_VALUE" } },
}

local parsed = {}   -- text -> list of { stat, value, rating } or false (unrated)

-- Returns a list of { stat = key, value = n, rating = crName or nil } for a
-- bonus text, or nil if it can't be rated.
function SetBonus.ParseEffect(text)
    if parsed[text] ~= nil then return parsed[text] or nil end
    local result = false
    local clean = strtrim(text)

    local value, name = clean:match("^%+(%d+) ([%a ]+)%.?$")
    if value and NAMED_STATS[name:lower()] then
        result = { { stat = NAMED_STATS[name:lower()], value = tonumber(value) } }
    else
        for _, p in ipairs(PATTERNS) do
            local captures = { clean:match(p[1]) }
            if #captures > 0 then
                if p[2][1] == "@SCHOOL" then
                    local school = SCHOOL_NAMES[captures[1]:lower()]
                    if school then
                        result = { { stat = school .. "_DAMAGE", value = tonumber(captures[2]) or 0 } }
                        break
                    end
                else
                    result = {}
                    for i, stat in ipairs(p[2]) do
                        table.insert(result, { stat = stat, value = tonumber(captures[i]) or 0, rating = p[3] })
                    end
                    break
                end
            end
        end
    end

    parsed[text] = result
    return result or nil
end

function SetBonus.GetSet(setID)
    return setID and ns.SetData and ns.SetData.Sets[setID]
end

-- Manual value for an effect the parser can't rate, or nil
local function ManualValue(setID, effect, spec)
    local overrides = ns.Weights.SET_EFFECTS[setID]
    local manual = overrides and overrides[effect.count]
    if manual and manual[spec] then return manual[spec] end
    for _, rule in ipairs(ns.Weights.SET_EFFECT_TEXTS) do
        if effect.text:find(rule.match, 1, true) and rule.value[spec] then
            return rule.value[spec]
        end
    end
    return nil
end

-- Score of one effect for a spec (no caps: bonuses are small and flat)
function SetBonus.EffectValue(setID, effect, spec, weights)
    local manual = ManualValue(setID, effect, spec)
    if manual then return manual, true end

    local parts = SetBonus.ParseEffect(effect.text)
    if not parts then
        return ns.Weights.UNRATED_SET_EFFECT, false
    end
    local score = 0
    for _, part in ipairs(parts) do
        local v = part.value
        if part.rating then
            -- percent -> rating points, the unit item stats use
            local r = ns.Character:Rating(ns.Weights.RatingName(spec, part.rating))
            if r then v = v / r.ratio end
        end
        score = score + v * ns.Weights.Of(weights, part.stat)
    end
    return score, true
end

-- Total value of all bonuses active with `count` pieces
function SetBonus.Value(setID, count, spec, weights)
    local set = SetBonus.GetSet(setID)
    if not set or count <= 0 then return 0 end
    local total = 0
    for _, effect in ipairs(set.effects) do
        if effect.count <= count then
            total = total + SetBonus.EffectValue(setID, effect, spec, weights)
        end
    end
    return total
end

-- Effects that switch on/off when going from `before` to `after` pieces
function SetBonus.ChangedEffects(setID, before, after)
    local set = SetBonus.GetSet(setID)
    local gained, lost = {}, {}
    if not set then return gained, lost end
    for _, effect in ipairs(set.effects) do
        if effect.count > before and effect.count <= after then
            table.insert(gained, effect)
        elseif effect.count <= before and effect.count > after then
            table.insert(lost, effect)
        end
    end
    return gained, lost
end

-- Smallest bonus threshold above `count`, or nil
function SetBonus.NextThreshold(setID, count)
    local set = SetBonus.GetSet(setID)
    if not set then return nil end
    for _, effect in ipairs(set.effects) do
        if effect.count > count then return effect.count, effect end
    end
    return nil
end
