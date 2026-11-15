-- WOWClassHelper: Mage profile
--
-- Fields are explained in Classes/Priest.lua. New profile, not yet checked
-- in game. Forever specifics from https://classicwowforever.com/ (talents:
-- client build 1.60.1.70862; class guide and class changes, 15 Nov 2026):
--   - Arcane: Intellect matters most - each Arcane Blast stack gives 12% of
--     Intellect as spell damage, Arcane Wrath adds 5% of max mana
--   - Fire: crit is emphasized (Critical Mass, Incineration, Ignite)
--   - Ice Barrier absorbs 10% of spell power and adds Frost damage
local _, ns = ...
local W = ns.Weights

ns:RegisterClass("MAGE", {
    name = "Mage", plural = "Mages",
    mana = true,
    school = { id = 3, name = "Fire" },

    armor = { [1] = true },
    weapons = { [7] = true, [10] = true, [15] = true, [19] = true },   -- 1H swords, staves, daggers, wands
    dualWield = false,
    groupLabels = { ranged = "wands" },

    specs = {
        { key = "ARCANE", id = 237, retailIDs = { 62 }, name = "Arcane", short = "Arcane", role = "Damage",
          attack = "SPELL", icon = "Interface\\Icons\\Spell_Holy_MagicalSentry" },
        { key = "FIRE", id = 8, retailIDs = { 63 }, name = "Fire", short = "Fire", role = "Damage",
          attack = "SPELL", icon = "Interface\\Icons\\Spell_Fire_FireBolt02" },
        { key = "FROST", id = 6, retailIDs = { 64 }, name = "Frost", short = "Frost", role = "Damage",
          attack = "SPELL", icon = "Interface\\Icons\\Spell_Frost_FrostBolt02" },
    },
    tabOrder = { "ARCANE", "FIRE", "FROST" },
    defaultSpec = "FROST",
    aliases = { dps = "FROST", damage = "FROST" },

    sampleSpell = { 133, "Fireball" },
    debugTalents = {
        { "Precision", 29438 }, { "Arcane Meditation", 18462 }, { "Presence of Mind", 12043 },
        { "Ice Barrier", 11426 }, { "Combustion", 11129 }, { "Arcane Blast", 400574 },
    },

    weights = {
        -- 1.0 = one point of spell damage at full value
        ROLE = {
            ARCANE = {
                DAMAGE = 1.0, SHARE_ARCANE = 0.85, SHARE_FIRE = 0.1, SHARE_FROST = 0.05,
                HIT = 1.1, SPELL_HIT = 1.1, CRIT = 0.5, SPELL_CRIT = 0.5,
                HASTE = 0.7, MASTERY = 0.5, VERSATILITY = 0.5,
                INTELLECT = 0.55, SPIRIT = 0.2, MANA_REGENERATION = 1.1,
                STAMINA = 0.15, ARMOR = 0.001, WAND_DPS = 0.3,
            },
            FIRE = {
                DAMAGE = 1.0, SHARE_FIRE = 0.95, SHARE_FROST = 0.05,
                HIT = 1.1, SPELL_HIT = 1.1, CRIT = 0.6, SPELL_CRIT = 0.6,
                HASTE = 0.7, MASTERY = 0.5, VERSATILITY = 0.5,
                INTELLECT = 0.35, SPIRIT = 0.12, MANA_REGENERATION = 0.9,
                STAMINA = 0.15, ARMOR = 0.001, WAND_DPS = 0.3,
            },
            FROST = {
                DAMAGE = 1.0, SHARE_FROST = 0.95, SHARE_FIRE = 0.05,
                HIT = 1.1, SPELL_HIT = 1.1, CRIT = 0.45, SPELL_CRIT = 0.45,
                HASTE = 0.7, MASTERY = 0.5, VERSATILITY = 0.5,
                INTELLECT = 0.35, SPIRIT = 0.12, MANA_REGENERATION = 0.9,
                STAMINA = 0.2, ARMOR = 0.001, WAND_DPS = 0.3,
            },
        },
        ROLE_REGEN_SHARE = { ARCANE = 0.2, FIRE = 0.25, FROST = 0.25 },

        -- Mages level with spells and less wanding than Priests; conjured
        -- water means drinking more often. See Weights.CasterQuesting.
        QUESTING = {
            CAST_SHARE = 0.4,
            DAMAGE_PER_CAST_SECOND = 1 / 3.5,
            MANA_DAMAGE = 1.0,
            REGEN_SHARE = 0.5,
            DRINK_SECONDS = 200,
            WAND_SHARE_LOW = 0.35,
            WAND_SHARE_HIGH = 0.2,
            WAND_START_DELAY = 0.5,     -- assumed as for the Priest (site: since 15 Oct, VERIFY for Mages)
            WAND_SECONDS = 6,
            KILL_SECONDS = 35,
            SPIRIT_REGEN = 0.125,       -- classic Mage: 13 + Spirit / 4 every 2 sec
            MANA_PER_INTELLECT = 15,
            STAMINA = 0.55,
            HEALING = { ARCANE = 0, FIRE = 0, FROST = 0 },
        },

        Questing = function(spec, level)
            local schools
            if level < 10 then
                schools = { FIRE = 0.5, FROST = 0.4, ARCANE = 0.1 }   -- Fireball, Frostbolt, Arcane Missiles
            elseif spec == "ARCANE" then
                schools = { ARCANE = 0.5, FIRE = 0.3, FROST = 0.2 }
            elseif spec == "FIRE" then
                schools = { FIRE = 0.8, FROST = 0.15, ARCANE = 0.05 }
            else
                schools = { FROST = 0.8, FIRE = 0.15, ARCANE = 0.05 }
            end
            return W.CasterQuesting(spec, level, W.QUESTING, schools)
        end,

        -- Talents (tree 1112), site values at max rank
        TALENTS = {
            WAND_SPECIALIZATION = { spell = 6057,    ranks = 2 },  -- wand damage +25%
            ARCANE_MIND         = { spell = 11232,   ranks = 5 },  -- Intellect +10%, Arcane crit damage bonus +100%
            ARCANE_MEDITATION   = { spell = 18462,   ranks = 3 },  -- 50% of regeneration continues while casting
            ARCANE_BLAST        = { spell = 400574,  ranks = 1 },  -- each stack: 12% of Intellect as spell damage
            ARCANE_WRATH        = { spell = 1326079, ranks = 1 },  -- spell damage +5% of max mana
            ICE_SHARDS          = { spell = 11207,   ranks = 5 },  -- Frost crit damage bonus +100%
            IGNITE              = { spell = 11119,   ranks = 5 },  -- Fire crits burn for 40% more
            FIRE_POWER          = { spell = 11124,   ranks = 3 },  -- Fire damage +3% per Fire effect, up to 12%
        },

        ApplyTalents = function(w, spec, _, regenShare)
            local function T(name) return W.Talent(name, spec) end
            local arcane, fire, frost = w.SHARE_ARCANE or 0, w.SHARE_FIRE or 0, w.SHARE_FROST or 0
            W.Mul(w, "WAND_DPS", 1 + 0.25 * T("WAND_SPECIALIZATION"))
            W.RegenWhileCasting(w, 0.5 * T("ARCANE_MEDITATION"), regenShare)
            -- Arcane Blast (about one stack on average over all casts) and
            -- Arcane Wrath (15 mana per Intellect, a fifth of the casts)
            -- turn Intellect into spell damage
            local damage = w.DAMAGE or 0
            w.INTELLECT = w.INTELLECT + (0.12 * T("ARCANE_BLAST") + 0.15 * T("ARCANE_WRATH")) * damage * arcane
            W.Mul(w, "INTELLECT", 1 + 0.10 * T("ARCANE_MIND"))
            local critBonus = 1 + T("ARCANE_MIND") * arcane + T("ICE_SHARDS") * frost + 0.4 * T("IGNITE") * fire
            W.Mul(w, "CRIT", critBonus)
            W.Mul(w, "SPELL_CRIT", critBonus)
            W.SpellSchools(w, { FIRE = 1 + 0.09 * T("FIRE_POWER") })
        end,

        CAPS = {
            ARCANE = { HIT = W.CAP.SPELL_HIT, SPELL_HIT = W.CAP.SPELL_HIT, HASTE = W.CAP.SPELL_HASTE },
            FIRE   = { HIT = W.CAP.SPELL_HIT, SPELL_HIT = W.CAP.SPELL_HIT, HASTE = W.CAP.SPELL_HASTE },
            FROST  = { HIT = W.CAP.SPELL_HIT, SPELL_HIT = W.CAP.SPELL_HIT, HASTE = W.CAP.SPELL_HASTE },
        },

        SET_EFFECT_TEXTS = {
            { match = "Blink", value = { ARCANE = 2, FIRE = 2, FROST = 2 } },
            { match = "Evocation", value = { ARCANE = 3, FIRE = 2, FROST = 2 } },
            { match = "Arcane Intellect", value = { ARCANE = 1, FIRE = 1, FROST = 1 } },
        },
    },
})
