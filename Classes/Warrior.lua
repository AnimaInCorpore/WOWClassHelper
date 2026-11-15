-- WOWClassHelper: Warrior profile
--
-- Fields are explained in Classes/Priest.lua. New profile, not yet checked
-- in game: the weights are classic-style estimates adjusted to what
-- https://classicwowforever.com/ says about Forever (talents: client build
-- 1.60.1.70862; class changes and weapon guide read 15 Nov 2026):
--   - Whirlwind hits with both weapons for every Warrior (favors dual wield)
--   - basic-attack crits give 100% more Rage (crit is worth more)
--   - Arms levels with the slowest two-hander; the weapon guide counts
--     14 attack power per weapon DPS and prefers slower main hands
local _, ns = ...
local W = ns.Weights

ns:RegisterClass("WARRIOR", {
    name = "Warrior", plural = "Warriors",
    mana = false,

    -- Cloth to mail, plate from 40, shields; every weapon but wands
    -- (polearms from 20, site)
    armor = { [1] = true, [2] = true, [3] = true, [4] = 40, [6] = true },
    weapons = {
        [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = 20, [7] = true,
        [8] = true, [10] = true, [13] = true, [15] = true, [16] = true, [18] = true,
    },
    dualWield = 20,   -- Dual Wield from the trainer at level 20 (classic)
    groupLabels = { offhand = "shields & off hands" },

    specs = {
        { key = "ARMS", id = 26, retailIDs = { 71 }, name = "Arms", short = "Arms", role = "Damage",
          attack = "MELEE", icon = "Interface\\Icons\\Ability_Rogue_Eviscerate" },
        { key = "FURY", id = 256, retailIDs = { 72 }, name = "Fury", short = "Fury", role = "Damage",
          attack = "MELEE", icon = "Interface\\Icons\\Ability_Warrior_InnerRage" },
        { key = "PROTECTION", id = 257, retailIDs = { 73 }, name = "Protection", short = "Prot", role = "Tank",
          attack = "MELEE", icon = "Interface\\Icons\\INV_Shield_06" },
    },
    tabOrder = { "ARMS", "FURY", "PROTECTION" },
    defaultSpec = "ARMS",
    aliases = { tank = "PROTECTION", dps = "ARMS", damage = "ARMS", dw = "FURY" },

    sampleSpell = { 78, "Heroic Strike" },
    debugTalents = {
        { "Cruelty", 12320 }, { "Anticipation", 12297 }, { "Shield Specialization", 12298 },
        { "Mortal Strike", 12294 }, { "Bloodthirst", 23881 }, { "Shield Slam", 23922 },
    },

    weights = {
        -- 1.0 = one point of Strength (2 attack power); 1 weapon DPS = 14 attack
        -- power = 7 Strength. Tank: 1.0 = one point of Stamina.
        ROLE = {
            -- Two-hander: Mortal Strike, Overpower and Slam use weapon damage
            ARMS = {
                STRENGTH = 1.0, ATTACK_POWER = 0.5, DPS = 7.5, AGILITY = 0.65,
                CRIT = 1.0, HIT = 1.4, HASTE = 0.7, MASTERY = 0.6, VERSATILITY = 0.7,
                STAMINA = 0.3, ARMOR = 0.01, RANGED_DPS = 0.1,
            },
            -- Dual wield: both weapons count; crits give double Rage
            FURY = {
                STRENGTH = 1.0, ATTACK_POWER = 0.5, DPS = 6.0, AGILITY = 0.7,
                CRIT = 1.2, HIT = 1.6, HASTE = 0.8, MASTERY = 0.6, VERSATILITY = 0.7,
                STAMINA = 0.3, ARMOR = 0.01, RANGED_DPS = 0.1,
            },
            -- Shield tank: Shield Slam scales with block value
            PROTECTION = {
                STAMINA = 1.0,
                DEFENSE = 1.2, DODGE = 0.9, PARRY = 0.8, BLOCK = 0.7, BLOCK_VALUE = 0.6, ARMOR = 0.06,
                STRENGTH = 0.6, AGILITY = 0.6, ATTACK_POWER = 0.3,
                HIT = 0.7, CRIT = 0.3, HASTE = 0.3, MASTERY = 0.4, VERSATILITY = 0.5,
                DPS = 1.5, RANGED_DPS = 0.05,
            },
        },

        -- Warriors level in melee like Paladins, without mana
        QUESTING = {
            WEAPON_DPS = 7.0,         -- 1 weapon DPS = 14 attack power = 7 Strength
            AGILITY_LOW = 0.3,        -- crit and armor from Agility at level 10 ...
            AGILITY_HIGH = 0.55,      -- ... and at max level
            STAMINA = 0.45,           -- surviving pulls
            SPIRIT = 0.1,             -- health regeneration between pulls
            ARMOR = 0.008,
            LEGACY_STAMINA = 0.04,    -- Stamina +4% per rank of Thrill of Adventure (health back per kill)
        },

        Questing = function(spec, level)
            local Q = W.QUESTING
            local w = {
                STRENGTH = 1.0, ATTACK_POWER = 0.5, DPS = Q.WEAPON_DPS,
                AGILITY = W.Lerp(Q.AGILITY_LOW, Q.AGILITY_HIGH, W.Clamp((level - 10) / 50)),
                CRIT = 0.8, HIT = 0.6, HASTE = 0.5, MASTERY = 0.4, VERSATILITY = 0.5,
                STAMINA = Q.STAMINA * (1 + Q.LEGACY_STAMINA * W.LegacyRank()),
                SPIRIT = Q.SPIRIT, ARMOR = Q.ARMOR,
                DEFENSE = 0.1, DODGE = 0.25, PARRY = 0.2, BLOCK = 0.1, BLOCK_VALUE = 0.05,
                RANGED_DPS = 0.3,     -- pulling with a bow or gun
            }
            if spec == "ARMS" then
                w.DPS = Q.WEAPON_DPS + 0.5           -- site: slow two-handers while leveling
            elseif spec == "PROTECTION" then
                w.STAMINA, w.DEFENSE, w.BLOCK, w.BLOCK_VALUE, w.ARMOR = 0.6, 0.2, 0.2, 0.15, 0.012
            end
            return w
        end,

        -- Talents (tree 1117), site values at max rank
        TALENTS = {
            TWO_HANDED_WEAPON = { spell = 12163, ranks = 3, spec = "ARMS" },        -- two-hander damage +6%
            IMPALE            = { spell = 16493, ranks = 2 },                       -- ability crit damage bonus +20%
            DEEP_WOUNDS       = { spell = 12834, ranks = 3 },                       -- crits bleed 60% of weapon damage
            FLURRY            = { spell = 12319, ranks = 3 },                       -- +30% attack speed after a crit
            DUAL_WIELD_SPECIALIZATION = { spell = 23584, ranks = 5, spec = "FURY" }, -- off-hand damage +25%
            BASTION           = { spell = 16538, ranks = 5, spec = "PROTECTION" },  -- all damage +10% with a shield
        },

        ApplyTalents = function(w, spec)
            local function T(name) return W.Talent(name, spec) end
            local damage = (1 + 0.06 * T("TWO_HANDED_WEAPON")) * (1 + 0.10 * T("BASTION"))
            for _, stat in ipairs({ "STRENGTH", "ATTACK_POWER", "DPS", "AGILITY", "CRIT", "HIT", "HASTE" }) do
                W.Mul(w, stat, damage)
            end
            W.Mul(w, "CRIT", 1 + 0.10 * T("IMPALE"))       -- abilities are about half the damage
            W.Mul(w, "CRIT", 1 + 0.15 * T("DEEP_WOUNDS"))
            W.Mul(w, "CRIT", 1 + 0.15 * T("FLURRY"))
            W.Mul(w, "DPS", 1 + 0.08 * T("DUAL_WIELD_SPECIALIZATION"))  -- off hand ~1/3 of white damage
        end,

        CAPS = {
            ARMS       = { HIT = W.CAP.MELEE_HIT, HASTE = W.CAP.MELEE_HASTE },
            FURY       = { HIT = W.CAP.MELEE_HIT, HASTE = W.CAP.MELEE_HASTE },
            PROTECTION = { HIT = W.CAP.MELEE_HIT, DEFENSE = W.CAP.DEFENSE, HASTE = W.CAP.MELEE_HASTE },
        },

        SET_EFFECT_TEXTS = {
            { match = "Intercept", value = { ARMS = 2, FURY = 2, PROTECTION = 2 } },
            { match = "rage cost of Whirlwind", value = { ARMS = 2, FURY = 3, PROTECTION = 1 } },
        },
    },
})
