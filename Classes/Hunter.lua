-- WOWClassHelper: Hunter profile
--
-- Fields are explained in Classes/Priest.lua. New profile, not yet checked
-- in game. Forever specifics from https://classicwowforever.com/ (talents:
-- client build 1.60.1.70862, read 15 Nov 2026):
--   - Survival gets more melee and trap tools (Mongoose Bite, Strider Kick,
--     Predator's Edge: off-hand damage +50%), so it is scored as a melee spec
--   - wands, bows and guns "lead with DPS" in the weapon guide
--   - Careful Aim: attack power +100% of Intellect
local _, ns = ...
local W = ns.Weights

ns:RegisterClass("HUNTER", {
    name = "Hunter", plural = "Hunters",
    mana = true,

    armor = { [1] = true, [2] = true, [3] = 40 },   -- mail from level 40
    weapons = {
        [0] = true, [1] = true, [2] = true, [3] = true, [6] = 20, [7] = true, [8] = true, [10] = true,
        [13] = true, [15] = true, [16] = true, [18] = true,
    },
    dualWield = 20,

    specs = {
        { key = "BEAST_MASTERY", id = 50, retailIDs = { 253 }, name = "Beast Mastery", short = "BM", role = "Damage",
          attack = "RANGED", icon = "Interface\\Icons\\Ability_Hunter_BeastTaming" },
        { key = "MARKSMANSHIP", id = 163, retailIDs = { 254 }, name = "Marksmanship", short = "MM", role = "Damage",
          attack = "RANGED", icon = "Interface\\Icons\\Ability_Marksmanship" },
        { key = "SURVIVAL", id = 51, retailIDs = { 255 }, name = "Survival", short = "Surv", role = "Damage",
          attack = "MELEE", icon = "Interface\\Icons\\Ability_Hunter_SwiftStrike" },
    },
    tabOrder = { "BEAST_MASTERY", "MARKSMANSHIP", "SURVIVAL" },
    defaultSpec = "BEAST_MASTERY",
    aliases = { beast = "BEAST_MASTERY", marks = "MARKSMANSHIP", sv = "SURVIVAL", melee = "SURVIVAL",
                dps = "BEAST_MASTERY", damage = "BEAST_MASTERY" },

    sampleSpell = { 1978, "Serpent Sting" },
    debugTalents = {
        { "Surefooted", 19290 }, { "Lethal Attacks", 19426 }, { "Lone Wolf", 415370 },
        { "Trueshot Aura", 1299346 }, { "Bestial Wrath", 19574 }, { "Counterattack", 19306 },
    },

    weights = {
        -- 1.0 = one point of Agility. "+Attack Power" on items also raises
        -- ranged attack power; 1 ranged weapon DPS = 14 ranged attack power.
        ROLE = {
            -- Pet damage, Auto Shot and Arcane Shot
            BEAST_MASTERY = {
                AGILITY = 1.0, RANGED_DPS = 6.0, RANGED_ATTACK_POWER = 0.45, ATTACK_POWER = 0.45,
                CRIT = 0.7, HIT = 1.2, HASTE = 0.7, MASTERY = 0.5, VERSATILITY = 0.5,
                INTELLECT = 0.3, MANA_REGENERATION = 0.6, SPIRIT = 0.05,
                STAMINA = 0.35, ARMOR = 0.005, DPS = 0.2, STRENGTH = 0.05,
            },
            -- Aimed Shot, Multi-Shot, Sniper Shot: weapon damage, crits with Mortal Shots
            MARKSMANSHIP = {
                AGILITY = 1.0, RANGED_DPS = 7.0, RANGED_ATTACK_POWER = 0.5, ATTACK_POWER = 0.5,
                CRIT = 0.9, HIT = 1.4, HASTE = 0.8, MASTERY = 0.5, VERSATILITY = 0.5,
                INTELLECT = 0.25, MANA_REGENERATION = 0.6, SPIRIT = 0.05,
                STAMINA = 0.25, ARMOR = 0.005, DPS = 0.2, STRENGTH = 0.05,
            },
            -- Melee with two weapons (Predator's Edge), Mongoose Bite
            SURVIVAL = {
                AGILITY = 1.0, STRENGTH = 0.5, ATTACK_POWER = 0.5, DPS = 6.0,
                RANGED_DPS = 1.5, RANGED_ATTACK_POWER = 0.1,
                CRIT = 1.0, HIT = 1.3, HASTE = 0.7, MASTERY = 0.5, VERSATILITY = 0.5,
                INTELLECT = 0.25, MANA_REGENERATION = 0.5, SPIRIT = 0.05,
                STAMINA = 0.4, ARMOR = 0.008, DODGE = 0.15, PARRY = 0.15,
            },
        },
        ROLE_REGEN_SHARE = { BEAST_MASTERY = 0.3, MARKSMANSHIP = 0.25, SURVIVAL = 0.3 },

        -- Hunters level with the pet tanking and ranged attacks
        QUESTING = {
            RANGED_DPS = 6.5,         -- 1 ranged weapon DPS = 14 ranged attack power = 7 Agility
            STAMINA = 0.45,
            INTELLECT = 0.25,         -- mana for shots, stings and Mend Pet
            SPIRIT = 0.15,
            MANA_REGENERATION = 0.6,
            ARMOR = 0.006,
            REGEN_SHARE = 0.5,
            LEGACY_INTELLECT = 0.06,  -- Intellect +6% per rank of Thrill of Adventure (as for the Paladin)
        },

        Questing = function(spec, level)
            local Q = W.QUESTING
            local w = {
                AGILITY = 1.0, RANGED_DPS = Q.RANGED_DPS, RANGED_ATTACK_POWER = 0.45, ATTACK_POWER = 0.45,
                CRIT = 0.7, HIT = 0.6, HASTE = 0.5, MASTERY = 0.3, VERSATILITY = 0.4,
                INTELLECT = Q.INTELLECT * (1 + Q.LEGACY_INTELLECT * W.LegacyRank()),
                SPIRIT = Q.SPIRIT, MANA_REGENERATION = Q.MANA_REGENERATION,
                STAMINA = Q.STAMINA, ARMOR = Q.ARMOR,
                DPS = 0.6, STRENGTH = 0.15, DODGE = 0.1,   -- some melee while the pet holds aggro
            }
            if spec == "SURVIVAL" then
                w.DPS, w.STRENGTH, w.ATTACK_POWER, w.RANGED_DPS = 4.0, 0.4, 0.5, 3.0
            end
            return w
        end,

        -- Talents (tree 1091), site values at max rank
        TALENTS = {
            LIGHTNING_REFLEXES = { spell = 19168,   ranks = 5 },  -- Agility +15%
            CAREFUL_AIM        = { spell = 1223984, ranks = 5 },  -- attack power +100% of Intellect
            RANGED_WEAPON_SPECIALIZATION = { spell = 19507, ranks = 5 },  -- ranged weapon damage +5%
            MORTAL_SHOTS       = { spell = 19485,   ranks = 5 },  -- ranged crit damage bonus +30%
            PREDATORS_EDGE     = { spell = 1310627, ranks = 5 },  -- melee crit damage +30%, off hand +50%
            BESTIAL_DISCIPLINE = { spell = 19590,   ranks = 2 },  -- 50% of regeneration continues while casting
        },

        ApplyTalents = function(w, spec, _, regenShare)
            local function T(name) return W.Talent(name, spec) end
            W.Mul(w, "RANGED_DPS", 1 + 0.05 * T("RANGED_WEAPON_SPECIALIZATION"))
            W.Mul(w, "RANGED_ATTACK_POWER", 1 + 0.05 * T("RANGED_WEAPON_SPECIALIZATION"))
            W.Mul(w, "CRIT", 1 + 0.25 * T("MORTAL_SHOTS"))
            W.Mul(w, "CRIT", 1 + 0.15 * T("PREDATORS_EDGE"))
            W.Mul(w, "DPS", 1 + 0.10 * T("PREDATORS_EDGE"))
            W.RegenWhileCasting(w, 0.5 * T("BESTIAL_DISCIPLINE"), regenShare)
            -- Careful Aim turns Intellect into attack power
            w.INTELLECT = (w.INTELLECT or 0) + T("CAREFUL_AIM") * (w.ATTACK_POWER or 0)
            W.Mul(w, "AGILITY", 1 + 0.15 * T("LIGHTNING_REFLEXES"))
        end,

        CAPS = {
            BEAST_MASTERY = { HIT = W.CAP.RANGED_HIT, HASTE = W.CAP.RANGED_HASTE },
            MARKSMANSHIP  = { HIT = W.CAP.RANGED_HIT, HASTE = W.CAP.RANGED_HASTE },
            SURVIVAL      = { HIT = W.CAP.MELEE_HIT, HASTE = W.CAP.MELEE_HASTE },
        },

        SET_EFFECT_TEXTS = {
            { match = "Concussive Shot", value = { BEAST_MASTERY = 2, MARKSMANSHIP = 2, SURVIVAL = 2 } },
            { match = "Arcane Shot", value = { BEAST_MASTERY = 2, MARKSMANSHIP = 3, SURVIVAL = 1 } },
            { match = "your pet", value = { BEAST_MASTERY = 5, MARKSMANSHIP = 2, SURVIVAL = 3 } },
        },
    },
})
