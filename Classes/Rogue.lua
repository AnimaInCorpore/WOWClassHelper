-- WOWClassHelper: Rogue profile
--
-- Fields are explained in Classes/Priest.lua. New profile, not yet checked
-- in game. Forever specifics from https://classicwowforever.com/ (talents:
-- client build 1.60.1.70862; weapon guide and class changes, 15 Nov 2026):
--   - Rogues can use one-handed axes (Hack and Slash replaced the weapon
--     specializations); Combat and Subtlety use any weapon type
--   - Assassination needs daggers for Mutilate and favors dual wield (Venom)
--   - every Rogue learns Shank, an off-hand strike
local _, ns = ...
local W = ns.Weights

ns:RegisterClass("ROGUE", {
    name = "Rogue", plural = "Rogues",
    mana = false,

    armor = { [1] = true, [2] = true },
    weapons = {
        [0] = true, [2] = true, [3] = true, [4] = true, [7] = true, [13] = true, [15] = true,
        [16] = true, [18] = true,
    },
    dualWield = 10,

    specs = {
        { key = "ASSASSINATION", id = 253, retailIDs = { 259 }, name = "Assassination", short = "Assa", role = "Damage",
          attack = "MELEE", icon = "Interface\\Icons\\Ability_Rogue_Eviscerate" },
        { key = "COMBAT", id = 38, retailIDs = { 260 }, name = "Combat", short = "Combat", role = "Damage",
          attack = "MELEE", icon = "Interface\\Icons\\Ability_BackStab" },
        { key = "SUBTLETY", id = 39, retailIDs = { 261 }, name = "Subtlety", short = "Sub", role = "Damage",
          attack = "MELEE", icon = "Interface\\Icons\\Ability_Stealth" },
    },
    tabOrder = { "ASSASSINATION", "COMBAT", "SUBTLETY" },
    defaultSpec = "COMBAT",
    aliases = { assa = "ASSASSINATION", mutilate = "ASSASSINATION", sub = "SUBTLETY", dps = "COMBAT", damage = "COMBAT" },

    sampleSpell = { 1752, "Sinister Strike" },
    debugTalents = {
        { "Malice", 14138 }, { "Precision", 13705 }, { "Weapon Expertise", 30919 },
        { "Hack and Slash", 13960 }, { "Mutilate", 399956 }, { "Death Mark", 1316709 },
    },

    weights = {
        -- 1.0 = one point of Agility (1 attack power plus crit, dodge and armor);
        -- Strength gives 1 attack power; 1 weapon DPS = 14 attack power.
        ROLE = {
            -- Mutilate with daggers in both hands, Seal Fate
            ASSASSINATION = {
                AGILITY = 1.0, STRENGTH = 0.5, ATTACK_POWER = 0.5, DPS = 5.5,
                CRIT = 1.2, HIT = 1.5, HASTE = 0.8, MASTERY = 0.6, VERSATILITY = 0.6,
                STAMINA = 0.3, ARMOR = 0.005, RANGED_DPS = 0.1,
            },
            -- Sinister Strike: main hand weapon damage, Blade Flurry
            COMBAT = {
                AGILITY = 1.0, STRENGTH = 0.5, ATTACK_POWER = 0.5, DPS = 6.5,
                CRIT = 1.0, HIT = 1.6, HASTE = 0.9, MASTERY = 0.6, VERSATILITY = 0.6,
                STAMINA = 0.3, ARMOR = 0.005, RANGED_DPS = 0.1,
            },
            -- Backstab and Hemorrhage
            SUBTLETY = {
                AGILITY = 1.0, STRENGTH = 0.5, ATTACK_POWER = 0.5, DPS = 6.5,
                CRIT = 1.0, HIT = 1.4, HASTE = 0.7, MASTERY = 0.6, VERSATILITY = 0.6,
                STAMINA = 0.35, ARMOR = 0.005, RANGED_DPS = 0.1,
            },
        },

        QUESTING = {
            WEAPON_DPS = 7.0,         -- 1 weapon DPS = 14 attack power = 7 Agility (as attack power)
            STAMINA = 0.45,
            SPIRIT = 0.1,             -- health regeneration between pulls
            ARMOR = 0.006,
            LEGACY_STAMINA = 0.04,    -- Stamina +4% per rank of Thrill of Adventure (health back per kill)
        },

        Questing = function(spec, level)
            local Q = W.QUESTING
            return {
                AGILITY = 1.0, STRENGTH = 0.5, ATTACK_POWER = 0.5, DPS = Q.WEAPON_DPS,
                CRIT = 0.8, HIT = 0.6, HASTE = 0.6, MASTERY = 0.4, VERSATILITY = 0.5,
                STAMINA = Q.STAMINA * (1 + Q.LEGACY_STAMINA * W.LegacyRank()),
                SPIRIT = Q.SPIRIT, ARMOR = Q.ARMOR,
                DEFENSE = 0.1, DODGE = 0.3, PARRY = 0.15, RANGED_DPS = 0.2,
            }
        end,

        -- Talents (tree 1111), site values at max rank
        TALENTS = {
            LETHALITY   = { spell = 14128, ranks = 2 },                         -- ability crit damage bonus +20%
            SEAL_FATE   = { spell = 14186, ranks = 3, spec = "ASSASSINATION" }, -- crits add a combo point
            DUAL_WIELD_SPECIALIZATION = { spell = 13715, ranks = 2 },           -- off-hand damage +50%
            OPPORTUNITY = { spell = 14057, ranks = 5, spec = "SUBTLETY" },      -- Backstab, Ambush, Mutilate +20%
        },

        ApplyTalents = function(w, spec)
            local function T(name) return W.Talent(name, spec) end
            W.Mul(w, "CRIT", 1 + 0.12 * T("LETHALITY"))
            W.Mul(w, "CRIT", 1 + 0.20 * T("SEAL_FATE"))
            W.Mul(w, "DPS", 1 + 0.12 * T("DUAL_WIELD_SPECIALIZATION"))
            W.Mul(w, "DPS", 1 + 0.10 * T("OPPORTUNITY"))
        end,

        CAPS = {
            ASSASSINATION = { HIT = W.CAP.MELEE_HIT, HASTE = W.CAP.MELEE_HASTE },
            COMBAT        = { HIT = W.CAP.MELEE_HIT, HASTE = W.CAP.MELEE_HASTE },
            SUBTLETY      = { HIT = W.CAP.MELEE_HIT, HASTE = W.CAP.MELEE_HASTE },
        },

        SET_EFFECT_TEXTS = {
            { match = "Gouge", value = { ASSASSINATION = 2, COMBAT = 2, SUBTLETY = 2 } },
            { match = "Evasion", value = { ASSASSINATION = 2, COMBAT = 2, SUBTLETY = 2 } },
            { match = "Blind", value = { ASSASSINATION = 1, COMBAT = 1, SUBTLETY = 1 } },
        },
    },
})
