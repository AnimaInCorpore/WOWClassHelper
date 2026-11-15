-- WOWClassHelper: /wch debug - diagnostics for checking the addon's assumptions
--
-- Collects which APIs exist in this client, how spec / level / stats are
-- detected, which Forever talents are known, and the raw stat keys of an
-- equipped item. The report is shown in a copyable window (Ctrl+A, Ctrl+C)
-- and also saved to WOWClassHelperDB.lastDebug, so it can be read from the
-- SavedVariables file after logging out.
local addonName, ns = ...

local Debug = {}
ns.Debug = Debug

local SLOT_NAMES = {
    head = 1, neck = 2, shoulder = 3, chest = 5, waist = 6, legs = 7, feet = 8,
    wrist = 9, hands = 10, finger = 11, finger2 = 12, trinket = 13, trinket2 = 14,
    back = 15, mainhand = 16, offhand = 17, ranged = 18, wand = 18, relic = 18,
}

local APIS = {
    "TooltipDataProcessor.AddTooltipPostCall", "Enum.TooltipDataType.Item",
    "TooltipUtil.GetDisplayedItem", "C_TooltipInfo.GetInventoryItem",
    "C_Item.GetItemInfo", "C_Item.GetItemStats", "GetItemStats",
    "C_Item.GetDetailedItemLevelInfo", "Item.CreateFromItemLink",
    "GetSpecialization", "GetSpecializationInfo", "C_SpecializationInfo.GetSpecialization",
    "C_ClassTalents.GetActiveConfigID", "C_Traits.GetNodeInfo", "GetNumTalentTabs", "GetTalentTabInfo",
    "IsPlayerSpell", "GetCombatRating", "GetCombatRatingBonus",
    "GetCombatRatingBonusForCombatRatingValue", "GetSpellHitModifier", "GetHitModifier",
    "UnitDefense", "GetManaRegen", "GetSpellBonusDamage", "GetSpellBonusHealing",
    "C_Spell.GetSpellPowerCost", "GetMaxLevelForPlayerExpansion",
    "C_Container.GetContainerItemLink", "C_MerchantFrame.GetItemInfo", "GetMerchantItemInfo",
    "issecretvalue", "Enum.PowerType.Mana", "Enum.PowerType.HolyPower",
    "Enum.BagIndex.Bank", "NUM_BAG_SLOTS", "NUM_BANKBAGSLOTS",
    "AddonCompartmentFrame", "MenuUtil.CreateContextMenu",
}

local RATINGS = {
    "CR_HIT_MELEE", "CR_HIT_RANGED", "CR_HIT_SPELL", "CR_CRIT_MELEE", "CR_CRIT_RANGED", "CR_CRIT_SPELL",
    "CR_HASTE_MELEE", "CR_HASTE_RANGED", "CR_HASTE_SPELL", "CR_DEFENSE_SKILL", "CR_DODGE", "CR_PARRY",
    "CR_BLOCK", "CR_MASTERY", "CR_VERSATILITY_DAMAGE_DONE",
}

-- Helpers -----------------------------------------------------------------

-- Resolves a dotted global path like "C_Item.GetItemStats"
local function Resolve(path)
    local value = _G
    for part in path:gmatch("[^%.]+") do
        if type(value) ~= "table" then return nil end
        value = value[part]
    end
    return value
end

-- Safe tostring that also marks secret values
local function Str(v)
    if ns.IsSecret(v) then return "<secret>" end
    if type(v) == "number" then
        return tostring(math.floor(v * 100 + 0.5) / 100)
    end
    return tostring(v)
end

-- Calls fn and returns all results as strings, or the error
local function Try(fn, ...)
    if type(fn) ~= "function" then return "n/a" end
    local r = { pcall(fn, ...) }
    if not r[1] then return "error: " .. tostring(r[2]) end
    local parts = {}
    for i = 2, #r do parts[#parts + 1] = Str(r[i]) end
    return #parts > 0 and table.concat(parts, ", ") or "(nothing)"
end

local function Known(spellID)
    if not IsPlayerSpell then return "?" end
    local ok, known = pcall(IsPlayerSpell, spellID)
    return ok and (known and "yes" or "no") or "err"
end

-- Sections ----------------------------------------------------------------

local function SectionClient(out)
    local version, build, date, toc = GetBuildInfo()
    out("Client: version %s, build %s (%s), interface %s", Str(version), Str(build), Str(date), Str(toc))
    out("WOW_PROJECT_ID: %s   Addon %s, TOC interface 16001", Str(WOW_PROJECT_ID), addonName)
    out("Character: %s, class %s (profile: %s), level %s, in combat: %s", Str(UnitName("player")),
        Str(ns.classToken), ns.class and ns.class.name or "none", Str(UnitLevel("player")),
        InCombatLockdown() and "YES (values may be secret)" or "no")
end

local function SectionApis(out)
    out("APIs (missing ones use a fallback or are skipped):")
    for _, path in ipairs(APIS) do
        local v = Resolve(path)
        local state
        if v == nil then
            state = "MISSING"
        elseif type(v) == "function" then
            state = "ok"
        else
            state = "= " .. Str(v)
        end
        out("  %-42s %s", path, state)
    end
end

local function SectionSpec(out)
    out("Spec detection:")
    local data = ns.TalentData and ns.TalentData[ns.classToken]
    out("  Forever talent tree %s, points: %s", Str(data and data.tree), ns.Spec.PointsText(ns.Spec.TalentPoints()))
    if C_ClassTalents and C_ClassTalents.GetActiveConfigID then
        out("  C_ClassTalents.GetActiveConfigID() -> %s", Try(C_ClassTalents.GetActiveConfigID))
    end
    local learned = {}
    for _, key in ipairs(ns.Spec.KEYS) do
        for _, node in ipairs(ns.Spec.TALENTS[key]) do
            if IsPlayerSpell and Known(node[2]) == "yes" then
                learned[#learned + 1] = ("%s:%d"):format(ns.Spec.INFO[key].short, node[2])
            end
        end
    end
    out("  Talent spells known: %s", #learned > 0 and table.concat(learned, ", ") or "none")
    local counted, names = {}, {}
    for name in pairs(ns.Weights.TALENTS or {}) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        local t = ns.Weights.TALENTS[name]
        local rank = ns.Spec.TalentRank(t.spell)
        if rank > 0 then counted[#counted + 1] = ("%s %d/%d"):format(name, rank, t.ranks) end
    end
    out("  Talents counted in the weights: %s", #counted > 0 and table.concat(counted, ", ") or "none")
    if GetSpecialization then
        local index = Try(GetSpecialization)
        out("  GetSpecialization() -> %s", index)
        local n = tonumber(index)
        if n and n > 0 and GetSpecializationInfo then
            out("  GetSpecializationInfo(%d) -> %s", n, Try(GetSpecializationInfo, n))
        end
    end
    if GetNumTalentTabs and GetTalentTabInfo then
        local okTabs, numTabs = pcall(GetNumTalentTabs)
        out("  GetNumTalentTabs() -> %s", okTabs and Str(numTabs) or "error")
        for tab = 1, math.min(okTabs and tonumber(numTabs) or 0, 3) do
            out("  GetTalentTabInfo(%d) -> %s", tab, Try(GetTalentTabInfo, tab))
        end
    end
    local detected, detectSource = ns.Spec.Detect()
    local spec, source = ns.Spec.Get()
    out("  Detected: %s (%s)   Used: %s (%s)", Str(detected), detectSource, spec, source)
    out("  Level %d / max %d, leveling: %s, weights: %s", ns.Spec.GetLevel(), ns.Spec.GetMaxLevel(),
        tostring(ns.Spec.IsLeveling()), ns.Weights.BandText(spec))
end

local function SectionProficiency(out)
    local class = ns.class
    if not IsPlayerSpell then
        out("Proficiencies: IsPlayerSpell missing - using the built-in %s table", class.name)
        return
    end
    local parts = {}
    local armor = {}
    for sub in pairs(class.armor or {}) do armor[#armor + 1] = sub end
    table.sort(armor)
    for _, sub in ipairs(armor) do
        local skill = ns.ItemData.ARMOR_SKILLS[sub]
        if skill then parts[#parts + 1] = ns.ItemData.ARMOR_NAMES[sub] .. "=" .. Known(skill) end
    end
    local weapons = {}
    for sub in pairs(class.weapons or {}) do weapons[#weapons + 1] = sub end
    table.sort(weapons)
    for _, sub in ipairs(weapons) do
        local skill = ns.ItemData.WEAPON_SKILLS[sub]
        if skill then parts[#parts + 1] = ns.ItemData.WEAPON_NAMES[sub] .. "=" .. Known(skill) end
    end
    if class.dualWield then parts[#parts + 1] = "Dual Wield=" .. Known(674) end
    out("Proficiencies: %s", table.concat(parts, ", "))
    parts = {}
    for _, t in ipairs(class.debugTalents or {}) do parts[#parts + 1] = t[1] .. "=" .. Known(t[2]) end
    if #parts > 0 then out("Talents (by spell ID): %s", table.concat(parts, ", ")) end
end

local function SectionPower(out)
    local mana = Enum.PowerType and Enum.PowerType.Mana or 0
    out("Power: type %s, mana %s / %s", Try(UnitPowerType, "player"),
        Try(UnitPower, "player", mana), Try(UnitPowerMax, "player", mana))
    local hp = Enum.PowerType and Enum.PowerType.HolyPower
    if hp then
        out("  Holy Power (not used in Forever): %s / %s", Try(UnitPower, "player", hp), Try(UnitPowerMax, "player", hp))
    end
    out("  GetManaRegen() -> %s (per second: outside / while casting)", Try(GetManaRegen))
    local sample = ns.class.sampleSpell
    if sample and C_Spell and C_Spell.GetSpellPowerCost then
        local ok, costs = pcall(C_Spell.GetSpellPowerCost, sample[1])
        local first = ok and type(costs) == "table" and costs[1]
        out("  GetSpellPowerCost(%d %s) -> %s", sample[1], sample[2],
            first and ("type " .. Str(first.type) .. ", cost " .. Str(first.cost))
            or (ok and "no cost data" or "error"))
    end
    local bar = ns.ManaBar
    if bar and bar.frame then
        out("  Five-second-rule timer: %s", bar.ruleEnd and ("running, %ss left"):format(Str(bar.ruleEnd - GetTime()))
            or "idle (full regeneration)")
    end
end

local function SectionStats(out)
    local parts = {}
    for i, name in ipairs({ "Str", "Agi", "Sta", "Int", "Spi" }) do
        local ok, _, effective = pcall(UnitStat, "player", i)
        parts[#parts + 1] = name .. " " .. (ok and Str(effective) or "err")
    end
    out("Character sheet: %s, armor %s", table.concat(parts, ", "), Try(UnitArmor, "player"))
    local school = ns.class.school
    out("  GetHitModifier() -> %s   GetSpellHitModifier() -> %s   UnitDefense() -> %s",
        Try(GetHitModifier), Try(GetSpellHitModifier), Try(UnitDefense, "player"))
    out("  GetSpellBonusDamage(%s) -> %s   GetSpellBonusHealing() -> %s",
        school and (school.id .. " " .. school.name) or "-", school and Try(GetSpellBonusDamage, school.id) or "-",
        Try(GetSpellBonusHealing))

    out("Combat ratings (index: rating -> bonus %%, bonus %% for 100 rating):")
    for _, name in ipairs(RATINGS) do
        local cr = _G[name]
        if type(cr) ~= "number" then
            out("  %-28s MISSING", name)
        else
            out("  %-28s %d: %s -> %s, %s", name, cr, Try(GetCombatRating, cr), Try(GetCombatRatingBonus, cr),
                Try(GetCombatRatingBonusForCombatRatingValue, cr, 100))
        end
    end

    local C = ns.Character
    C:Refresh()
    local spec = ns.Spec.Get()
    out("Conversion used by the addon (percent per rating point):")
    for _, name in ipairs(RATINGS) do
        local r = C:Rating(name)
        if r then out("  %-28s %s%s", name, Str(r.ratio), r.estimated and " (estimated)" or "") end
    end
    out("Totals used for caps (%s, in item stat units):", spec)
    local capped = {}
    for stat in pairs(ns.Weights.CAPS[spec] or {}) do capped[#capped + 1] = stat end
    table.sort(capped)
    for _, stat in ipairs(capped) do
        local total, cap, mode = C:CapUnits(spec, stat)
        out("  %-9s gear %s, total %s, cap %s, mode %s", stat,
            Str(C.totals[stat] or 0), Str(total or C:Total(stat)), Str(cap or "none"), Str(mode or "-"))
    end
    local mods = {}
    for name, value in pairs(C.modifiers) do mods[#mods + 1] = name .. "=" .. Str(value) end
    table.sort(mods)
    out("  Modifiers (talents/buffs): %s", #mods > 0 and table.concat(mods, ", ") or "none")
    local sets = {}
    for setID, count in pairs(C.sets) do sets[#sets + 1] = setID .. "=" .. count end
    out("  Equipped set pieces: %s", #sets > 0 and table.concat(sets, ", ") or "none")
end

local function SectionWeights(out)
    local spec = ns.Spec.Get()
    local weights = ns.Weights.Get(spec)
    local rows = {}
    for stat, w in pairs(weights) do
        if w > 0 then rows[#rows + 1] = { stat, w } end
    end
    table.sort(rows, function(a, b) return a[2] > b[2] end)
    local parts = {}
    for i, row in ipairs(rows) do
        if i > 24 then break end
        parts[#parts + 1] = ("%s %s"):format(row[1], Str(row[2]))
    end
    out("Weights for %s (%s): %s", spec, ns.Weights.BandText(spec), table.concat(parts, ", "))
end

local function SectionItem(out, slot)
    local link = GetInventoryItemLink("player", slot)
    if not link then
        out("Equipped item in slot %d: none", slot)
        return
    end
    local GetInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local name, _, quality, ilvl, reqLevel, _, _, _, equipLoc, _, sellPrice,
          classID, subclassID, _, _, setID = GetInfo(link)
    out("Equipped item in slot %d: %s", slot, Str(name))
    out("  quality %s, ilvl %s, reqLevel %s, equipLoc %s, class %s/%s, setID %s, sell %s",
        Str(quality), Str(ilvl), Str(reqLevel), Str(equipLoc), Str(classID), Str(subclassID),
        Str(setID), Str(sellPrice))
    out("  item string: %s", Str(link:match("item:[%-%d:]+")))

    local GetStats = (C_Item and C_Item.GetItemStats) or GetItemStats
    local ok, raw = pcall(GetStats, link)
    if not ok then
        out("  GetItemStats error: %s", tostring(raw))
    elseif type(raw) ~= "table" or not next(raw) then
        out("  GetItemStats returned no stats - the addon will use Data/Items.lua if the item is there")
    else
        local keys = {}
        for k in pairs(raw) do keys[#keys + 1] = k end
        table.sort(keys)
        out("  Raw stats (game key = value -> addon key):")
        for _, k in ipairs(keys) do
            out("    %s = %s -> %s", k, Str(raw[k]), ns.ItemData.NormalizeStat(k))
        end
    end
    local info = ns.ItemData.Parse(link)
    if info then
        local keys = {}
        for k, v in pairs(info.stats) do keys[#keys + 1] = k .. "=" .. Str(v) end
        table.sort(keys)
        out("  Stats the addon scores: %s", table.concat(keys, ", "))
    end

    -- Tooltip text shows whether hit/crit are given in % or as ratings
    if C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
        local okTip, data = pcall(C_TooltipInfo.GetInventoryItem, "player", slot)
        if okTip and type(data) == "table" and data.lines then
            out("  Tooltip lines:")
            for i, line in ipairs(data.lines) do
                if i > 20 then break end
                local text = line.leftText
                if type(text) == "string" and text ~= "" and not ns.IsSecret(text) then
                    out("    %s", (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")))
                end
            end
        end
    end
end

local function SectionData(out)
    local items, sets, talentClasses = 0, 0, 0
    for _ in pairs(ns.Items or {}) do items = items + 1 end
    for _ in pairs(ns.SetData and ns.SetData.Sets or {}) do sets = sets + 1 end
    for _ in pairs(ns.TalentData or {}) do talentClasses = talentClasses + 1 end
    local kb, bags, bank = 0, 0, 0
    for _ in pairs(ns.KB.items or {}) do kb = kb + 1 end
    for _ in pairs(ns.KB.owned and ns.KB.owned.bags or {}) do bags = bags + 1 end
    for _ in pairs(ns.KB.owned and ns.KB.owned.bank or {}) do bank = bank + 1 end
    out("Data: %d exported items, %d exported sets, talent trees of %d classes, knowledge base %d items (%d in bags, %d in bank)",
        items, sets, talentClasses, kb, bags, bank)
    local imported = {}
    for name in pairs(ns.db.imported or {}) do imported[#imported + 1] = name end
    table.sort(imported)
    out("Imported from old addons: %s", #imported > 0 and table.concat(imported, ", ") or "nothing")
end

-- Copy window -------------------------------------------------------------

local function GetCopyFrame()
    if Debug.frame then return Debug.frame end

    local f = CreateFrame("Frame", "WOWClassHelperDebugFrame", UIParent, "BackdropTemplate")
    f:SetSize(680, 460)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -18)
    title:SetText("WOWClassHelper debug - Ctrl+A, then Ctrl+C to copy")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    local ok, scroll = pcall(CreateFrame, "ScrollFrame", "WOWClassHelperDebugScroll", f, "UIPanelScrollFrameTemplate")
    if not ok then
        scroll = CreateFrame("ScrollFrame", "WOWClassHelperDebugScroll", f, "ScrollFrameTemplate")
    end
    scroll:SetPoint("TOPLEFT", 22, -44)
    scroll:SetPoint("BOTTOMRIGHT", -40, 22)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetMaxLetters(0)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(600)
    edit:SetAutoFocus(false)
    edit:SetScript("OnEscapePressed", function() f:Hide() end)
    scroll:SetScrollChild(edit)

    f.edit = edit
    table.insert(UISpecialFrames, "WOWClassHelperDebugFrame") -- close with Escape
    Debug.frame = f
    return f
end

-- Command -----------------------------------------------------------------

function Debug.Run(arg)
    arg = strtrim(arg or ""):lower()
    local slot = tonumber(arg) or SLOT_NAMES[arg]
    if not slot then
        -- First equipped of chest, head, main hand, legs
        for _, s in ipairs({ 5, 1, 16, 7 }) do
            if GetInventoryItemLink("player", s) then slot = s break end
        end
        slot = slot or 5
    end

    local lines = {}
    local function out(fmt, ...)
        local ok, text = pcall(string.format, fmt, ...)
        lines[#lines + 1] = ok and text or (fmt .. " [format error]")
    end

    out("WOWClassHelper debug report - %s", date("%Y-%m-%d %H:%M:%S"))
    local sections = {
        { "client", SectionClient }, { "apis", SectionApis }, { "spec", SectionSpec },
        { "proficiency", SectionProficiency }, { "power", SectionPower },
        { "stats", SectionStats }, { "weights", SectionWeights },
        { "item", function(o) SectionItem(o, slot) end }, { "data", SectionData },
    }
    for _, section in ipairs(sections) do
        out("")
        local ok, err = pcall(section[2], out)
        if not ok then out("!! section '%s' failed: %s", section[1], tostring(err)) end
    end

    ns.db.lastDebug = { time = time(), class = ns.classToken, lines = lines }

    local f = GetCopyFrame()
    f.edit:SetText(table.concat(lines, "\n"))
    f:Show()
    f.edit:SetFocus()
    f.edit:HighlightText()
    ns.Print(("debug report: %d lines (also saved in SavedVariables as lastDebug)."):format(#lines))
end

ns:RegisterCommand("debug", "[slot]", "diagnostics report in a copy window (slot: e.g. chest, mainhand, ranged, 5)", Debug.Run)
