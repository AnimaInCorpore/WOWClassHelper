-- WOWClassHelper: compares an item with the equipped gear for each spec
--
-- For every spec of the class the item gets a score delta:
--   sum over stats of (stat change x spec weight), with caps applied against
--   the player's current totals, plus the change in set bonus value.
-- The delta is turned into a verdict: UPGRADE, LATER (needs a higher level),
-- KEEP (set piece), SIDEGRADE, NO, UNUSABLE or EQUIPPED.
local _, ns = ...

local Compare = {}
ns.Compare = Compare

local TWO_HAND = "INVTYPE_2HWEAPON"
local ITEM_CLASS_WEAPON = 2
local STAFF = 10

Compare.SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 },
    INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 },
    INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 },
    INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_2HWEAPON = { 16 },
    INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 }, INVTYPE_WEAPONOFFHAND = { 17 },
    INVTYPE_RELIC = { 18 }, INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 },
}

local MAIN_HAND = { INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true }
local OFF_HAND  = { INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true, INVTYPE_WEAPONOFFHAND = true }

-- Slot groups for the best command and the "best seen" list
Compare.GROUPS = {
    head = { INVTYPE_HEAD = true }, neck = { INVTYPE_NECK = true },
    shoulder = { INVTYPE_SHOULDER = true }, back = { INVTYPE_CLOAK = true },
    chest = { INVTYPE_CHEST = true, INVTYPE_ROBE = true }, wrist = { INVTYPE_WRIST = true },
    hands = { INVTYPE_HAND = true }, waist = { INVTYPE_WAIST = true },
    legs = { INVTYPE_LEGS = true }, feet = { INVTYPE_FEET = true },
    finger = { INVTYPE_FINGER = true }, trinket = { INVTYPE_TRINKET = true },
    mainhand = { INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true, INVTYPE_2HWEAPON = true },
    offhand = { INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true, INVTYPE_WEAPONOFFHAND = true },
    ranged = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true },
    relic = { INVTYPE_RELIC = true },
}
-- Other words for groups in the best command
Compare.GROUP_ALIASES = {
    wand = "ranged", bow = "ranged", gun = "ranged", crossbow = "ranged", thrown = "ranged",
    libram = "relic", idol = "relic", totem = "relic",
    weapon = "mainhand", shield = "offhand", ring = "finger", cloak = "back",
}

-- Plural names for the tooltip header: "Best <label> seen"
Compare.GROUP_LABELS = {
    head = "head items", neck = "necks", shoulder = "shoulders", back = "cloaks",
    chest = "chest items", wrist = "bracers", hands = "gloves", waist = "belts",
    legs = "leg items", feet = "boots", finger = "rings", trinket = "trinkets",
    mainhand = "weapons", offhand = "off hands", ranged = "ranged weapons", relic = "relics",
}

local dualWield = false

-- Class-specific labels (wands, librams, ...) and dual wield
function Compare.Select(class)
    for group, label in pairs(class.groupLabels or {}) do Compare.GROUP_LABELS[group] = label end
    dualWield = class.dualWield or false
end

-- Can the player hold a one-hander in the off hand? (Dual Wield is learned
-- at a trainer; without the spell API the class profile decides.)
local DUAL_WIELD_SPELL = 674
local function CanDualWield()
    if not dualWield then return false end
    if type(dualWield) == "number" and ns.Spec.GetLevel() < dualWield then return false end
    -- If the spell API works (every class knows Cloth), Dual Wield must be learned
    if IsPlayerSpell then
        local okCloth, cloth = pcall(IsPlayerSpell, 9078)
        if okCloth and cloth == true then
            local ok, known = pcall(IsPlayerSpell, DUAL_WIELD_SPELL)
            return ok and known == true
        end
    end
    return true
end

-- Plain score of a stat table (caps limit a single item, not totals)
function Compare.RawScore(stats, spec, weights)
    local score = 0
    for stat, value in pairs(stats or {}) do
        local w = ns.Weights.Of(weights, stat)
        if w > 0 then
            local _, cap = ns.Character:CapUnits(spec, stat)
            score = score + (cap and math.min(value, cap) or value) * w
        end
    end
    return score
end

local function TwoHandName(item)
    return item.subclassID == STAFF and "staff" or "two-hander"
end

-- Off-hand attacks deal half damage (classic), so weapon DPS in the off hand
-- counts half. Talents like Dual Wield Specialization raise DPS weights.
Compare.OFF_HAND_DPS = 0.5

-- Which equipped items the new item would replace.
-- Returns list of replaced infos, an optional note, and true if the item
-- goes into the off hand as a weapon (its DPS then counts half).
function Compare.GetReplaced(info, spec, weights)
    local C = ns.Character
    local loc = info.equipLoc
    local slots = Compare.SLOTS[loc]
    local mainHand = C:EquippedInSlot(16)

    if loc == TWO_HAND then
        local replaced = {}
        if mainHand then table.insert(replaced, mainHand) end
        local offHand = C:EquippedInSlot(17)
        if offHand then table.insert(replaced, offHand) end
        if offHand then return replaced, "Replaces main hand and off hand" end
        return replaced
    end

    -- Dual wield: a one-hander replaces the weaker of two equipped weapons
    if loc == "INVTYPE_WEAPON" and CanDualWield() and not (mainHand and mainHand.equipLoc == TWO_HAND) then
        local offHand = C:EquippedInSlot(17)
        if offHand and offHand.classID == ITEM_CLASS_WEAPON and mainHand then
            if Compare.RawScore(mainHand.stats, spec, weights) <= Compare.RawScore(offHand.stats, spec, weights) then
                return { mainHand }
            end
            return { offHand }, "Compared against your off-hand weapon (off-hand damage counts half)", true
        end
        if mainHand and not offHand then
            return {}, "Fills your empty off hand (dual wield, off-hand damage counts half)", true
        end
    end
    if loc == "INVTYPE_WEAPONOFFHAND" then
        local offHand = C:EquippedInSlot(17)
        if mainHand and mainHand.equipLoc == TWO_HAND then
            return { mainHand }, ("Needs a one-handed weapon - compared against your %s"):format(TwoHandName(mainHand)), true
        end
        if not offHand then return {}, "Fills an empty slot", true end
        return { offHand }, nil, true
    end

    if #slots == 2 then
        local a, b = C:EquippedInSlot(slots[1]), C:EquippedInSlot(slots[2])
        if not a or not b then return {}, "Fills an empty slot" end
        -- Replace the weaker of the two
        if Compare.RawScore(a.stats, spec, weights) <= Compare.RawScore(b.stats, spec, weights) then
            return { a }
        end
        return { b }
    end

    if mainHand and mainHand.equipLoc == TWO_HAND then
        if MAIN_HAND[loc] then
            return { mainHand }, ("Replaces your %s (off hand becomes free)"):format(TwoHandName(mainHand))
        elseif OFF_HAND[loc] then
            return { mainHand }, ("Needs a one-handed weapon - compared against your %s"):format(TwoHandName(mainHand))
        end
    end

    local equipped = C:EquippedInSlot(slots[1])
    if not equipped then return {}, "Fills an empty slot" end
    return { equipped }
end

function Compare.IsEquipped(info)
    local slots = Compare.SLOTS[info.equipLoc] or {}
    if info.equipLoc == "INVTYPE_WEAPON" then slots = { 16, 17 } end
    for _, slot in ipairs(slots) do
        local equipped = ns.Character:EquippedInSlot(slot)
        if equipped and equipped.key == info.key then return true end
    end
    return false
end

-- Set bonus change for one spec
local function SetDelta(info, replaced, spec, weights)
    local C = ns.Character
    local affected = {}
    if info.setID then affected[info.setID] = true end
    for _, r in ipairs(replaced) do
        if r.setID then affected[r.setID] = true end
    end

    local total, changes = 0, {}
    for setID in pairs(affected) do
        local before = C:SetCount(setID)
        local after = before + ((info.setID == setID) and 1 or 0)
        for _, r in ipairs(replaced) do
            if r.setID == setID then after = after - 1 end
        end
        if after ~= before then
            local value = ns.SetBonus.Value(setID, after, spec, weights) - ns.SetBonus.Value(setID, before, spec, weights)
            local gained, lost = ns.SetBonus.ChangedEffects(setID, before, after)
            total = total + value
            table.insert(changes, {
                setID = setID, before = before, after = after,
                value = value, gained = gained, lost = lost,
            })
        end
    end
    return total, changes
end

-- Score delta of an item for one spec
function Compare.ScoreRole(info, spec)
    local C = ns.Character
    local weights = ns.Weights.Get(spec)
    local replaced, note, offHand = Compare.GetReplaced(info, spec, weights)

    local delta = {}
    for stat, v in pairs(info.stats) do delta[stat] = v end
    for _, r in ipairs(replaced) do
        for stat, v in pairs(r.stats) do delta[stat] = (delta[stat] or 0) - v end
    end

    local score, contributions = 0, {}
    for stat, dv in pairs(delta) do
        local w = ns.Weights.Of(weights, stat)
        if offHand and stat == "DPS" then w = w * Compare.OFF_HAND_DPS end
        if w > 0 and dv ~= 0 then
            local effective, capped = dv, false
            local total, cap = C:CapUnits(spec, stat)
            if cap then
                effective = math.min(total + dv, cap) - math.min(total, cap)
                capped = math.abs(effective - dv) > 0.001
            end
            local value = effective * w
            score = score + value
            table.insert(contributions, { stat = stat, delta = dv, value = value, capped = capped })
        end
    end
    table.sort(contributions, function(a, b) return math.abs(a.value) > math.abs(b.value) end)

    -- The item's own stats that are worth nothing for this spec (e.g. Fire
    -- damage for a Shadow Priest, spell power for a Warrior)
    local ignored = {}
    for stat, v in pairs(info.stats) do
        if v > 0 and ns.Weights.Of(weights, stat) <= 0 then
            table.insert(ignored, { stat = stat, value = v })
        end
    end
    table.sort(ignored, function(a, b) return a.stat < b.stat end)

    local setValue, setChanges = SetDelta(info, replaced, spec, weights)
    score = score + setValue

    local base = 0
    for _, r in ipairs(replaced) do base = base + Compare.RawScore(r.stats, spec, weights) end

    return {
        spec = spec,
        score = score,
        base = base,
        pct = base > 0 and (score / base * 100) or nil,
        contributions = contributions,
        ignored = ignored,
        sets = setChanges,
        replaced = replaced,
        note = note,
    }
end

-- Is the item worth keeping as part of a set the player is collecting?
local function SetKeepReason(info)
    if not info.setID then return nil end
    local set = ns.SetBonus.GetSet(info.setID)
    if not set or #set.effects == 0 then return nil end
    local owned = ns.Character:SetCount(info.setID) + ns.KB:OwnedSetPieces(info.setID)
    local alreadyOwned = ns.KB.owned and (ns.KB.owned.bags[info.key] or ns.KB.owned.bank[info.key])
    if not alreadyOwned and not Compare.IsEquipped(info) then owned = owned + 1 end
    if owned >= set.effects[1].count then
        return ("Set piece: you own %d/%d of %s"):format(owned, #set.items, set.name)
    end
    return nil
end

-- Score change below which an item counts as equal: 1% of the replaced items
local function Threshold(role)
    return math.max(0.5, role.base * 0.01)
end

-- needLevel: the level from which the item can be used (its required level,
-- or the level the armor or weapon type can be learned)
local function RoleVerdict(role, usable, equipped, level, needLevel)
    local threshold = Threshold(role)
    if not usable then return "UNUSABLE" end
    if equipped then return "EQUIPPED" end
    if needLevel > level then
        return role.score > threshold and "LATER" or "NO"
    end
    if role.score > threshold then return "UPGRADE" end
    -- Nothing on the item counts for this spec (a healer necklace for a
    -- Rogue): not "equal", just worthless
    if #role.contributions == 0 and #role.ignored > 0 and #role.sets == 0 then return "NO" end
    if role.score > -threshold then return "SIDEGRADE" end
    return "NO"
end

-- Full evaluation of an item. context: "MERCHANT", "LOOT" or nil
function Compare.Evaluate(info, context)
    if not info or not Compare.SLOTS[info.equipLoc] then return nil end

    local spec, specSource = ns.Spec.Get()
    local level = ns.Spec.GetLevel()
    local usable, unusableReason, learnLevel = ns.ItemData.CanUse(info)
    local needLevel = math.max(info.reqLevel or 0, learnLevel or 0)
    -- A type the class learns later (plate at 40) is scored like an item
    -- with a higher required level
    local scoreable = usable or learnLevel ~= nil
    local equipped = Compare.IsEquipped(info)
    local keepReason = SetKeepReason(info)

    local roles = {}
    for _, key in ipairs(ns.Spec.KEYS) do
        local role = Compare.ScoreRole(info, key)
        role.verdict = RoleVerdict(role, scoreable, equipped, level, needLevel)
        if keepReason and (role.verdict == "NO" or role.verdict == "SIDEGRADE") then
            role.verdict = "KEEP"
        end
        roles[key] = role
    end

    local current = roles[spec]
    local overall, reason, offSpec = current.verdict, nil, nil

    if overall == "NO" or overall == "SIDEGRADE" then
        for _, key in ipairs(ns.Spec.KEYS) do
            local v = roles[key].verdict
            if key ~= spec and (v == "UPGRADE" or v == "LATER") then
                overall = "OFFSPEC"
                offSpec = ns.Spec.DisplayName(key)
                reason = "Upgrade for " .. ns.Spec.Label(key)
                break
            end
        end
    end

    if overall == "UNUSABLE" then reason = unusableReason
    elseif overall == "LATER" then
        reason = (learnLevel and learnLevel >= (info.reqLevel or 0)) and unusableReason
            or ("Requires level " .. needLevel)
    elseif overall == "KEEP" then reason = keepReason
    end

    return {
        info = info,
        spec = spec,
        specSource = specSource,
        level = level,
        needLevel = needLevel,
        usable = usable,
        leveling = ns.Spec.IsLeveling(),
        roles = roles,
        current = current,
        verdict = overall,
        reason = reason,
        action = Compare.ActionText(overall, context, info, offSpec, needLevel),
    }
end

-- Main action text, depending on where the item is shown:
-- context nil = bags/chat link, "MERCHANT" = vendor window, "LOOT" = loot/roll window
function Compare.ActionText(verdict, context, info, offSpec, needLevel)
    local merchant, loot = context == "MERCHANT", context == "LOOT"
    local function pick(bag, vendor, looting)
        if merchant then return vendor end
        if loot then return looting end
        return bag
    end
    local lvl = needLevel or info.reqLevel or 0

    if verdict == "UPGRADE" then
        return pick("Equip now", "Buy & equip", "Take & equip")
    elseif verdict == "LATER" then
        return pick("Keep for level " .. lvl, "Buy at level " .. lvl, "Take - usable at " .. lvl)
    elseif verdict == "KEEP" then
        return pick("Keep (set piece)", "Buy (set piece)", "Take (set piece)")
    elseif verdict == "OFFSPEC" then
        local name = offSpec or "off-spec"
        return pick("Keep for " .. name, "Buy for " .. name, "Take for " .. name)
    elseif verdict == "SIDEGRADE" then
        return pick("Equal - your choice", "Optional", "Optional")
    elseif verdict == "EQUIPPED" then
        return "Currently equipped"
    elseif verdict == "UNUSABLE" then
        return pick("Can't use - sell", "Can't use - skip", "Can't use - loot & sell")
    end
    -- NO
    local sellable = (info.sellPrice or 0) > 0
    return pick(sellable and "Sell" or "Drop", "Skip", sellable and "Loot & sell" or "Leave it")
end

-- Ranking of known items ---------------------------------------------------
-- The knowledge base ranked per slot group, for the tooltip's "best seen"
-- list and the best command.

local groupOf = {}
for name, locs in pairs(Compare.GROUPS) do
    for loc in pairs(locs) do groupOf[loc] = name end
end

function Compare.GroupOf(equipLoc)
    return groupOf[equipLoc]
end

-- Where a known item is, long form for chat
local function WhereText(entry, key)
    local owned = ns.KB.owned
    if Compare.IsEquipped(entry) then return "equipped" end
    if owned.bags[key] then return "in bags" end
    if owned.bank[key] then return "in bank" end
    if entry.vendor then return "vendor: " .. entry.vendor end
    if entry.zone then return "seen in " .. entry.zone end
    return "seen via " .. (entry.lastSource or "?")
end

-- Where a known item is, one word for the tooltip
function Compare.WhereShort(entry, key)
    local owned = ns.KB.owned
    if Compare.IsEquipped(entry) then return "worn" end
    if owned.bags[key] then return "bags" end
    if owned.bank[key] then return "bank" end
    if entry.vendor then return "vendor" end
    if entry.zone then return "loot" end
    if entry.lastSource == "chat" then return "chat" end
    return "seen"
end

local rankCache = {}

-- Known items of a slot group the player can use at the current level, best
-- first for `spec`: list of { key, entry, score }. Cached until the knowledge
-- base, the gear, the level or the talents change (tooltips refresh several
-- times a second).
function Compare.Ranking(groupName, spec)
    local group = Compare.GROUPS[groupName]
    if not group then return {} end
    ns.Character:Get()
    local level = ns.Spec.GetLevel()
    local stamp = (ns.KB.revision or 0) .. ":" .. (ns.Character.version or 0) .. ":" .. level
        .. ":" .. ns.Weights.Signature() .. ":" .. tostring(ns.classToken)
    local cacheKey = groupName .. ":" .. spec
    local cached = rankCache[cacheKey]
    if cached and cached.stamp == stamp then return cached.list end

    local weights = ns.Weights.Get(spec)
    local list = {}
    for key, entry in pairs(ns.KB.items or {}) do
        if group[entry.equipLoc] and (entry.reqLevel or 0) <= level and ns.ItemData.CanUse(entry) then
            table.insert(list, { key = key, entry = entry, score = Compare.RawScore(entry.stats, spec, weights) })
        end
    end
    table.sort(list, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.key < b.key
    end)
    rankCache[cacheKey] = { stamp = stamp, list = list }
    return list
end

-- Where an item stands among the known items of its slot group:
--   { group, label, list, total, rank, eligible }
-- eligible = false when the item isn't in the list (needs a higher level,
-- can't be used, or isn't recorded); rank is then where it would be.
-- Returns nil for slots without a group.
function Compare.Rank(info, spec)
    local groupName = groupOf[info.equipLoc]
    if not groupName then return nil end
    local list = Compare.Ranking(groupName, spec)
    local result = {
        group = groupName, label = Compare.GROUP_LABELS[groupName] or groupName,
        list = list, total = #list, eligible = false,
    }
    for i, e in ipairs(list) do
        if e.key == info.key then
            result.rank, result.eligible = i, true
            return result
        end
    end
    local score = Compare.RawScore(info.stats, spec, ns.Weights.Get(spec))
    local rank = 1
    for _, e in ipairs(list) do
        if e.score > score then rank = rank + 1 end
    end
    result.rank = rank
    return result
end

-- Improvement of a ranked item over the current gear: score change (as in the
-- tooltip's first line, set bonuses included) and "UPGRADE", "SIDEGRADE" or
-- "NO". Returns nil for items that are worn. Memoized on the ranking entry,
-- which is rebuilt when gear, level or the knowledge base change.
function Compare.Improvement(e, spec)
    if Compare.IsEquipped(e.entry) then return nil end
    if e.improvementSpec ~= spec then
        local role = Compare.ScoreRole(e.entry, spec)
        local threshold = Threshold(role)
        e.improvement = role.score
        e.improvementVerdict = role.score > threshold and "UPGRADE"
            or role.score > -threshold and "SIDEGRADE" or "NO"
        e.improvementSpec = spec
    end
    return e.improvement, e.improvementVerdict
end

-- /wch best <slot> ------------------------------------------------------

function Compare.GroupFromWord(word)
    word = (word or ""):lower()
    if Compare.GROUPS[word] then return word end
    return Compare.GROUP_ALIASES[word]
end

ns:RegisterCommand("best", function() return "<slot> [" .. ns.Spec.ChoiceText() .. "]" end,
    "best known items for a slot from the knowledge base", function(arg)
    local slotWord, specName = strtrim(arg or ""):lower():match("^(%S*)%s*(%S*)$")
    local slotName = Compare.GroupFromWord(slotWord)
    if not slotName then
        local names = {}
        for name in pairs(Compare.GROUPS) do table.insert(names, name) end
        table.sort(names)
        ns.Print("slots: " .. table.concat(names, ", "))
        return
    end

    local spec = ns.Spec.FromAlias(specName) or ns.Spec.Get()
    local level = ns.Spec.GetLevel()
    local list = Compare.Ranking(slotName, spec)

    ns.Print(("best known %s for %s (level %d):"):format(slotName, ns.Spec.Label(spec), level))
    if #list == 0 then print("  nothing known yet - hover over items to teach the addon.") end
    for i = 1, math.min(5, #list) do
        local e = list[i]
        local delta = Compare.Improvement(e, spec)
        print(("  %d. %s  score %.1f%s  (%s)"):format(i, e.entry.link or e.entry.name, e.score,
            delta and ((", %s%.1f vs. your gear"):format(delta >= 0 and "+" or "", delta)) or "",
            WhereText(e.entry, e.key)))
    end
end)
