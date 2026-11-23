-- WOWClassHelper: Warlock profile
--
-- Fields are explained in Classes/Priest.lua. New profile, not yet checked
-- in game. Talent values from https://classicwowforever.com/talents/warlock/
-- (client build 1.60.1.70862, read 15 Nov 2026). Life Tap turns health into
-- mana, so Stamina is worth more and drinking is rare.
local _, ns = ...
local W = ns.Weights

ns:RegisterClass("WARLOCK", {
    name = "Warlock", plural = "Warlocks",
    mana = true,
    school = { id = 6, name = "Shadow" },

    armor = { [1] = true },
    weapons = { [7] = true, [10] = true, [15] = true, [19] = true },   -- 1H swords, staves, daggers, wands
    dualWield = false,
    groupLabels = { ranged = "wands" },

    -- mainExtra: Life Tap makes Stamina a main stat next to spell damage
    specs = {
        { key = "AFFLICTION", id = 355, retailIDs = { 265 }, name = "Affliction", short = "Affli", role = "Damage",
          attack = "SPELL", icon = "Interface\\Icons\\Spell_Shadow_DeathCoil", mainExtra = { "STAMINA" } },
        { key = "DEMONOLOGY", id = 354, retailIDs = { 266 }, name = "Demonology", short = "Demo", role = "Damage",
          attack = "SPELL", icon = "Interface\\Icons\\Spell_Shadow_Metamorphosis", mainExtra = { "STAMINA" } },
        { key = "DESTRUCTION", id = 593, retailIDs = { 267 }, name = "Destruction", short = "Destro", role = "Damage",
          attack = "SPELL", icon = "Interface\\Icons\\Spell_Shadow_RainOfFire", mainExtra = { "STAMINA" } },
    },
    tabOrder = { "AFFLICTION", "DEMONOLOGY", "DESTRUCTION" },
    defaultSpec = "AFFLICTION",
    aliases = { aff = "AFFLICTION", dps = "AFFLICTION", damage = "AFFLICTION" },

    sampleSpell = { 686, "Shadow Bolt" },
    debugTalents = {
        { "Suppression", 18174 }, { "Shadow Mastery", 18271 }, { "Soul Link", 19028 },
        { "Conflagrate", 1293817 }, { "Wrack", 1316697 }, { "Demonic Knowledge", 412732 },
    },

    weights = {
        -- 1.0 = one point of spell damage at full value
        ROLE = {
            -- DoTs and drains: Shadow, few crits
            AFFLICTION = {
                DAMAGE = 1.0, SHARE_SHADOW = 0.95, SHARE_FIRE = 0.05,
                HIT = 1.1, SPELL_HIT = 1.1, CRIT = 0.3, SPELL_CRIT = 0.3,
                HASTE = 0.6, MASTERY = 0.5, VERSATILITY = 0.5,
                INTELLECT = 0.3, SPIRIT = 0.1, MANA_REGENERATION = 0.6,
                STAMINA = 0.4, ARMOR = 0.001, WAND_DPS = 0.3,
            },
            DEMONOLOGY = {
                DAMAGE = 1.0, SHARE_SHADOW = 0.85, SHARE_FIRE = 0.15,
                HIT = 1.1, SPELL_HIT = 1.1, CRIT = 0.35, SPELL_CRIT = 0.35,
                HASTE = 0.6, MASTERY = 0.5, VERSATILITY = 0.5,
                INTELLECT = 0.3, SPIRIT = 0.1, MANA_REGENERATION = 0.6,
                STAMINA = 0.45, ARMOR = 0.001, WAND_DPS = 0.3,
            },
            -- Shadow Bolt, Incinerate, Conflagrate: crits with Ruin
            DESTRUCTION = {
                DAMAGE = 1.0, SHARE_SHADOW = 0.6, SHARE_FIRE = 0.4,
                HIT = 1.1, SPELL_HIT = 1.1, CRIT = 0.55, SPELL_CRIT = 0.55,
                HASTE = 0.7, MASTERY = 0.5, VERSATILITY = 0.5,
                INTELLECT = 0.3, SPIRIT = 0.1, MANA_REGENERATION = 0.6,
                STAMINA = 0.35, ARMOR = 0.001, WAND_DPS = 0.3,
            },
        },
        ROLE_REGEN_SHARE = { AFFLICTION = 0.3, DEMONOLOGY = 0.3, DESTRUCTION = 0.25 },

        -- Warlocks level with DoTs, the pet and the wand. See Weights.CasterQuesting.
        QUESTING = {
            CAST_SHARE = 0.35,
            DAMAGE_PER_CAST_SECOND = 1 / 3.5,
            MANA_DAMAGE = 1.0,
            REGEN_SHARE = 0.55,
            DRINK_SECONDS = 360,        -- Life Tap: drinking is rare
            WAND_SHARE_LOW = 0.4,
            WAND_SHARE_HIGH = 0.25,
            WAND_START_DELAY = 0.5,     -- assumed as for the Priest (site: since 15 Oct, VERIFY for Warlocks)
            WAND_SECONDS = 8,
            KILL_SECONDS = 40,
            SPIRIT_REGEN = 0.125,       -- classic Warlock: 8 + Spirit / 4 every 2 sec
            MANA_PER_INTELLECT = 15,
            STAMINA = 0.75,             -- Life Tap turns health into mana
            HEALING = { AFFLICTION = 0, DEMONOLOGY = 0, DESTRUCTION = 0 },
        },

        Questing = function(spec, level)
            local schools
            if level < 10 then
                schools = { SHADOW = 0.6, FIRE = 0.4 }    -- Shadow Bolt and Immolate
            elseif spec == "DESTRUCTION" then
                schools = { SHADOW = 0.6, FIRE = 0.4 }
            elseif spec == "DEMONOLOGY" then
                schools = { SHADOW = 0.8, FIRE = 0.2 }
            else
                schools = { SHADOW = 0.9, FIRE = 0.1 }
            end
            return W.CasterQuesting(spec, level, W.QUESTING, schools)
        end,

        -- Talents (tree 1116), site values at max rank
        TALENTS = {
            SHADOW_MASTERY    = { spell = 18271,  ranks = 5 },  -- Shadow damage +10%
            DEMONIC_EMBRACE   = { spell = 18697,  ranks = 5 },  -- total Stamina +15%
            FEL_VITALITY      = { spell = 18731,  ranks = 3 },  -- max mana +15%
            IMPROVED_LIFE_TAP = { spell = 18182,  ranks = 2 },  -- Life Tap mana +20%
            RUIN              = { spell = 17959,  ranks = 5 },  -- Destruction crit damage bonus +100%
            PANDEMIC          = { spell = 427712, ranks = 3 },  -- DoT and drain crit damage bonus +100%
        },

        ApplyTalents = function(w, spec)
            local function T(name) return W.Talent(name, spec) end
            W.Mul(w, "STAMINA", (1 + 0.15 * T("DEMONIC_EMBRACE")) * (1 + 0.10 * T("IMPROVED_LIFE_TAP")))
            W.Mul(w, "INTELLECT", 1 + 0.15 * T("FEL_VITALITY"))
            local critBonus = 1 + 0.8 * T("RUIN") + 0.8 * T("PANDEMIC")
            W.Mul(w, "CRIT", critBonus)
            W.Mul(w, "SPELL_CRIT", critBonus)
            W.SpellSchools(w, { SHADOW = 1 + 0.10 * T("SHADOW_MASTERY") })
        end,

        CAPS = {
            AFFLICTION  = { HIT = W.CAP.SPELL_HIT, SPELL_HIT = W.CAP.SPELL_HIT, HASTE = W.CAP.SPELL_HASTE },
            DEMONOLOGY  = { HIT = W.CAP.SPELL_HIT, SPELL_HIT = W.CAP.SPELL_HIT, HASTE = W.CAP.SPELL_HASTE },
            DESTRUCTION = { HIT = W.CAP.SPELL_HIT, SPELL_HIT = W.CAP.SPELL_HIT, HASTE = W.CAP.SPELL_HASTE },
        },

        SET_EFFECT_TEXTS = {
            { match = "Immolate", value = { AFFLICTION = 3, DEMONOLOGY = 3, DESTRUCTION = 5 } },
            { match = "Corruption", value = { AFFLICTION = 5, DEMONOLOGY = 3, DESTRUCTION = 2 } },
            { match = "Death Coil", value = { AFFLICTION = 2, DEMONOLOGY = 2, DESTRUCTION = 2 } },
            { match = "Life Tap", value = { AFFLICTION = 2, DEMONOLOGY = 2, DESTRUCTION = 2 } },
        },
    },
})
