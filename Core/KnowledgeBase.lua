-- WOWClassHelper: knowledge base of every item the player has seen
--
-- Item entries are stored account-wide in WOWClassHelperDB.kb (every class
-- learns from what the others saw), keyed by item key (item ID, plus random
-- suffix if present). Each entry keeps the item info from ItemData.Parse plus
-- where and when it was seen:
--
--   items[key] = { id, name, link, quality, ilvl, reqLevel, equipLoc, classID,
--                  subclassID, sellPrice, icon, setID, stats,
--                  firstSeen, lastSeen, seen, sources = { tooltip = n, loot = n, ... },
--                  buyPrice, vendor, zone,
--                  quest, instance, instanceType, profession }
--
-- How an item is obtained (Compare.Origins): vendor (merchant window), quest
-- (quest reward; the title, or true if unknown), instance + instanceType
-- ("party" dungeon or "raid": looted, rolled on or looted by the group
-- there), profession (seen in a profession window), zone (looted outside
-- an instance).
--
-- What this character carries is stored per character
-- (WOWClassHelperCharDB.owned = { bags = { [key] = count }, bank = { [key] = count } }).
local _, ns = ...

-- revision changes whenever entries are added or ownership changes, so
-- rankings built from the knowledge base (Compare.Ranking) know when to rebuild.
local KB = ns:RegisterModule("KnowledgeBase", { revision = 0 })
ns.KB = KB

local function Changed()
    KB.revision = KB.revision + 1
end

local COUNT_INTERVAL = 60   -- count a repeat sighting at most once per minute

local INFO_FIELDS = {
    "key", "id", "name", "link", "quality", "ilvl", "reqLevel", "equipLoc", "classID",
    "subclassID", "sellPrice", "icon", "setID",
}

function KB:OnInitialize()
    local kb = ns.db.kb
    kb.owned = nil   -- account-wide bags/bank of the old addons; now per character
    self.items = kb.items
    self.owned = ns.char.owned
    self.owned.bags = self.owned.bags or {}
    self.owned.bank = self.owned.bank or {}
    -- Entries from older versions kept wand and ranged DPS as melee DPS
    for _, entry in pairs(self.items) do
        if type(entry.stats) == "table" then
            ns.ItemData.SplitWeaponDPS(entry.stats, entry.classID, entry.subclassID)
        end
    end
end

-- Record an item link. source: "tooltip", "bag", "bank", "equipped", "loot",
-- "merchant", "chat". extra: optional fields to store (buyPrice, vendor, zone).
function KB:Record(link, source, extra, isRetry)
    if not self.items or type(link) ~= "string" then return end
    local info = ns.ItemData.Parse(link)
    if not info then
        -- Not cached yet: retry once when the client has loaded the item.
        if not isRetry and Item and Item.CreateFromItemLink then
            local ok, item = pcall(Item.CreateFromItemLink, Item, link)
            if ok and item and not item:IsItemEmpty() then
                item:ContinueOnItemLoad(function() KB:Record(link, source, extra, true) end)
            end
        end
        return
    end

    local now = time()
    local entry = self.items[info.key]
    if not entry then
        entry = { firstSeen = now, seen = 0, sources = {} }
        self.items[info.key] = entry
        Changed()
    end

    for _, field in ipairs(INFO_FIELDS) do
        if info[field] ~= nil then entry[field] = info[field] end
    end
    if next(info.stats) then entry.stats = info.stats end
    entry.stats = entry.stats or {}

    local isNewSighting = (now - (entry.lastSeen or 0)) >= COUNT_INTERVAL or entry.lastSource ~= source
    if isNewSighting then
        entry.seen = entry.seen + 1
        entry.sources[source] = (entry.sources[source] or 0) + 1
    end
    entry.lastSeen = now
    entry.lastSource = source

    if extra then
        -- true means "known, details unknown" and never replaces a detail
        for k, v in pairs(extra) do
            if v ~= true or entry[k] == nil then entry[k] = v end
        end
    end
    return entry
end

function KB:Get(key)
    return self.items and self.items[key]
end

-- Copies entries from another knowledge base (WOWPriest, WOWPaladin) that
-- aren't known yet; for known ones, fills in vendor, price and zone if
-- missing. Returns the number of new entries.
function KB:Import(items)
    local added = 0
    for key, old in pairs(items) do
        if type(old) == "table" and type(old.stats) == "table" and old.equipLoc then
            local entry = self.items[key]
            if not entry then
                entry = {}
                for k, v in pairs(old) do entry[k] = v end
                entry.stats = {}
                for stat, v in pairs(old.stats) do entry.stats[stat] = v end
                entry.sources = {}
                for source, n in pairs(type(old.sources) == "table" and old.sources or {}) do
                    entry.sources[source] = n
                end
                entry.seen = tonumber(entry.seen) or 1
                ns.ItemData.SplitWeaponDPS(entry.stats, entry.classID, entry.subclassID)
                self.items[key] = entry
                added = added + 1
            else
                for _, field in ipairs({ "vendor", "buyPrice", "zone" }) do
                    if entry[field] == nil then entry[field] = old[field] end
                end
            end
        end
    end
    if added > 0 then Changed() end
    return added
end

-- How many pieces of a set the player owns in bags/bank (not equipped)
function KB:OwnedSetPieces(setID)
    local count = 0
    for _, place in ipairs({ "bags", "bank" }) do
        for key in pairs(self.owned[place] or {}) do
            local entry = self.items[key]
            if entry and entry.setID == setID then count = count + 1 end
        end
    end
    return count
end

-- Scanners --------------------------------------------------------------

local function ContainerLinks(bagIDs)
    local links = {}
    if not C_Container then return links end
    for _, bag in ipairs(bagIDs) do
        local ok, slots = pcall(C_Container.GetContainerNumSlots, bag)
        if ok and slots then
            for slot = 1, slots do
                local link = C_Container.GetContainerItemLink(bag, slot)
                if link then table.insert(links, link) end
            end
        end
    end
    return links
end

function KB:ScanContainers(place, bagIDs)
    local owned = {}
    for _, link in ipairs(ContainerLinks(bagIDs)) do
        local entry = self:Record(link, place)
        local key = entry and ns.ItemData.KeyFromLink(link)
        if key then owned[key] = (owned[key] or 0) + 1 end
    end
    self.owned[place] = owned
    Changed()
end

function KB:ScanBags()
    local bags = {}
    for bag = 0, (NUM_BAG_SLOTS or 4) do table.insert(bags, bag) end
    self:ScanContainers("bags", bags)
end

function KB:ScanBank()
    local bags = { (Enum.BagIndex and Enum.BagIndex.Bank) or -1 }
    local first = (NUM_BAG_SLOTS or 4) + 1
    for bag = first, first + (NUM_BANKBAGSLOTS or 7) - 1 do table.insert(bags, bag) end
    self:ScanContainers("bank", bags)
end

function KB:ScanEquipped()
    for _, slot in ipairs(ns.Character.SLOT_IDS) do
        local link = GetInventoryItemLink("player", slot)
        if link then self:Record(link, "equipped") end
    end
end

local function SafeCall(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, a, b, c = pcall(func, ...)
    if not ok then return nil end
    return a, b, c
end

-- { instance, instanceType } inside a dungeon or raid, else nil
local function InstanceExtra()
    local inInstance, instanceType = SafeCall(IsInInstance)
    if not inInstance or (instanceType ~= "party" and instanceType ~= "raid") then return nil end
    local name = SafeCall(GetInstanceInfo)
    if type(name) ~= "string" or name == "" then name = SafeCall(GetRealZoneText) end
    return { instance = name, instanceType = instanceType }
end

function KB:ScanLoot()
    local extra = InstanceExtra() or {}
    extra.zone = SafeCall(GetRealZoneText)
    for i = 1, (GetNumLootItems() or 0) do
        local link = GetLootSlotLink(i)
        if link then self:Record(link, "loot", extra) end
    end
end

-- Group loot roll in a dungeon or raid
function KB:ScanLootRoll(rollID)
    local link = SafeCall(GetLootRollItemLink, rollID)
    if link then self:Record(link, "loot", InstanceExtra()) end
end

-- Quest rewards in the quest dialog (accepting or turning in)
function KB:ScanQuestRewards()
    local title = SafeCall(GetTitleText)
    local extra = { quest = (type(title) == "string" and title ~= "") and title or true }
    for _, kind in ipairs({ "choice", "reward" }) do
        local count = SafeCall(kind == "choice" and GetNumQuestChoices or GetNumQuestRewards) or 0
        for i = 1, count do
            local link = SafeCall(GetQuestItemLink, kind, i)
            if link then self:Record(link, "quest", extra) end
        end
    end
end

-- Gear in an open profession window (crafted items). Only equippable
-- items are recorded; the window updates often, so at most every 2 sec.
local TRADE_SKILL_INTERVAL = 2
function KB:ScanTradeSkill(force)
    if type(GetNumTradeSkills) ~= "function" or type(GetTradeSkillItemLink) ~= "function" then return end
    local now = GetTime and GetTime() or 0
    if not force and self.lastTradeScan and now - self.lastTradeScan < TRADE_SKILL_INTERVAL then return end
    self.lastTradeScan = now
    local profession = SafeCall(GetTradeSkillLine)
    local extra = { profession = (type(profession) == "string" and profession ~= "") and profession or true }
    for i = 1, (SafeCall(GetNumTradeSkills) or 0) do
        local _, kind = SafeCall(GetTradeSkillInfo, i)
        if kind ~= "header" then
            local link = SafeCall(GetTradeSkillItemLink, i)
            local info = link and ns.ItemData.Parse(link)
            if info and info.equipLoc ~= "" and info.equipLoc ~= "INVTYPE_NON_EQUIP_IGNORE" then
                self:Record(link, "craft", extra)
            end
        end
    end
end

local function MerchantPrice(index)
    if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
        local ok, data = pcall(C_MerchantFrame.GetItemInfo, index)
        if ok and type(data) == "table" then return data.price end
    end
    if GetMerchantItemInfo then
        local _, _, price = GetMerchantItemInfo(index)
        return price
    end
end

function KB:ScanMerchant()
    local vendor = UnitName("npc")
    for i = 1, (GetMerchantNumItems() or 0) do
        local link = GetMerchantItemLink(i)
        if link then
            self:Record(link, "merchant", { buyPrice = MerchantPrice(i), vendor = vendor })
        end
    end
end

-- Loot messages; inside a dungeon or raid they mark the item as from there
function KB:ScanChat(msg)
    local extra = InstanceExtra()
    for itemString in msg:gmatch("item:[%-%d:]+") do
        self:Record(itemString, "chat", extra)
    end
end

function KB:OnEnable()
    local events = CreateFrame("Frame")
    for _, event in ipairs({
        "PLAYER_ENTERING_WORLD", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED",
        "LOOT_READY", "MERCHANT_SHOW", "BANKFRAME_OPENED", "CHAT_MSG_LOOT",
        "START_LOOT_ROLL", "QUEST_DETAIL", "QUEST_COMPLETE", "TRADE_SKILL_SHOW", "TRADE_SKILL_UPDATE",
    }) do
        pcall(events.RegisterEvent, events, event)
    end

    events:SetScript("OnEvent", function(_, event, arg1)
        if event == "START_LOOT_ROLL" then return self:ScanLootRoll(arg1) end
        if event == "QUEST_DETAIL" or event == "QUEST_COMPLETE" then return self:ScanQuestRewards() end
        if event == "TRADE_SKILL_SHOW" then return self:ScanTradeSkill(true) end
        if event == "TRADE_SKILL_UPDATE" then return self:ScanTradeSkill() end
        if event == "PLAYER_ENTERING_WORLD" then
            self:ScanBags()
            self:ScanEquipped()
        elseif event == "BAG_UPDATE_DELAYED" then
            self:ScanBags()
        elseif event == "PLAYER_EQUIPMENT_CHANGED" then
            self:ScanEquipped()
        elseif event == "LOOT_READY" then
            self:ScanLoot()
        elseif event == "MERCHANT_SHOW" then
            self:ScanMerchant()
        elseif event == "BANKFRAME_OPENED" then
            self:ScanBank()
        elseif event == "CHAT_MSG_LOOT" and type(arg1) == "string" and not ns.IsSecret(arg1) then
            self:ScanChat(arg1)
        end
    end)
end

-- Commands --------------------------------------------------------------

local QUALITY_NAMES = { [0] = "Poor", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Artifact", "Heirloom" }

ns:RegisterCommand("kb", "[wipe]", "knowledge base summary (wipe = delete all entries)", function(arg)
    if strtrim(arg or ""):lower() == "wipe" then
        wipe(KB.items)
        wipe(KB.owned.bags)
        wipe(KB.owned.bank)
        Changed()
        ns.Print("knowledge base wiped.")
        return
    end
    local total, gear, byQuality = 0, 0, {}
    for _, entry in pairs(KB.items) do
        total = total + 1
        if entry.equipLoc and entry.equipLoc ~= "" then gear = gear + 1 end
        local q = entry.quality or 1
        byQuality[q] = (byQuality[q] or 0) + 1
    end
    ns.Print(("knowledge base: %d items, %d equippable (shared by all characters of the account)."):format(total, gear))
    for q = 0, 7 do
        if byQuality[q] then
            local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
            local name = QUALITY_NAMES[q] or tostring(q)
            print(("  %s: %d"):format(color and (color.hex .. name .. "|r") or name, byQuality[q]))
        end
    end
end)
