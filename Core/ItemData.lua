-- WOWClassHelper: item parsing, stat normalization and usability checks
local _, ns = ...

local ItemData = {}
ns.ItemData = ItemData

local GetItemInfo  = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetItemStats = (C_Item and C_Item.GetItemStats) or GetItemStats
local GetDetailedItemLevelInfo = (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo

local ITEM_CLASS_WEAPON, ITEM_CLASS_ARMOR = 2, 4
ItemData.ITEM_CLASS_WEAPON, ItemData.ITEM_CLASS_ARMOR = ITEM_CLASS_WEAPON, ITEM_CLASS_ARMOR

-- Weapon subclasses whose DPS is not melee weapon damage
local WAND = 19
local RANGED = { [2] = true, [3] = true, [16] = true, [18] = true }   -- bows, guns, thrown, crossbows

-- Stat key normalization ------------------------------------------------

local RESISTANCES = {
    [0] = "ARMOR", [1] = "HOLY_RESISTANCE", [2] = "FIRE_RESISTANCE", [3] = "NATURE_RESISTANCE",
    [4] = "FROST_RESISTANCE", [5] = "SHADOW_RESISTANCE", [6] = "ARCANE_RESISTANCE",
}

-- Spell schools for "+<school> damage" stats
local SCHOOLS = { HOLY = true, FIRE = true, NATURE = true, FROST = true, SHADOW = true, ARCANE = true }

-- Game stat keys (after stripping ITEM_MOD_ / _SHORT) -> our names.
-- Battle.net API names (used by Data/Items.lua) go through the same table.
local ALIASES = {
    DAMAGE_PER_SECOND = "DPS",
    POWER_REGEN0 = "MANA_REGENERATION",
    MANA_REGENERATION = "MANA_REGENERATION",
    DEFENSE_SKILL_RATING = "DEFENSE", DEFENSE_SKILL = "DEFENSE",
    DODGE_RATING = "DODGE", PARRY_RATING = "PARRY",
    BLOCK_RATING = "BLOCK", BLOCK_VALUE = "BLOCK_VALUE",
    HIT_RATING = "HIT", HIT_MELEE_RATING = "HIT", HIT_SPELL_RATING = "SPELL_HIT", HIT_RANGED_RATING = "HIT",
    CRIT_RATING = "CRIT", CRIT_MELEE_RATING = "CRIT", CRIT_SPELL_RATING = "SPELL_CRIT", CRIT_RANGED_RATING = "CRIT",
    HASTE_RATING = "HASTE", MASTERY_RATING = "MASTERY",
    SPELL_HEALING_DONE = "HEALING", SPELL_DAMAGE_DONE = "SPELL_DAMAGE",
    EXTRA_ARMOR = "ARMOR",
    CR_VERSATILITY = "VERSATILITY",
}

local labels = {
    DPS = "Weapon DPS",
    WAND_DPS = "Wand DPS",
    RANGED_DPS = "Ranged DPS",
    SHADOW_DAMAGE = "Shadow Damage",
    HOLY_DAMAGE = "Holy Damage",
}

function ItemData.NormalizeStat(raw)
    local resistance = raw:match("^RESISTANCE(%d)_NAME$")
    if resistance then
        return RESISTANCES[tonumber(resistance)] or raw
    end
    local key = raw:gsub("^ITEM_MOD_", "")
    key = key:gsub("_SHORT$", "")
    if ALIASES[key] then return ALIASES[key] end
    -- "+Shadow damage" style stats, e.g. BONUS_STAT_SHADOW_DAMAGE_DONE
    local school = key:match("^BONUS_STAT_(%u+)_DAMAGE_DONE$")
        or key:match("^(%u+)_DAMAGE_DONE$")
        or key:match("^SPELL_DAMAGE_(%u+)$")
    if school and SCHOOLS[school] then
        return school .. "_DAMAGE"
    end
    return key
end

-- Readable name for a normalized stat key
function ItemData.StatLabel(key)
    if labels[key] then return labels[key] end
    local pretty = key:gsub("_", " "):lower():gsub("(%a)(%w*)", function(a, b) return a:upper() .. b end)
    labels[key] = pretty
    return pretty
end

-- Remember the localized label the game uses for a raw key
local function RememberLabel(raw, key)
    if not labels[key] and type(_G[raw]) == "string" then
        labels[key] = _G[raw]
    end
end

-- Link helpers -----------------------------------------------------------

-- Splits "item:ID:enchant:gem1:gem2:gem3:gem4:suffix:..." keeping empty fields
local function LinkFields(link)
    local itemString = link and link:match("item:([%-%d:]*)")
    if not itemString then return nil end
    local fields = {}
    for field in (itemString .. ":"):gmatch("([^:]*):") do
        fields[#fields + 1] = field
    end
    return fields
end

-- Stable key for the knowledge base: item ID, plus random suffix if present
-- ("of the Owl" items have different stats per suffix).
function ItemData.KeyFromLink(link)
    local fields = LinkFields(link)
    if not fields then return nil end
    local id = tonumber(fields[1])
    local suffix = tonumber(fields[7] or "")
    if suffix and suffix ~= 0 then
        return id .. ":" .. suffix, id
    end
    return tostring(id), id
end

-- Stats -------------------------------------------------------------------

-- Wand and ranged weapon DPS are stored apart from melee weapon damage
-- (WAND_DPS, RANGED_DPS), so each class can weigh them on their own.
-- Also used to update knowledge base entries saved by older versions.
function ItemData.SplitWeaponDPS(stats, classID, subclassID)
    if classID ~= ITEM_CLASS_WEAPON or not stats.DPS then return stats end
    if subclassID == WAND then
        stats.WAND_DPS, stats.DPS = stats.DPS, nil
    elseif RANGED[subclassID] then
        stats.RANGED_DPS, stats.DPS = stats.DPS, nil
    end
    return stats
end

local function StatsFromStatic(id)
    local static = ns.Items and ns.Items[id]
    if not static then return nil end
    local stats = {}
    for raw, value in pairs(static.stats or {}) do
        stats[ItemData.NormalizeStat(raw)] = value
    end
    if static.armor then stats.ARMOR = static.armor end
    if static.weapon and static.weapon.speed and static.weapon.speed > 0 then
        stats.DPS = (static.weapon.min + static.weapon.max) / 2 / static.weapon.speed
    end
    return stats
end

-- classID / subclassID are optional (for the weapon DPS split).
function ItemData.GetStats(link, id, classID, subclassID)
    local stats = {}
    local found = false
    local ok, raw = pcall(GetItemStats, link)
    if ok and type(raw) == "table" then
        for rawKey, value in pairs(raw) do
            if type(value) == "number" and value ~= 0 then
                local key = ItemData.NormalizeStat(rawKey)
                RememberLabel(rawKey, key)
                stats[key] = (stats[key] or 0) + value
                found = true
            end
        end
    end
    if not found then
        stats = StatsFromStatic(id) or stats
    end
    return ItemData.SplitWeaponDPS(stats, classID, subclassID)
end

-- Parse -------------------------------------------------------------------

-- Returns an info table for an item link, or nil if the item is not cached yet.
-- The same fields are stored in the knowledge base, so KB entries can be
-- scored exactly like live items.
function ItemData.Parse(link)
    if type(link) ~= "string" then return nil end
    local key, id = ItemData.KeyFromLink(link)
    if not id then return nil end

    local name, fullLink, quality, ilvl, reqLevel, _, _, _, equipLoc, icon,
          sellPrice, classID, subclassID, _, _, setID = GetItemInfo(link)
    if not name then return nil end

    if GetDetailedItemLevelInfo then
        local ok, effective = pcall(GetDetailedItemLevelInfo, link)
        if ok and type(effective) == "number" then ilvl = effective end
    end

    if (not setID or setID == 0) and ns.SetData and ns.SetData.ItemToSet then
        setID = ns.SetData.ItemToSet[id]
    end

    return {
        id = id,
        key = key,
        link = fullLink or link,
        name = name,
        quality = quality,
        ilvl = ilvl,
        reqLevel = reqLevel or 0,
        equipLoc = equipLoc or "",
        classID = classID,
        subclassID = subclassID,
        sellPrice = sellPrice or 0,
        icon = icon,
        setID = (setID and setID ~= 0) and setID or nil,
        stats = ItemData.GetStats(link, id, classID, subclassID),
    }
end

-- Usability -------------------------------------------------------------
-- What a class can ever use comes from its profile (armor, weapons); what it
-- has trained so far from the proficiency spells.

ItemData.ARMOR_NAMES = {
    [0] = "Miscellaneous", [1] = "Cloth", [2] = "Leather", [3] = "Mail", [4] = "Plate",
    [6] = "Shields", [7] = "Librams", [8] = "Idols", [9] = "Totems",
}
ItemData.WEAPON_NAMES = {
    [0] = "One-handed axes", [1] = "Two-handed axes", [2] = "Bows", [3] = "Guns",
    [4] = "One-handed maces", [5] = "Two-handed maces", [6] = "Polearms",
    [7] = "One-handed swords", [8] = "Two-handed swords", [10] = "Staves",
    [13] = "Fist weapons", [15] = "Daggers", [16] = "Thrown weapons",
    [18] = "Crossbows", [19] = "Wands", [20] = "Fishing poles",
}

-- Proficiency spell per item subclass (classic spell IDs)
ItemData.ARMOR_SKILLS  = { [1] = 9078, [2] = 9077, [3] = 8737, [4] = 750, [6] = 9116 }
ItemData.WEAPON_SKILLS = {
    [0] = 196, [1] = 197, [2] = 264, [3] = 266, [4] = 198, [5] = 199, [6] = 200, [7] = 201,
    [8] = 202, [10] = 227, [13] = 15590, [15] = 1180, [16] = 2567, [18] = 5011, [19] = 5009,
}

local classArmor, classWeapons, plural = { [0] = true }, {}, "You"

function ItemData.Select(class)
    classArmor = { [0] = true }   -- rings, necks, trinkets, cloaks, held-in-off-hand items
    for sub, learn in pairs(class.armor or {}) do classArmor[sub] = learn end
    classWeapons = class.weapons or {}
    plural = class.plural or class.name
end

-- The proficiency spells can be trusted if the client knows one of the
-- armor skills the class has from level 1
local function ProficiencySpellsWork()
    if not IsPlayerSpell then return false end
    for sub in pairs(classArmor) do
        local skill = ItemData.ARMOR_SKILLS[sub]
        if skill and IsPlayerSpell(skill) then return true end
    end
    return false
end

-- Returns usable (bool), a reason when not usable, and the level from which
-- the class can learn the type when that is above the player's level (plate
-- and mail at 40, polearms at 20: the profile gives a level instead of true).
-- The class table comes first, so a type the class can never use (daggers
-- for a Paladin) says so instead of sounding trainable.
function ItemData.CanUse(info)
    local trust = ProficiencySpellsWork()
    local level = ns.Spec.GetLevel()
    if info.classID == ITEM_CLASS_ARMOR then
        local name = ItemData.ARMOR_NAMES[info.subclassID]
        local learn = classArmor[info.subclassID]
        if not learn then
            return false, ("%s can't use %s"):format(plural, name or "this armor type")
        end
        if type(learn) == "number" and level < learn then
            return false, ("%s can be worn from level %d"):format(name or "This armor", learn), learn
        end
        local skill = ItemData.ARMOR_SKILLS[info.subclassID]
        if trust and skill and not IsPlayerSpell(skill) then
            return false, "Can't wear " .. (name or "this armor") .. " yet"
        end
    elseif info.classID == ITEM_CLASS_WEAPON then
        local name = ItemData.WEAPON_NAMES[info.subclassID]
        local learn = classWeapons[info.subclassID]
        if not learn then
            return false, ("%s can't use %s"):format(plural, (name or "this weapon type"):lower())
        end
        if type(learn) == "number" and level < learn then
            return false, ("%s can be learned from level %d"):format(name or "This weapon type", learn), learn
        end
        local skill = ItemData.WEAPON_SKILLS[info.subclassID]
        if trust and skill and not IsPlayerSpell(skill) then
            return false, (name or "This weapon type") .. " not learned yet - visit a weapon master"
        end
    end
    return true
end
