-- WOWClassHelper smoke test: loads the addon in plain Lua 5.1 with a stubbed
-- WoW API and runs it through load, events, tooltips, commands, the mana bar
-- and combat ("secret values"), for every class.
--
-- Usage: lua5.1 tools/smoke-test.lua [addon root] [-v] [-t]
--   -v  also print what the addon writes to chat
--   -t  also print every rendered verdict tooltip
--
-- It catches runtime errors (nil values, typos, wrong widget methods, unknown
-- events) and checks the main verdicts. The Priest and Paladin checks come
-- from the WOWPriest and WOWPaladin smoke tests. It can't tell whether the
-- real WoW Forever client behaves like these stubs - that needs /wch debug.
-- The stubs are strict on purpose: unknown frame methods, unknown events and
-- script names, and SetBackdrop without BackdropTemplate raise errors.

local ROOT, VERBOSE, SHOW_TIPS = ".", false, false
for _, a in ipairs(arg or {}) do
    if a == "-v" then VERBOSE = true elseif a == "-t" then SHOW_TIPS = true else ROOT = a end
end
ROOT = ROOT:gsub("[\\/]+$", "")
local ADDON = "WOWClassHelper"

local realPrint = print

-- Bookkeeping -----------------------------------------------------------------

local results = { passed = 0, failed = 0, failures = {}, tests = 0 }
local currentTest = "?"
local printed = {}

local function fail(msg)
    results.failed = results.failed + 1
    table.insert(results.failures, currentTest .. ": " .. tostring(msg))
end

local function check(cond, msg)
    if cond then results.passed = results.passed + 1 else fail(msg) end
    return cond
end

local function eq(actual, expected, msg)
    return check(actual == expected, ("%s (expected %s, got %s)"):format(msg, tostring(expected), tostring(actual)))
end

local function near(actual, expected, msg)
    return check(type(actual) == "number" and math.abs(actual - expected) < 0.01,
        ("%s (expected %s, got %s)"):format(msg, tostring(expected), tostring(actual)))
end

local function test(name, fn)
    currentTest = name
    results.tests = results.tests + 1
    local before = results.failed
    printed = {}
    local ok, err = xpcall(fn, debug.traceback)
    if not ok then fail("ERROR " .. tostring(err)) end
    for _, line in ipairs(printed) do
        if line:find("error in ") or line:find("tooltip error") or line:find("import of old addon data failed") then
            fail("addon reported: " .. line)
        end
    end
    realPrint((results.failed == before and "PASS  " or "FAIL  ") .. name)
end

-- Secret values ------------------------------------------------------------------
-- Userdata that raises an error on arithmetic, comparison, concatenation.

local secretValues = setmetatable({}, { __mode = "k" })
local function secretError() error("attempt to use a secret value", 2) end

local function Secret(v)
    local p = newproxy(true)
    local mt = getmetatable(p)
    for _, ev in ipairs({ "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__unm",
                          "__concat", "__lt", "__le", "__len", "__call", "__index", "__newindex" }) do
        mt[ev] = secretError
    end
    mt.__tostring = function() return "<secret>" end
    secretValues[p] = v
    return p
end

-- World state ----------------------------------------------------------------------

local W

-- Spells a Priest knows in the Priest scenarios: Cloth, 1H Mace, Staff,
-- Dagger, Wand, Shoot, plus the talents Meditation (Disc) and Shadow Focus
-- (Shadow), so their points tie 1 : 1.
local PRIEST_KNOWN = {
    [9078] = true, [198] = true, [227] = true, [1180] = true, [5009] = true, [5019] = true,
    [14521] = true, [15260] = true,
}

local function ResetWorld(opts)
    opts = opts or {}
    W = {
        class = opts.class or "PRIEST",
        level = opts.level or 60,
        specIndex = opts.specIndex,          -- 1..3 or nil
        specIDs = opts.specIDs,              -- default: the profile's Forever IDs in spec order
        talentPoints = opts.talentPoints,    -- classic talent tabs { a, b, c } or nil
        traitRanks = opts.traitRanks,        -- Forever talent tree: { [nodeID] = ranks } or nil
        inCombat = false,
        secret = false,                      -- combat values are secret
        time = 1000,
        equipped = {},
        bags = { [0] = {} },
        bank = {},
        loot = {},
        merchant = {},
        uncached = {},
        pendingLoads = {},
        noLiveStats = false,
        known = opts.known,                  -- default: see LoadAddon
        hitModifier = opts.hitModifier or 0,   -- GetSpellHitModifier
        meleeHit = opts.meleeHit or 0,         -- GetHitModifier
        defenseBonus = opts.defenseBonus or 0, -- UnitDefense bonus
        mana = 3000, manaMax = 4000,
        frames = {},
        postCalls = {},
        lastMenu = nil,
    }
end

local function S(v)
    if W.inCombat and W.secret and type(v) == "number" then return Secret(v) end
    return v
end

-- Items ------------------------------------------------------------------------------

local ITEMS = {}
do
    local dataNs = {}
    local chunk = assert(loadfile(ROOT .. "/Data/Items.lua"))
    chunk(ADDON, dataNs)
    for id, item in pairs(dataNs.Items) do ITEMS[id] = item end
end

local function AddItem(id, item) ITEMS[id] = item end
-- From the WOWPriest smoke test
AddItem(90001, { name = "Test Leather Vest", quality = 2, ilvl = 25, reqLevel = 20, class = 4, subclass = 2, slot = "CHEST", stats = { AGILITY = 10, STAMINA = 8 }, armor = 120 })
AddItem(90002, { name = "Test Recurve Bow", quality = 2, ilvl = 25, reqLevel = 20, class = 2, subclass = 2, slot = "RANGED", stats = { AGILITY = 4 }, weapon = { min = 20, max = 38, speed = 2.8 } })
AddItem(90003, { name = "Test Cloth Robe", quality = 2, ilvl = 22, reqLevel = 18, class = 4, subclass = 1, slot = "ROBE", stats = { INTELLECT = 8, SPIRIT = 9, STAMINA = 5 }, armor = 40 })
AddItem(90004, { name = "Test Mace", quality = 2, ilvl = 22, reqLevel = 18, class = 2, subclass = 4, slot = "WEAPONMAINHAND", stats = { INTELLECT = 4 }, weapon = { min = 20, max = 38, speed = 2.4 } })
AddItem(90005, { name = "Test Shadow Ring", quality = 3, ilvl = 45, reqLevel = 40, class = 4, subclass = 0, slot = "FINGER", stats = { BONUS_STAT_SHADOW_DAMAGE_DONE = 12, STAMINA = 5 } })
AddItem(90006, { name = "Test Spirit Ring", quality = 2, ilvl = 28, reqLevel = 25, class = 4, subclass = 0, slot = "FINGER", stats = { SPIRIT = 8 } })
AddItem(90007, { name = "Test Held Orb", quality = 2, ilvl = 25, reqLevel = 20, class = 4, subclass = 0, slot = "HOLDABLE", stats = { INTELLECT = 6, SPIRIT = 4 } })
AddItem(90009, { name = "Test Plate Helm", quality = 2, ilvl = 45, reqLevel = 40, class = 4, subclass = 4, slot = "HEAD", stats = { STRENGTH = 12 }, armor = 400 })
AddItem(90010, { name = "Test Libram", quality = 3, ilvl = 50, reqLevel = 45, class = 4, subclass = 7, slot = "RELIC", stats = {} })
AddItem(90011, { name = "Test Late Item", quality = 2, ilvl = 20, reqLevel = 15, class = 4, subclass = 1, slot = "FEET", stats = { STAMINA = 3, SPIRIT = 3 }, armor = 20 })
AddItem(90012, { name = "Test Cheap Ring", quality = 1, ilvl = 10, reqLevel = 5, class = 4, subclass = 0, slot = "FINGER", stats = { STAMINA = 1 } })
AddItem(90013, { name = "Test Silk Cap", quality = 2, ilvl = 33, reqLevel = 30, class = 4, subclass = 1, slot = "HEAD", stats = { INTELLECT = 5, SPIRIT = 5 }, armor = 30 })
AddItem(90014, { name = "Test Linen Hood", quality = 1, ilvl = 8, reqLevel = 5, class = 4, subclass = 1, slot = "HEAD", stats = { STAMINA = 2 }, armor = 10 })
AddItem(90015, { name = "Test Fire Wand", quality = 2, ilvl = 13, reqLevel = 8, class = 2, subclass = 19, slot = "RANGEDRIGHT", stats = { BONUS_STAT_FIRE_DAMAGE_DONE = 1 }, weapon = { min = 11, max = 21, speed = 1.5 } })
AddItem(90016, { name = "Test Shadow Wand", quality = 2, ilvl = 13, reqLevel = 8, class = 2, subclass = 19, slot = "RANGEDRIGHT", stats = { BONUS_STAT_SHADOW_DAMAGE_DONE = 1 }, weapon = { min = 11, max = 21, speed = 1.5 } })
AddItem(90020, { name = "Test Linen Cloth", quality = 1, ilvl = 5, reqLevel = 0, class = 7, subclass = 5, slot = "NON_EQUIP_IGNORE", stats = {} })
-- From the WOWPaladin smoke test (Fixtures.lua), with the Soulforge pieces from Data/Items.lua
AddItem(90101, { name = "Test Helm of Might", quality = 2, ilvl = 50, reqLevel = 0, class = 4, subclass = 4, slot = "HEAD", sellPrice = 5000, stats = { STRENGTH = 15, STAMINA = 12 }, armor = 500 })
AddItem(90102, { name = "Test Pendant", quality = 2, ilvl = 50, reqLevel = 0, class = 4, subclass = 0, slot = "NECK", stats = { STRENGTH = 5, STAMINA = 8 } })
AddItem(90111, { name = "Test Band A", quality = 2, ilvl = 50, reqLevel = 0, class = 4, subclass = 0, slot = "FINGER", stats = { STRENGTH = 6 } })
AddItem(90112, { name = "Test Band B", quality = 2, ilvl = 50, reqLevel = 0, class = 4, subclass = 0, slot = "FINGER", stats = { STAMINA = 10 } })
AddItem(90113, { name = "Test Charm", quality = 2, ilvl = 50, reqLevel = 0, class = 4, subclass = 0, slot = "TRINKET", stats = { ATTACK_POWER = 30 } })
AddItem(90116, { name = "Test Greatsword", quality = 2, ilvl = 50, reqLevel = 0, class = 2, subclass = 8, slot = "TWOHWEAPON", stats = { STRENGTH = 15 }, weapon = { min = 100, max = 140, speed = 3 } })
AddItem(90121, { name = "Test Dagger", quality = 2, ilvl = 50, reqLevel = 0, class = 2, subclass = 15, slot = "WEAPON", stats = { AGILITY = 8 }, weapon = { min = 50, max = 70, speed = 2 } })
AddItem(90122, { name = "Test Robe of Wisdom", quality = 2, ilvl = 50, reqLevel = 0, class = 4, subclass = 1, slot = "ROBE", stats = { INTELLECT = 20, SPIRIT = 15, SPELL_HEALING_DONE = 30 }, armor = 80 })
AddItem(90123, { name = "Test Future Gauntlets", quality = 2, ilvl = 90, reqLevel = 99, class = 4, subclass = 4, slot = "HAND", stats = { STRENGTH = 25, STAMINA = 20 }, armor = 400 })
AddItem(90124, { name = "Test Tower Shield", quality = 2, ilvl = 50, reqLevel = 0, class = 4, subclass = 6, slot = "SHIELD", stats = { STAMINA = 20, DEFENSE_SKILL_RATING = 10, BLOCK_VALUE = 30 }, armor = 2000 })
AddItem(90125, { name = "Test Blade of Justice", quality = 2, ilvl = 50, reqLevel = 0, class = 2, subclass = 7, slot = "WEAPON", stats = { STRENGTH = 10 }, weapon = { min = 50, max = 70, speed = 2 } })
AddItem(90126, { name = "Test Ring of Accuracy", quality = 2, ilvl = 50, reqLevel = 0, class = 4, subclass = 0, slot = "FINGER", stats = { HIT_RATING = 15, STRENGTH = 5 } })
AddItem(90127, { name = "Test Linen Shirt", quality = 1, ilvl = 5, reqLevel = 0, class = 4, subclass = 0, slot = "BODY", stats = {} })
AddItem(90129, { name = "Test Rusty Helm", quality = 0, ilvl = 20, reqLevel = 0, class = 4, subclass = 4, slot = "HEAD", sellPrice = 50, stats = { STRENGTH = 2 }, armor = 100 })
AddItem(90130, { name = "Test Equal Helm", quality = 2, ilvl = 50, reqLevel = 0, class = 4, subclass = 4, slot = "HEAD", stats = { STRENGTH = 15, STAMINA = 12 }, armor = 500 })
AddItem(90131, { name = "Test Halberd", quality = 2, ilvl = 18, reqLevel = 14, class = 2, subclass = 6, slot = "TWOHWEAPON", stats = { STRENGTH = 9, STAMINA = 6 }, weapon = { min = 40, max = 60, speed = 3.4 } })
-- New for the other classes
AddItem(90201, { name = "Test Mail Vest", quality = 2, ilvl = 33, reqLevel = 30, class = 4, subclass = 3, slot = "CHEST", stats = { AGILITY = 10, STAMINA = 10, INTELLECT = 5 }, armor = 300 })
AddItem(90202, { name = "Test Plate Chest", quality = 2, ilvl = 38, reqLevel = 35, class = 4, subclass = 4, slot = "CHEST", stats = { STRENGTH = 15, STAMINA = 12 }, armor = 600 })
AddItem(90203, { name = "Test Leather Hood", quality = 2, ilvl = 30, reqLevel = 25, class = 4, subclass = 2, slot = "HEAD", stats = { AGILITY = 8, STAMINA = 6 }, armor = 90 })
AddItem(90204, { name = "Test Longbow", quality = 2, ilvl = 30, reqLevel = 25, class = 2, subclass = 2, slot = "RANGED", stats = { AGILITY = 5 }, weapon = { min = 50, max = 62, speed = 2.8 } })
AddItem(90205, { name = "Test Blunderbuss", quality = 2, ilvl = 30, reqLevel = 25, class = 2, subclass = 3, slot = "RANGEDRIGHT", stats = { AGILITY = 4 }, weapon = { min = 40, max = 60, speed = 2.5 } })
AddItem(90206, { name = "Test Claw", quality = 2, ilvl = 30, reqLevel = 25, class = 2, subclass = 13, slot = "WEAPON", stats = { AGILITY = 6, STRENGTH = 4 }, weapon = { min = 40, max = 60, speed = 2 } })
AddItem(90207, { name = "Test Greataxe", quality = 2, ilvl = 30, reqLevel = 25, class = 2, subclass = 1, slot = "TWOHWEAPON", stats = { STRENGTH = 18, STAMINA = 10 }, weapon = { min = 110, max = 160, speed = 3.6 } })
AddItem(90208, { name = "Test Staff of Power", quality = 2, ilvl = 30, reqLevel = 25, class = 2, subclass = 10, slot = "TWOHWEAPON", stats = { INTELLECT = 15, SPELL_POWER = 20 }, weapon = { min = 60, max = 90, speed = 3 } })
AddItem(90209, { name = "Test Idol", quality = 3, ilvl = 50, reqLevel = 45, class = 4, subclass = 8, slot = "RELIC", stats = {} })
AddItem(90210, { name = "Test Totem", quality = 3, ilvl = 50, reqLevel = 45, class = 4, subclass = 9, slot = "RELIC", stats = {} })
AddItem(90211, { name = "Test Shortsword", quality = 2, ilvl = 30, reqLevel = 25, class = 2, subclass = 7, slot = "WEAPON", stats = { AGILITY = 7 }, weapon = { min = 35, max = 55, speed = 2 } })
AddItem(90212, { name = "Test Nature Ring", quality = 2, ilvl = 30, reqLevel = 25, class = 4, subclass = 0, slot = "FINGER", stats = { BONUS_STAT_NATURE_DAMAGE_DONE = 10, STAMINA = 4 } })
AddItem(90213, { name = "Test Healer Necklace", quality = 2, ilvl = 30, reqLevel = 25, class = 4, subclass = 0, slot = "NECK", stats = { SPELL_HEALING_DONE = 20, MANA_REGENERATION = 3 } })
AddItem(90214, { name = "Test Hand Axe", quality = 2, ilvl = 30, reqLevel = 25, class = 2, subclass = 0, slot = "WEAPON", stats = { AGILITY = 5, STRENGTH = 3 }, weapon = { min = 40, max = 58, speed = 2.6 } })
AddItem(90215, { name = "Test Throwing Knives", quality = 2, ilvl = 30, reqLevel = 25, class = 2, subclass = 16, slot = "THROWN", stats = {}, weapon = { min = 20, max = 30, speed = 2 } })
AddItem(90216, { name = "Test Hunter Spaulders", quality = 2, ilvl = 30, reqLevel = 25, class = 4, subclass = 2, slot = "SHOULDER", stats = { AGILITY = 6, INTELLECT = 6, STAMINA = 4 }, armor = 80 })

local SLOT_TO_LOC = { TWOHWEAPON = "INVTYPE_2HWEAPON" }

local STAT_KEYS = {
    INTELLECT = "ITEM_MOD_INTELLECT_SHORT", STAMINA = "ITEM_MOD_STAMINA_SHORT",
    SPIRIT = "ITEM_MOD_SPIRIT_SHORT", STRENGTH = "ITEM_MOD_STRENGTH_SHORT", AGILITY = "ITEM_MOD_AGILITY_SHORT",
    HIT_RATING = "ITEM_MOD_HIT_RATING_SHORT", CRIT_RATING = "ITEM_MOD_CRIT_RATING_SHORT",
    HASTE_RATING = "ITEM_MOD_HASTE_RATING_SHORT", SPELL_POWER = "ITEM_MOD_SPELL_POWER_SHORT",
    SPELL_HEALING_DONE = "ITEM_MOD_SPELL_HEALING_DONE_SHORT", MANA_REGENERATION = "ITEM_MOD_POWER_REGEN0_SHORT",
    ATTACK_POWER = "ITEM_MOD_ATTACK_POWER_SHORT", DEFENSE_SKILL_RATING = "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT",
    BLOCK_VALUE = "ITEM_MOD_BLOCK_VALUE_SHORT",
    BONUS_STAT_SHADOW_DAMAGE_DONE = "ITEM_MOD_BONUS_STAT_SHADOW_DAMAGE_DONE_SHORT",
    BONUS_STAT_FIRE_DAMAGE_DONE = "ITEM_MOD_BONUS_STAT_FIRE_DAMAGE_DONE_SHORT",
    BONUS_STAT_NATURE_DAMAGE_DONE = "ITEM_MOD_BONUS_STAT_NATURE_DAMAGE_DONE_SHORT",
    FIRE_RESISTANCE = "RESISTANCE2_NAME", NATURE_RESISTANCE = "RESISTANCE3_NAME",
    FROST_RESISTANCE = "RESISTANCE4_NAME", SHADOW_RESISTANCE = "RESISTANCE5_NAME",
    ARCANE_RESISTANCE = "RESISTANCE6_NAME",
}

local function ItemID(linkOrID)
    if type(linkOrID) == "number" then return linkOrID end
    return tonumber(tostring(linkOrID):match("item:(%-?%d+)") or linkOrID)
end

local function Link(id, suffix)
    local item = ITEMS[id]
    return ("|cff1eff00|Hitem:%d:0:0:0:0:0:%s:0:%d|h[%s]|h|r"):format(id, tostring(suffix or 0), W.level,
        item and item.name or "Item")
end

local function GearStat(stat)
    local total = 0
    for _, link in pairs(W.equipped) do
        local item = ITEMS[ItemID(link)]
        total = total + (item and item.stats and item.stats[stat] or 0)
    end
    return total
end

-- Ratings: the "real" client uses 12 hit rating per 1% at 60, so tests can
-- tell the client conversion from the addon's estimate (10 per 1%).
local CR = {
    CR_DEFENSE_SKILL = 2, CR_DODGE = 3, CR_PARRY = 4, CR_BLOCK = 5,
    CR_HIT_MELEE = 6, CR_HIT_RANGED = 7, CR_HIT_SPELL = 8, CR_CRIT_MELEE = 9, CR_CRIT_RANGED = 10,
    CR_CRIT_SPELL = 11, CR_HASTE_MELEE = 18, CR_HASTE_RANGED = 19, CR_HASTE_SPELL = 20,
    CR_MASTERY = 26, CR_VERSATILITY_DAMAGE_DONE = 29,
}
local RATING_STAT = { [6] = "HIT_RATING", [7] = "HIT_RATING", [8] = "HIT_RATING", [9] = "CRIT_RATING",
                      [10] = "CRIT_RATING", [11] = "CRIT_RATING", [18] = "HASTE_RATING", [19] = "HASTE_RATING",
                      [20] = "HASTE_RATING" }
local TRUE_PER60 = { HIT_RATING = 12, CRIT_RATING = 14, HASTE_RATING = 10 }
local function TruePctPerRating(stat)
    local level = math.min(math.max(W.level, 10), 60)
    return 1 / ((TRUE_PER60[stat] or 10) * (level - 8) / 52)
end

-- Widgets ------------------------------------------------------------------------

local KNOWN_EVENTS = {}
for _, e in ipairs({
    "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP",
    "PLAYER_TALENT_UPDATE", "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
    "UNIT_STATS", "GET_ITEM_INFO_RECEIVED", "BAG_UPDATE_DELAYED", "LOOT_READY", "MERCHANT_SHOW",
    "BANKFRAME_OPENED", "CHAT_MSG_LOOT", "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER",
    "UNIT_SPELLCAST_SUCCEEDED", "UNIT_DISPLAYPOWER", "SPELLS_CHANGED", "TRAIT_CONFIG_UPDATED",
}) do KNOWN_EVENTS[e] = true end

local KNOWN_SCRIPTS = {}
for _, s in ipairs({ "OnEvent", "OnUpdate", "OnDragStart", "OnDragStop", "OnEscapePressed", "OnHide",
                     "OnShow", "OnEnter", "OnLeave", "OnTooltipCleared", "OnTooltipSetItem", "OnClick" }) do
    KNOWN_SCRIPTS[s] = true
end

-- The addon registers some events inside pcall (clients may not know them),
-- which hides the error; every attempt is recorded and checked at the end.
local unknownEvents = {}

local Methods = {}
local function NewWidget(kind, name, parent, template)
    local w = setmetatable({
        __kind = kind, __name = name, __parent = parent, __template = template or "",
        __events = {}, __unitEvents = {}, __scripts = {}, __hooks = {}, __shown = true,
        __points = {}, __lines = {},
    }, { __index = Methods })
    if kind == "GameTooltip" then w.__shown = false end
    table.insert(W.frames, w)
    if name then _G[name] = w end
    return w
end

function Methods:RegisterEvent(event)
    if not KNOWN_EVENTS[event] then
        unknownEvents[tostring(event)] = true
        error("unknown event " .. tostring(event), 2)
    end
    self.__events[event] = true
end
function Methods:RegisterUnitEvent(event, unit)
    if not KNOWN_EVENTS[event] then
        unknownEvents[tostring(event)] = true
        error("unknown event " .. tostring(event), 2)
    end
    self.__unitEvents[event] = unit
end
function Methods:UnregisterEvent(event) self.__events[event] = nil; self.__unitEvents[event] = nil end
function Methods:SetScript(name, fn)
    if not KNOWN_SCRIPTS[name] then error("unknown script " .. tostring(name), 2) end
    self.__scripts[name] = fn
end
function Methods:GetScript(name) return self.__scripts[name] end
function Methods:HookScript(name, fn)
    if not KNOWN_SCRIPTS[name] then error("unknown script " .. tostring(name), 2) end
    self.__hooks[name] = self.__hooks[name] or {}
    table.insert(self.__hooks[name], fn)
end
function Methods:HasScript(name)
    if name == "OnTooltipCleared" or name == "OnTooltipSetItem" then return self.__kind == "GameTooltip" end
    return KNOWN_SCRIPTS[name] or false
end
local function RunScript(w, name, ...)
    if w.__scripts[name] then w.__scripts[name](w, ...) end
    for _, fn in ipairs(w.__hooks[name] or {}) do fn(w, ...) end
end
function Methods:Show() self.__shown = true; RunScript(self, "OnShow") end
function Methods:Hide()
    local was = self.__shown
    self.__shown = false
    if was then RunScript(self, "OnHide") end
end
function Methods:SetShown(shown) if shown then self:Show() else self:Hide() end end
function Methods:IsShown() return self.__shown end
function Methods:IsVisible()
    local w = self
    while w do
        if not w.__shown then return false end
        w = w.__parent
    end
    return true
end
function Methods:SetSize(w, h) self.__w, self.__h = w, h end
function Methods:SetWidth(w) self.__w = w end
function Methods:SetHeight(h) self.__h = h end
function Methods:GetWidth()
    if self.__kind == "GameTooltip" then return self.__w or 320 end
    return self.__w or 100
end
function Methods:GetHeight()
    if self.__kind == "GameTooltip" then return 14 * #self.__lines + 20 end
    return self.__h or 20
end
function Methods:GetBottom() return self.__bottom or 400 end
function Methods:GetTop() return self:GetBottom() + self:GetHeight() end
function Methods:GetLeft() return self.__left or 100 end
function Methods:GetRight() return self.__right or (self:GetLeft() + self:GetWidth()) end
function Methods:GetEffectiveScale() return self.__scale or 1 end
function Methods:SetPoint(...) table.insert(self.__points, { ... }) end
function Methods:ClearAllPoints() self.__points = {} end
function Methods:GetPoint()
    local p = self.__points[1] or { "CENTER", nil, "CENTER", 0, 0 }
    return p[1], p[2], p[3], p[4], p[5]
end
function Methods:GetName() return self.__name end
function Methods:GetParent() return self.__parent end
function Methods:SetMovable() end
function Methods:EnableMouse(on) self.__mouse = on end
function Methods:RegisterForDrag() end
function Methods:StartMoving() end
function Methods:StopMovingOrSizing() end
function Methods:SetFrameStrata() end
function Methods:SetClampedToScreen() end
local function NeedBackdrop(self)
    if not self.__template:find("BackdropTemplate") then error("SetBackdrop* needs BackdropTemplate", 3) end
end
function Methods:SetBackdrop() NeedBackdrop(self) end
function Methods:SetBackdropColor() NeedBackdrop(self) end
function Methods:SetBackdropBorderColor() NeedBackdrop(self) end
function Methods:CreateTexture() return NewWidget("Texture", nil, self) end
function Methods:CreateFontString() return NewWidget("FontString", nil, self) end
function Methods:SetColorTexture() end
-- StatusBar
function Methods:SetStatusBarTexture() end
function Methods:SetStatusBarColor(r, g, b) self.__color = { r, g, b } end
function Methods:SetMinMaxValues(lo, hi) self.__min, self.__max = lo, hi end
function Methods:SetValue(v) self.__value = v end
function Methods:GetValue() return self.__value end
-- FontString / EditBox
function Methods:SetText(t) self.__text = t end
function Methods:GetText() return self.__text end
function Methods:SetFormattedText(fmt, ...) self.__text = string.format(fmt, ...) end
function Methods:SetMultiLine() end
function Methods:SetMaxLetters() end
function Methods:SetFontObject() end
function Methods:SetAutoFocus() end
function Methods:SetFocus() end
function Methods:HighlightText() end
function Methods:SetScrollChild(child) self.__child = child end
-- GameTooltip
function Methods:SetOwner(owner) self.__owner = owner; self.__lines = {} end
function Methods:GetOwner() return self.__owner end
function Methods:AddLine(text) table.insert(self.__lines, tostring(text)) end
function Methods:AddDoubleLine(l, r) table.insert(self.__lines, tostring(l) .. " || " .. tostring(r)) end
function Methods:NumLines() return #self.__lines end
function Methods:GetItem() return self.__itemName, self.__itemLink end

function CreateFrame(kind, name, parent, template)
    if template == "UIPanelScrollFrameTemplate" or template == "UIPanelCloseButton"
        or template == "GameTooltipTemplate" or template == "BackdropTemplate" or template == nil
        or template == "ScrollFrameTemplate" then
        return NewWidget(kind, name, parent, template)
    end
    error("unknown template " .. tostring(template), 2)
end

local function FireEvent(event, ...)
    for _, w in ipairs(W.frames) do
        local unit = w.__unitEvents[event]
        if w.__events[event] or (unit and unit == (...)) then
            RunScript(w, "OnEvent", event, ...)
        end
    end
end

local function Tick(seconds)
    local steps = math.floor(seconds / 0.1 + 0.5)
    for _ = 1, steps do
        W.time = W.time + 0.1
        for _, w in ipairs(W.frames) do
            if (w.__scripts.OnUpdate or w.__hooks.OnUpdate) and w:IsVisible() then RunScript(w, "OnUpdate", 0.1) end
        end
    end
end

-- Menu (MenuUtil.CreateContextMenu)
local function NewMenuRoot()
    local root = { entries = {} }
    local function add(kind, text, a, b) table.insert(root.entries, { kind = kind, text = text, a = a, b = b }) end
    function root:CreateTitle(text) add("title", text) end
    function root:CreateDivider() add("divider") end
    function root:CreateRadio(text, isSelected, setSelected) add("radio", text, isSelected, setSelected) end
    function root:CreateCheckbox(text, isSelected, setSelected) add("checkbox", text, isSelected, setSelected) end
    function root:CreateButton(text, onClick) add("button", text, onClick) end
    return root
end

-- API stubs -----------------------------------------------------------------------

local API_GLOBALS = {}

local function InstallAPI(missing)
    missing = missing or {}
    local g = {}

    g.print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
        local line = table.concat(parts, " ")
        table.insert(printed, line)
        if VERBOSE then realPrint("    | " .. line) end
    end
    g.strtrim = function(s) return (tostring(s or ""):match("^%s*(.-)%s*$")) end
    g.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    g.date = os.date
    g.time = function() return math.floor(W.time) end
    g.GetTime = function() return W.time end
    g.issecretvalue = function(v) return secretValues[v] ~= nil end
    g.SlashCmdList = {}
    g.UISpecialFrames = {}
    g.ChatFontNormal = {}
    g.WOW_PROJECT_ID = 1
    g.NUM_BAG_SLOTS = 4
    g.NUM_BANKBAGSLOTS = 7
    g.ITEM_QUALITY_COLORS = {}
    for q = 0, 7 do g.ITEM_QUALITY_COLORS[q] = { hex = "|cffffffff" } end
    g.ITEM_MOD_INTELLECT_SHORT = "Intellect"
    g.ITEM_MOD_STAMINA_SHORT = "Stamina"
    g.ITEM_MOD_SPIRIT_SHORT = "Spirit"
    g.ITEM_MOD_SPELL_POWER_SHORT = "Spell Power"
    g.ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "Damage Per Second"
    for name, value in pairs(CR) do g[name] = value end

    g.Enum = {
        PowerType = { Mana = 0, Rage = 1, Focus = 2, Energy = 3, HolyPower = 9 },
        TooltipDataType = { Item = 0 },
        BagIndex = { Bank = -1 },
    }

    g.GetBuildInfo = function() return "1.60.1", "70399", "Nov 1 2026", 16001 end
    g.UnitClass = function() return W.class:sub(1, 1) .. W.class:sub(2):lower(), W.class end
    g.UnitName = function(unit) return unit == "npc" and "Vendor Bob" or "Testchar" end
    g.UnitLevel = function() return W.level end
    g.InCombatLockdown = function() return W.inCombat end
    g.GetMaxLevelForPlayerExpansion = function() return 60 end
    g.IsPlayerSpell = function(id) return W.known[id] == true end
    g.GetRealZoneText = function() return "Elwynn Forest" end

    g.GetSpecialization = function() return W.specIndex end
    g.GetSpecializationInfo = function(index) return W.specIDs[index], "Spec" .. index end
    g.GetNumTalentTabs = function() return W.talentPoints and 3 or 0 end
    -- Forever's talent tree (one tree, three spec sections); ranks are secret in combat
    g.C_ClassTalents = { GetActiveConfigID = function() return W.traitRanks and 4711 or nil end }
    g.C_Traits = {
        GetNodeInfo = function(configID, nodeID)
            if configID ~= 4711 then error("GetNodeInfo: wrong config " .. tostring(configID)) end
            local rank = W.traitRanks[nodeID]
            if not rank then return { ID = 0, ranksPurchased = 0, activeRank = 0, maxRanks = 0 } end
            return { ID = nodeID, ranksPurchased = S(rank), activeRank = S(rank), maxRanks = 5 }
        end,
    }
    g.GetTalentTabInfo = function(tab)
        return "Tab" .. tab, "icon", W.talentPoints and W.talentPoints[tab] or 0
    end

    g.UnitStat = function(_, i)
        local names = { "STRENGTH", "AGILITY", "STAMINA", "INTELLECT", "SPIRIT" }
        local v = 20 + GearStat(names[i])
        return S(v), S(v), 0, 0
    end
    g.UnitArmor = function() return S(100), S(100) end
    g.UnitDefense = function() return S(5 * W.level), S(W.defenseBonus) end
    g.UnitPower = function() return S(W.mana) end
    g.UnitPowerMax = function() return S(W.manaMax) end
    g.UnitPowerType = function() return 0, "MANA" end
    g.GetManaRegen = function() return S(10), S(3) end
    g.GetSpellBonusDamage = function() return S(GearStat("SPELL_POWER") + GearStat("BONUS_STAT_SHADOW_DAMAGE_DONE")) end
    g.GetSpellBonusHealing = function() return S(GearStat("SPELL_POWER") + GearStat("SPELL_HEALING_DONE")) end
    g.GetSpellHitModifier = function() return S(W.hitModifier) end
    g.GetHitModifier = function() return S(W.meleeHit) end
    g.GetCombatRating = function(cr) local s = RATING_STAT[cr]; return S(s and GearStat(s) or 0) end
    g.GetCombatRatingBonus = function(cr)
        local s = RATING_STAT[cr]
        return S(s and GearStat(s) * TruePctPerRating(s) or 0)
    end
    g.GetCombatRatingBonusForCombatRatingValue = function(cr, value)
        local s = RATING_STAT[cr]
        return S(s and value * TruePctPerRating(s) or 0)
    end

    g.GetInventoryItemLink = function(_, slot) return W.equipped[slot] end

    local function GetItemInfo(linkOrID)
        local id = ItemID(linkOrID)
        local item = id and ITEMS[id]
        if not item or W.uncached[id] then return nil end
        local loc = SLOT_TO_LOC[item.slot] or ("INVTYPE_" .. item.slot)
        return item.name, Link(id), item.quality, item.ilvl, item.reqLevel, "Type", "SubType", 1, loc,
            item.icon or 134400, item.sellPrice or (item.quality or 1) * 100, item.class, item.subclass,
            1, 0, item.setID, false
    end
    local function GetItemStats(link)
        local id = ItemID(link)
        local item = id and ITEMS[id]
        if not item or W.noLiveStats then return {} end
        local stats = {}
        for stat, value in pairs(item.stats or {}) do
            local key = STAT_KEYS[stat]
            if not key then error("smoke test: no game key for stat " .. stat) end
            stats[key] = value
        end
        if item.armor then stats.RESISTANCE0_NAME = item.armor end
        if item.weapon then
            stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT = (item.weapon.min + item.weapon.max) / 2 / item.weapon.speed
        end
        return stats
    end
    g.C_Item = {
        GetItemInfo = GetItemInfo,
        GetItemStats = GetItemStats,
        GetDetailedItemLevelInfo = function(link) local id = ItemID(link); return ITEMS[id] and ITEMS[id].ilvl end,
    }
    -- Classic globals, used when C_Item is missing
    g.GetItemInfo, g.GetItemStats = GetItemInfo, GetItemStats
    g.Item = {
        CreateFromItemLink = function(_, link)
            local obj = { link = link }
            function obj:IsItemEmpty() return false end
            function obj:ContinueOnItemLoad(cb) table.insert(W.pendingLoads, cb) end
            return obj
        end,
    }

    g.C_Spell = {
        GetSpellPowerCost = function(id)
            if id == 5019 or id == 6603 or id == 75 then return {} end
            if W.inCombat and W.secret then return { { type = Secret(0), cost = Secret(25) } } end
            return { { type = 0, cost = 25, name = "MANA" } }
        end,
    }

    g.C_Container = {
        GetContainerNumSlots = function(bag)
            local list = (bag == -1 or bag > 4) and W.bank[bag] or W.bags[bag]
            return list and #list or 0
        end,
        GetContainerItemLink = function(bag, slot)
            local list = (bag == -1 or bag > 4) and W.bank[bag] or W.bags[bag]
            return list and list[slot]
        end,
    }
    g.GetNumLootItems = function() return #W.loot end
    g.GetLootSlotLink = function(i) return W.loot[i] end
    g.GetMerchantNumItems = function() return #W.merchant end
    g.GetMerchantItemLink = function(i) return W.merchant[i] and W.merchant[i].link end
    g.GetMerchantItemInfo = function(i) return "Item", 134400, W.merchant[i] and W.merchant[i].price end

    g.TooltipDataProcessor = {
        AddTooltipPostCall = function(kind, fn)
            W.postCalls[kind] = W.postCalls[kind] or {}
            table.insert(W.postCalls[kind], fn)
        end,
    }
    g.TooltipUtil = {
        GetDisplayedItem = function(tooltip) return tooltip.__itemName, tooltip.__itemLink end,
    }
    g.C_TooltipInfo = {
        GetInventoryItem = function(_, slot)
            local link = W.equipped[slot]
            if not link then return nil end
            return { lines = { { leftText = ITEMS[ItemID(link)].name }, { leftText = "|cff1eff00Equip: something|r" } } }
        end,
    }
    g.MenuUtil = {
        CreateContextMenu = function(owner, generator)
            local root = NewMenuRoot()
            generator(owner, root)
            W.lastMenu = root
        end,
    }
    g.AddonCompartmentFrame = {}

    g.CreateFrame = CreateFrame

    for _, name in ipairs(missing) do
        local tbl, key = name:match("^(.-)%.(.+)$")
        if tbl then g[tbl][key] = nil else g[name] = nil end
    end

    for name in pairs(API_GLOBALS) do _G[name] = nil end
    API_GLOBALS = {}
    for name, value in pairs(g) do
        _G[name] = value
        API_GLOBALS[name] = true
    end
end

-- Loading ---------------------------------------------------------------------------

local function TocFiles()
    local files = {}
    for line in io.lines(ROOT .. "/" .. ADDON .. ".toc") do
        line = line:gsub("\r", ""):match("^%s*(.-)%s*$")
        if line ~= "" and not line:find("^#") then table.insert(files, (line:gsub("\\", "/"))) end
    end
    return files
end

-- Proficiency spells for everything the class can use at the world's level
local function TrainedSpells(ns, class)
    local known = {}
    local profile = ns.Classes[class]
    if not profile then return known end
    local function add(list, skills)
        for sub, learn in pairs(list or {}) do
            if skills[sub] and (learn == true or W.level >= learn) then known[skills[sub]] = true end
        end
    end
    add(profile.armor, ns.ItemData.ARMOR_SKILLS)
    add(profile.weapons, ns.ItemData.WEAPON_SKILLS)
    known[9078] = true
    if profile.dualWield and (profile.dualWield == true or W.level >= profile.dualWield) then known[674] = true end
    return known
end

-- Fresh world, fresh API, addon files loaded in TOC order. Returns ns.
local function LoadAddon(opts)
    opts = opts or {}
    ResetWorld(opts)
    InstallAPI(opts.missing)
    UIParent = NewWidget("Frame", "UIParent")
    GameTooltip = NewWidget("GameTooltip", "GameTooltip", UIParent, "GameTooltipTemplate")
    ItemRefTooltip = NewWidget("GameTooltip", "ItemRefTooltip", UIParent, "GameTooltipTemplate")
    -- "Currently equipped" comparison tooltips; Retail lists them on GameTooltip
    NewWidget("GameTooltip", "ShoppingTooltip1", UIParent, "GameTooltipTemplate")
    NewWidget("GameTooltip", "ShoppingTooltip2", UIParent, "GameTooltipTemplate")
    NewWidget("GameTooltip", "ItemRefShoppingTooltip1", UIParent, "GameTooltipTemplate")
    NewWidget("GameTooltip", "ItemRefShoppingTooltip2", UIParent, "GameTooltipTemplate")
    GameTooltip.shoppingTooltips = { ShoppingTooltip1, ShoppingTooltip2 }
    MerchantFrame = NewWidget("Frame", "MerchantFrame", UIParent)
    MerchantFrame.__shown = false
    LootFrame = NewWidget("Frame", "LootFrame", UIParent)
    LootFrame.__shown = false
    GroupLootContainer = NewWidget("Frame", "GroupLootContainer", UIParent)
    WOWClassHelperDB = opts.savedVars
    WOWClassHelperCharDB = opts.charVars
    WOWPriestDB = opts.oldPriestDB
    WOWPaladinDB = opts.oldPaladinDB
    SLASH_WOWCLASSHELPER1, SLASH_WOWCLASSHELPER2 = nil, nil

    local ns = {}
    for _, file in ipairs(TocFiles()) do
        local chunk, err = loadfile(ROOT .. "/" .. file)
        if not chunk then error("load " .. file .. ": " .. tostring(err)) end
        chunk(ADDON, ns)
    end
    local profile = ns.Classes[W.class]
    if not W.known then
        W.known = W.class == "PRIEST" and {} or TrainedSpells(ns, W.class)
        if W.class == "PRIEST" then for id in pairs(PRIEST_KNOWN) do W.known[id] = true end end
    end
    if not W.specIDs then
        W.specIDs = {}
        for i, s in ipairs(profile and profile.specs or {}) do W.specIDs[i] = s.id end
    end
    if profile and not profile.mana then W.mana, W.manaMax = 0, 0 end
    return ns
end

local function Boot(ns)
    FireEvent("ADDON_LOADED", "SomeOtherAddon")
    FireEvent("ADDON_LOADED", ADDON)
    FireEvent("PLAYER_LOGIN")
    FireEvent("PLAYER_ENTERING_WORLD", true, false)
    return ns
end

local function Equip(slot, id)
    W.equipped[slot] = id and Link(id) or nil
    FireEvent("PLAYER_EQUIPMENT_CHANGED", slot, id == nil)
end

local function Slash(msg) SlashCmdList.WOWCLASSHELPER(msg) end

local function Printed(pattern)
    for _, line in ipairs(printed) do
        if line:find(pattern, 1, true) then return line end
    end
    return nil
end

local function Plain(line)
    return (line:gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", ""))
end

-- Hover an item: GameTooltip shows it, post-calls run. Returns the verdict
-- tooltip's lines (empty if hidden).
local function Hover(ns, link, owner, tooltip)
    tooltip = tooltip or GameTooltip
    tooltip.__itemLink = link
    tooltip.__itemName = link and link:match("%[(.-)%]")
    tooltip.__owner = owner or UIParent
    tooltip:Show()
    for _, fn in ipairs(W.postCalls[0] or {}) do fn(tooltip, {}) end
    for _, fn in ipairs(tooltip.__hooks.OnTooltipSetItem or {}) do fn(tooltip) end
    local tip = ns.VerdictTooltip.frames[tooltip]
    if not tip or not tip.__shown then return {} end
    if SHOW_TIPS then
        realPrint(("    +-- %s (%s %d)"):format(tostring(tooltip.__itemName), W.class, W.level))
        for _, line in ipairs(tip.__lines) do realPrint("    | " .. Plain(line)) end
    end
    return tip.__lines
end

local function HasLine(lines, text)
    for _, line in ipairs(lines) do
        if line:find(text, 1, true) then return line end
    end
    return nil
end

-- Same, on the text without color and icon codes
local function HasPlain(lines, text)
    for _, line in ipairs(lines) do
        if Plain(line):find(text, 1, true) then return Plain(line) end
    end
    return nil
end

-- Rows of the "Best ... seen" list, and the one marked as the hovered item
local function ListRows(lines)
    local rows, marked = {}, nil
    for _, line in ipairs(lines) do
        if line:find("^> %d+%. ") then marked = line end
        if line:find("^> %d+%. ") or line:find("^   %d+%. ") then rows[#rows + 1] = line end
    end
    return rows, marked
end

local function Evaluate(ns, id, context)
    local info = ns.ItemData.Parse(Link(id))
    return ns.Compare.Evaluate(info, context)
end

local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

-- Tests: loading ------------------------------------------------------------------------

realPrint(("WOWClassHelper smoke test - %s, addon at %s"):format(_VERSION, ROOT))

local ns

test("addon files load in TOC order", function()
    ns = LoadAddon()
    check(#TocFiles() >= 20, "TOC lists the addon files")
    for _, name in ipairs({ "Spec", "Weights", "ItemData", "Character", "SetBonus", "KB", "Compare",
                            "VerdictTooltip", "Debug", "Compartment", "ManaBar" }) do
        check(ns[name] ~= nil, "ns." .. name .. " exists")
    end
    check(ns.Items and ns.Items[22514] and ns.Items[22091], "exported items loaded (Priest and Paladin)")
    check(ns.SetData and ns.SetData.Sets[525] and ns.SetData.Sets[516], "exported sets loaded")
    for _, class in ipairs(CLASSES) do
        check(ns.Classes[class] ~= nil, "profile for " .. class)
        check(ns.TalentData[class] ~= nil, "talent tree for " .. class)
    end
    eq(#ns.modules, 4, "registered modules")
end)

test("boot as a Priest", function()
    Boot(ns)
    check(type(WOWClassHelperDB) == "table" and ns.db == WOWClassHelperDB, "saved variables created")
    check(type(WOWClassHelperCharDB) == "table" and ns.char == WOWClassHelperCharDB, "per-character saved variables created")
    eq(ns.char.specOverride, false, "spec override per character")
    check(ns.char.owned and ns.char.owned.bags, "bags per character")
    eq(ns.db.manaBar.timer, true, "default mana bar timer")
    eq(ns.db.tooltip.enabled, true, "default tooltip enabled")
    eq(ns.classToken, "PRIEST", "class detected")
    check(Printed("loaded for Priest. Type /wch"), "login message printed")
    check(ns.ManaBar.frame and not ns.ManaBar.frame:IsShown(), "mana bar created, hidden by default")
    check(W.postCalls[0] and #W.postCalls[0] == 1, "tooltip post-call registered")
    eq(SLASH_WOWCLASSHELPER1, "/wch", "slash command")
end)

test("saved variables from an older version get new defaults", function()
    ns = LoadAddon({ savedVars = { manaBar = { shown = false }, specOverride = "HOLY",
        kb = { items = {}, owned = { bags = { ["1"] = 1 }, bank = {} } } } })
    Boot(ns)
    eq(ns.db.manaBar.shown, false, "existing value kept")
    eq(ns.db.manaBar.locked, false, "missing value added")
    eq(ns.db.tooltip.maxStatLines, 4, "missing table added")
    eq(ns.ManaBar.frame:IsShown(), false, "hidden mana bar stays hidden")
    eq(ns.db.kb.owned, nil, "account-wide bag contents of the old addons dropped")
    eq(ns.Spec.Get(), "SHADOW", "an account-wide spec override doesn't apply to characters")
end)

test("classes without a profile stay silent", function()
    ns = LoadAddon({ class = "MONK" })
    Boot(ns)
    check(Printed("no profile for the class MONK"), "one line explains it")
    check(not Printed("loaded for"), "no login message")
    check(ns.ManaBar.frame == nil, "no mana bar")
    check(W.postCalls[0] == nil, "no tooltip hook")
    eq(#Hover(ns, Link(22514)), 0, "no verdict tooltip")
    Slash("stats")
    check(Printed("no profile for the class MONK yet"), "commands explain it too")
end)

-- Tests: Priest (from WOWPriest) ----------------------------------------------------------

test("Priest: spec detection", function()
    local cases = {
        { { specIndex = 1 }, "DISCIPLINE", "specialization" },
        { { specIndex = 2 }, "HOLY", "specialization" },
        { { specIndex = 3 }, "SHADOW", "specialization" },
        { { specIndex = 1, specIDs = { 256, 257, 258 } }, "DISCIPLINE", "specialization" },
        { { specIndex = 3, specIDs = { 256, 257, 258 } }, "SHADOW", "specialization" },
        { { talentPoints = { 5, 31, 15 } }, "HOLY", "talent tabs" },
        { { specIndex = 3, traitRanks = { [105850] = 2, [105837] = 5 } }, "DISCIPLINE", "talents" },
        { {}, "SHADOW", "default" },
    }
    for i, c in ipairs(cases) do
        ns = Boot(LoadAddon(c[1]))
        local spec, source = ns.Spec.Get()
        eq(spec, c[2], "case " .. i .. " spec")
        eq(source, c[3], "case " .. i .. " source")
    end
    Slash("spec disc")
    eq(ns.Spec.Get(), "DISCIPLINE", "manual override")
    eq(ns.char.specOverride, "DISCIPLINE", "override saved per character")
    check(Printed("Discipline (Healer) - source: manual"), "override printed")
    Slash("spec nonsense")
    check(Printed("unknown spec") and Printed("auto, disc, holy, shadow"), "bad spec name rejected")
    Slash("spec auto")
    eq(ns.char.specOverride, false, "back to automatic")
end)

test("Priest: spec from the Forever talent tree", function()
    -- Talent config: Wand Specialization 2 + Mental Strength 5 + Meditation known = Disc 8,
    -- Shadow Focus known = Shadow 1. Talents win over the specialization API.
    ns = Boot(LoadAddon({ specIndex = 3, traitRanks = { [105850] = 2, [105837] = 5 } }))
    local points = ns.Spec.TalentPoints()
    eq(points.DISCIPLINE, 8, "Disc points")
    eq(points.HOLY, 0, "Holy points")
    eq(points.SHADOW, 1, "Shadow points")
    eq(ns.Spec.Get(), "DISCIPLINE", "most points decide")
    Slash("spec")
    check(Printed("Discipline (Healer) - source: talents"), "spec command shows the source")
    check(Printed("talent points: Disc 8, Holy 0, Shadow 1"), "spec command shows the points")
    local lines = Hover(ns, Link(22514))
    check(HasLine(lines, "Discipline 60"), "tooltip compares for Discipline")

    -- In combat the ranks are secret: the last readable result is kept
    W.inCombat, W.secret = true, true
    eq(ns.Spec.Get(), "DISCIPLINE", "spec kept in combat")
    check(#Hover(ns, Link(22514)) > 0, "tooltip works in combat")
    W.inCombat, W.secret = false, false

    -- Without a talent config, known talent spells count (one point each)
    ns = Boot(LoadAddon({ specIndex = 1, missing = { "C_ClassTalents" } }))
    W.known[15270], W.known[15407], W.known[15473] = true, true, true   -- Spirit Tap, Mind Flay, Shadowform
    FireEvent("SPELLS_CHANGED")
    eq(ns.Spec.TalentPoints().SHADOW, 4, "known Shadow talents")
    eq(ns.Spec.Get(), "SHADOW", "talent spells beat the specialization API")
    -- Holy Specialization sits on two nodes but counts once
    W.known[14889] = true
    eq(ns.Spec.TalentPoints().HOLY, 0, "talents are cached until an event says they changed")
    FireEvent("SPELLS_CHANGED")
    eq(ns.Spec.TalentPoints().HOLY, 1, "duplicate node counted once")

    -- A tie falls back to the specialization API, then to the default
    ns = Boot(LoadAddon({ specIndex = 2 }))      -- Meditation and Shadow Focus known: 1 : 1
    local spec, source = ns.Spec.Get()
    eq(spec, "HOLY", "tie uses the specialization API")
    eq(source, "specialization", "tie source")
    ns = Boot(LoadAddon({ level = 20 }))
    spec, source = ns.Spec.Get()
    eq(source, "default", "nothing found")
    lines = Hover(ns, Link(90013))
    check(HasLine(lines, "no spec found - set it with /wch spec"), "tooltip asks to set the spec")
    Slash("spec")
    check(Printed("no spec found, so Shadow is used"), "spec command explains the default")
    Slash("spec disc")
    lines = Hover(ns, Link(90013))
    check(not HasLine(lines, "no spec found"), "hint gone after setting the spec")
end)

test("Priest: weights for every spec and level band", function()
    ns = Boot(LoadAddon({ specIndex = 2 }))
    for _, level in ipairs({ 1, 10, 19, 20, 39, 40, 59, 60 }) do
        W.level = level
        for _, spec in ipairs(ns.Spec.KEYS) do
            local weights = ns.Weights.Get(spec)
            for stat, w in pairs(weights) do
                check(w >= 0, ("%s weight %s at level %d is negative"):format(spec, stat, level))
            end
            check(ns.Weights.BandText(spec):find("level") ~= nil, "band text")
        end
    end
    W.level = 30
    check(ns.Weights.Get("SHADOW").WAND_DPS > 1, "wand counts while leveling")
    for _, spec in ipairs(ns.Spec.KEYS) do
        eq(ns.Weights.Get(spec).DPS, nil, spec .. ": melee weapon damage doesn't count")
    end
    W.level = 60
    eq(ns.Weights.BandText("HOLY"), "max level", "band text at max level")
    eq(ns.Weights.Of(ns.Weights.Get("HOLY"), "STRENGTH_AGILITY_INTELLECT"), ns.Weights.Get("HOLY").INTELLECT,
        "combined primary stat uses the best part")
end)

test("Priest: weights follow level and talents", function()
    ns = Boot(LoadAddon({ level = 13, traitRanks = {} }))
    local Wt = ns.Weights
    near(Wt.SpellPowerFactor(13), 0.625, "spell power counts less below level 20")
    eq(Wt.SpellPowerFactor(30), 1, "full spell power from level 23")
    eq(Wt.RoleShare(10, 60), 0, "questing only at level 10")
    near(Wt.RoleShare(35, 60), 0.5, "half and half at 35")
    eq(Wt.RoleShare(60, 60), 1, "role only at max level")
    eq(Wt.BandText("DISCIPLINE"), "level 13: questing 94%", "band text while leveling")

    -- Questing at 13: the wand is the big upgrade, Spirit and Intellect beat Stamina
    local w = Wt.Get("DISCIPLINE")
    check(w.WAND_DPS > 3 * w.SPELL_POWER, ("wand DPS %.2f vs spell power %.2f at 13"):format(w.WAND_DPS, w.SPELL_POWER))
    check(w.SPIRIT > w.STAMINA and w.INTELLECT > w.STAMINA, "Spirit and Intellect over Stamina while questing")
    near(w.SPELL_POWER, w.SPELL_DAMAGE + w.HEALING, "spell power = damage + healing")
    near(w.SPELL_DAMAGE, w.HOLY_DAMAGE + w.SHADOW_DAMAGE, "spell damage = Holy + Shadow")
    W.level = 60
    local w60 = Wt.Get("DISCIPLINE")
    check(w60.HEALING > 0.9 and w60.WAND_DPS < 0.5, "healing first, wand barely at 60")

    -- Learned talents change the values (ranks from the talent config)
    W.level = 13
    local before = Wt.Get("SHADOW")
    W.traitRanks[105850] = 2      -- Wand Specialization 2/2
    W.traitRanks[105837] = 5      -- Mental Strength 5/5
    W.traitRanks[105817] = 1      -- Shadowform
    W.traitRanks[105853] = 5      -- Spiritual Guidance 5/5
    eq(ns.Spec.TalentRank(14524), 0, "talent ranks cached until an event")
    FireEvent("TRAIT_CONFIG_UPDATED")
    eq(ns.Spec.TalentRank(14524), 2, "ranks read again after the talent event")
    local after = Wt.Get("SHADOW")
    near(after.WAND_DPS, before.WAND_DPS * 1.25, "Wand Specialization +25%")
    near(after.INTELLECT, before.INTELLECT * 1.1, "Mental Strength +10% Intellect")
    near(after.SHADOW_DAMAGE, before.SHADOW_DAMAGE * 1.1, "Shadowform +10% Shadow damage")
    check(after.CRIT > before.CRIT * 1.5, "Shadowform crit bonus")
    check(after.SPIRIT > before.SPIRIT, "Spiritual Guidance makes Spirit worth more")
    eq(after.HOLY_DAMAGE, before.HOLY_DAMAGE, "Holy damage unchanged")

    W.traitRanks = {}
    FireEvent("PLAYER_TALENT_UPDATE")
    near(Wt.Get("SHADOW").WAND_DPS, before.WAND_DPS, "back without talents")

    -- The wand waits 0.5 sec before it shoots (since 15 Oct)
    near(Wt.Questing("SHADOW", 13).WAND_DPS, 3.5 * (1 - 0.5 / 8), "wand start delay counted")
    -- Power in Light: Smite and Penance +10%
    local holyBefore = Wt.Get("DISCIPLINE").HOLY_DAMAGE
    W.traitRanks[110853] = 5
    FireEvent("TRAIT_CONFIG_UPDATED")
    near(Wt.Get("DISCIPLINE").HOLY_DAMAGE, holyBefore * 1.1, "Power in Light +10% Holy damage")

    -- Legacy perk Thrill of Adventure: mana back per kill makes Intellect worth more while questing
    local intBefore = Wt.Get("DISCIPLINE").INTELLECT
    local listBefore = ns.Compare.Ranking("head", "DISCIPLINE")
    Slash("legacy")
    check(Printed("Thrill of Adventure (Abenteuerlust): rank 0/5"), "legacy command shows the rank")
    Slash("legacy 5")
    eq(ns.db.legacy.adventure, 5, "rank saved")
    check(Wt.Get("DISCIPLINE").INTELLECT > intBefore * 1.25, "Intellect worth more with the perk")
    check(ns.Compare.Ranking("head", "DISCIPLINE") ~= listBefore, "ranking rebuilt for the perk")
    Slash("legacy 9")
    eq(ns.db.legacy.adventure, 5, "rank capped at 5")
    Slash("legacy lots")
    check(Printed("use a rank from 0 to 5"), "bad rank rejected")
    W.level = 60
    local withPerk = Wt.Get("DISCIPLINE").INTELLECT
    Slash("legacy 0")
    near(Wt.Get("DISCIPLINE").INTELLECT, withPerk, "no effect at max level (dungeons and raids)")
end)

test("Priest: item parsing and stat names", function()
    ns = Boot(LoadAddon({ specIndex = 3 }))
    local anathema = ns.ItemData.Parse(Link(18609))
    eq(anathema.stats.SHADOW_DAMAGE, 69, "Anathema +Shadow damage")
    eq(anathema.stats.MANA_REGENERATION, 7, "mp5 from POWER_REGEN0")
    eq(anathema.stats.SHADOW_RESISTANCE, 20, "resistance from RESISTANCE5_NAME")
    eq(anathema.equipLoc, "INVTYPE_2HWEAPON", "two-hander slot")
    check(anathema.stats.DPS and anathema.stats.DPS > 40, "staff keeps melee DPS")
    local wand = ns.ItemData.Parse(Link(11288))
    check(wand.stats.WAND_DPS and wand.stats.DPS == nil, "wand DPS stored as WAND_DPS")
    near(wand.stats.WAND_DPS, (22 + 41) / 2 / 1.8, "wand DPS value")
    local bow = ns.ItemData.Parse(Link(90002))
    check(bow.stats.RANGED_DPS and bow.stats.DPS == nil, "bow DPS stored as RANGED_DPS")
    eq(ns.ItemData.Parse(Link(22514)).stats.HEALING, 75, "+healing from SPELL_HEALING_DONE")
    eq(ns.ItemData.Parse(Link(22514)).setID, 525, "set ID")
    eq(ns.ItemData.Parse(Link(19379)).stats.HIT, 20, "hit rating")
    eq(ns.ItemData.Parse(Link(22080)).stats.CRIT, 14, "crit rating")
    eq(ns.ItemData.Parse(Link(22080)).stats.ARMOR, 75, "armor")
    eq(ns.ItemData.KeyFromLink(Link(90003, -12)), "90003:-12", "random suffix key")
    eq(ns.ItemData.KeyFromLink(Link(90003)), "90003", "plain key")
    W.uncached[90011] = true
    check(ns.ItemData.Parse(Link(90011)) == nil, "uncached item returns nil")
    W.uncached[90011] = nil
    -- Fallback to Data/Items.lua when the game returns no stats
    W.noLiveStats = true
    eq(ns.ItemData.Parse(Link(18609)).stats.SHADOW_DAMAGE, 69, "static fallback: Shadow damage")
    check(ns.ItemData.Parse(Link(11288)).stats.WAND_DPS ~= nil, "static fallback: wand DPS")
    eq(ns.ItemData.Parse(Link(22080)).stats.ARMOR, 75, "static fallback: armor")
    W.noLiveStats = false
    eq(ns.ItemData.NormalizeStat("ITEM_MOD_SPELL_DAMAGE_DONE_SHORT"), "SPELL_DAMAGE", "spell damage key")
    eq(ns.ItemData.NormalizeStat("ITEM_MOD_HOLY_DAMAGE_DONE_SHORT"), "HOLY_DAMAGE", "holy damage key")
    eq(ns.ItemData.NormalizeStat("ITEM_MOD_BONUS_STAT_HOLY_DAMAGE_DONE_SHORT"), "HOLY_DAMAGE", "+Holy damage key")
    eq(ns.ItemData.StatLabel("WAND_DPS"), "Wand DPS", "wand label")
    eq(ns.ItemData.StatLabel("INTELLECT"), "Intellect", "localized label remembered")
end)

test("Priest: spell schools on wands", function()
    -- Forever wands carry small spell stats, e.g. +1 Fire damage on fire wands
    ns = Boot(LoadAddon({ level = 15, traitRanks = { [105850] = 2, [105837] = 3 } }))
    eq(ns.Spec.Get(), "DISCIPLINE", "Disc by talents")
    for _, spec in ipairs(ns.Spec.KEYS) do
        for _, level in ipairs({ 10, 30, 50, 60 }) do
            W.level = level
            eq(ns.Weights.Get(spec).FIRE_DAMAGE, nil, spec .. " ignores Fire damage at " .. level)
        end
    end
    W.level = 15
    check(ns.Weights.Get("DISCIPLINE").SHADOW_DAMAGE > 0.3, "Shadow damage counts for Disc while leveling")
    check(ns.Weights.Get("HOLY").SHADOW_DAMAGE > 0.3, "Shadow damage counts for Holy while leveling")
    local fire, shadow = Evaluate(ns, 90015), Evaluate(ns, 90016)
    check(shadow.roles.DISCIPLINE.score > fire.roles.DISCIPLINE.score, "same DPS: the Shadow wand wins for Disc")
    check(shadow.roles.SHADOW.score > fire.roles.SHADOW.score, "same DPS: the Shadow wand wins for Shadow")
    eq(fire.current.ignored[1] and fire.current.ignored[1].stat, "FIRE_DAMAGE", "Fire damage listed as not counted")
    local lines = Hover(ns, Link(90015))
    check(HasLine(lines, "Not counted: Fire Damage +1"), "tooltip says Fire damage isn't counted")
    lines = Hover(ns, Link(90016))
    check(not HasLine(lines, "Not counted"), "nothing ignored on the Shadow wand")
    check(HasPlain(lines, "Shadow Damage +1"), "Shadow damage shown as a stat change")
    -- Strength on plate isn't counted either, but the item is unusable anyway
    lines = Hover(ns, Link(90009))
    check(not HasLine(lines, "Not counted"), "no such line on unusable items")
end)

test("Priest: what a Priest can use", function()
    ns = Boot(LoadAddon({ specIndex = 2 }))
    local function canUse(id) return ns.ItemData.CanUse(ns.ItemData.Parse(Link(id))) end
    local ok, reason = canUse(90001)
    check(not ok and reason == "Priests can't use Leather", "leather: " .. tostring(reason))
    ok, reason = canUse(90009)
    check(not ok and reason:find("Plate"), "plate: " .. tostring(reason))
    check(not canUse(90002), "bow")
    check(not canUse(90010), "libram")
    check(canUse(90003), "cloth")
    check(canUse(11288), "wand")
    check(canUse(18608), "staff")
    check(canUse(90007), "held in off hand")
    check(canUse(23061), "ring")
    W.known[227] = false
    ok, reason = canUse(18608)
    check(not ok and reason:find("Staves not learned"), "untrained staff: " .. tostring(reason))
    W.known[227] = true
    -- Proficiency API not working: class table only
    W.known[9078] = false
    check(canUse(18608), "class table fallback allows staves")
    check(not canUse(90001), "class table fallback rejects leather")
end)

test("Priest: rating conversion and the Shadow hit cap", function()
    ns = Boot(LoadAddon({ specIndex = 3, hitModifier = 5 }))
    Equip(11, 21709)   -- 10 hit
    Equip(12, 19403)   -- 10 hit
    local total, cap, mode, r = ns.Character:CapUnits("SHADOW", "HIT")
    eq(mode, "rating", "rating mode")
    check(not r.estimated, "client conversion used")
    near(r.ratio, 1 / 12, "ratio from client")
    near(total, (20 / 12 + 5) * 12, "total = rating + talent hit, in rating")
    near(cap, 16 * 12, "cap at 60 in rating")
    check(ns.Character:CapUnits("HOLY", "HIT") == nil, "healers have no hit cap")
    -- No conversion function, no hit on gear: estimate from Weights
    ns = Boot(LoadAddon({ specIndex = 3, missing = { "GetCombatRatingBonusForCombatRatingValue" } }))
    total, cap, mode, r = ns.Character:CapUnits("SHADOW", "HIT")
    check(r and r.estimated, "estimated without client conversion")
    near(cap, 160, "estimated cap at 60")
    near(total, 0, "no hit yet")
    W.level = 30
    ns.Character.dirty = true
    total, cap = ns.Character:CapUnits("SHADOW", "HIT")
    near(cap, 3 * 10 * 22 / 52, "estimated cap at level 30")
    -- An item with 10 hit counts fully while leveling (the old WOWPaladin bug)
    local result = Evaluate(ns, 21709)
    local hit
    for _, c in ipairs(result.roles.SHADOW.contributions) do if c.stat == "HIT" then hit = c end end
    check(hit and not hit.capped, "10 hit rating at level 30 isn't capped")
end)

test("Priest: verdicts at level 60", function()
    ns = Boot(LoadAddon({ specIndex = 2 }))
    Equip(1, 22080)    -- Virtuous Crown
    Equip(16, 90004)   -- mace
    Equip(17, 90007)   -- held orb
    local r = Evaluate(ns, 22514)   -- Circlet of Faith
    eq(r.roles.HOLY.verdict, "UPGRADE", "Circlet for Holy")
    eq(r.roles.DISCIPLINE.verdict, "UPGRADE", "Circlet for Discipline")
    eq(r.roles.SHADOW.verdict, "NO", "Circlet for Shadow")
    eq(r.action, "Equip now", "action in bags")
    eq(Evaluate(ns, 22514, "MERCHANT").action, "Buy & equip", "action at merchant")
    eq(Evaluate(ns, 22514, "LOOT").action, "Take & equip", "action when looting")
    r = Evaluate(ns, 90001)
    eq(r.verdict, "UNUSABLE", "leather unusable")
    eq(r.action, "Can't use - sell", "unusable action")
    eq(Evaluate(ns, 22080).verdict, "EQUIPPED", "equipped item")
    eq(Evaluate(ns, 22080).action, "Currently equipped", "equipped action")
    -- Off-spec: the Shadow tome is worse for Holy, better for Shadow
    r = Evaluate(ns, 19309)
    eq(r.roles.HOLY.verdict, "NO", "tome for Holy")
    eq(r.roles.SHADOW.verdict, "UPGRADE", "tome for Shadow")
    eq(r.verdict, "OFFSPEC", "off-spec verdict")
    eq(r.action, "Keep for Shadow", "off-spec action")
    eq(r.reason, "Upgrade for Shadow (Damage)", "off-spec reason")
    -- Two-hander replaces main hand and off hand
    r = Evaluate(ns, 18608)
    eq(#r.current.replaced, 2, "staff replaces two items")
    eq(r.current.note, "Replaces main hand and off hand", "staff note")
    Equip(16, 18608)
    Equip(17, nil)
    eq(Evaluate(ns, 90004).current.note, "Replaces your staff (off hand becomes free)", "mace vs staff")
    eq(Evaluate(ns, 90007).current.note, "Needs a one-handed weapon - compared against your staff", "orb vs staff")
    -- Rings: empty slot, then the weaker one is replaced
    eq(Evaluate(ns, 23061).current.note, "Fills an empty slot", "first ring")
    Equip(11, 90012)
    Equip(12, 90006)
    r = Evaluate(ns, 23061)
    eq(r.current.replaced[1].id, 90012, "weaker ring replaced")
end)

test("Priest: verdicts while leveling", function()
    ns = Boot(LoadAddon({ specIndex = 3, level = 20 }))
    Equip(18, 5240)    -- Torchlight Wand
    local r = Evaluate(ns, 11288)   -- Greater Magic Wand
    eq(r.roles.SHADOW.verdict, "UPGRADE", "better wand at 20")
    check(r.current.contributions[1].stat == "WAND_DPS", "wand DPS is the main reason")
    r = Evaluate(ns, 22514)         -- needs level 60
    check(r.roles.HOLY.verdict == "LATER", "level 60 healer item for Holy at 20: " .. r.roles.HOLY.verdict)
    r = Evaluate(ns, 90009)
    eq(r.verdict, "UNUSABLE", "plate at 20")
    W.level = 10
    r = Evaluate(ns, 90003)          -- needs 18
    check(r.verdict == "LATER" or r.verdict == "OFFSPEC" or r.verdict == "NO", "robe at 10: " .. r.verdict)
    if r.verdict == "LATER" then eq(r.action, "Keep for level 18", "later action") end
end)

test("Priest: set pieces", function()
    ns = Boot(LoadAddon({ specIndex = 2 }))
    Equip(1, 22080)    -- Virtuous Crown, better than the Circlet for Shadow
    Equip(5, 22512)
    Equip(7, 22513)
    Equip(3, 22515)
    local r = Evaluate(ns, 22514)   -- 4th piece of Vestments of Faith
    local change
    for _, c in ipairs(r.current.sets) do if c.setID == 525 then change = c end end
    check(change ~= nil, "set change found")
    if change then
        eq(change.before, 3, "pieces before")
        eq(change.after, 4, "pieces after")
        near(change.value, 15, "4-piece value for Holy")
        eq(#change.gained, 1, "one bonus gained")
    end
    -- Shadow collecting the set: KEEP instead of scrap
    ns.char.specOverride = "SHADOW"
    r = Evaluate(ns, 22514)
    eq(r.verdict, "KEEP", "set piece kept for Shadow")
    eq(r.action, "Keep (set piece)", "keep action")
    check(r.reason:find("Vestments of Faith"), "keep reason names the set")
end)

test("Priest: set bonus texts", function()
    local SB = ns.SetBonus
    local p = SB.ParseEffect("Increases healing done by up to 44 and damage done by up to 15 for all magical spells and effects.")
    check(p and #p == 2 and p[1].stat == "HEALING" and p[1].value == 44 and p[2].stat == "SPELL_DAMAGE" and p[2].value == 15,
        "two-stat PvP text")
    p = SB.ParseEffect("Improves your chance to hit by 2.0%.")
    check(p and p[1].stat == "HIT" and p[1].value == 2 and p[1].rating == "CR_HIT_*", "decimal percent text")
    eq(ns.Weights.RatingName("SHADOW", p[1].rating), "CR_HIT_SPELL", "generic hit uses spell hit for a Priest")
    p = SB.ParseEffect("+8 All Resistances.")
    check(p and p[1].stat == "ALL_RESISTANCES" and p[1].value == 8, "+N text")
    p = SB.ParseEffect("Increases damage and healing done by magical spells and effects by up to 23.")
    check(p and p[1].stat == "SPELL_POWER" and p[1].value == 23, "spell power text")
    p = SB.ParseEffect("Increases damage done by Shadow spells and effects by up to 29.")
    check(p and p[1].stat == "SHADOW_DAMAGE" and p[1].value == 29, "school damage text")
    check(SB.ParseEffect("Reduces the cooldown of your Gouge ability by 1 sec.") == nil, "unrated text")
    -- Percent bonus converted to rating: 2% hit = 24 rating with 12 per 1%
    ns = Boot(LoadAddon({ specIndex = 3 }))
    local weights = ns.Weights.Get("SHADOW")
    local value = ns.SetBonus.EffectValue(143, { count = 2, text = "Improves your chance to hit by 2.0%." }, "SHADOW", weights)
    near(value, 24 * weights.HIT, "percent bonus scored as rating")
    -- Every effect of every exported set can be scored
    local rated, total = 0, 0
    for setID, set in pairs(ns.SetData.Sets) do
        for _, effect in ipairs(set.effects) do
            for _, spec in ipairs(ns.Spec.KEYS) do
                local v, isRated = ns.SetBonus.EffectValue(setID, effect, spec, ns.Weights.Get(spec))
                check(type(v) == "number", "value for set " .. setID)
                if spec == "HOLY" then
                    total = total + 1
                    if isRated then rated = rated + 1 end
                end
            end
        end
    end
    realPrint(("      %d of %d set effects rated for a Holy Priest, the rest use the default value"):format(rated, total))
    eq(ns.SetBonus.EffectValue(342, { count = 4, text = "Increases the duration of your Psychic Scream spell by 1 sec." },
        "HOLY", ns.Weights.Get("HOLY")), 2, "Psychic Scream text rule")
end)

test("Priest: verdict tooltip on hover", function()
    ns = Boot(LoadAddon({ specIndex = 2 }))
    Equip(1, 22080)
    local lines = Hover(ns, Link(22514))
    check(lines[1] and lines[1]:find("Equip now || +60.1 (+109%)", 1, true), "action and score: " .. tostring(lines[1]))
    local vs = HasLine(lines, "vs. ")
    check(vs and vs:find("[Virtuous Crown]", 1, true) and vs:find("|| Holy 60$"), "compared item, spec and level")
    check(HasLine(lines, "Disc ") and HasLine(lines, "Shadow ") and not HasLine(lines, "Discipline"),
        "other specs in one short line")
    local stats = HasLine(lines, "Healing ")
    check(stats and stats:find(" || "), "two stat changes per line")
    check(HasLine(lines, "Vestments of Faith 1/9 with this, bonus at 2"), "set progress line")
    check(not HasLine(lines, "Vestments of the Virtuous"), "set change without effect hidden")
    check(not HasLine(lines, "max level") and not HasLine(lines, "WOWClassHelper"), "no title or band line at max level")
    check(#lines <= 12, "compact: " .. #lines .. " lines")
    check(ns.KB:Get("22514") ~= nil, "hovered item recorded")
    -- Other specs hidden
    ns.db.tooltip.offspec = false
    lines = Hover(ns, Link(22514))
    check(not HasLine(lines, "Disc "), "other specs hidden")
    ns.db.tooltip.offspec = true
    -- Merchant context
    MerchantFrame.__shown = true
    local button = CreateFrame("Button", "MerchantItem1ItemButton", MerchantFrame)
    lines = Hover(ns, Link(22514), button)
    check(HasLine(lines, "Buy & equip"), "merchant action")
    MerchantFrame.__shown = false
    -- Clicked chat link
    lines = Hover(ns, Link(19309), nil, ItemRefTooltip)   -- off hand is empty
    check(HasLine(lines, "Fills an empty slot") and HasLine(lines, "Equip now"), "ItemRefTooltip works")
    -- Unusable: action only, no stat or set lines
    lines = Hover(ns, Link(90001))
    check(HasLine(lines, "Can't use - sell") and not HasLine(lines, "Agility"), "unusable item has no stat lines")
    -- Near-worthless replaced item: no silly percentage
    Equip(11, 90012)
    Equip(12, 90012)
    lines = Hover(ns, Link(23061))
    check(lines[1] and lines[1]:find("Equip now") and not lines[1]:find("%%"),
        "no percent against a 1-Stamina ring: " .. tostring(lines[1]))
    check(HasLine(lines, "Shadow "), "other specs present")
    -- Not equippable, hidden owner, disabled
    eq(#Hover(ns, Link(90020)), 0, "no verdict for cloth reagent")
    Hover(ns, Link(22514))
    GameTooltip:Hide()
    check(not ns.VerdictTooltip.frames[GameTooltip].__shown, "verdict hides with the item tooltip")
    Slash("tooltip")
    eq(#Hover(ns, Link(22514)), 0, "disabled tooltip")
    Slash("tooltip")
    check(#Hover(ns, Link(22514)) > 0, "enabled again")
end)

test("Priest: best items seen and rank", function()
    ns = Boot(LoadAddon({ specIndex = 2 }))
    Equip(1, 22080)                        -- Virtuous Crown, worn
    W.bags[0] = { Link(90013) }            -- Silk Cap in bags
    FireEvent("BAG_UPDATE_DELAYED")
    local lines = Hover(ns, Link(22514))   -- Circlet of Faith
    check(HasLine(lines, "Best head items seen || this #1 of 3"), "header with rank")
    local rows, marked = ListRows(lines)
    eq(#rows, 3, "three rows")
    check(marked and marked:find("^> 1%. ") and marked:find("[Circlet of Faith]", 1, true), "hovered item marked #1")
    check(marked and marked:find("115 seen  |cff", 1, true) and marked:find("+60.1|r$"),
        "improvement behind the hovered row, same as the action line: " .. tostring(marked))
    check(rows[2] and rows[2]:find("[Virtuous Crown]", 1, true) and rows[2]:find("55 worn$"),
        "worn item #2 without improvement: " .. tostring(rows[2]))
    check(rows[3] and rows[3]:find("[Test Silk Cap]", 1, true) and rows[3]:find("6 bags  ", 1, true)
        and rows[3]:find("-49.2|r$"), "bag item #3 with its (negative) improvement: " .. tostring(rows[3]))
    -- Improvement colors: upgrade green, worse red
    check(marked and marked:find("|cff1ae61a+60.1", 1, true), "upgrade in green")
    check(rows[3] and rows[3]:find("|cffff4040-49.2", 1, true), "worse item in red")
    -- A weaker item: rank shown, row marked
    lines = Hover(ns, Link(90013))
    check(HasLine(lines, "this #3 of 3"), "silk cap ranks #3")
    rows, marked = ListRows(lines)
    check(marked and marked:find("^> 3%. "), "silk cap row marked")
    -- Fourth item: ranked, but outside the top 3
    lines = Hover(ns, Link(90014))
    check(HasLine(lines, "this #4 of 4"), "linen hood ranks #4")
    rows, marked = ListRows(lines)
    check(#rows == 3 and marked == nil, "top 3 only, no marked row")
    -- Wearing the silk cap updates the list
    Equip(1, 90013)
    lines = Hover(ns, Link(22080))
    rows = ListRows(lines)
    check(HasLine(rows, "[Test Silk Cap]") and HasLine(rows, "[Test Silk Cap]"):find("worn$"), "list follows gear changes")
    -- Unusable item: list but no rank
    lines = Hover(ns, Link(90009))
    local header = HasLine(lines, "Best head items seen")
    check(header and not header:find("this #"), "no rank for unusable items")
    -- Other groups
    check(HasLine(Hover(ns, Link(90004)), "Best weapons seen"), "weapon list")
    check(HasLine(Hover(ns, Link(11288)), "Best wands seen"), "wand list")
    -- Settings
    ns.db.tooltip.topCount = 2
    eq(#ListRows(Hover(ns, Link(22514))), 2, "topCount respected")
    ns.db.tooltip.topList = false
    check(not HasLine(Hover(ns, Link(22514)), "Best "), "list switched off")
    ns.db.tooltip.topList, ns.db.tooltip.topCount = true, 3
    -- /wch best uses the same ranking
    Slash("best head")
    check(Printed("1. ") and Printed("[Circlet of Faith]"), "/wch best lists the ranking")
    check(Printed("vs. your gear"), "/wch best shows the improvement")
    Slash("best wand")
    check(Printed("best known ranged"), "'wand' is a slot word")
    -- Item above the player's level: where it would rank
    ns = Boot(LoadAddon({ specIndex = 2, level = 20 }))
    Hover(ns, Link(90014))
    lines = Hover(ns, Link(22514))
    check(HasLine(lines, "this #1 at level 60"), "rank for a level 60 item at 20")
    rows = ListRows(lines)
    check(#rows == 1 and rows[1]:find("[Test Linen Hood]", 1, true), "list only has usable items")
end)

test("verdict tooltip placement", function()
    ns = Boot(LoadAddon({ specIndex = 2 }))
    Equip(1, 22080)
    Hover(ns, Link(22514))
    local tip = ns.VerdictTooltip.frames[GameTooltip]
    local p = tip.__points[1]
    check(p and p[1] == "TOPLEFT" and p[2] == GameTooltip and p[3] == "BOTTOMLEFT" and p[5] == -4,
        "below the item tooltip")
    -- Comparison tooltip shows up later on the right and reaches lower
    ShoppingTooltip1.__left, ShoppingTooltip1.__right, ShoppingTooltip1.__bottom = 400, 700, 250
    ShoppingTooltip1:Show()
    Tick(0.2)
    eq(tip.__points[1][5], -(400 - 250) - 4, "moved below the comparison tooltip")
    -- On the left side it doesn't overlap: back below the item tooltip
    ShoppingTooltip1.__left, ShoppingTooltip1.__right = -200, 100
    Tick(0.2)
    eq(tip.__points[1][5], -4, "comparison tooltip on the left ignored")
    ShoppingTooltip1:Hide()
    -- No room below: above the item tooltip
    GameTooltip.__bottom = 60
    Hover(ns, Link(22514))
    p = tip.__points[1]
    check(p[1] == "BOTTOMLEFT" and p[3] == "TOPLEFT" and p[5] == 4, "above when there's no room below")
    GameTooltip.__bottom = 400
    -- Clicked chat links avoid their own comparison tooltips
    ItemRefShoppingTooltip1.__left, ItemRefShoppingTooltip1.__right, ItemRefShoppingTooltip1.__bottom = 400, 700, 200
    ItemRefShoppingTooltip1:Show()
    Hover(ns, Link(22514), nil, ItemRefTooltip)
    eq(ns.VerdictTooltip.frames[ItemRefTooltip].__points[1][5], -(400 - 200) - 4, "chat link tooltip moved down")
    -- Driver stops when no verdict tooltip is shown
    GameTooltip:Hide()
    ItemRefTooltip:Hide()
    Tick(0.2)
    check(not ns.VerdictTooltip.driver:IsShown(), "placement driver idle")
end)

test("verdict tooltip without TooltipDataProcessor", function()
    ns = Boot(LoadAddon({ specIndex = 2, missing = { "TooltipDataProcessor", "TooltipUtil" } }))
    check(GameTooltip.__hooks.OnTooltipSetItem ~= nil, "legacy hook installed")
    check(#Hover(ns, Link(22514)) > 0, "legacy hook renders")
end)

test("knowledge base scanners", function()
    ns = LoadAddon({ specIndex = 3 })
    W.bags[0] = { Link(90003), Link(22518) }
    W.bags[1] = { Link(90011) }
    W.uncached[90011] = true
    Boot(ns)
    check(ns.KB:Get("90003") and ns.KB.owned.bags["90003"] == 1, "bag item recorded")
    check(ns.char.owned.bags["90003"] == 1, "bag contents saved per character")
    check(ns.KB:Get("90011") == nil, "uncached item waits")
    eq(#W.pendingLoads, 1, "retry queued")
    W.uncached[90011] = nil
    for _, cb in ipairs(W.pendingLoads) do cb() end
    check(ns.KB:Get("90011") ~= nil, "uncached item recorded after load")
    W.bank[-1] = { Link(22519) }
    FireEvent("BANKFRAME_OPENED")
    check(ns.KB.owned.bank["22519"] == 1, "bank item recorded")
    W.loot = { Link(90005) }
    FireEvent("LOOT_READY")
    eq(ns.KB:Get("90005").zone, "Elwynn Forest", "loot zone")
    W.merchant = { { link = Link(90006), price = 1234 } }
    FireEvent("MERCHANT_SHOW")
    eq(ns.KB:Get("90006").buyPrice, 1234, "merchant price")
    eq(ns.KB:Get("90006").vendor, "Vendor Bob", "vendor name")
    FireEvent("CHAT_MSG_LOOT", "You receive loot: " .. Link(90012) .. ".")
    check(ns.KB:Get("90012") ~= nil, "chat loot recorded")
    FireEvent("CHAT_MSG_LOOT", Secret("secret text"))
    eq(ns.KB.owned.bags["22518"], 1, "set piece in bags")
    eq(ns.KB:OwnedSetPieces(525), 2, "owned Faith pieces in bags and bank")
end)

test("Priest: slash commands", function()
    ns = Boot(LoadAddon({ specIndex = 3, hitModifier = 5 }))
    Equip(11, 21709)
    Equip(18, 11288)
    Hover(ns, Link(21585))
    Hover(ns, Link(19403))
    Slash("")
    check(Printed("/wch best") and Printed("[auto|disc|holy|shadow]"), "help lists commands with spec names")
    Slash("stats")
    check(Printed("Priest Shadow (Damage)"), "stats header")
    check(Printed("Hit:") and Printed("% cap"), "hit cap line")
    check(Printed("Character sheet:") and Printed("regen 50 per 5 sec, 15 while casting"), "mana regen line")
    for _, slot in ipairs({ "head", "neck", "shoulder", "back", "chest", "wrist", "hands", "waist", "legs",
                            "feet", "finger", "trinket", "mainhand", "offhand", "ranged", "relic", "wand" }) do
        Slash("best " .. slot)
        Slash("best " .. slot .. " holy")
    end
    check(Printed("best known finger for Shadow (Damage)"), "best finger")
    check(Printed("best known finger for Holy (Healer)"), "best for another spec")
    Slash("best nowhere")
    check(Printed("slots: "), "slot list")
    Slash("kb")
    check(Printed("knowledge base:"), "kb summary")
    Slash("lock"); eq(ns.db.manaBar.locked, true, "locked")
    eq(ns.ManaBar.frame.__mouse, false, "locked bar ignores the mouse")
    Slash("unlock"); eq(ns.db.manaBar.locked, false, "unlocked")
    Slash("toggle"); eq(ns.ManaBar.frame:IsShown(), true, "bar shown")
    Slash("toggle"); eq(ns.ManaBar.frame:IsShown(), false, "bar hidden")
    Slash("timer"); eq(ns.ManaBar.frame.timer:IsShown(), false, "timer hidden")
    Slash("timer"); eq(ns.ManaBar.frame.timer:IsShown(), true, "timer shown")
    Slash("reset")
    check(Printed("position reset"), "reset")
    Slash("kb wipe")
    check(next(ns.KB.items) == nil, "kb wiped")
end)

test("mana bar and five-second rule", function()
    ns = Boot(LoadAddon({ specIndex = 2 }))
    Slash("toggle")   -- hidden by default
    local f = ns.ManaBar.frame
    check(f:IsShown(), "bar shown after toggle")
    eq(f.bar.__value, 3000, "mana value")
    eq(f.bar.__max, 4000, "mana max")
    eq(f.text.__text, "3000 / 4000", "mana text")
    W.mana = 2500
    FireEvent("UNIT_POWER_UPDATE", "player", "MANA")
    eq(f.bar.__value, 2500, "mana update")
    W.mana = 2000
    FireEvent("UNIT_POWER_UPDATE", "player", "RAGE")
    eq(f.bar.__value, 2500, "other power types ignored")
    FireEvent("UNIT_POWER_UPDATE", "target", "MANA")
    eq(f.bar.__value, 2500, "other units ignored")
    check(ns.ManaBar.ruleEnd == nil, "timer idle at start")
    FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 585)
    check(ns.ManaBar.ruleEnd ~= nil, "mana spell starts the timer")
    Tick(3)
    check(ns.ManaBar.ruleEnd ~= nil and f.timer.__value < 2.1 and f.timer.__value > 1.9, "timer runs down")
    Tick(2.5)
    check(ns.ManaBar.ruleEnd == nil, "timer stops after 5 sec")
    eq(f.timer.__value, 5, "timer full again")
    check(f.__scripts.OnUpdate == nil, "OnUpdate removed when idle")
    FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-2", 5019)
    check(ns.ManaBar.ruleEnd == nil, "wand Shoot doesn't start the timer")
    FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-2b", 75)
    check(ns.ManaBar.ruleEnd == nil, "Auto Shot doesn't start the timer")
    FireEvent("UNIT_SPELLCAST_SUCCEEDED", "party1", "Cast-3", 585)
    check(ns.ManaBar.ruleEnd == nil, "other units' casts ignored")
    ns.db.manaBar.text = false
    ns.ManaBar:Refresh()
    eq(f.text:IsShown(), false, "text hidden by setting")
end)

test("combat with secret values", function()
    ns = Boot(LoadAddon({ specIndex = 3, hitModifier = 5 }))
    Slash("toggle")   -- show the mana bar
    Equip(11, 21709)
    ns.Character:Refresh()
    W.inCombat, W.secret = true, true
    FireEvent("PLAYER_REGEN_DISABLED")
    local f = ns.ManaBar.frame
    FireEvent("UNIT_POWER_UPDATE", "player", "MANA")
    check(issecretvalue(f.bar.__value), "secret mana passed to the status bar")
    eq(f.text.__text, "", "text cleared when it can't be formatted")
    FireEvent("UNIT_POWER_UPDATE", "player", Secret("MANA"))
    FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", Secret(585))
    check(ns.ManaBar.ruleEnd ~= nil, "secret spell ID starts the timer")
    Tick(6)
    FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-2", 589)
    check(ns.ManaBar.ruleEnd ~= nil, "secret spell cost starts the timer")
    -- Gear change in combat: stats are re-read but character sheet values kept
    Equip(12, 19403)
    local total, cap = ns.Character:CapUnits("SHADOW", "HIT")
    check(type(total) == "number" and type(cap) == "number", "caps still numbers in combat")
    check(#Hover(ns, Link(21585)) > 0, "verdict tooltip in combat")
    Slash("stats")
    Slash("debug")
    W.inCombat, W.secret = false, false
    ns.Character:Get()
    eq(ns.Character.dirty, false, "character data read")
    FireEvent("PLAYER_REGEN_ENABLED")
    eq(ns.Character.dirty, true, "stats are read again after combat")
    FireEvent("UNIT_POWER_UPDATE", "player", "MANA")
    eq(f.text.__text, "3000 / 4000", "text back after combat")
end)

test("AddOn compartment", function()
    ns = Boot(LoadAddon({ specIndex = 2 }))
    WOWClassHelper_OnAddonCompartmentEnter(ADDON, UIParent)
    check(GameTooltip.__lines[1] == "WOWClassHelper", "mouse-over tooltip")
    check(HasLine(GameTooltip.__lines, "Holy (Healer)") and HasLine(GameTooltip.__lines, "Priest"), "mouse-over class and spec")
    WOWClassHelper_OnAddonCompartmentLeave(ADDON, UIParent)
    WOWClassHelper_OnAddonCompartmentClick(ADDON, "LeftButton", UIParent)
    local menu = W.lastMenu
    check(menu and #menu.entries > 10, "menu built")
    local labels = {}
    for _, e in ipairs(menu.entries) do
        if e.text then labels[#labels + 1] = e.text end
        if e.kind == "radio" or e.kind == "checkbox" then
            local before = e.a()
            e.b()
            check(type(e.a()) == "boolean", "menu state for " .. e.text)
            if e.kind == "checkbox" then
                check(e.a() ~= before, "checkbox toggles: " .. e.text)
                e.b()
            end
        elseif e.kind == "button" then
            e.a()
        end
    end
    local all = table.concat(labels, "|")
    check(all:find("Automatic - Holy (Healer)", 1, true), "automatic shows detected spec")
    check(all:find("Mana bar", 1, true), "mana bar entries for a Priest")
    eq(ns.db.tooltip.enabled, true, "toggles restored")
    -- No modern menu API: command list instead
    ns = Boot(LoadAddon({ specIndex = 2, missing = { "MenuUtil" } }))
    WOWClassHelper_OnAddonCompartmentClick(ADDON, "LeftButton", UIParent)
    check(Printed("commands:"), "fallback prints the command list")
end)

test("Priest: debug report", function()
    ns = Boot(LoadAddon({ specIndex = 3, hitModifier = 5 }))
    Equip(5, 22512)
    Equip(18, 11288)
    for _, slot in ipairs({ "", "chest", "wand", "mainhand", "11", "nothing" }) do
        Slash("debug " .. slot)
        local lines = ns.db.lastDebug and ns.db.lastDebug.lines or {}
        check(#lines > 30, "report has lines (" .. slot .. ")")
        for _, line in ipairs(lines) do
            check(not line:find("!! section"), "section failed: " .. line)
            check(not line:find("[format error]", 1, true), "format error: " .. line)
        end
    end
    local report = table.concat(ns.db.lastDebug.lines, "\n")
    check(report:find("Shadow Focus=yes", 1, true), "talent check in report")
    check(report:find("Wands=yes", 1, true), "wand proficiency in report")
    check(report:find("Forever talent tree 1114", 1, true), "talent tree in report")
    check(report:find("Weights for SHADOW", 1, true), "weights in report")
    check(WOWClassHelperDebugFrame and WOWClassHelperDebugFrame:IsShown(), "copy window shown")
    -- Missing APIs show up as MISSING / n/a instead of errors
    ns = Boot(LoadAddon({ specIndex = 3, missing = { "GetManaRegen", "C_Spell", "GetSpellHitModifier",
        "GetCombatRatingBonusForCombatRatingValue", "C_TooltipInfo", "UnitDefense", "GetHitModifier" } }))
    Slash("debug")
    report = table.concat(ns.db.lastDebug.lines, "\n")
    check(report:find("GetManaRegen%s+MISSING"), "missing API listed")
    check(not report:find("!! section"), "no failed sections with missing APIs")
end)

test("older client APIs", function()
    ns = Boot(LoadAddon({ talentPoints = { 0, 0, 31 }, missing = {
        "GetSpecialization", "C_Spell", "GetCombatRatingBonusForCombatRatingValue", "GetCombatRating", "GetManaRegen",
        "GetSpellHitModifier", "GetSpellBonusDamage", "GetSpellBonusHealing" } }))
    eq(ns.Spec.Get(), "SHADOW", "talent tab fallback")
    FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 5019)
    check(ns.ManaBar.ruleEnd == nil, "Shoot still ignored without spell cost API")
    FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-2", 585)
    check(ns.ManaBar.ruleEnd ~= nil, "unknown cost counts as mana")
    Equip(11, 21709)
    check(#Hover(ns, Link(19403)) > 0, "tooltip works")
    Slash("stats")
    check(Printed("estimated"), "estimated conversion shown in stats")
end)

-- Tests: Paladin (from WOWPaladin) --------------------------------------------------------

-- The WOWPaladin fixtures: three Soulforge pieces (shoulder, chest, legs) and test gear
local function PaladinGear()
    for slot, id in pairs({ [1] = 90101, [2] = 90102, [3] = 22093, [5] = 22089, [7] = 22092,
                            [11] = 90111, [12] = 90112, [13] = 90113, [16] = 90116 }) do
        W.equipped[slot] = Link(id)
    end
    W.bags[0] = { Link(90121), Link(90129), Link(22091), Link(90020) }
    W.bank[-1] = { Link(22090) }
    W.merchant = { { link = Link(90130), price = 10000 }, { link = Link(90125), price = 25000 } }
    W.loot = { Link(90126) }
end

-- "max" scenario: level 60, Retribution from the spec API, no client rating
-- conversion (estimated 10 hit rating per 1%), 8% hit from talents
local function PaladinMax(opts)
    opts = opts or {}
    ns = LoadAddon({ class = "PALADIN", specIndex = 3, traitRanks = opts.traitRanks or {}, meleeHit = 8,
        defenseBonus = 10, missing = { "GetCombatRatingBonusForCombatRatingValue" } })
    PaladinGear()
    Boot(ns)
    FireEvent("BANKFRAME_OPENED")
    return ns
end

test("Paladin: spec, caps and the Forever talent tree", function()
    PaladinMax()
    local spec, source = ns.Spec.Get()
    eq(spec, "RETRIBUTION", "spec from Forever spec ID 184")
    eq(source, "specialization", "source")
    eq(ns.Weights.BandText(spec), "max level", "max level weights")
    -- No client conversion and no hit on gear: estimated 10 rating per 1%;
    -- the 8% from talents is added in percent, not mixed with rating
    local total, cap, mode, r = ns.Character:CapUnits("RETRIBUTION", "HIT")
    check(mode == "rating" and r and r.estimated, "estimated rating conversion")
    near(cap, 90, "9% hit cap in rating")
    near(total, 80, "8% talent hit in rating")
    local dTotal, dCap, dMode = ns.Character:CapUnits("PROTECTION", "DEFENSE")
    check(dMode == "percent" and dTotal == 10 and dCap == 140, ("defense bonus from the character sheet: %s of %s (%s)"):format(
        tostring(dTotal), tostring(dCap), tostring(dMode)))

    -- Talent config with 8 Protection points beats the spec API
    W.traitRanks = { [105332] = 5, [105626] = 3 }
    eq(ns.Spec.Get(), "RETRIBUTION", "talents are cached until an event says they changed")
    FireEvent("TRAIT_CONFIG_UPDATED")
    spec, source = ns.Spec.Get()
    eq(spec, "PROTECTION", "most talent points decide")
    eq(source, "talents", "talent source")
    Slash("spec")
    check(Printed("source: talents") and Printed("talent points: Tank 8, Healer 0, Damage 0"),
        "/wch spec shows the source and the points")
    local lines = Hover(ns, Link(22091))
    check(HasLine(lines, "|| Tank 60"), "tooltip compares for the tank spec")
    -- Secret values (combat): the last readable points are kept
    W.inCombat, W.secret = true, true
    FireEvent("SPELLS_CHANGED")
    eq(ns.Spec.Get(), "PROTECTION", "spec kept while talent values are secret")
    W.inCombat, W.secret = false, false
    -- A tie falls back to the spec API
    W.traitRanks = { [105332] = 2, [105335] = 2 }
    FireEvent("TRAIT_CONFIG_UPDATED")
    spec, source = ns.Spec.Get()
    check(spec == "RETRIBUTION" and source == "specialization", "tie uses the spec API")
    -- Nothing found: default spec and a hint
    W.traitRanks = {}
    W.specIndex = nil
    FireEvent("TRAIT_CONFIG_UPDATED")
    spec, source = ns.Spec.Get()
    check(spec == "RETRIBUTION" and source == "default", "nothing found: " .. spec .. " " .. source)
    lines = Hover(ns, Link(22091))
    check(HasLine(lines, "no spec found - set it with /wch spec"), "tooltip asks to set the spec")
    Slash("spec")
    check(Printed("no spec found, so Retribution is used"), "/wch spec explains the default")
    Slash("spec tank")
    eq(ns.char.specOverride, "PROTECTION", "role words work as spec names")
    Slash("spec auto")
end)

test("Paladin: weights follow level and talents", function()
    PaladinMax()
    local Wt = ns.Weights
    local q = Wt.Questing("RETRIBUTION", 13)
    check(q.DPS == 7 and q.STRENGTH == 1, "questing: 1 weapon DPS = 7 Strength")
    check(Wt.Questing("RETRIBUTION", 60).AGILITY > q.AGILITY, "Agility (crit) worth more at higher levels")
    near(Wt.Questing("PROTECTION", 30).SPELL_DAMAGE, 0.25, "site: tank spell power 0.25 while questing")
    near(Wt.Get("PROTECTION").SPELL_DAMAGE, 0.5, "site: tank spell power 0.5 at max level")
    local w = Wt.Get("RETRIBUTION")
    check(math.abs(w.SPELL_POWER - (w.SPELL_DAMAGE + w.HEALING)) < 1e-9 and w.HOLY_DAMAGE == w.SPELL_DAMAGE,
        "spell power = damage + healing, Holy damage = spell damage")
    -- Legacy perk: questing Intellect +30% at rank 5
    local intBefore = Wt.Questing("RETRIBUTION", 25).INTELLECT
    Slash("legacy 5")
    near(Wt.Questing("RETRIBUTION", 25).INTELLECT, intBefore * 1.3, "Legacy perk rank 5: questing Intellect +30%")
    Slash("legacy 0")
    -- Learned talents
    local before, holyBefore = Wt.Get("RETRIBUTION"), Wt.Get("HOLY")
    W.traitRanks = { [113630] = 5, [105697] = 3, [110882] = 5, [105321] = 5 }   -- Divine Strength, 2H Spec, Champion, Holy Power
    FireEvent("TRAIT_CONFIG_UPDATED")
    local after, holyAfter = Wt.Get("RETRIBUTION"), Wt.Get("HOLY")
    near(after.STRENGTH, before.STRENGTH * 1.1 * 1.06, "Divine Strength and 2H Specialization raise Strength")
    near(after.DPS, before.DPS * 1.06, "2H Specialization raises weapon DPS")
    check(after.INTELLECT > before.INTELLECT, "Champion of the Light makes Intellect worth more")
    near(holyAfter.CRIT, holyBefore.CRIT * 1.5, "Holy Power raises healing crit for the healer")
    near(after.CRIT, before.CRIT * 1.06, "Holy Power doesn't touch the damage spec's crit")
    W.traitRanks = {}
    FireEvent("TRAIT_CONFIG_UPDATED")
    eq(Wt.Get("RETRIBUTION").DPS, before.DPS, "back without talents")
end)

test("Paladin: set bonus texts", function()
    PaladinMax()
    local SB, spec = ns.SetBonus, "RETRIBUTION"
    local w = ns.Weights.Get(spec)
    local hit = SB.ParseEffect("Improves your chance to hit by 1.0%.")
    check(hit and hit[1].stat == "HIT" and hit[1].value == 1, "'by 1.0%' (decimal percent) parsed")
    eq(ns.Weights.RatingName(spec, hit[1].rating), "CR_HIT_MELEE", "generic hit uses melee hit for Retribution")
    local r = ns.Character:Rating("CR_HIT_MELEE")
    near(SB.EffectValue(0, { count = 2, text = "Improves your chance to hit by 1.0%." }, spec, w),
        (1 / r.ratio) * ns.Weights.Of(w, "HIT"), "1% hit scored as rating points")
    local crit = SB.ParseEffect("Improves your chance to get a critical strike with melee attacks by 2.0%.")
    check(crit and crit[1].stat == "CRIT" and crit[1].value == 2 and crit[1].rating == "CR_CRIT_MELEE", "melee crit text parsed")
    local holy = SB.ParseEffect("Increases damage done by Holy spells and effects by up to 29.")
    check(holy and holy[1].stat == "HOLY_DAMAGE" and holy[1].value == 29, "Holy damage text")
    near(SB.EffectValue(0, { count = 2, text = "Increases damage done by Holy spells and effects by up to 29." }, spec, w),
        29 * w.SPELL_DAMAGE, "Holy damage counts as spell damage")
    local hoj, rated = SB.EffectValue(0, { count = 2, text = "Reduces the cooldown of your Hammer of Justice by 10 sec." }, spec, w)
    check(hoj == 2 and rated, "Hammer of Justice bonus valued from SET_EFFECT_TEXTS")
    local _, unrated = SB.EffectValue(0, { count = 2, text = "Chance on hit to do something unusual." }, spec, w)
    eq(unrated, false, "unknown effect text stays unrated")
    local block = SB.ParseEffect("Increases the block value of your shield by 30.")
    check(block and block[1].stat == "BLOCK_VALUE", "block value text")
end)

test("Paladin: verdict tooltips at level 60", function()
    PaladinMax()
    local lines = Hover(ns, Link(22091))
    check(HasLine(lines, "Equip now"), "Soulforge Helm: equip")
    check(HasLine(lines, "Soulforge Armor 3->4/8"), "set bonus change shown (3 -> 4 pieces)")
    check(HasLine(lines, "|| Damage 60"), "current spec and level next to the compared item")
    local others = HasLine(lines, "Tank ")
    check(others and others:find("Healer") and not others:find("Damage"), "other two specs in one line")
    check(not HasLine(lines, "WOWClassHelper") and not HasLine(lines, "max level"), "no title, no band line at max level")
    check(#lines <= 12, ("compact: %d lines"):format(#lines))
    lines = Hover(ns, Link(90121))
    check(HasLine(lines, "Can't use") and HasLine(lines, "Paladins can't use daggers"),
        "dagger: never usable, not 'skill not learned'")
    check(HasLine(Hover(ns, Link(90123)), "Keep for level 99"), "level 99 item")
    check(HasLine(Hover(ns, Link(90116)), "Currently equipped"), "equipped item")
    check(HasLine(Hover(ns, Link(90129)), "Sell"), "worse item")
    check(HasLine(Hover(ns, Link(90130)), "Equal"), "identical item")
    check(HasLine(Hover(ns, Link(90124)), "Keep for Tank"), "shield: tank upgrade")
    check(HasLine(Hover(ns, Link(90122)), "Keep for Healer"), "cloth healer robe")
    eq(#Hover(ns, Link(90127)), 0, "no verdict for a shirt")
    Hover(ns, Link(90101, 1234))
    check(ns.KB:Get("90101:1234") ~= nil, "random-suffix item stored as 90101:1234")
    check(HasLine(Hover(ns, Link(22091), nil, ItemRefTooltip), "Equip now"), "chat link tooltip")
    MerchantFrame.__shown = true
    local merchantButton = CreateFrame("Button", "MerchantItem1ItemButton", MerchantFrame)
    check(HasLine(Hover(ns, Link(90125), merchantButton), "Skip"), "1H blade at merchant")
    MerchantFrame.__shown = false
    LootFrame.__shown = true
    local lootButton = CreateFrame("Button", "LootButton1", LootFrame)
    check(HasLine(Hover(ns, Link(90126), lootButton), "Take"), "ring in loot window")
    LootFrame.__shown = false
    local r = Evaluate(ns, 90126)
    local hit
    for _, c in ipairs(r.current.contributions) do if c.stat == "HIT" then hit = c end end
    check(hit and hit.capped, "hit on ring is capped (8% talents + 1.5% from 15 rating > 9% cap)")
    -- Best items seen
    lines = Hover(ns, Link(22091))
    local header = HasLine(lines, "Best head items seen")
    check(header and header:find("this #1 of %d+$"), "Soulforge Helm ranks #1: " .. tostring(header))
    local rows, marked = ListRows(lines)
    eq(#rows, 3, "top 3 rows")
    check(marked and marked:find("[Soulforge Helm]", 1, true) and marked:find(" bags  ", 1, true), "hovered row marked")
    check(rows[2] and rows[2]:find("[Test Helm of Might]", 1, true) and rows[2]:find(" worn$"), "worn item without improvement")
    lines = Hover(ns, Link(90121))
    header = HasLine(lines, "Best weapons seen")
    check(header and not header:find("this #"), "list but no rank for an unusable item")
    check(HasLine(Hover(ns, Link(90123)), "this #1 at level 99"), "rank at the required level")
    Slash("best head")
    check(Printed("Soulforge Helm") and Printed("vs. your gear"), "/wch best uses the same ranking")
    -- Labels for the Paladin's slots
    check(HasLine(Hover(ns, Link(90124)), "Best shields & off hands seen"), "shield list label")
    check(HasLine(Hover(ns, Link(90010)), "Best librams seen") or #Hover(ns, Link(90010)) > 0, "libram tooltip")
end)

test("Paladin: leveling, plate from level 40, polearms from 20", function()
    -- "leveling" scenario: level 25, classic talent tabs, fallback APIs,
    -- client conversion with no hit on gear
    ns = LoadAddon({ class = "PALADIN", level = 25, talentPoints = { 2, 14, 4 },
        missing = { "TooltipDataProcessor", "TooltipUtil", "MenuUtil", "C_Item" } })
    PaladinGear()
    Boot(ns)
    local spec, source = ns.Spec.Get()
    check(spec == "PROTECTION" and source == "talent tabs", "spec from talent tab points: " .. spec .. " " .. source)
    eq(ns.Weights.BandText(spec), "level 25: questing 70%", "weights while leveling")
    local total, cap, mode, r = ns.Character:CapUnits("PROTECTION", "HIT")
    check(mode == "rating" and r and not r.estimated and total == 0, "client conversion with no hit on gear")
    near(cap, 5 * 12 * 17 / 52, "5% cap converted to rating at level 25")
    -- Plate at 25: wearable from 40, so scored like an item for a higher level
    local result = Evaluate(ns, 22091)
    eq(result.needLevel, 40, "plate needs level 40")
    check(result.verdict == "LATER" or result.verdict == "NO" or result.verdict == "OFFSPEC", "plate at 25: " .. result.verdict)
    if result.verdict == "LATER" then
        eq(result.action, "Keep for level 40", "keep plate for level 40")
        eq(result.reason, "Plate can be worn from level 40", "reason names the level")
    end
    local lines = Hover(ns, Link(22091))
    check(#lines > 0 and not HasLine(lines, "Can't use"), "plate isn't 'can't use' while leveling")
    check(HasLine(lines, "Best head items seen") == nil or not HasLine(lines, "> 1."), "plate not in the usable list yet")
    check(#Hover(ns, Link(90124)) > 0, "verdict through the OnTooltipSetItem fallback")
    lines = Hover(ns, Link(90122))
    check(HasLine(lines, "level 25: questing 70%"), "level weights shown while leveling")
    -- Polearm at 15 (learnable from 20)
    W.level = 15
    ns.Character.dirty = true
    result = Evaluate(ns, 90131)
    eq(result.needLevel, 20, "polearms from level 20")
    check(result.reason == nil or result.reason:find("level 20"), "polearm reason: " .. tostring(result.reason))
    W.level = 45
    W.known[750] = true
    ns.Character.dirty = true
    check(ns.ItemData.CanUse(ns.ItemData.Parse(Link(22091))), "plate usable at 45 once trained")
    W.known[750] = nil
    local ok, reason = ns.ItemData.CanUse(ns.ItemData.Parse(Link(22091)))
    check(not ok and reason == "Can't wear Plate yet", "untrained plate at 45: " .. tostring(reason))
end)

-- Tests: all classes ------------------------------------------------------------------------

test("every class profile is consistent", function()
    ns = LoadAddon()
    for _, class in ipairs(CLASSES) do
        local profile = ns.Classes[class]
        local data = ns.TalentData[class]
        eq(#profile.specs, 3, class .. " has three specs")
        local bySpell = {}
        for _, s in ipairs(profile.specs) do
            local section = data.specs[s.id]
            check(section ~= nil, ("%s %s: spec ID %d in the talent data"):format(class, s.key, s.id))
            for _, n in ipairs(section and section.nodes or {}) do bySpell[n[2]] = n[3] end
            for _, field in ipairs({ "key", "name", "short", "role", "attack", "icon" }) do
                check(s[field] ~= nil, ("%s %s: field %s"):format(class, s.key, field))
            end
            check(s.attack == "SPELL" or s.attack == "MELEE" or s.attack == "RANGED", class .. " attack type")
        end
        for name, t in pairs(profile.weights.TALENTS or {}) do
            check(bySpell[t.spell] ~= nil, ("%s talent %s (spell %d) is in the talent tree"):format(class, name, t.spell))
            eq(bySpell[t.spell], t.ranks, ("%s talent %s ranks"):format(class, name))
        end
        for spec, caps in pairs(profile.weights.CAPS or {}) do
            for stat, def in pairs(caps) do
                check(type(def) == "table" and def.cap ~= nil and def.rating ~= nil, ("%s %s cap %s"):format(class, spec, stat))
            end
        end
        for word, key in pairs(profile.aliases or {}) do
            local found = false
            for _, s in ipairs(profile.specs) do if s.key == key then found = true end end
            check(found, ("%s alias %s -> %s"):format(class, word, key))
        end
        for _, t in ipairs(profile.debugTalents or {}) do
            check(bySpell[t[2]] ~= nil, ("%s debug talent %s is in the talent tree"):format(class, t[1]))
        end
    end
end)

test("weights of every class, spec and level", function()
    for _, class in ipairs(CLASSES) do
        ns = Boot(LoadAddon({ class = class, traitRanks = {} }))
        for _, level in ipairs({ 1, 10, 13, 25, 40, 59, 60 }) do
            W.level = level
            for _, spec in ipairs(ns.Spec.KEYS) do
                local w = ns.Weights.Get(spec)
                local count = 0
                for stat, v in pairs(w) do
                    count = count + 1
                    check(type(v) == "number" and v >= 0 and v == v and v < 100,
                        ("%s %s %s at %d = %s"):format(class, spec, stat, level, tostring(v)))
                    check(not stat:find("^SHARE_") and stat ~= "DAMAGE", ("%s %s leftover key %s"):format(class, spec, stat))
                end
                check(count >= 8, ("%s %s has weights at %d"):format(class, spec, level))
                local main = math.max(ns.Weights.Of(w, "STRENGTH"), ns.Weights.Of(w, "AGILITY"),
                    w.SPELL_DAMAGE or 0, w.HEALING or 0, w.STAMINA or 0)
                check(main > 0.2, ("%s %s at %d values a main stat"):format(class, spec, level))
            end
        end
        -- Every talent the weights use can be learned without errors
        local ranks = {}
        for _, key in ipairs(ns.Spec.KEYS) do
            for _, node in ipairs(ns.Spec.TALENTS[key]) do ranks[node[1]] = node[3] end
        end
        W.traitRanks = ranks
        FireEvent("TRAIT_CONFIG_UPDATED")
        for _, level in ipairs({ 12, 60 }) do
            W.level = level
            for _, spec in ipairs(ns.Spec.KEYS) do
                for stat, v in pairs(ns.Weights.Get(spec)) do
                    check(v >= 0 and v == v and v < 100, ("%s %s with all talents: %s = %s"):format(class, spec, stat, tostring(v)))
                end
            end
        end
    end
end)

test("spec detection from the talent tree for every class", function()
    for _, class in ipairs(CLASSES) do
        for i = 1, 3 do
            ns = LoadAddon({ class = class, traitRanks = {} })
            local profile = ns.Classes[class]
            local key = profile.specs[i].key
            local nodes = ns.TalentData[class].specs[profile.specs[i].id].nodes
            W.traitRanks = { [nodes[1][1]] = nodes[1][3], [nodes[2][1]] = nodes[2][3] }
            Boot(ns)
            local spec, source = ns.Spec.Get()
            eq(spec, key, class .. " spec " .. i)
            eq(source, "talents", class .. " spec " .. i .. " source")
        end
        -- The specialization API with Forever IDs, and the default
        ns = Boot(LoadAddon({ class = class, specIndex = 2 }))
        eq(ns.Spec.Get(), ns.Classes[class].specs[2].key, class .. " from the specialization API")
        ns = Boot(LoadAddon({ class = class }))
        local spec, source = ns.Spec.Get()
        check(source == "default" and spec == ns.Classes[class].defaultSpec, class .. " default spec")
    end
end)

local ALL_ITEMS = {
    90001, 90002, 90003, 90004, 90005, 90007, 90009, 90010, 90013, 90015, 90016, 90101, 90116, 90121,
    90122, 90124, 90125, 90126, 90131, 90201, 90202, 90203, 90204, 90205, 90206, 90207, 90208, 90209, 90210,
    90211, 90212, 90213, 90214, 90215, 90216, 18608, 18609, 19019, 22091, 22514, 11288,
}

test("every class boots, scores and renders", function()
    for _, class in ipairs(CLASSES) do
        for _, level in ipairs({ 12, 35, 60 }) do
            ns = LoadAddon({ class = class, level = level })
            W.equipped[1] = Link(90014)
            W.equipped[16] = Link(90125)
            W.bags[0] = { Link(90203), Link(90211) }
            Boot(ns)
            check(Printed("loaded for " .. ns.class.name), class .. " login message")
            eq(ns.ManaBar.frame ~= nil, ns.class.mana == true, class .. " mana bar only with mana")
            for _, id in ipairs(ALL_ITEMS) do
                local r = Evaluate(ns, id)
                check(r and r.action and r.action ~= "", ("%s %d: verdict for item %d"):format(class, level, id))
                local lines = Hover(ns, Link(id))
                check(#lines > 0, ("%s %d: tooltip for item %d"):format(class, level, id))
            end
            Slash("stats")
            Slash("best mainhand")
            Slash("best ranged")
            Slash("spec")
            Slash("debug")
            for _, line in ipairs(ns.db.lastDebug.lines) do
                check(not line:find("!! section"), class .. " debug section failed: " .. line)
            end
            WOWClassHelper_OnAddonCompartmentClick(ADDON, "LeftButton", UIParent)
            for _, e in ipairs(W.lastMenu.entries) do
                if e.kind == "button" then e.a() end
            end
            Slash("toggle")
            if not ns.class.mana then check(Printed("have no mana bar"), class .. " mana bar command explains") end
        end
    end
end)

test("what each class can use", function()
    local cases = {
        -- class, item, usable at 60
        { "WARRIOR", 90202, true }, { "WARRIOR", 90015, false }, { "WARRIOR", 90204, true },
        { "ROGUE", 90214, true }, { "ROGUE", 90201, false }, { "ROGUE", 90207, false },
        { "HUNTER", 90201, true }, { "HUNTER", 90202, false }, { "HUNTER", 90204, true },
        { "MAGE", 90015, true }, { "MAGE", 90211, true }, { "MAGE", 90004, false },
        { "WARLOCK", 90208, true }, { "WARLOCK", 90203, false },
        { "DRUID", 90209, true }, { "DRUID", 90206, true }, { "DRUID", 90124, false }, { "DRUID", 90211, false },
        { "SHAMAN", 90207, true }, { "SHAMAN", 90210, true }, { "SHAMAN", 90124, true }, { "SHAMAN", 90211, false },
        { "PALADIN", 90010, true }, { "PALADIN", 90209, false }, { "PRIEST", 90210, false },
    }
    for _, c in ipairs(cases) do
        ns = Boot(LoadAddon({ class = c[1] }))
        local ok, reason = ns.ItemData.CanUse(ns.ItemData.Parse(Link(c[2])))
        eq(ok == true, c[3], ("%s and %s (%s)"):format(c[1], ITEMS[c[2]].name, tostring(reason)))
    end
    -- Level gates: mail for Hunters and Shamans, plate for Warriors at 40
    ns = Boot(LoadAddon({ class = "WARRIOR", level = 30 }))
    W.equipped[5] = Link(90001)
    ns.Character.dirty = true
    local r = Evaluate(ns, 90202)
    eq(r.needLevel, 40, "Warrior plate at 30 needs level 40")
    eq(r.verdict, "LATER", "Warrior: better plate chest kept for later")
    eq(r.action, "Keep for level 40", "keep plate for level 40")
    eq(r.reason, "Plate can be worn from level 40", "reason")
    ns = Boot(LoadAddon({ class = "HUNTER", level = 30 }))
    eq(Evaluate(ns, 90201).needLevel, 40, "Hunter mail at 30 needs level 40")
end)

test("dual wield, ranged weapons and Feral weapon DPS", function()
    ns = LoadAddon({ class = "ROGUE", level = 30 })
    W.equipped[16] = Link(90211)   -- shortsword
    W.equipped[17] = Link(90121)   -- dagger
    Boot(ns)
    local r = Evaluate(ns, 90214)  -- hand axe
    eq(#r.current.replaced, 1, "one-hander replaces one weapon")
    check(r.current.replaced[1].id == 90211 or r.current.replaced[1].id == 90121, "replaces a hand weapon")
    check(ns.Compare.IsEquipped(ns.ItemData.Parse(Link(90121))), "off-hand weapon counts as equipped")
    W.equipped[17] = nil
    ns.Character.dirty = true
    r = Evaluate(ns, 90214)
    check((r.current.note or ""):find("Fills your empty off hand", 1, true), "empty off hand: " .. tostring(r.current.note))
    -- Off-hand damage counts half: the same weapon is worth less in the off hand
    local function DpsValue(result)
        for _, c in ipairs(result.current.contributions) do if c.stat == "DPS" then return c.value, c.delta end end
    end
    local offValue, offDelta = DpsValue(r)
    near(offDelta, (40 + 58) / 2 / 2.6, "stat line shows the weapon's real DPS")
    W.equipped[16] = nil
    ns.Character.dirty = true
    local mainValue = DpsValue(Evaluate(ns, 90214))
    near(offValue, mainValue * 0.5, "off-hand weapon DPS counts half")
    W.equipped[16] = Link(90211)
    W.known[674] = nil
    ns.Character.dirty = true
    check(not (Evaluate(ns, 90214).current.note or ""):find("off hand", 1, true), "no dual wield without the skill")
    -- Nothing on the item counts for the spec: sell it, it isn't "equal"
    r = Evaluate(ns, 90213)   -- healer necklace into an empty neck slot
    eq(r.verdict, "NO", "healer necklace for a Rogue")
    eq(r.action, "Sell", "sell it")
    -- Priests don't dual wield
    ns = LoadAddon({ class = "PRIEST" })
    W.equipped[16] = Link(90004)
    Boot(ns)
    eq(Evaluate(ns, 90121).current.replaced[1].id, 90004, "Priest: one-hander replaces the main hand")
    -- Ranged DPS: the Hunter's main weapon, small for a Warrior, nothing for a Mage
    for _, c in ipairs({ { "HUNTER", 3 }, { "WARRIOR", 0.01 } }) do
        ns = Boot(LoadAddon({ class = c[1], level = 30 }))
        local w = ns.Weights.Get(ns.Spec.Get())
        check((w.RANGED_DPS or 0) >= c[2], c[1] .. " ranged DPS weight " .. tostring(w.RANGED_DPS))
    end
    ns = Boot(LoadAddon({ class = "HUNTER", level = 30 }))
    local bow = Evaluate(ns, 90204)
    check(bow.current.contributions[1].stat == "RANGED_DPS", "bow DPS is the main reason for a Hunter")
    ns = Boot(LoadAddon({ class = "MAGE", level = 30 }))
    eq(ns.Weights.Get("FROST").RANGED_DPS, nil, "Mage: ranged weapon DPS doesn't count")
    eq(ns.Weights.Get("FROST").DPS, nil, "Mage: melee weapon DPS doesn't count")
    -- Site: Druid forms use the equipped weapon's DPS
    ns = Boot(LoadAddon({ class = "DRUID", level = 40 }))
    check((ns.Weights.Get("FERAL").DPS or 0) > 3, "Feral: weapon DPS counts")
    eq(ns.Weights.Get("BALANCE").WAND_DPS, nil, "Druids have no wand")
    -- Survival Hunters are scored as melee
    check(ns.Classes.HUNTER.specs[3].attack == "MELEE", "Survival is a melee spec")
end)

test("talents change the new classes' weights", function()
    local function TalentEffect(class, spec, level, talentName, stat)
        ns = Boot(LoadAddon({ class = class, level = level, traitRanks = {} }))
        local before = ns.Weights.Get(spec)[stat] or 0
        local t = ns.Weights.TALENTS[talentName]
        local node
        for _, key in ipairs(ns.Spec.KEYS) do
            for _, n in ipairs(ns.Spec.TALENTS[key]) do if n[2] == t.spell then node = n end end
        end
        W.traitRanks = { [node[1]] = t.ranks }
        FireEvent("TRAIT_CONFIG_UPDATED")
        return before, ns.Weights.Get(spec)[stat] or 0
    end
    local cases = {
        { "SHAMAN", "ENHANCEMENT", 60, "MENTAL_DEXTERITY", "INTELLECT" },   -- Intellect -> attack power
        { "SHAMAN", "ELEMENTAL", 60, "ELEMENTAL_FURY", "SPELL_CRIT" },
        { "HUNTER", "MARKSMANSHIP", 60, "CAREFUL_AIM", "INTELLECT" },
        { "HUNTER", "SURVIVAL", 60, "LIGHTNING_REFLEXES", "AGILITY" },
        { "MAGE", "ARCANE", 60, "ARCANE_BLAST", "INTELLECT" },
        { "MAGE", "FIRE", 60, "IGNITE", "CRIT" },
        { "MAGE", "FROST", 20, "WAND_SPECIALIZATION", "WAND_DPS" },
        { "WARLOCK", "AFFLICTION", 60, "SHADOW_MASTERY", "SHADOW_DAMAGE" },
        { "WARLOCK", "DEMONOLOGY", 30, "DEMONIC_EMBRACE", "STAMINA" },
        { "DRUID", "RESTORATION", 60, "BLOOM", "SPIRIT" },
        { "DRUID", "BALANCE", 60, "MOONFURY", "ARCANE_DAMAGE" },
        { "DRUID", "FERAL", 60, "NATURAL_INSTINCT", "CRIT" },
        { "WARRIOR", "ARMS", 60, "TWO_HANDED_WEAPON", "DPS" },
        { "WARRIOR", "FURY", 60, "FLURRY", "CRIT" },
        { "WARRIOR", "PROTECTION", 60, "BASTION", "STRENGTH" },
        { "ROGUE", "ASSASSINATION", 60, "SEAL_FATE", "CRIT" },
        { "ROGUE", "COMBAT", 60, "DUAL_WIELD_SPECIALIZATION", "DPS" },
    }
    for _, c in ipairs(cases) do
        local before, after = TalentEffect(c[1], c[2], c[3], c[4], c[5])
        check(after > before * 1.02, ("%s %s: %s raises %s (%.3f -> %.3f)"):format(c[1], c[2], c[4], c[5], before, after))
    end
    -- A spec-limited talent doesn't change the other specs
    local before, after = TalentEffect("SHAMAN", "RESTORATION", 60, "ELEMENTAL_FURY", "SPELL_CRIT")
    near(after, before, "Elemental Fury doesn't touch the Restoration weights")
end)

test("old WOWPriest and WOWPaladin knowledge bases are imported once", function()
    local oldItems = {
        ["22514"] = { id = 22514, key = "22514", name = "Circlet of Faith", equipLoc = "INVTYPE_HEAD", classID = 4,
                      subclassID = 1, reqLevel = 60, stats = { HEALING = 75 }, seen = 3, sources = { tooltip = 3 } },
        ["11288"] = { id = 11288, key = "11288", name = "Greater Magic Wand", equipLoc = "INVTYPE_RANGEDRIGHT", classID = 2,
                      subclassID = 19, reqLevel = 13, stats = { DPS = 17.5 }, seen = 1, sources = { bag = 1 } },
        ["junk"] = "not an entry",
    }
    local paladinItems = {
        ["22091"] = { id = 22091, key = "22091", name = "Soulforge Helm", equipLoc = "INVTYPE_HEAD", classID = 4,
                      subclassID = 4, reqLevel = 0, stats = { STRENGTH = 16 }, vendor = "Bob" },
        ["22514"] = { id = 22514, key = "22514", name = "Circlet of Faith", equipLoc = "INVTYPE_HEAD", classID = 4,
                      subclassID = 1, reqLevel = 60, stats = { HEALING = 75 }, zone = "Naxxramas" },
    }
    ns = Boot(LoadAddon({ class = "MAGE", oldPriestDB = { kb = { items = oldItems }, legacy = { adventure = 3 } },
        oldPaladinDB = { kb = { items = paladinItems } } }))
    check(Printed("imported 2 items from the WOWPriest knowledge base"), "Priest items imported")
    check(Printed("imported 1 items from the WOWPaladin knowledge base"), "Paladin items imported")
    check(ns.KB:Get("22514") and ns.KB:Get("22091") and ns.KB:Get("11288"), "entries present")
    eq(ns.KB:Get("22514").zone, "Naxxramas", "missing fields filled in from the second import")
    eq(ns.KB:Get("11288").stats.WAND_DPS, 17.5, "old wand DPS moved to WAND_DPS")
    eq(ns.db.legacy.adventure, 3, "Legacy perk rank taken over")
    check(ns.db.imported.WOWPriest and ns.db.imported.WOWPaladin, "imports remembered")
    -- Next login: nothing imported again
    local saved, char = WOWClassHelperDB, WOWClassHelperCharDB
    printed = {}
    ns = Boot(LoadAddon({ class = "MAGE", savedVars = saved, charVars = char,
        oldPriestDB = { kb = { items = oldItems } } }))
    check(not Printed("imported"), "no second import")
    check(ns.KB:Get("22091") ~= nil, "knowledge base shared across characters of the account")
    -- The other characters keep their own spec override and bags
    ns.char.specOverride = "FIRE"
    ns = Boot(LoadAddon({ class = "WARLOCK", savedVars = saved }))
    eq(ns.char.specOverride, false, "new character starts on automatic")
    eq(ns.KB:Get("22091") ~= nil, true, "same knowledge base for the Warlock")
end)

test("no unknown events registered", function()
    local names = {}
    for event in pairs(unknownEvents) do names[#names + 1] = event end
    table.sort(names)
    eq(#names, 0, "unknown events (typo, or add them to KNOWN_EVENTS): " .. table.concat(names, ", "))
end)

-- Summary ---------------------------------------------------------------------------

realPrint("")
realPrint(("%d tests, %d checks passed, %d failed"):format(results.tests, results.passed, results.failed))
for i, f in ipairs(results.failures) do
    if i > 60 then realPrint(("  ... and %d more"):format(#results.failures - 60)) break end
    realPrint("  - " .. f)
end
os.exit(results.failed > 0 and 1 or 0)
