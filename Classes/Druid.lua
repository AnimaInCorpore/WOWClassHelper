-- WOWClassHelper: Druid profile
--
-- Fields are explained in Classes/Priest.lua. New profile, not yet checked
-- in game. Forever specifics from https://classicwowforever.com/ (talents:
-- client build 1.60.1.70862; weapon guide and class changes, 15 Nov 2026):
--   - Bear, Cat and Dire Bear attacks use the equipped weapon's DPS with the
--     form's own swing speed (confirmed by Blizzard), so weapon DPS counts
--     for Feral, unlike in classic
--   - Bloom heals for 100% of Spirit when Rejuvenation or Regrowth expires
local _, ns = ...
local W = ns.Weights

ns:RegisterClass("DRUID", {
    name = "Druid", plural = "Druids",
    mana = true,
    school = { id = 4, name = "Nature" },

    armor = { [1] = true, [2] = true, [8] = true },                    -- cloth, leather, idols
    weapons = { [4] = true, [5] = true, [10] = true, [13] = true, [15] = true },
    dualWield = false,
    groupLabels = { relic = "idols" },

    specs = {
        { key = "BALANCE", id = 574, retailIDs = { 102 }, name = "Balance", short = "Balance", role = "Damage",
          attack = "SPELL", icon = "Interface\\Icons\\Spell_Nature_StarFall" },
        -- mainExtra: bear form tanks with Stamina and Armor
        { key = "FERAL", id = 134, retailIDs = { 103, 104 }, name = "Feral", short = "Feral", role = "Cat/Bear",
          attack = "MELEE", icon = "Interface\\Icons\\Ability_Racial_BearForm", mainExtra = { "STAMINA", "ARMOR" } },
        { key = "RESTORATION", id = 573, retailIDs = { 105 }, name = "Restoration", short = "Resto", role = "Healer",
          attack = "SPELL", icon = "Interface\\Icons\\Spell_Nature_HealingTouch" },
    },
    tabOrder = { "BALANCE", "FERAL", "RESTORATION" },
    defaultSpec = "FERAL",
    aliases = {
        boomkin = "BALANCE", moonkin = "BALANCE", cat = "FERAL", bear = "FERAL", tank = "FERAL",
        dps = "FERAL", damage = "FERAL", heal = "RESTORATION", healer = "RESTORATION", tree = "RESTORATION",
    },

    sampleSpell = { 5176, "Wrath" },
    debugTalents = {
        { "Nature's Reach", 16819 }, { "Moonkin Form", 24858 }, { "Leader of the Pack", 17007 },
        { "Swiftmend", 18562 }, { "Natural Reaction", 417051 }, { "Bloom", 1328621 },
    },

    weights = {
        -- Balance and Restoration: 1.0 = one point of spell damage / healing.
        -- Feral: 1.0 = one point of Strength (2 attack power in forms).
        ROLE = {
            -- Starfire and Moonfire (Arcane), Wrath and Insect Swarm (Nature)
            BALANCE = {
                DAMAGE = 1.0, SHARE_ARCANE = 0.55, SHARE_NATURE = 0.45, HEALING = 0.05,
                HIT = 1.1, SPELL_HIT = 1.1, CRIT = 0.55, SPELL_CRIT = 0.55,
                HASTE = 0.7, MASTERY = 0.5, VERSATILITY = 0.5,
                INTELLECT = 0.4, SPIRIT = 0.2, MANA_REGENERATION = 1.0,
                STAMINA = 0.15, ARMOR = 0.004,   -- Moonkin Form: armor from items +360%
            },
            -- Cat damage with bear tanking stats on top; forms use weapon DPS
            FERAL = {
                STRENGTH = 1.0, AGILITY = 1.0, ATTACK_POWER = 0.5, DPS = 5.0,
                CRIT = 1.0, HIT = 1.3, HASTE = 0.6, MASTERY = 0.5, VERSATILITY = 0.6,
                STAMINA = 0.5, ARMOR = 0.03, DODGE = 0.4, DEFENSE = 0.3,
                INTELLECT = 0.05, SPIRIT = 0.02, MANA_REGENERATION = 0.05,
            },
            -- Heals over time; Bloom makes Spirit worth more (site)
            RESTORATION = {
                HEALING = 1.0, DAMAGE = 0.05, SHARE_NATURE = 0.6, SHARE_ARCANE = 0.4,
                MANA_REGENERATION = 2.0, INTELLECT = 0.6, SPIRIT = 0.55,
                CRIT = 0.4, SPELL_CRIT = 0.4, HASTE = 0.6, MASTERY = 0.4, VERSATILITY = 0.4,
                STAMINA = 0.15, ARMOR = 0.002,
            },
        },
        ROLE_REGEN_SHARE = { BALANCE = 0.25, FERAL = 0.5, RESTORATION = 0.25 },

        -- Balance and Restoration level as casters (no wand), Feral in forms
        QUESTING = {
            CAST_SHARE = 0.45,
            DAMAGE_PER_CAST_SECOND = 1 / 3.5,
            MANA_DAMAGE = 1.0,
            REGEN_SHARE = 0.5,
            DRINK_SECONDS = 240,
            KILL_SECONDS = 40,
            SPIRIT_REGEN = 0.1,         -- classic Druid: 15 + Spirit / 5 every 2 sec
            MANA_PER_INTELLECT = 15,
            STAMINA = 0.5,
            HEALING = { BALANCE = 0.3, FERAL = 0.2, RESTORATION = 0.5 },
            WEAPON_DPS = 5.0,           -- forms use weapon DPS at the form's swing speed
            LEGACY_INTELLECT = 0.06,
        },

        Questing = function(spec, level)
            local Q = W.QUESTING
            if spec == "FERAL" then
                local spf = W.SpellPowerFactor(level)
                return {
                    STRENGTH = 1.0, AGILITY = W.Lerp(0.6, 0.9, W.Clamp((level - 10) / 50)), ATTACK_POWER = 0.5,
                    DPS = Q.WEAPON_DPS, CRIT = 0.8, HIT = 0.6, HASTE = 0.5, MASTERY = 0.4, VERSATILITY = 0.5,
                    STAMINA = Q.STAMINA, ARMOR = 0.015, DODGE = 0.3, DEFENSE = 0.15,
                    INTELLECT = 0.15 * (1 + Q.LEGACY_INTELLECT * W.LegacyRank()),   -- shifting and healing mana
                    SPIRIT = 0.15, MANA_REGENERATION = 0.3, HEALING = 0.1 * spf,
                }
            end
            local schools = level < 10 and { NATURE = 0.7, ARCANE = 0.3 }   -- Wrath and Moonfire
                or spec == "BALANCE" and { ARCANE = 0.5, NATURE = 0.5 }
                or { NATURE = 0.6, ARCANE = 0.4 }
            return W.CasterQuesting(spec, level, Q, schools)
        end,

        -- Talents (tree 1089), site values at max rank
        TALENTS = {
            HEART_OF_THE_WILD = { spell = 17003,   ranks = 5 },  -- Intellect +10%; Cat: Strength +10%, Bear: Stamina +20%
            REFLECTION        = { spell = 17106,   ranks = 3 },  -- 50% of regeneration continues while casting
            GIFT_OF_NATURE    = { spell = 17104,   ranks = 5 },  -- healing +10%
            LIVING_SPIRIT     = { spell = 1309631, ranks = 3 },  -- Spirit +15%
            MOONFURY          = { spell = 16896,   ranks = 5 },  -- Arcane and Nature damage +10%
            VENGEANCE         = { spell = 16909,   ranks = 5, spec = "BALANCE" },      -- Arcane and Nature crit bonus +100%
            NATURAL_INSTINCT  = { spell = 1223242, ranks = 2 },  -- melee crit damage +20%, healing +25% of Intellect
            BLOOM             = { spell = 1328621, ranks = 1, spec = "RESTORATION" },  -- HoTs heal for 100% of Spirit at the end
        },

        ApplyTalents = function(w, spec, _, regenShare)
            local function T(name) return W.Talent(name, spec) end
            W.RegenWhileCasting(w, 0.5 * T("REFLECTION"), regenShare)
            W.Mul(w, "HEALING", 1 + 0.10 * T("GIFT_OF_NATURE"))
            local critBonus = 1 + T("VENGEANCE")
            W.Mul(w, "CRIT", critBonus)
            W.Mul(w, "SPELL_CRIT", critBonus)
            if spec == "FERAL" then
                W.Mul(w, "CRIT", 1 + 0.2 * T("NATURAL_INSTINCT"))
                W.Mul(w, "STRENGTH", 1 + 0.05 * T("HEART_OF_THE_WILD"))   -- half the time in Cat Form
                W.Mul(w, "STAMINA", 1 + 0.10 * T("HEART_OF_THE_WILD"))    -- half the time in Bear Form
            end
            if w.DAMAGE then
                local moonfury = 1 + 0.10 * T("MOONFURY")
                W.SpellSchools(w, { ARCANE = moonfury, NATURE = moonfury })
            end
            w.HEALING = w.HEALING or 0
            -- Natural Instinct and Bloom turn Intellect and Spirit into healing
            w.INTELLECT = (w.INTELLECT or 0) + 0.25 * T("NATURAL_INSTINCT") * w.HEALING
            w.SPIRIT = (w.SPIRIT or 0) + 0.3 * T("BLOOM") * w.HEALING
            W.Mul(w, "INTELLECT", 1 + 0.10 * T("HEART_OF_THE_WILD"))
            W.Mul(w, "SPIRIT", 1 + 0.15 * T("LIVING_SPIRIT"))
        end,

        CAPS = {
            BALANCE     = { HIT = W.CAP.SPELL_HIT, SPELL_HIT = W.CAP.SPELL_HIT, HASTE = W.CAP.SPELL_HASTE },
            FERAL       = { HIT = W.CAP.MELEE_HIT, DEFENSE = W.CAP.DEFENSE, HASTE = W.CAP.MELEE_HASTE },
            RESTORATION = { HASTE = W.CAP.SPELL_HASTE },
        },

        SET_EFFECT_TEXTS = {
            { match = "Bear, Cat, or Travel Form", value = { BALANCE = 2, FERAL = 3, RESTORATION = 2 } },
            { match = "Rebirth", value = { BALANCE = 2, FERAL = 2, RESTORATION = 3 } },
            { match = "Starfire", value = { BALANCE = 4, FERAL = 0, RESTORATION = 0 } },
            { match = "Rejuvenation", value = { BALANCE = 1, FERAL = 1, RESTORATION = 4 } },
            { match = "Regrowth", value = { BALANCE = 1, FERAL = 0, RESTORATION = 4 } },
        },
    },
})
