-- WOWClassHelper: Priest profile (from WOWPriest)
--
-- This is the reference profile; the other classes use the same fields.
-- Values marked "site" were cross-checked with the talent pages of
-- https://classicwowforever.com/talents/priest/ (client build 1.60.1.70862,
-- read 8 Nov 2026), which is newer than the API data in Data/Talents.lua.
local _, ns = ...
local W = ns.Weights

ns:RegisterClass("PRIEST", {
    name = "Priest", plural = "Priests",
    mana = true,                          -- gets the mana bar with the five-second-rule timer
    school = { id = 6, name = "Shadow" }, -- spell damage shown in /wch stats

    -- What the class can ever use: armor and weapon subclasses -> true, or the
    -- level from which they can be learned. Miscellaneous armor (rings,
    -- necks, trinkets, cloaks, held-in-off-hand items) is always allowed.
    armor = { [1] = true },                                          -- cloth
    weapons = { [4] = true, [10] = true, [15] = true, [19] = true }, -- 1H maces, staves, daggers, wands
    dualWield = false,
    groupLabels = { ranged = "wands" },

    -- Specs in talent-window order. id: Forever specialization ID (Data/Talents.lua);
    -- retailIDs: Retail IDs, also accepted from the spec API. short: name in
    -- the tooltip's other-specs line and for commands. attack: which combat
    -- ratings percent set bonuses use (SPELL, MELEE or RANGED).
    -- Discipline and Holy are both healers, so the UI shows spec names first
    -- and the role in brackets.
    specs = {
        { key = "DISCIPLINE", id = 613, retailIDs = { 256 }, name = "Discipline", short = "Disc", role = "Healer",
          attack = "SPELL", icon = "Interface\\Icons\\Spell_Holy_PowerWordShield" },
        { key = "HOLY", id = 56, retailIDs = { 257 }, name = "Holy", short = "Holy", role = "Healer",
          attack = "SPELL", icon = "Interface\\Icons\\Spell_Holy_GreaterHeal" },
        { key = "SHADOW", id = 78, retailIDs = { 258 }, name = "Shadow", short = "Shadow", role = "Damage",
          attack = "SPELL", icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain" },
    },
    tabOrder = { "DISCIPLINE", "HOLY", "SHADOW" },   -- classic talent tabs
    defaultSpec = "SHADOW",                           -- no talent points yet: level as damage dealer
    aliases = { heal = "HOLY", healer = "HOLY", sp = "SHADOW", damage = "SHADOW", dps = "SHADOW" },

    -- For /wch debug
    sampleSpell = { 585, "Smite" },
    debugTalents = {
        { "Meditation", 14521 }, { "Spiritual Guidance", 14901 }, { "Shadow Focus", 15260 },
        { "Shadowform", 15473 }, { "Spirit Tap", 15270 }, { "Wand Specialization", 14524 },
        { "Inner Focus", 14751 }, { "Power Infusion", 10060 }, { "Vampiric Embrace", 15286 },
    },

    weights = {
        -- Priest-specific stat keys:
        --   HEALING        "+healing" items (SPELL_HEALING_DONE)
        --   SHADOW_DAMAGE  "+Shadow damage" items (BONUS_STAT_SHADOW_DAMAGE_DONE)
        --   HOLY_DAMAGE    "+Holy damage" items (Smite, Holy Fire)
        --   WAND_DPS       damage per second of a wand. Melee weapon DPS (DPS) is
        --                  worth nothing: Priests don't fight in melee.
        -- 1.0 = one point of spell damage or healing at full value.

        -- Role at max level, before talents. Item ratings in Forever: 14 crit
        -- rating and 10 hit rating are 1% at 60.
        ROLE = {
            -- Healer: shields, Penance and Power Infusion
            DISCIPLINE = {
                HEALING = 1.0, DAMAGE = 0.1, SHARE_HOLY = 0.5, SHARE_SHADOW = 0.5,
                MANA_REGENERATION = 2.0, INTELLECT = 0.8, SPIRIT = 0.35,
                CRIT = 0.5, SPELL_CRIT = 0.5, HASTE = 0.6, MASTERY = 0.4, VERSATILITY = 0.4,
                HIT = 0.05, STAMINA = 0.15, ARMOR = 0.002, WAND_DPS = 0.3,
            },
            -- Healer: big heals, Prayer of Mending
            HOLY = {
                HEALING = 1.0, DAMAGE = 0.1, SHARE_HOLY = 0.7, SHARE_SHADOW = 0.3,
                MANA_REGENERATION = 2.0, INTELLECT = 0.7, SPIRIT = 0.35,
                CRIT = 0.6, SPELL_CRIT = 0.6, HASTE = 0.6, MASTERY = 0.4, VERSATILITY = 0.4,
                HIT = 0.05, STAMINA = 0.15, ARMOR = 0.002, WAND_DPS = 0.3,
            },
            -- Damage: Shadow spells, hit capped against raid bosses
            SHADOW = {
                DAMAGE = 1.0, SHARE_HOLY = 0.05, SHARE_SHADOW = 0.95, HEALING = 0.05,
                HIT = 1.1, SPELL_HIT = 1.1,
                CRIT = 0.4, SPELL_CRIT = 0.4, HASTE = 0.7, MASTERY = 0.5, VERSATILITY = 0.5,
                MANA_REGENERATION = 1.0, INTELLECT = 0.4, SPIRIT = 0.2,
                STAMINA = 0.25, ARMOR = 0.002, WAND_DPS = 0.5,
            },
        },

        -- Share of the time the five-second rule is not running in the role at
        -- max level (raid healing: rarely), for Meditation's value.
        ROLE_REGEN_SHARE = { DISCIPLINE = 0.25, HOLY = 0.25, SHADOW = 0.35 },

        -- Questing: a Priest levels alone with damage spells and the wand. The
        -- values follow from these assumptions (change them here if your play
        -- differs), see Weights.CasterQuesting:
        QUESTING = {
            CAST_SHARE = 0.3,           -- share of all time spent casting damage spells
            DAMAGE_PER_CAST_SECOND = 1 / 3.5, -- damage per spell power per second of casting
            MANA_DAMAGE = 1.0,          -- damage a point of mana buys (Smite, Mind Blast)
            REGEN_SHARE = 0.6,          -- share of time outside the five-second rule (wanding counts)
            DRINK_SECONDS = 240,        -- time between drinks: how often the mana pool is refilled
            WAND_SHARE_LOW = 0.5,       -- share of fight time spent wanding up to level 20 ...
            WAND_SHARE_HIGH = 0.35,     -- ... and at max level
            WAND_START_DELAY = 0.5,     -- site: since 15 Oct you stand still 0.5 sec before the wand fires
            WAND_SECONDS = 8,           -- wanding per fight, over which that delay is lost
            KILL_SECONDS = 40,          -- one pull including rest, for the Legacy perk Thrill of Adventure
            SPIRIT_REGEN = 0.125,       -- mana per second per Spirit outside the five-second rule
                                        -- (classic Priest: 13 + Spirit / 4 every 2 sec)
            MANA_PER_INTELLECT = 15,
            STAMINA = 0.5,              -- surviving pulls, not derived
            HEALING = { DISCIPLINE = 0.5, HOLY = 0.5, SHADOW = 0.2 },   -- self-heals, dungeon healing
        },

        Questing = function(spec, level)
            local holy
            if spec == "SHADOW" then
                holy = level < 10 and 0.6 or 0.15     -- Smite early, then Mind Blast, SW:P, Mind Flay
            else
                holy = level < 10 and 0.7 or 0.45     -- Smite and Holy Fire next to SW:P and Mind Blast
            end
            return W.CasterQuesting(spec, level, W.QUESTING, { HOLY = holy, SHADOW = 1 - holy })
        end,

        -- Talents that change what a stat is worth, with their Forever texts
        -- at max rank (talent tree 1114). Values scale with the learned ranks.
        -- Site-checked (8 Nov 2026): same values.
        TALENTS = {
            WAND_SPECIALIZATION = { spell = 14524,   ranks = 2 },  -- wand damage +13% / +25%
            POWER_IN_LIGHT      = { spell = 1309969, ranks = 5 },  -- Smite and Penance +10% on targets with Holy Fire or SW:P
            MENTAL_STRENGTH     = { spell = 18551,   ranks = 5 },  -- total Intellect +10%
            MEDITATION          = { spell = 14521,   ranks = 3 },  -- 50% of regeneration continues while casting
            SPIRIT_TAP          = { spell = 15270,   ranks = 5 },  -- Spirit +100% for 15 sec after a kill
            DARK_INSPIRATION    = { spell = 1326159, ranks = 5 },  -- Spirit +15% for 10 sec after Mind Blast / Mind Flay
            SPIRITUAL_GUIDANCE  = { spell = 14901,   ranks = 5 },  -- healing +25% and damage +8% of total Spirit
            SPIRITUAL_HEALING   = { spell = 14898,   ranks = 3 },  -- healing +10%
            SEARING_LIGHT       = { spell = 14909,   ranks = 2 },  -- Holy damage +5%
            DARKNESS            = { spell = 15259,   ranks = 5 },  -- Shadow damage +10%
            SHADOW_WEAVING      = { spell = 15257,   ranks = 3 },  -- Shadow damage taken +2% per stack, up to 5
            SHADOWFORM          = { spell = 15473,   ranks = 1 },  -- Shadow damage +10%, Shadow crit damage bonus +100%
        },

        -- roleShare: 0 while questing at level 10 .. 1 at max level;
        -- regenShare: time outside the five-second rule at this mix.
        ApplyTalents = function(w, spec, roleShare, regenShare)
            local function T(name) return W.Talent(name, spec) end
            w.WAND_DPS = w.WAND_DPS * (1 + 0.25 * T("WAND_SPECIALIZATION"))
            w.INTELLECT = w.INTELLECT * (1 + 0.10 * T("MENTAL_STRENGTH"))
            -- Regeneration while casting adds the part of the time inside the rule
            W.RegenWhileCasting(w, 0.5 * T("MEDITATION"), regenShare)
            -- Spirit Tap needs kills: up about half the time while questing
            w.SPIRIT = w.SPIRIT * (1 + 0.6 * T("SPIRIT_TAP") * (1 - roleShare))
            w.SPIRIT = w.SPIRIT * (1 + 0.15 * 0.6 * T("DARK_INSPIRATION"))

            local shadowShare = w.SHARE_SHADOW or 0
            local holy = (1 + 0.05 * T("SEARING_LIGHT")) * (1 + 0.10 * T("POWER_IN_LIGHT"))
            local shadow = (1 + 0.10 * T("DARKNESS")) * (1 + 0.10 * T("SHADOW_WEAVING"))
                * (1 + 0.10 * T("SHADOWFORM"))
            w.HEALING = w.HEALING * (1 + 0.10 * T("SPIRITUAL_HEALING"))
            W.SpellSchools(w, { HOLY = holy, SHADOW = shadow })
            -- Shadowform doubles the crit bonus of Shadow spells
            local critBonus = 1 + T("SHADOWFORM") * shadowShare
            w.CRIT, w.SPELL_CRIT = w.CRIT * critBonus, w.SPELL_CRIT * critBonus
            -- Spiritual Guidance turns Spirit into healing and damage
            w.SPIRIT = w.SPIRIT + T("SPIRITUAL_GUIDANCE") * (0.25 * w.HEALING + 0.08 * w.SPELL_DAMAGE)
        end,

        -- Caps per spec (see Core/Weights.lua). Forever items give generic
        -- HIT_RATING; older data may say spell hit.
        CAPS = {
            DISCIPLINE = { HASTE = W.CAP.SPELL_HASTE },
            HOLY       = { HASTE = W.CAP.SPELL_HASTE },
            SHADOW     = { HIT = W.CAP.SPELL_HIT, SPELL_HIT = W.CAP.SPELL_HIT, HASTE = W.CAP.SPELL_HASTE },
        },

        -- Value of set bonus effects the text parser can't rate (procs etc.),
        -- per spec: SET_EFFECTS[setID][requiredCount] = { SPEC = score points }
        SET_EFFECTS = {
            -- Vestments of Faith (Naxxramas)
            [525] = {
                [2] = { DISCIPLINE = 6,  HOLY = 8,  SHADOW = 0 },   -- Renew costs 12% less mana
                [4] = { DISCIPLINE = 12, HOLY = 15, SHADOW = 0 },   -- Armor of Faith on Greater Heal crits
                [6] = { DISCIPLINE = 3,  HOLY = 3,  SHADOW = 0 },   -- less threat from healing
                [8] = { DISCIPLINE = 20, HOLY = 20, SHADOW = 8 },   -- Epiphany: +24 mana regen for 30 sec
            },
            -- Vestments of the Virtuous (dungeon set)
            [514] = {
                [4] = { DISCIPLINE = 3, HOLY = 3, SHADOW = 3 },     -- absorb shield proc when struck
            },
            -- Garments of the Oracle (Temple of Ahn'Qiraj)
            [507] = {
                [3] = { DISCIPLINE = 4, HOLY = 4,  SHADOW = 0 },    -- heals on others also heal you
                [5] = { DISCIPLINE = 8, HOLY = 10, SHADOW = 0 },    -- Renew lasts 3 sec longer
            },
            -- Confessor's Raiment (Zul'Gurub)
            [480] = {
                [3] = { DISCIPLINE = 1, HOLY = 1, SHADOW = 0 },     -- Smite and Holy Fire range
                [5] = { DISCIPLINE = 1, HOLY = 1, SHADOW = 1 },     -- faster Mind Control
            },
            -- Finery of Infinite Wisdom (Ruins of Ahn'Qiraj)
            [508] = {
                [3] = { DISCIPLINE = 1, HOLY = 0, SHADOW = 10 },    -- Shadow Word: Pain +5% damage
            },
        },

        -- Effects shared by many sets (PvP sets), matched by plain text after SET_EFFECTS
        SET_EFFECT_TEXTS = {
            { match = "Psychic Scream", value = { DISCIPLINE = 2, HOLY = 2, SHADOW = 2 } },
        },
    },
})
