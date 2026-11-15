-- WOWClassHelper: Paladin profile (from WOWPaladin)
--
-- Fields are explained in Classes/Priest.lua. Values marked "site" come from
-- https://classicwowforever.com/ (talents: client build 1.60.1.70862, weapon
-- guide and class changes read 15 Nov 2026).
local _, ns = ...
local W = ns.Weights

ns:RegisterClass("PALADIN", {
    name = "Paladin", plural = "Paladins",
    mana = true,
    school = { id = 2, name = "Holy" },

    -- All armor types (plate from level 40), shields and librams; axes, maces
    -- and swords (one- and two-handed) and polearms (site: from level 20).
    armor = { [1] = true, [2] = true, [3] = true, [4] = 40, [6] = true, [7] = true },
    weapons = { [0] = true, [1] = true, [4] = true, [5] = true, [6] = 20, [7] = true, [8] = true },
    dualWield = false,
    groupLabels = { offhand = "shields & off hands", relic = "librams" },

    -- Every Paladin spec has its own role, so the compact tooltip uses the
    -- role as the short name and in "Keep for ..." ("Tank", "Healer", "Damage").
    specs = {
        { key = "PROTECTION", id = 267, retailIDs = { 66 }, name = "Protection", short = "Tank", role = "Tank",
          display = "Tank", attack = "MELEE", icon = "Interface\\Icons\\Ability_Paladin_ShieldoftheTemplar" },
        { key = "HOLY", id = 594, retailIDs = { 65 }, name = "Holy", short = "Healer", role = "Healer",
          display = "Healer", attack = "SPELL", icon = "Interface\\Icons\\Spell_Holy_HolyBolt" },
        { key = "RETRIBUTION", id = 184, retailIDs = { 70 }, name = "Retribution", short = "Damage", role = "Damage",
          display = "Damage", attack = "MELEE", icon = "Interface\\Icons\\Spell_Holy_AuraOfLight" },
    },
    tabOrder = { "HOLY", "PROTECTION", "RETRIBUTION" },
    defaultSpec = "RETRIBUTION",
    aliases = {
        tank = "PROTECTION", prot = "PROTECTION", heal = "HOLY", dps = "RETRIBUTION", ret = "RETRIBUTION",
    },

    sampleSpell = { 635, "Holy Light" },
    debugTalents = {
        { "Precision", 20189 }, { "Conviction", 20117 }, { "Anticipation", 20096 },
        { "Divine Precision", 1310904 }, { "Holy Shield", 20925 }, { "Reverence", 1310899 },
    },

    weights = {
        -- SPELL_DAMAGE is Holy damage (all Paladin spells are Holy), so
        -- HOLY_DAMAGE gets the same weight; SPELL_POWER = SPELL_DAMAGE + HEALING.
        -- Role: 1.0 = the role's main stat. Questing: 1.0 = one point of Strength.

        ROLE = {
            -- Tank. Site: Holy Shield is back to 30% block (block worth more),
            -- spell power 0.5 for AoE tanking.
            PROTECTION = {
                STAMINA = 1.0,
                DEFENSE = 1.2, DODGE = 0.9, PARRY = 0.8, BLOCK = 0.8,
                BLOCK_VALUE = 0.4, ARMOR = 0.05,
                STRENGTH = 0.5, AGILITY = 0.5,
                HIT = 0.5, SPELL_DAMAGE = 0.5, HEALING = 0.02,
                INTELLECT = 0.3, MANA_REGENERATION = 0.3, SPIRIT = 0.05,
                HASTE = 0.3, MASTERY = 0.4, VERSATILITY = 0.5,
                DPS = 1.0,
            },
            -- Healer
            HOLY = {
                INTELLECT = 1.0,
                HEALING = 0.9, SPELL_DAMAGE = 0.05,
                MANA_REGENERATION = 1.2, SPIRIT = 0.3,
                CRIT = 0.6, SPELL_CRIT = 0.6, HASTE = 0.6, MASTERY = 0.5, VERSATILITY = 0.4,
                STAMINA = 0.2, ARMOR = 0.005,
                STRENGTH = 0.05,
            },
            -- Damage: white hits scale with weapon damage, 1 weapon DPS = 14 attack
            -- power = 7 Strength (site: the weapon guide uses the same 14 AP per
            -- DPS); judgements and Consecration don't, hence 6
            RETRIBUTION = {
                STRENGTH = 1.0,
                DPS = 6.0, ATTACK_POWER = 0.45,
                CRIT = 0.8, HIT = 0.9, HASTE = 0.6, MASTERY = 0.6, VERSATILITY = 0.6,
                AGILITY = 0.6, STAMINA = 0.4,
                INTELLECT = 0.25, SPELL_DAMAGE = 0.2, HEALING = 0.02,
                MANA_REGENERATION = 0.3, SPIRIT = 0.05,
                ARMOR = 0.01,
            },
        },

        -- Share of the time the five-second rule is not running in the role at
        -- max level, for Reverence's value.
        ROLE_REGEN_SHARE = { PROTECTION = 0.3, HOLY = 0.25, RETRIBUTION = 0.35 },

        -- Every Paladin levels in melee, with seals and judgements:
        QUESTING = {
            WEAPON_DPS = 7.0,         -- 1 weapon DPS = 14 attack power = 7 Strength (2 AP each)
            AGILITY_LOW = 0.3,        -- crit and armor from Agility at level 10 ...
            AGILITY_HIGH = 0.55,      -- ... and at max level: crit is worth more as weapon damage grows
            SPELL_DAMAGE = 0.3,       -- seals, judgements, Exorcism (at full spell power)
            TANK_SPELL_DAMAGE = 0.25, -- site: tank path while questing
            HEALING = 0.15,           -- self-heals between pulls
            STAMINA = 0.5,            -- surviving pulls
            INTELLECT = 0.35,         -- mana for seals, judgements and heals
            SPIRIT = 0.3,
            MANA_REGENERATION = 1.0,
            ARMOR = 0.008,            -- plate armor: ~0.04% less damage per point at level 13
            REGEN_SHARE = 0.5,        -- share of time outside the five-second rule
            LEGACY_INTELLECT = 0.06,  -- Intellect +6% per rank of the Legacy perk Thrill of Adventure
                                      -- (mana back per kill grows with the pool; as for the Priest)
        },

        Questing = function(spec, level)
            local Q = W.QUESTING
            local spf = W.SpellPowerFactor(level)
            local legacy = 1 + Q.LEGACY_INTELLECT * W.LegacyRank()
            local w = {
                STRENGTH = 1.0, ATTACK_POWER = 0.5, DPS = Q.WEAPON_DPS,
                AGILITY = W.Lerp(Q.AGILITY_LOW, Q.AGILITY_HIGH, W.Clamp((level - 10) / 50)),
                CRIT = 0.8, HIT = 0.6, HASTE = 0.5, MASTERY = 0.4, VERSATILITY = 0.5,
                SPELL_DAMAGE = Q.SPELL_DAMAGE * spf, HEALING = Q.HEALING * spf,
                STAMINA = Q.STAMINA, INTELLECT = Q.INTELLECT * legacy,
                SPIRIT = Q.SPIRIT,
                MANA_REGENERATION = Q.MANA_REGENERATION, ARMOR = Q.ARMOR,
                DEFENSE = 0.15, DODGE = 0.3, PARRY = 0.25, BLOCK = 0.15, BLOCK_VALUE = 0.05,
            }
            if spec == "PROTECTION" then
                -- levels with one-hander and shield: blocks and Stamina matter a bit more
                w.STAMINA, w.DEFENSE, w.BLOCK, w.BLOCK_VALUE, w.ARMOR = 0.6, 0.25, 0.25, 0.15, 0.012
                w.SPELL_DAMAGE = Q.TANK_SPELL_DAMAGE * spf
            elseif spec == "HOLY" then
                -- still melee, but heals more and drinks more
                w.INTELLECT = 0.45 * legacy
                w.SPIRIT, w.MANA_REGENERATION = 0.35, 1.1
                w.HEALING = 0.3 * spf
            end
            return w
        end,

        -- Talents with their Forever texts at max rank (talent tree 1100).
        -- Site-checked (15 Nov 2026): same values. Two-Handed Weapon
        -- Specialization only works with a two-hander; it is counted for the
        -- damage spec.
        TALENTS = {
            DIVINE_STRENGTH       = { spell = 20262,   ranks = 5 },  -- Strength +10%
            DIVINE_INTELLECT      = { spell = 20257,   ranks = 5 },  -- total Intellect +10%
            TOUGHNESS             = { spell = 20143,   ranks = 5 },  -- armor from items +10%
            REVERENCE             = { spell = 1310899, ranks = 2 },  -- 30% of regeneration continues while casting
            CHAMPION_OF_THE_LIGHT = { spell = 1311084, ranks = 5 },  -- spell damage +60% of Intellect
            HEALING_LIGHT         = { spell = 20237,   ranks = 3 },  -- Holy Light, Flash of Light, Holy Shock +12%
            TWO_HANDED_WEAPON     = { spell = 20111,   ranks = 3, spec = "RETRIBUTION" }, -- Physical and Holy damage +6%
            VENGEANCE             = { spell = 20049,   ranks = 3, spec = "RETRIBUTION" }, -- +3% damage per stack after crits, 5 stacks
            HOLY_POWER            = { spell = 5923,    ranks = 5, spec = "HOLY" },        -- crit healing bonus +50%
            ILLUMINATION          = { spell = 20210,   ranks = 5, spec = "HOLY" },        -- crit heals return 50% of the base cost
            SHIELD_SPECIALIZATION = { spell = 20150,   ranks = 2, spec = "PROTECTION" },  -- shield absorbs +30%
        },

        ApplyTalents = function(w, spec, _, regenShare)
            local function T(name) return W.Talent(name, spec) end
            local function Mul(stat, factor) W.Mul(w, stat, factor) end
            Mul("STRENGTH", 1 + 0.10 * T("DIVINE_STRENGTH"))
            Mul("INTELLECT", 1 + 0.10 * T("DIVINE_INTELLECT"))
            Mul("ARMOR", 1 + 0.10 * T("TOUGHNESS"))
            W.RegenWhileCasting(w, 0.3 * T("REVERENCE"), regenShare)
            Mul("HEALING", 1 + 0.12 * T("HEALING_LIGHT"))
            Mul("BLOCK_VALUE", 1 + 0.3 * T("SHIELD_SPECIALIZATION"))
            local damage = 1 + 0.06 * T("TWO_HANDED_WEAPON")
            for _, stat in ipairs({ "STRENGTH", "ATTACK_POWER", "DPS", "AGILITY", "CRIT", "HIT", "SPELL_DAMAGE" }) do
                Mul(stat, damage)
            end
            Mul("CRIT", 1 + 0.2 * T("VENGEANCE"))
            local healCrit = (1 + 0.5 * T("HOLY_POWER")) * (1 + 0.3 * T("ILLUMINATION"))
            Mul("CRIT", healCrit)
            Mul("SPELL_CRIT", healCrit)
            -- Champion of the Light turns Intellect into spell damage
            w.INTELLECT = (w.INTELLECT or 0) + 0.6 * T("CHAMPION_OF_THE_LIGHT") * (w.SPELL_DAMAGE or 0)

            w.HOLY_DAMAGE = w.SPELL_DAMAGE
            w.SPELL_POWER = (w.SPELL_DAMAGE or 0) + (w.HEALING or 0)
        end,

        CAPS = {
            PROTECTION  = { HIT = W.CAP.MELEE_HIT, DEFENSE = W.CAP.DEFENSE, HASTE = W.CAP.MELEE_HASTE },
            HOLY        = { HASTE = W.CAP.SPELL_HASTE },
            RETRIBUTION = { HIT = W.CAP.MELEE_HIT, HASTE = W.CAP.MELEE_HASTE },
        },

        SET_EFFECTS = {
            -- Example: [516] = { [4] = { PROTECTION = 10, HOLY = 15, RETRIBUTION = 20 } },
        },
        SET_EFFECT_TEXTS = {
            { match = "Hammer of Justice", value = { PROTECTION = 2, HOLY = 2, RETRIBUTION = 2 } },
        },
    },
})
