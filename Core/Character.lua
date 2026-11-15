-- WOWClassHelper: the player's current gear, stat totals and set pieces
--
-- Totals are built from the stats of the equipped items, so they use the same
-- units as item stats. Capped stats (hit, defense, haste) are measured with
-- the character sheet's values instead, so talents and the rating-to-percent
-- conversion of the current level are included.
local _, ns = ...

local Character = ns:RegisterModule("Character", {
    slots = {},      -- slotID -> item info
    totals = {},     -- stat -> sum over equipped gear
    sets = {},       -- setID -> number of equipped pieces
    api = {},        -- raw character sheet values (for display)
    ratings = {},    -- "CR_HIT_SPELL" -> { ratio, bonus, estimated }
    modifiers = {},  -- "GetSpellHitModifier" -> percent (or skill) from talents/buffs
    dirty = true,
})
ns.Character = Character

Character.SLOT_IDS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }

local function AddStats(totals, stats, sign)
    for stat, value in pairs(stats) do
        totals[stat] = (totals[stat] or 0) + value * (sign or 1)
    end
end

local function SafeCall(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, a, b, c = pcall(func, ...)
    if not ok then return nil end
    return a, b, c
end

-- Rating conversion -------------------------------------------------------

-- Percent per rating point from Weights.RATING_PER_PERCENT, scaled to level
local function EstimateRatio(name)
    local per = ns.Weights.RATING_PER_PERCENT[name]
    if not per then return nil end
    local level = math.min(math.max(ns.Spec.GetLevel(), 10), 60)
    return 1 / (per * (level - 8) / 52)
end

-- Reads one combat rating from the client: current rating, its percent
-- bonus and the conversion ratio at the current level.
local function ReadRating(name)
    local cr = _G[name]
    if type(cr) ~= "number" then return nil end
    local rating = ns.Num(SafeCall(GetCombatRating, cr)) or 0
    local bonus = ns.Num(SafeCall(GetCombatRatingBonus, cr)) or 0

    local ratio
    -- Works even without any rating on gear
    local per100 = ns.Num(SafeCall(GetCombatRatingBonusForCombatRatingValue, cr, 100))
    if per100 and per100 > 0 then
        ratio = per100 / 100
    elseif rating > 0 and bonus > 0 then
        ratio = bonus / rating
    end
    if ratio then
        return { ratio = ratio, bonus = bonus }
    end
    local estimate = EstimateRatio(name)
    if estimate then
        return { ratio = estimate, bonus = rating * estimate, estimated = true }
    end
    return nil
end

-- Percent (or defense skill) from sources other than rating, for the
-- `modifier` of a cap definition. Usually a client API function;
-- "UnitDefenseBonus" is the character sheet's defense bonus minus the part
-- that comes from defense rating.
local function ReadModifier(name, ratings)
    if name == "UnitDefenseBonus" then
        local _, bonus = SafeCall(UnitDefense, "player")
        bonus = ns.Num(bonus)
        if not bonus then return 0 end
        local r = ratings.CR_DEFENSE_SKILL
        return math.max(0, bonus - (r and r.bonus or 0))
    end
    return ns.Num(SafeCall(_G[name])) or 0
end

-- Character sheet ---------------------------------------------------------

function Character:ReadApiStats()
    -- In combat values may be secret; keep the last snapshot instead.
    if InCombatLockdown() then return end
    local api = {}

    for i, stat in ipairs({ "STRENGTH", "AGILITY", "STAMINA", "INTELLECT", "SPIRIT" }) do
        local _, effective = SafeCall(UnitStat, "player", i)
        api[stat] = ns.Num(effective)
    end

    local _, effectiveArmor = SafeCall(UnitArmor, "player")
    api.ARMOR = ns.Num(effectiveArmor)
    local defenseBase, defenseBonus = SafeCall(UnitDefense, "player")
    api.DEFENSE_BASE = ns.Num(defenseBase)
    api.DEFENSE_BONUS = ns.Num(defenseBonus)
    api.HIT = ns.Num(SafeCall(GetHitModifier))
    api.MANA = ns.Num(SafeCall(UnitPowerMax, "player", Enum.PowerType and Enum.PowerType.Mana or 0))
    local school = ns.class and ns.class.school
    api.SCHOOL_POWER = school and ns.Num(SafeCall(GetSpellBonusDamage, school.id))
    api.HEALING_POWER = ns.Num(SafeCall(GetSpellBonusHealing))

    -- Mana per second outside / inside the five-second rule
    local regenOut, regenCasting = SafeCall(GetManaRegen)
    api.REGEN_OUT = ns.Num(regenOut)
    api.REGEN_CASTING = ns.Num(regenCasting)

    self.api = api

    -- Rating -> percent conversion at the current level, plus percent from
    -- talents and buffs for capped stats
    local ratings, modifiers = {}, {}
    local function addRating(name)
        if name and not ratings[name] then ratings[name] = ReadRating(name) end
    end
    for name in pairs(ns.Weights.RATING_PER_PERCENT) do addRating(name) end
    for _, name in ipairs(ns.Weights.READ_RATINGS) do addRating(name) end
    for _, specCaps in pairs(ns.Weights.CAPS) do
        for _, def in pairs(specCaps) do addRating(def.rating) end
    end
    for _, specCaps in pairs(ns.Weights.CAPS) do
        for _, def in pairs(specCaps) do
            if def.modifier and modifiers[def.modifier] == nil then
                modifiers[def.modifier] = ReadModifier(def.modifier, ratings)
            end
        end
    end
    self.ratings = ratings
    self.modifiers = modifiers
end

function Character:Refresh()
    wipe(self.slots)
    wipe(self.totals)
    wipe(self.sets)
    local pending = false

    for _, slot in ipairs(self.SLOT_IDS) do
        local link = GetInventoryItemLink("player", slot)
        if link then
            local info = ns.ItemData.Parse(link)
            if info then
                self.slots[slot] = info
                AddStats(self.totals, info.stats)
                if info.setID then
                    self.sets[info.setID] = (self.sets[info.setID] or 0) + 1
                end
            else
                pending = true -- item data not cached yet; retry later
            end
        end
    end

    self:ReadApiStats()
    self.dirty = pending
    self.version = (self.version or 0) + 1
end

function Character:Get()
    if self.dirty then self:Refresh() end
    return self
end

-- Current total of a stat over the equipped gear
function Character:Total(stat)
    self:Get()
    return self.totals[stat] or 0
end

-- Rating conversion for a combat rating constant name, e.g. "CR_HIT_SPELL":
-- { ratio = percent per rating point, bonus = current percent from rating,
--   estimated = true when the client gave no conversion }. nil if unknown.
function Character:Rating(name)
    self:Get()
    if self.ratings[name] then return self.ratings[name] end
    local estimate = EstimateRatio(name)
    return estimate and { ratio = estimate, bonus = 0, estimated = true } or nil
end

-- Current total and cap of a capped stat, both in item stat units, at the
-- current level. Returns nil if the stat has no cap for this spec/level.
--   rating: converts with the rating->% ratio of the current level and adds
--           percent from talents/buffs (def.modifier)
--   percent: no conversion known, item stats are taken as percent
function Character:CapUnits(spec, stat)
    self:Get()
    local capValue, def = ns.Weights.GetCap(spec, stat)
    if not capValue then return nil end
    local modifier = def.modifier and self.modifiers[def.modifier] or 0
    local r = def.rating and self:Rating(def.rating)
    if r then
        return (r.bonus + modifier) / r.ratio, capValue / r.ratio, "rating", r
    end
    return math.max(self:Total(stat), modifier), capValue, "percent"
end

function Character:SetCount(setID)
    self:Get()
    return self.sets[setID] or 0
end

function Character:EquippedInSlot(slot)
    self:Get()
    return self.slots[slot]
end

function Character:OnEnable()
    local events = CreateFrame("Frame")
    for _, event in ipairs({
        "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP",
        "PLAYER_TALENT_UPDATE", "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_REGEN_ENABLED",
    }) do
        pcall(events.RegisterEvent, events, event)
    end
    events:RegisterUnitEvent("UNIT_STATS", "player")
    events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    events:SetScript("OnEvent", function(_, event)
        if event == "GET_ITEM_INFO_RECEIVED" and not self.dirty then return end
        self.dirty = true
    end)
end

-- /wch stats ---------------------------------------------------------------

local function Round(v) return math.floor(v * 10 + 0.5) / 10 end

ns:RegisterCommand("stats", "", "show the stats the suggestions are based on", function()
    Character:Refresh()
    local spec, source = ns.Spec.Get()
    local weights = ns.Weights.Get(spec)
    ns.Print(("%s %s (%s), level %d - weights: %s"):format(ns.class.name, ns.Spec.Label(spec), source,
        ns.Spec.GetLevel(), ns.Weights.BandText(spec)))

    local rows = {}
    for stat in pairs(Character.totals) do
        if ns.Weights.Of(weights, stat) > 0 then table.insert(rows, stat) end
    end
    -- Capped stats are listed without gear too when talents add to them
    for stat in pairs(ns.Weights.CAPS[spec] or {}) do
        local total = not Character.totals[stat] and Character:CapUnits(spec, stat)
        if total and total > 0 then table.insert(rows, stat) end
    end
    table.sort(rows, function(a, b) return ns.Weights.Of(weights, a) > ns.Weights.Of(weights, b) end)
    for _, stat in ipairs(rows) do
        local total, cap, mode, r = Character:CapUnits(spec, stat)
        local line = ("  %s: %s"):format(ns.ItemData.StatLabel(stat), tostring(Round(Character:Total(stat))))
        if cap and mode == "rating" then
            local unit = stat == "DEFENSE" and "" or "%"
            line = line .. (" - %s%s of %s%s cap (%s more rating%s)"):format(
                tostring(Round(total * r.ratio)), unit,
                tostring(Round(cap * r.ratio)), stat == "DEFENSE" and " skill" or "%",
                tostring(math.max(0, math.ceil(cap - total))), r.estimated and ", estimated" or "")
        elseif cap then
            line = line .. (" - %s of cap %s"):format(tostring(Round(total)), tostring(Round(cap)))
        end
        print(line)
    end

    local api = Character.api
    if api.MANA and api.MANA > 0 then
        local parts = { ("%d mana"):format(api.MANA) }
        if api.REGEN_OUT and api.REGEN_CASTING then
            table.insert(parts, ("regen %d per 5 sec, %d while casting"):format(
                math.floor(api.REGEN_OUT * 5 + 0.5), math.floor(api.REGEN_CASTING * 5 + 0.5)))
        end
        if api.HEALING_POWER and api.HEALING_POWER > 0 then
            table.insert(parts, ("+%d healing"):format(api.HEALING_POWER))
        end
        local school = ns.class.school
        if school and api.SCHOOL_POWER then
            table.insert(parts, ("+%d %s damage"):format(api.SCHOOL_POWER, school.name))
        end
        print("  Character sheet: " .. table.concat(parts, ", "))
    end

    local hasSets = false
    for setID, count in pairs(Character.sets) do
        local set = ns.SetData and ns.SetData.Sets[setID]
        print(("  Set: %s %d/%d"):format(set and set.name or ("#" .. setID), count, set and #set.items or 0))
        hasSets = true
    end
    if not hasSets then print("  No set pieces equipped.") end
end)
