-- WOWClassHelper: compares an item with the equipped gear for each spec
--
-- For every spec of the class the item gets a score delta:
--   sum over stats of (stat change x spec weight), with caps applied against
--   the player's current totals, plus the change in set bonus value.
-- Two-handers are compared with one-hander + off hand pairs (see "Weapon
-- pairs" below). While leveling, how long an item stays current adds to it
-- (see "Longevity").
-- The delta is turned into a verdict: UPGRADE, LATER (needs a higher level),
-- KEEP (set piece), SIDEGRADE, NO, UNUSABLE or EQUIPPED. Main stats lead: an
-- item that loses the spec's main stats is at best SIDEGRADE.
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

-- Off-hand attacks deal half damage (classic), so weapon DPS in the off hand
-- counts half. Talents like Dual Wield Specialization raise DPS weights.
Compare.OFF_HAND_DPS = 0.5

-- Plain score of a stat table (caps limit a single item, not totals).
-- off = the item sits in the off hand, so its weapon DPS counts half.
-- filter: optional function(stat) -> true for the stats to count.
function Compare.RawScore(stats, spec, weights, off, filter)
    local score = 0
    for stat, value in pairs(stats or {}) do
        local w = ns.Weights.Of(weights, stat)
        if w > 0 and (not filter or filter(stat)) then
            if off and stat == "DPS" then w = w * Compare.OFF_HAND_DPS end
            local _, cap = ns.Character:CapUnits(spec, stat)
            score = score + (cap and math.min(value, cap) or value) * w
        end
    end
    return score
end

-- Longevity while leveling ----------------------------------------------------
-- Gear is outgrown some levels after its required level, and better quality
-- lasts longer: a blue item keeps up longer than a green one of the same
-- level. While leveling, each level an item stays current adds a share of
-- its score, so an item in your level range beats a lower-level item with
-- slightly better stats that you would replace soon anyway.

-- Levels an item stays current after its required level, by quality
-- (0 poor, 1 common, 2 uncommon, 3 rare, 4 epic, 5 legendary, 6 artifact,
-- 7 heirloom - heirlooms grow with you)
Compare.LIFESPAN = { [0] = 2, [1] = 4, [2] = 7, [3] = 11, [4] = 16, [5] = 25, [6] = 25, [7] = 99 }
Compare.LONGEVITY_PER_LEVEL = 0.03   -- value of each level ahead, as a share of the item's score
Compare.LONGEVITY_HORIZON = 10       -- levels ahead that count

-- The level up to which an item stays current. Items without a required
-- level count from their item level (required level ~ item level - 5).
function Compare.LastsTo(item)
    local base = item.reqLevel or 0
    if base <= 0 then base = math.max(1, (item.ilvl or 1) - 5) end
    return base + (Compare.LIFESPAN[item.quality or 2] or Compare.LIFESPAN[2])
end

-- Levels the item stays current, from now or, for an item that needs a
-- higher level, from that level (0 at max level)
function Compare.LevelsLeft(item)
    local level, maxLevel = ns.Spec.GetLevel(), ns.Spec.GetMaxLevel()
    if level >= maxLevel then return 0 end
    local from = math.max(level, item.reqLevel or 0)
    local left = math.min(Compare.LastsTo(item), maxLevel) - from
    return math.max(0, math.min(Compare.LONGEVITY_HORIZON, left))
end

-- Score of an item including its longevity while leveling; what rankings
-- and the choice of a partner or of the weaker ring go by
function Compare.ItemValue(item, spec, weights, off)
    local raw = Compare.RawScore(item.stats, spec, weights, off)
    return raw * (1 + Compare.LONGEVITY_PER_LEVEL * Compare.LevelsLeft(item))
end

local function TwoHandName(item)
    return item.subclassID == STAFF and "staff" or "two-hander"
end

-- Weapon pairs ---------------------------------------------------------------
-- A two-hander takes both hands, so it is compared with a one-hander and an
-- off hand together: a one-hander or off hand hovered while you wear a
-- two-hander is paired with the best fitting item from your bags or bank,
-- and the weapons list ranks one-handers together with the best off hand
-- seen.

-- Items that can be one half of a pair (two-handers can't)
local PAIR_LOCS = {
    INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true,
    INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true, INVTYPE_WEAPONOFFHAND = true,
}

-- Can an item of this slot go into the off hand next to a one-hander?
-- dualWield: result of CanDualWield()
local function FitsOffHand(loc, dualWield)
    if loc == "INVTYPE_SHIELD" or loc == "INVTYPE_HOLDABLE" then return true end
    if loc == "INVTYPE_WEAPON" or loc == "INVTYPE_WEAPONOFFHAND" then return dualWield end
    return false
end

-- The hands an item can take in a pair: false = main hand, true = off hand.
-- A one-hander of a dual wielder can take either.
local function PairHands(loc, dualWield)
    local hands = {}
    if MAIN_HAND[loc] then hands[#hands + 1] = false end
    if OFF_HAND[loc] or (loc == "INVTYPE_WEAPON" and dualWield) then hands[#hands + 1] = true end
    return hands
end

-- Score of a pool candidate in one hand (rankings precompute it)
local function CandidateScore(c, off, spec, weights)
    local cached
    if off then cached = c.offScore else cached = c.mainScore end
    if cached then return cached end
    return Compare.ItemValue(c.entry, spec, weights, off)
end

-- Best partner for a one-hander or off hand from a pool of candidates
-- { key, entry, count, where }. Returns the partner { item, key, where, off },
-- whether the item itself goes into the off hand, and the pair's score.
-- nil if nothing in the pool fits or adds anything. An item is never paired
-- with itself unless there are two of it.
function Compare.BestPartner(info, pool, spec, weights)
    local best
    local dualWield = CanDualWield()
    for _, off in ipairs(PairHands(info.equipLoc, dualWield)) do
        local own = Compare.ItemValue(info, spec, weights, off)
        for _, c in ipairs(pool) do
            local loc = c.entry.equipLoc
            local fits
            if off then fits = MAIN_HAND[loc] else fits = FitsOffHand(loc, dualWield) end
            if fits and (c.key ~= info.key or (c.count or 1) > 1) then
                local s = CandidateScore(c, not off, spec, weights)
                local total = own + s
                if s > 0 and (not best or total > best.score
                        or (total == best.score and c.key < best.partner.key)) then
                    best = { score = total, off = off,
                             partner = { item = c.entry, key = c.key, where = c.where, off = not off } }
                end
            end
        end
    end
    if best then return best.partner, best.off, best.score end
    return nil
end

local ownedCache = {}

-- One-handers and off hands in your bags and bank that you can use now:
-- the partners for a pair against a worn two-hander.
function Compare.OwnedPartners()
    local KB = ns.KB
    ns.Character:Get()
    local level = ns.Spec.GetLevel()
    local stamp = (KB.revision or 0) .. ":" .. (ns.Character.version or 0) .. ":" .. level
        .. ":" .. tostring(ns.classToken)
    if ownedCache.stamp == stamp then return ownedCache.list end

    local list, byKey = {}, {}
    local owned, items = KB.owned or {}, KB.items or {}
    for _, place in ipairs({ "bags", "bank" }) do
        for key, count in pairs(owned[place] or {}) do
            local entry = items[key]
            if entry and PAIR_LOCS[entry.equipLoc] and (entry.reqLevel or 0) <= level
                    and ns.ItemData.CanUse(entry) then
                local c = byKey[key]
                if not c then
                    c = { key = key, entry = entry, count = 0, where = place }
                    byKey[key] = c
                    list[#list + 1] = c
                end
                c.count = c.count + count
            end
        end
    end
    table.sort(list, function(a, b) return a.key < b.key end)
    ownedCache = { stamp = stamp, list = list }
    return list
end

-- How the item would be worn for one spec:
--   added    = { { item, off }, ... }  the item, and its partner if it has one
--   replaced = { { item, off }, ... }  equipped items that come off
--   note     = optional text, partner = { item, key, where, off } or nil
-- off = in the off hand (weapon DPS counts half). With `partner` given (the
-- weapons list), the item and the partner replace whatever is in both hands.
function Compare.Plan(info, spec, weights, partner)
    local C = ns.Character
    local loc = info.equipLoc
    local slots = Compare.SLOTS[loc]
    local mainHand, offHand = C:EquippedInSlot(16), C:EquippedInSlot(17)
    local plan = { added = {}, replaced = {} }
    local function put(item, off) plan.added[#plan.added + 1] = { item = item, off = off } end
    local function takeOff(item, off)
        if item then plan.replaced[#plan.replaced + 1] = { item = item, off = off } end
    end

    if partner then
        put(info, not partner.off)
        put(partner.item, partner.off)
        takeOff(mainHand, false)
        takeOff(offHand, true)
        plan.partner = partner
        return plan
    end

    if loc == TWO_HAND then
        put(info, false)
        takeOff(mainHand, false)
        takeOff(offHand, true)
        if offHand then plan.note = "Replaces main hand and off hand" end
        return plan
    end

    -- Against a worn two-hander, a one-hander or off hand counts together
    -- with the best partner you carry
    if mainHand and mainHand.equipLoc == TWO_HAND and (MAIN_HAND[loc] or OFF_HAND[loc]) then
        takeOff(mainHand, false)
        local found, off = Compare.BestPartner(info, Compare.OwnedPartners(), spec, weights)
        if found then
            put(info, off)
            put(found.item, found.off)
            plan.partner = found
        elseif MAIN_HAND[loc] then
            put(info, false)
            plan.note = ("Replaces your %s (off hand becomes free)"):format(TwoHandName(mainHand))
        else
            put(info, true)
            plan.note = ("Needs a one-handed weapon - compared against your %s"):format(TwoHandName(mainHand))
        end
        return plan
    end

    -- Dual wield: a one-hander replaces the weaker of two equipped weapons
    if loc == "INVTYPE_WEAPON" and CanDualWield() and mainHand then
        if offHand and offHand.classID == ITEM_CLASS_WEAPON then
            if Compare.ItemValue(mainHand, spec, weights) <= Compare.ItemValue(offHand, spec, weights) then
                put(info, false)
                takeOff(mainHand, false)
                return plan
            end
            put(info, true)
            takeOff(offHand, true)
            plan.note = "Compared against your off-hand weapon (off-hand damage counts half)"
            return plan
        end
        if not offHand then
            put(info, true)
            plan.note = "Fills your empty off hand (dual wield, off-hand damage counts half)"
            return plan
        end
    end

    if #slots == 2 then
        put(info, false)
        local a, b = C:EquippedInSlot(slots[1]), C:EquippedInSlot(slots[2])
        if not a or not b then
            plan.note = "Fills an empty slot"
        elseif Compare.ItemValue(a, spec, weights) <= Compare.ItemValue(b, spec, weights) then
            takeOff(a, false)   -- replace the weaker of the two
        else
            takeOff(b, false)
        end
        return plan
    end

    local off = slots[1] == 17
    put(info, off)
    local equipped = C:EquippedInSlot(slots[1])
    if equipped then takeOff(equipped, off) else plan.note = "Fills an empty slot" end
    return plan
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
local function SetDelta(plan, spec, weights)
    local C = ns.Character
    local change = {}
    for _, worn in ipairs(plan.added) do
        local setID = worn.item.setID
        if setID then change[setID] = (change[setID] or 0) + 1 end
    end
    for _, worn in ipairs(plan.replaced) do
        local setID = worn.item.setID
        if setID then change[setID] = (change[setID] or 0) - 1 end
    end

    local total, changes = 0, {}
    for setID, diff in pairs(change) do
        local before = C:SetCount(setID)
        local after = before + diff
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

-- Changes smaller than this are rounding noise from adding and removing
-- the same item (a worn partner in a pair)
local EPSILON = 1e-6

-- Score delta of an item for one spec. partner: see Compare.Plan.
function Compare.ScoreRole(info, spec, partner)
    local C = ns.Character
    local weights = ns.Weights.Get(spec)
    local plan = Compare.Plan(info, spec, weights, partner)

    -- delta: the stat change as shown; counted: as it counts, with weapon
    -- DPS in the off hand at half
    local delta, counted = {}, {}
    local function apply(list, sign)
        for _, worn in ipairs(list) do
            for stat, v in pairs(worn.item.stats or {}) do
                local factor = (worn.off and stat == "DPS") and Compare.OFF_HAND_DPS or 1
                delta[stat] = (delta[stat] or 0) + sign * v
                counted[stat] = (counted[stat] or 0) + sign * v * factor
            end
        end
    end
    apply(plan.added, 1)
    apply(plan.replaced, -1)

    local isMain = function(stat) return ns.Weights.IsMainStat(spec, stat) end
    local score, mainValue, contributions = 0, 0, {}
    for stat, dv in pairs(delta) do
        local w = ns.Weights.Of(weights, stat)
        local cv = counted[stat]
        if w > 0 and (math.abs(dv) > EPSILON or math.abs(cv) > EPSILON) then
            local effective, capped = cv, false
            local total, cap = C:CapUnits(spec, stat)
            if cap then
                effective = math.min(total + cv, cap) - math.min(total, cap)
                capped = math.abs(effective - cv) > 0.001
            end
            local value = effective * w
            score = score + value
            local c = { stat = stat, delta = dv, value = value, capped = capped, main = isMain(stat) }
            if c.main then
                mainValue = mainValue + value
                -- Change against what your gear has of the stat
                local gear = C:Total(stat)
                if gear > 0 then c.pct = dv / gear * 100 end
            end
            table.insert(contributions, c)
        end
    end
    -- Main stats first, then by size
    table.sort(contributions, function(a, b)
        if a.main ~= b.main then return a.main end
        if math.abs(a.value) ~= math.abs(b.value) then return math.abs(a.value) > math.abs(b.value) end
        return a.stat < b.stat
    end)

    -- The item's own stats that are worth nothing for this spec (e.g. Fire
    -- damage for a Shadow Priest, spell power for a Warrior)
    local ignored = {}
    for stat, v in pairs(info.stats) do
        if v > 0 and ns.Weights.Of(weights, stat) <= 0 then
            table.insert(ignored, { stat = stat, value = v })
        end
    end
    table.sort(ignored, function(a, b) return a.stat < b.stat end)

    local setValue, setChanges = SetDelta(plan, spec, weights)
    score = score + setValue

    local base, mainBase, replaced = 0, 0, {}
    for _, worn in ipairs(plan.replaced) do
        base = base + Compare.RawScore(worn.item.stats, spec, weights, worn.off)
        mainBase = mainBase + Compare.RawScore(worn.item.stats, spec, weights, worn.off, isMain)
        replaced[#replaced + 1] = worn.item
    end

    -- Longevity while leveling: each level an item stays current is worth a
    -- share of its score (the main stats' share for the main-stat check)
    local longevity
    if ns.Spec.IsLeveling() then
        local p = Compare.LONGEVITY_PER_LEVEL
        local value, mainLife, yours = 0, 0, nil
        local function life(list, sign)
            for _, worn in ipairs(list) do
                local left = p * Compare.LevelsLeft(worn.item) * sign
                value = value + left * Compare.RawScore(worn.item.stats, spec, weights, worn.off)
                mainLife = mainLife + left * Compare.RawScore(worn.item.stats, spec, weights, worn.off, isMain)
            end
        end
        life(plan.added, 1)
        life(plan.replaced, -1)
        for _, worn in ipairs(plan.replaced) do
            yours = math.min(yours or math.huge, Compare.LastsTo(worn.item))
        end
        local maxLevel = ns.Spec.GetMaxLevel()
        longevity = {
            value = value,
            lasts = math.min(Compare.LastsTo(info), maxLevel),
            yours = yours and math.min(yours, maxLevel),
        }
        score = score + value
        mainValue = mainValue + mainLife
    end

    -- Main stats lead: losing them can't be made up by minor stats alone
    local mainLoss = mainValue < -math.max(0.5, mainBase * 0.02)

    return {
        spec = spec,
        score = score,
        base = base,
        pct = base > 0 and (score / base * 100) or nil,
        contributions = contributions,
        ignored = ignored,
        sets = setChanges,
        longevity = longevity,
        mainValue = mainValue,
        mainLoss = mainLoss,
        replaced = replaced,
        partner = plan.partner,
        note = plan.note,
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

-- Better, equal or worse by the score. Main stats lead: an item that loses
-- main stats is at best equal, whatever minor stats it adds.
local function ScoreVerdict(role)
    local threshold = Threshold(role)
    if role.score > threshold then return role.mainLoss and "SIDEGRADE" or "UPGRADE" end
    if role.score > -threshold then return "SIDEGRADE" end
    return "NO"
end

-- Did the main-stat rule turn an upgrade into "equal"?
local function MainStatsHeldBack(role)
    return role.mainLoss and role.score > Threshold(role)
end

-- needLevel: the level from which the item can be used (its required level,
-- or the level the armor or weapon type can be learned)
local function RoleVerdict(role, usable, equipped, level, needLevel)
    if not usable then return "UNUSABLE" end
    if equipped then return "EQUIPPED" end
    local verdict = ScoreVerdict(role)
    if needLevel > level then return verdict == "UPGRADE" and "LATER" or "NO" end
    if verdict == "UPGRADE" then return verdict end
    -- Nothing on the item counts for this spec (a healer necklace for a
    -- Rogue): not "equal", just worthless
    if #role.contributions == 0 and #role.ignored > 0 and #role.sets == 0 then return "NO" end
    return verdict
end

-- "Loses main stats: Agility -4, Attack Power -10"
local function MainLossText(role)
    local parts = {}
    for _, c in ipairs(role.contributions) do
        if c.main and c.value < 0 and #parts < 2 then
            local rounded = math.floor(c.delta * 10 + 0.5) / 10
            parts[#parts + 1] = ns.ItemData.StatLabel(c.stat) .. " " .. rounded
        end
    end
    if #parts == 0 then return "Main stats last fewer levels than yours" end
    return "Loses main stats: " .. table.concat(parts, ", ")
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
    elseif (overall == "SIDEGRADE" or overall == "NO") and MainStatsHeldBack(current) then
        reason = MainLossText(current)
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
    -- Bags and chat links also cover quest rewards: don't take it, or sell
    -- (drop) it if you already have it
    local rid = "do not take/" .. (((info.sellPrice or 0) > 0) and "sell" or "drop")

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
        return pick("Can't use - " .. rid, "Can't use - skip", "Can't use - loot & sell")
    end
    -- NO
    local sellable = (info.sellPrice or 0) > 0
    return pick((rid:gsub("^d", "D")), "Skip", sellable and "Loot & sell" or "Leave it")
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

-- Where you have the item: "worn", "bags", "bank" or nil
function Compare.Location(entry, key)
    local owned = ns.KB.owned or {}
    if Compare.IsEquipped(entry) then return "worn" end
    if (owned.bags or {})[key] then return "bags" end
    if (owned.bank or {})[key] then return "bank" end
    return nil
end

-- How an item is obtained, from what the knowledge base saw: a list of
-- { tag, detail }, most telling first. Tags: quest (reward), raid and
-- dungeon (drop in an instance), crafted (profession), vendor, drop (world).
function Compare.Origins(item)
    local list = {}
    if not item then return list end
    local entry = (item.key and ns.KB:Get(item.key)) or item
    local function add(tag, detail)
        list[#list + 1] = { tag = tag, detail = (type(detail) == "string" and detail ~= "") and detail or nil }
    end
    if entry.quest then add("quest", entry.quest) end
    if entry.instanceType == "raid" then add("raid", entry.instance)
    elseif entry.instanceType == "party" then add("dungeon", entry.instance) end
    if entry.profession then add("crafted", entry.profession) end
    if entry.vendor then add("vendor", entry.vendor) end
    if entry.zone and not entry.instanceType then add("drop", entry.zone) end
    return list
end

local LOCATION_TEXT = { worn = "equipped", bags = "in bags", bank = "in bank" }

-- Where a known item is and how it is obtained, long form for chat
local function WhereText(entry, key)
    local parts = {}
    local location = Compare.Location(entry, key)
    if location then parts[1] = LOCATION_TEXT[location] end
    for _, origin in ipairs(Compare.Origins(entry)) do
        parts[#parts + 1] = origin.tag .. (origin.detail and (": " .. origin.detail) or "")
    end
    if #parts == 0 then return "seen via " .. (entry.lastSource or "?") end
    return table.concat(parts, "; ")
end

-- Where a known item is, one word for the tooltip: where you have it, else
-- how it is obtained, else where it was seen
function Compare.WhereShort(entry, key)
    local location = Compare.Location(entry, key)
    if location then return location end
    local origin = Compare.Origins(entry)[1]
    if origin then return origin.tag end
    if entry.lastSource == "chat" then return "chat" end
    return "seen"
end

local rankCache = {}

-- Known one-handers and off hands usable at `level`, with their score in
-- each hand they fit: the partners for one-handers in the weapons list
local function KnownPartners(spec, weights, level)
    local pool = {}
    local owned = ns.KB.owned or {}
    local dualWield = CanDualWield()
    for key, entry in pairs(ns.KB.items or {}) do
        if PAIR_LOCS[entry.equipLoc] and (entry.reqLevel or 0) <= level and ns.ItemData.CanUse(entry) then
            local c = { key = key, entry = entry, where = Compare.WhereShort(entry, key) }
            -- Two of the same weapon: owned twice, or sold by a vendor
            local count = ((owned.bags or {})[key] or 0) + ((owned.bank or {})[key] or 0)
            if Compare.IsEquipped(entry) then count = count + 1 end
            c.count = entry.vendor and 2 or math.max(1, count)
            if MAIN_HAND[entry.equipLoc] then c.mainScore = Compare.ItemValue(entry, spec, weights) end
            if FitsOffHand(entry.equipLoc, dualWield) then c.offScore = Compare.ItemValue(entry, spec, weights, true) end
            pool[#pool + 1] = c
        end
    end
    table.sort(pool, function(a, b) return a.key < b.key end)
    return pool
end

-- The partner a worn one-hander has in the other hand, or nil
local function WornPartner(entry)
    local C = ns.Character
    local mainHand, offHand = C:EquippedInSlot(16), C:EquippedInSlot(17)
    if mainHand and mainHand.key == entry.key and offHand then
        return { item = offHand, key = offHand.key, where = "worn", off = true }
    end
    if offHand and offHand.key == entry.key and mainHand then
        return { item = mainHand, key = mainHand.key, where = "worn", off = false }
    end
    return nil
end

-- Score of a weapon in the weapons list: a one-hander counts together with
-- its partner (the worn one if it is worn, else the best one seen).
-- Returns the score and the partner (nil: alone).
local function WeaponScore(entry, pool, spec, weights)
    local own = Compare.ItemValue(entry, spec, weights)
    if entry.equipLoc == TWO_HAND then return own end
    local worn = WornPartner(entry)
    if worn then
        return Compare.ItemValue(entry, spec, weights, not worn.off)
            + Compare.ItemValue(worn.item, spec, weights, worn.off), worn
    end
    local partner, _, pairScore = Compare.BestPartner(entry, pool, spec, weights)
    if partner then return pairScore, partner end
    return own
end

-- Known items of a slot group the player can use at the current level, best
-- first for `spec`: list of { key, entry, score, partner }. In the weapons
-- list a one-hander is scored together with an off hand (partner), so it
-- competes with two-handers on equal terms. Also returns the partner pool
-- (weapons list only). Cached until the knowledge base, the gear, the level
-- or the talents change (tooltips refresh several times a second).
function Compare.Ranking(groupName, spec)
    local group = Compare.GROUPS[groupName]
    if not group then return {} end
    ns.Character:Get()
    local level = ns.Spec.GetLevel()
    local stamp = (ns.KB.revision or 0) .. ":" .. (ns.Character.version or 0) .. ":" .. level
        .. ":" .. ns.Weights.Signature() .. ":" .. tostring(ns.classToken)
    local cacheKey = groupName .. ":" .. spec
    local cached = rankCache[cacheKey]
    if cached and cached.stamp == stamp then return cached.list, cached.pool end

    local weights = ns.Weights.Get(spec)
    local pool = groupName == "mainhand" and KnownPartners(spec, weights, level) or nil
    local list = {}
    for key, entry in pairs(ns.KB.items or {}) do
        if group[entry.equipLoc] and (entry.reqLevel or 0) <= level and ns.ItemData.CanUse(entry) then
            local e = { key = key, entry = entry }
            if pool then
                e.score, e.partner = WeaponScore(entry, pool, spec, weights)
            else
                e.score = Compare.ItemValue(entry, spec, weights)
            end
            table.insert(list, e)
        end
    end
    table.sort(list, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.key < b.key
    end)
    rankCache[cacheKey] = { stamp = stamp, list = list, pool = pool }
    return list, pool
end

-- Where an item stands among the known items of its slot group:
--   { group, label, list, total, rank, eligible }
-- eligible = false when the item isn't in the list (needs a higher level,
-- can't be used, or isn't recorded); rank is then where it would be.
-- Returns nil for slots without a group.
function Compare.Rank(info, spec)
    local groupName = groupOf[info.equipLoc]
    if not groupName then return nil end
    local list, pool = Compare.Ranking(groupName, spec)
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
    local weights = ns.Weights.Get(spec)
    local score = pool and WeaponScore(info, pool, spec, weights) or Compare.ItemValue(info, spec, weights)
    local rank = 1
    for _, e in ipairs(list) do
        if e.score > score then rank = rank + 1 end
    end
    result.rank = rank
    return result
end

-- Improvement of a ranked item over the current gear: score change (as in the
-- tooltip's first line, set bonuses included) and "UPGRADE", "SIDEGRADE" or
-- "NO". A one-hander with a partner counts as the pair against both hands.
-- Returns nil for items that are worn. Memoized on the ranking entry, which
-- is rebuilt when gear, level or the knowledge base change.
function Compare.Improvement(e, spec)
    if Compare.IsEquipped(e.entry) then return nil end
    if e.improvementSpec ~= spec then
        local role = Compare.ScoreRole(e.entry, spec, e.partner)
        e.improvement = role.score
        e.improvementVerdict = ScoreVerdict(role)
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
        local p = e.partner
        print(("  %d. %s%s  score %.1f%s  (%s%s)"):format(i, e.entry.link or e.entry.name,
            p and (" + " .. (p.item.link or p.item.name or "?")) or "", e.score,
            delta and ((", %s%.1f vs. your gear"):format(delta >= 0 and "+" or "", delta)) or "",
            WhereText(e.entry, e.key),
            p and ("; " .. (p.off and "off hand " or "main hand ") .. WhereText(p.item, p.key)) or ""))
    end
end)
