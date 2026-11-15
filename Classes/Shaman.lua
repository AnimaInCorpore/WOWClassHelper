-- WOWClassHelper: Shaman profile
--
-- Fields are explained in Classes/Priest.lua. New profile, not yet checked
-- in game. Forever specifics from https://classicwowforever.com/ (talents:
-- client build 1.60.1.70862; class changes and 10 Nov patch notes, read
-- 15 Nov 2026):
--   - two-handed axes and maces are baseline for every Shaman
--   - Windfury Weapon and Windfury Totem can be active together
--   - 10 Nov hotfix: Mental Dexterity 33/66/100% of Intellect as attack
--     power (the API text in Data/Talents.lua says 100% too); Stormstrike
--     100% weapon damage, 8 sec cooldown
local _, ns = ...
local W = ns.Weights

ns:RegisterClass("SHAMAN", {
    name = "Shaman", plural = "Shamans",
    mana = true,
    school = { id = 4, name = "Nature" },

    armor = { [1] = true, [2] = true, [3] = 40, [6] = true, [9] = true },   -- mail from 40, shields, totems
    weapons = { [0] = true, [1] = true, [4] = true, [5] = true, [10] = true, [13] = true, [15] = true },
    dualWield = false,   -- the site doesn't say whether Forever Shamans dual wield
    groupLabels = { offhand = "shields & off hands", relic = "totems" },

    specs = {
        { key = "ELEMENTAL", id = 375, retailIDs = { 262 }, name = "Elemental", short = "Ele", role = "Damage",
          attack = "SPELL", icon = "Interface\\Icons\\Spell_Nature_Lightning" },
        { key = "ENHANCEMENT", id = 373, retailIDs = { 263 }, name = "Enhancement", short = "Enh", role = "Damage",
          attack = "MELEE", icon = "Interface\\Icons\\Spell_Nature_LightningShield" },
        { key = "RESTORATION", id = 374, retailIDs = { 264 }, name = "Restoration", short = "Resto", role = "Healer",
          attack = "SPELL", icon = "Interface\\Icons\\Spell_Nature_MagicImmunity" },
    },
    tabOrder = { "ELEMENTAL", "ENHANCEMENT", "RESTORATION" },
    defaultSpec = "ENHANCEMENT",
    aliases = { enhance = "ENHANCEMENT", melee = "ENHANCEMENT", dps = "ENHANCEMENT", damage = "ENHANCEMENT",
                caster = "ELEMENTAL", heal = "RESTORATION", healer = "RESTORATION" },

    sampleSpell = { 403, "Lightning Bolt" },
    debugTalents = {
        { "Tidal Focus", 16179 }, { "Stormstrike", 17364 }, { "Mana Tide Totem", 16190 },
        { "Lightning Mastery", 16166 }, { "Water Shield", 408510 }, { "Maelstrom Weapon", 408498 },
    },

    weights = {
        -- Elemental and Restoration: 1.0 = one point of spell damage / healing.
        -- Enhancement: 1.0 = one point of Strength (2 attack power).
        ROLE = {
            ELEMENTAL = {
                DAMAGE = 1.0, SHARE_NATURE = 0.8, SHARE_FIRE = 0.15, SHARE_FROST = 0.05, HEALING = 0.05,
                HIT = 1.1, SPELL_HIT = 1.1, CRIT = 0.6, SPELL_CRIT = 0.6,
                HASTE = 0.7, MASTERY = 0.5, VERSATILITY = 0.5,
                INTELLECT = 0.45, SPIRIT = 0.1, MANA_REGENERATION = 1.1,
                STAMINA = 0.15, ARMOR = 0.002,
            },
            -- Slow two-hander with Windfury; Stormstrike and shocks
            ENHANCEMENT = {
                STRENGTH = 1.0, AGILITY = 0.6, ATTACK_POWER = 0.5, DPS = 6.5,
                CRIT = 1.0, HIT = 1.3, HASTE = 0.8, MASTERY = 0.5, VERSATILITY = 0.6,
                DAMAGE = 0.25, SHARE_NATURE = 0.7, SHARE_FIRE = 0.2, SHARE_FROST = 0.1, HEALING = 0.02,
                INTELLECT = 0.25, MANA_REGENERATION = 0.3, SPIRIT = 0.05,
                STAMINA = 0.3, ARMOR = 0.01, DODGE = 0.1, PARRY = 0.1,
            },
            RESTORATION = {
                HEALING = 1.0, DAMAGE = 0.05, SHARE_NATURE = 0.8, SHARE_FIRE = 0.2,
                MANA_REGENERATION = 2.2, INTELLECT = 0.7, SPIRIT = 0.25,
                CRIT = 0.5, SPELL_CRIT = 0.5, HASTE = 0.6, MASTERY = 0.4, VERSATILITY = 0.4,
                STAMINA = 0.2, ARMOR = 0.003,
            },
        },
        ROLE_REGEN_SHARE = { ELEMENTAL = 0.25, ENHANCEMENT = 0.4, RESTORATION = 0.25 },

        -- Elemental and Restoration level as casters that still melee between
        -- spells; Enhancement in melee like a Paladin
        QUESTING = {
            CAST_SHARE = 0.4,
            DAMAGE_PER_CAST_SECOND = 1 / 3.5,
            MANA_DAMAGE = 1.0,
            REGEN_SHARE = 0.5,
            DRINK_SECONDS = 240,
            KILL_SECONDS = 40,
            SPIRIT_REGEN = 0.1,         -- classic Shaman: 17 + Spirit / 5 every 2 sec
            MANA_PER_INTELLECT = 15,
            STAMINA = 0.5,
            HEALING = { ELEMENTAL = 0.3, ENHANCEMENT = 0.2, RESTORATION = 0.5 },
            MELEE_SHARE = 0.25,         -- casters: share of time in melee
            WEAPON_DPS = 7.0,           -- Enhancement: 1 weapon DPS = 14 attack power = 7 Strength
            LEGACY_INTELLECT = 0.06,
        },

        Questing = function(spec, level)
            local Q = W.QUESTING
            local spf = W.SpellPowerFactor(level)
            if spec == "ENHANCEMENT" then
                return {
                    STRENGTH = 1.0, ATTACK_POWER = 0.5, DPS = Q.WEAPON_DPS,
                    AGILITY = W.Lerp(0.3, 0.55, W.Clamp((level - 10) / 50)),
                    CRIT = 0.8, HIT = 0.6, HASTE = 0.5, MASTERY = 0.4, VERSATILITY = 0.5,
                    DAMAGE = 0.3 * spf, SHARE_NATURE = 0.7, SHARE_FIRE = 0.2, SHARE_FROST = 0.1,
                    HEALING = 0.15 * spf, STAMINA = Q.STAMINA,
                    INTELLECT = 0.3 * (1 + Q.LEGACY_INTELLECT * W.LegacyRank()),
                    SPIRIT = 0.25, MANA_REGENERATION = 0.9, ARMOR = 0.008,
                    DODGE = 0.25, PARRY = 0.15, BLOCK = 0.1, BLOCK_VALUE = 0.05, DEFENSE = 0.1,
                }
            end
            local schools = level < 10 and { NATURE = 0.6, FIRE = 0.3, FROST = 0.1 }
                or { NATURE = 0.75, FIRE = 0.2, FROST = 0.05 }
            local w = W.CasterQuesting(spec, level, Q, schools)
            -- Melee between spells: weapon DPS against spell power for the casting time
            local unit = Q.CAST_SHARE * Q.DAMAGE_PER_CAST_SECOND
            w.DPS = Q.MELEE_SHARE / unit
            w.ATTACK_POWER = w.DPS / 14
            w.STRENGTH = 2 * w.ATTACK_POWER
            return w
        end,

        -- Talents (tree 1082), site values at max rank
        TALENTS = {
            ANCESTRAL_KNOWLEDGE = { spell = 17485,   ranks = 5 },  -- Intellect +10%
            TOUGHNESS           = { spell = 16252,   ranks = 5 },  -- Stamina +10%
            MENTAL_DEXTERITY    = { spell = 415140,  ranks = 3 },  -- attack power +100% of Intellect (10 Nov hotfix)
            MENTAL_QUICKNESS    = { spell = 30812,   ranks = 2 },  -- spell damage and healing +30% of Intellect
            MINDFULNESS         = { spell = 1223033, ranks = 3 },  -- 50% of regeneration continues while casting
            PURIFICATION        = { spell = 16178,   ranks = 5 },  -- healing +10%
            HEALING_WAY         = { spell = 29206,   ranks = 3 },  -- Healing Wave +25%
            CONCUSSION          = { spell = 16035,   ranks = 5 },  -- Lightning Bolt, Chain Lightning, Earth Shock +5%
            ELEMENTAL_FURY      = { spell = 16089,   ranks = 5, spec = "ELEMENTAL" },   -- spell crit damage bonus +100%
            FLURRY              = { spell = 16256,   ranks = 5, spec = "ENHANCEMENT" }, -- +30% attack speed after a crit
        },

        ApplyTalents = function(w, spec, _, regenShare)
            local function T(name) return W.Talent(name, spec) end
            W.RegenWhileCasting(w, 0.5 * T("MINDFULNESS"), regenShare)
            W.Mul(w, "HEALING", (1 + 0.10 * T("PURIFICATION")) * (1 + 0.10 * T("HEALING_WAY")))
            W.Mul(w, "STAMINA", 1 + 0.10 * T("TOUGHNESS"))
            local critBonus = 1 + T("ELEMENTAL_FURY")
            W.Mul(w, "CRIT", critBonus * (1 + 0.15 * T("FLURRY")))
            W.Mul(w, "SPELL_CRIT", critBonus)
            if w.DAMAGE then W.SpellSchools(w, { NATURE = 1 + 0.05 * T("CONCUSSION") }) end
            -- Intellect turns into attack power and spell power
            w.INTELLECT = (w.INTELLECT or 0) + T("MENTAL_DEXTERITY") * (w.ATTACK_POWER or 0)
                + 0.3 * T("MENTAL_QUICKNESS") * ((w.SPELL_DAMAGE or 0) + (w.HEALING or 0))
            W.Mul(w, "INTELLECT", 1 + 0.10 * T("ANCESTRAL_KNOWLEDGE"))
        end,

        CAPS = {
            ELEMENTAL   = { HIT = W.CAP.SPELL_HIT, SPELL_HIT = W.CAP.SPELL_HIT, HASTE = W.CAP.SPELL_HASTE },
            ENHANCEMENT = { HIT = W.CAP.MELEE_HIT, HASTE = W.CAP.MELEE_HASTE },
            RESTORATION = { HASTE = W.CAP.SPELL_HASTE },
        },

        SET_EFFECT_TEXTS = {
            { match = "Shock spells", value = { ELEMENTAL = 4, ENHANCEMENT = 3, RESTORATION = 1 } },
            { match = "Mana Spring", value = { ELEMENTAL = 1, ENHANCEMENT = 1, RESTORATION = 2 } },
            { match = "totem spells", value = { ELEMENTAL = 1, ENHANCEMENT = 1, RESTORATION = 2 } },
            { match = "Healing Wave", value = { ELEMENTAL = 1, ENHANCEMENT = 1, RESTORATION = 4 } },
        },
    },
})
