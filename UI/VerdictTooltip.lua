-- WOWClassHelper: compact verdict tooltip next to the item tooltip
--
-- When an equippable item is shown in GameTooltip (mouse-over) or
-- ItemRefTooltip (clicked chat link), a second tooltip appears below it:
--
--   [v] Equip now                     +62.6 (+108%)   action, score for your spec
--   vs. [Virtuous Crown]                    Holy 60   what it replaces
--   with [Orb] in the off hand (bags)                 partner against a two-hander
--   [D] Disc [v] +63.9    [S] Shadow [x] -16.7        the other two specs
--   Not counted: Fire Damage +1                       stats worth nothing for your spec
--   Healing +75                     Spell Power -11   biggest stat changes,
--   Crit -14                              Spirit +6   two per line
--   Vestments of Faith 3->4/9                   +15   set bonus changes that matter
--   Best head items seen               this #1 of 3   best known items for the slot:
--   > 1. [Circlet of Faith]         120 bags  +62.6   score, where, improvement
--      2. [Virtuous Crown]                  58 worn   over your gear (">" = hovered)
--
-- It sits below the item tooltip and below the "currently equipped"
-- comparison tooltips beside it, so they don't cover each other.
local _, ns = ...

local VT = ns:RegisterModule("VerdictTooltip", { frames = {} })
ns.VerdictTooltip = VT

-- Style ---------------------------------------------------------------------
-- Every verdict maps to a tone. The tone decides color and icon:
--   TAKE    bright green + check mark     -> act now (equip, buy, take)
--   KEEP    soft green   + check mark     -> hold on to it (later level, set piece, off-spec)
--   NEUTRAL yellow       + question mark  -> about equal, your choice
--   DROP    red          + cross          -> get rid of it (sell, drop, skip)
--   INFO    grey, no icon                -> can't use / already equipped

local TONES = {
    TAKE    = { 0.10, 0.90, 0.10 },
    KEEP    = { 0.55, 0.90, 0.40 },
    NEUTRAL = { 1.00, 0.82, 0.00 },
    DROP    = { 1.00, 0.25, 0.25 },
    INFO    = { 0.60, 0.60, 0.60 },
}

local ICONS = {
    TAKE    = "Interface\\RaidFrame\\ReadyCheck-Ready",
    KEEP    = "Interface\\RaidFrame\\ReadyCheck-Ready",
    NEUTRAL = "Interface\\RaidFrame\\ReadyCheck-Waiting",
    DROP    = "Interface\\RaidFrame\\ReadyCheck-NotReady",
}

local VERDICT_TONE = {
    UPGRADE = "TAKE",
    LATER = "KEEP", KEEP = "KEEP", OFFSPEC = "KEEP",
    SIDEGRADE = "NEUTRAL",
    NO = "DROP",
    UNUSABLE = "INFO", EQUIPPED = "INFO",
}

local SET_COLOR  = { 1.00, 0.90, 0.50 }   -- set bonus lines, distinct from neutral yellow
local LIST_COLOR = { 0.55, 0.75, 1.00 }   -- "Best ... seen" header
local LIFE_COLOR = { 0.65, 0.90, 0.85 }   -- "Lasts to level ..." line
local GREY, LIGHT, WHITE = { 0.6, 0.6, 0.6 }, { 0.8, 0.8, 0.8 }, { 1, 1, 1 }

-- How an item is obtained (Compare.Origins), as a tag in the list and the
-- "Source:" line
local ORIGIN_COLORS = {
    quest   = { 1.00, 0.82, 0.00 },
    dungeon = { 0.40, 0.70, 1.00 },
    raid    = { 0.75, 0.50, 1.00 },
    crafted = { 0.45, 0.90, 0.45 },
    vendor  = { 0.80, 0.80, 0.80 },
    drop    = { 0.85, 0.75, 0.60 },
}
local ORIGIN_NAMES = {
    quest = "Quest", dungeon = "Dungeon", raid = "Raid", crafted = "Crafted", vendor = "Vendor", drop = "Drop",
}

-- Item names longer than this (characters) are cut with "..." so the
-- tooltip doesn't grow wide; pairs ("[A] + [B]") get less room per name
local MAX_NAME, MAX_PAIR_NAME = 30, 20

-- No score, stats or other specs for these: the action line says it all
local NO_SCORE = { UNUSABLE = true, EQUIPPED = true }

-- Percent change is hidden when the replaced item is (nearly) worthless,
-- where it would show silly values like "+3000%"
local MIN_BASE_FOR_PCT, MAX_PCT = 1, 200

local function Unpack(c) return c[1], c[2], c[3] end

local function Colored(c, text)
    return ("|cff%02x%02x%02x"):format(math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5),
        math.floor(c[3] * 255 + 0.5)) .. text .. "|r"
end

local function Icon(path, size)
    return ("|T%s:%d:%d|t"):format(path, size, size)
end

local function Tone(verdict)
    return VERDICT_TONE[verdict] or "INFO"
end

-- Returns the text with its verdict icon in front, plus the verdict color
local function Styled(verdict, text, size)
    local icon = ICONS[Tone(verdict)]
    return (icon and (Icon(icon, size or 14) .. " ") or "") .. text, TONES[Tone(verdict)]
end

-- Signed number with one decimal; values that round to 0 show as "0"
local function Fmt(v)
    local rounded = math.floor(v * 10 + 0.5) / 10
    if rounded == 0 then return "0" end
    return (rounded > 0 and "+" or "") .. rounded
end

-- Cuts a name to `max` characters (UTF-8 aware: German, French, ... names)
local function ShortName(name, max)
    local chars = {}
    for ch in name:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        chars[#chars + 1] = ch
        if #chars > max then break end
    end
    if #chars <= max then return name end
    return (table.concat(chars, "", 1, max - 1):gsub("%s+$", "")) .. "..."
end

-- An item as "[Name]" in its quality color, the name cut to `max` characters
local function ItemText(item, max)
    local name = item.name
    if not name then return item.link or "?" end
    local short = ShortName(name, max or MAX_NAME)
    if short == name and item.link then return item.link end
    local q = ITEM_QUALITY_COLORS and item.quality and ITEM_QUALITY_COLORS[item.quality]
    local color = (q and q.hex) or (item.link and item.link:match("^|c%x%x%x%x%x%x%x%x")) or ""
    return color .. "[" .. short .. "]" .. (color ~= "" and "|r" or "")
end

local function ScoreText(role)
    local text = Fmt(role.score)
    if role.pct and role.base >= MIN_BASE_FOR_PCT and role.pct <= MAX_PCT then
        local pct = math.floor(role.pct + 0.5)
        text = text .. (" (%s%d%%)"):format(pct > 0 and "+" or "", pct)
    end
    return text
end

-- Context ---------------------------------------------------------------

local function IsInside(frame, parent)
    while frame do
        if frame == parent then return true end
        frame = frame.GetParent and frame:GetParent()
    end
    return false
end

local function DetectContext(tooltip)
    local owner = tooltip.GetOwner and tooltip:GetOwner()
    if not owner then return nil end
    if MerchantFrame and MerchantFrame:IsShown() and IsInside(owner, MerchantFrame) then
        return "MERCHANT"
    end
    if (LootFrame and LootFrame:IsShown() and IsInside(owner, LootFrame))
        or (GroupLootContainer and IsInside(owner, GroupLootContainer)) then
        return "LOOT"
    end
    local name = owner.GetName and owner:GetName()
    if name and name:find("^GroupLootFrame") then return "LOOT" end
    return nil
end

-- How an item is obtained, from the window it is shown in: quest rewards
-- (quest dialog, quest log) and profession recipes
local QUEST_FRAMES = { "QuestFrame", "QuestLogFrame", "QuestLogDetailFrame", "QuestMapFrame", "QuestInfoFrame" }

local function SafeCall(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, a = pcall(func, ...)
    if ok then return a end
    return nil
end

local function QuestTitle()
    if QuestFrame and QuestFrame:IsShown() then
        local title = SafeCall(GetTitleText)
        if type(title) == "string" and title ~= "" then return title end
    end
    local index = SafeCall(GetQuestLogSelection)
    if type(index) == "number" and index > 0 then
        local title = SafeCall(GetQuestLogTitle, index)
        if type(title) == "string" and title ~= "" then return title end
    end
    if C_QuestLog and C_QuestLog.GetSelectedQuest and C_QuestLog.GetTitleForQuestID then
        local id = SafeCall(C_QuestLog.GetSelectedQuest)
        local title = id and SafeCall(C_QuestLog.GetTitleForQuestID, id)
        if type(title) == "string" and title ~= "" then return title end
    end
    return nil
end

-- Extra knowledge base fields for the item in this tooltip, or nil
local function DetectOrigin(tooltip)
    local owner = tooltip.GetOwner and tooltip:GetOwner()
    if not owner then return nil end
    for _, name in ipairs(QUEST_FRAMES) do
        local frame = _G[name]
        if frame and IsInside(owner, frame) then return { quest = QuestTitle() or true } end
    end
    if TradeSkillFrame and IsInside(owner, TradeSkillFrame) then
        local profession = SafeCall(GetTradeSkillLine)
        return { profession = (type(profession) == "string" and profession ~= "") and profession or true }
    end
    return nil
end

-- Frame -------------------------------------------------------------------

function VT:GetFrame(owner)
    local tip = self.frames[owner]
    if tip then return tip end
    local index = 0
    for _ in pairs(self.frames) do index = index + 1 end
    tip = CreateFrame("GameTooltip", "WOWClassHelperVerdictTooltip" .. (index + 1), UIParent, "GameTooltipTemplate")
    tip:SetClampedToScreen(true)
    owner:HookScript("OnHide", function() tip:Hide() end)
    if owner:HasScript("OnTooltipCleared") then
        owner:HookScript("OnTooltipCleared", function() tip:Hide() end)
    end
    self.frames[owner] = tip
    return tip
end

function VT:Hide(owner)
    local tip = self.frames[owner]
    if tip then tip:Hide() end
end

-- Placement -------------------------------------------------------------
-- Below the item tooltip; if a "currently equipped" comparison tooltip beside
-- it reaches lower and overlaps the verdict tooltip horizontally, below that
-- one instead. Without room at the bottom of the screen: above the item
-- tooltip. Comparison tooltips often appear a moment after the item tooltip,
-- so a small driver frame re-checks the placement while a verdict is shown.

local REANCHOR_INTERVAL = 0.1

local function ShoppingTooltips(owner)
    if type(owner.shoppingTooltips) == "table" then return owner.shoppingTooltips end
    if owner == ItemRefTooltip then return { ItemRefShoppingTooltip1, ItemRefShoppingTooltip2 } end
    return { ShoppingTooltip1, ShoppingTooltip2 }
end

-- Frame edges in screen pixels, or nil if the frame has no position yet
local function Edges(frame)
    local left, right, bottom = frame:GetLeft(), frame:GetRight(), frame:GetBottom()
    if not (left and right and bottom) then return nil end
    local s = frame:GetEffectiveScale()
    return left * s, right * s, bottom * s
end

function VT:Anchor(owner, tip)
    local oLeft, _, oBottom = Edges(owner)
    if not oLeft then return end
    local scale = tip:GetEffectiveScale()
    local tLeft, tRight = oLeft, oLeft + tip:GetWidth() * scale

    local lowest = oBottom
    for _, shop in ipairs(ShoppingTooltips(owner)) do
        if shop.IsShown and shop:IsShown() then
            local sLeft, sRight, sBottom = Edges(shop)
            if sLeft and sRight > tLeft and sLeft < tRight and sBottom < lowest then
                lowest = sBottom
            end
        end
    end

    local key, point, relPoint, y
    if lowest - (tip:GetHeight() + 4) * scale >= 0 then
        local drop = math.floor((oBottom - lowest) / scale + 0.5)
        key, point, relPoint, y = "below" .. drop, "TOPLEFT", "BOTTOMLEFT", -drop - 4
    else
        key, point, relPoint, y = "above", "BOTTOMLEFT", "TOPLEFT", 4
    end
    if tip.wchAnchor == key then return end
    tip.wchAnchor = key
    tip:ClearAllPoints()
    tip:SetPoint(point, owner, relPoint, 0, y)
end

function VT:CreateDriver()
    local driver = CreateFrame("Frame", nil, UIParent)
    driver:Hide()
    local elapsed = 0
    driver:SetScript("OnUpdate", function(frame, dt)
        elapsed = elapsed + (dt or 0)
        if elapsed < REANCHOR_INTERVAL then return end
        elapsed = 0
        local any = false
        for owner, tip in pairs(VT.frames) do
            if tip:IsShown() then
                any = true
                VT:Anchor(owner, tip)
            end
        end
        if not any then frame:Hide() end
    end)
    self.driver = driver
end

-- Sections ----------------------------------------------------------------

-- Action and score for the current spec, reason, what it replaces
local function AddHeader(tip, r)
    local current = r.current
    local actionText, actionColor = Styled(r.verdict, r.action)
    local right, rightColor = "", GREY
    if not NO_SCORE[r.verdict] then
        right, rightColor = ScoreText(current), TONES[Tone(current.verdict)]
    end
    local ar, ag, ab = Unpack(actionColor)
    local rr, rg, rb = Unpack(rightColor)
    tip:AddDoubleLine(actionText, right, ar, ag, ab, rr, rg, rb)
    if r.reason then tip:AddLine(r.reason, 0.85, 0.85, 0.85, true) end

    local names = {}
    local max = #current.replaced > 1 and MAX_PAIR_NAME or MAX_NAME
    for _, item in ipairs(current.replaced) do table.insert(names, ItemText(item, max)) end
    local gr, gg, gb = Unpack(GREY)
    tip:AddDoubleLine("vs. " .. (#names > 0 and table.concat(names, " + ") or "empty slot"),
        ("%s %d"):format(ns.Spec.DisplayName(r.spec), r.level), gr, gg, gb, gr, gg, gb)
    -- A one-hander or off hand against a two-hander: the partner it is
    -- counted with
    local p = not NO_SCORE[r.verdict] and current.partner
    if p then
        tip:AddLine(("with %s in the %s (%s)"):format(ItemText(p.item),
            p.off and "off hand" or "main hand", p.where or "?"), gr, gg, gb)
    end
end

-- The two other specs in one line
local function AddOtherSpecs(tip, r)
    if not ns.db.tooltip.offspec or NO_SCORE[r.verdict] then return end
    local parts = {}
    for _, key in ipairs(ns.Spec.KEYS) do
        if key ~= r.spec then
            local info = ns.Spec.INFO[key]
            local text, color = Styled(r.roles[key].verdict, Fmt(r.roles[key].score), 12)
            parts[#parts + 1] = ("%s %s %s"):format(Icon(info.icon, 12), info.short, Colored(color, text))
        end
    end
    tip:AddLine(table.concat(parts, "    "), Unpack(LIGHT))
end

-- "Agility +6 (+5%)": main stats also show the change against what your
-- gear has of the stat
local function StatText(c)
    local color = c.value > 0 and TONES.TAKE or c.value < 0 and TONES.DROP or GREY
    local text = Fmt(c.delta) .. (c.capped and " (cap)" or "")
    if c.main and c.pct then
        local pct = math.floor(c.pct + 0.5)
        if pct ~= 0 and math.abs(pct) <= 999 then text = text .. (" (%s%d%%)"):format(pct > 0 and "+" or "", pct) end
    end
    local label = ns.ItemData.StatLabel(c.stat)
    if c.main then label = Colored(WHITE, label) end
    return label .. " " .. Colored(color, text)
end

-- Biggest stat changes for the current spec, two per line
local function AddStats(tip, r)
    local settings, current = ns.db.tooltip, r.current
    if not settings.statDiff or NO_SCORE[r.verdict] then return end
    local n = math.min(settings.maxStatLines, #current.contributions)
    local lr, lg, lb = Unpack(LIGHT)
    for i = 1, n, 2 do
        local right = (i + 1 <= n) and StatText(current.contributions[i + 1]) or ""
        tip:AddDoubleLine(StatText(current.contributions[i]), right, lr, lg, lb, lr, lg, lb)
    end
    -- Stats on the item that don't count for this spec, so a "+1 Fire damage"
    -- doesn't look like the reason for the verdict
    local ignored = {}
    for i, c in ipairs(current.ignored or {}) do
        if i > 3 then break end
        ignored[#ignored + 1] = ns.ItemData.StatLabel(c.stat) .. " " .. Fmt(c.value)
    end
    if #ignored > 0 then
        local gr, gg, gb = Unpack(GREY)
        tip:AddLine("Not counted: " .. table.concat(ignored, ", "), gr, gg, gb, true)
    end
end

local function SetMatters(change)
    return math.abs(change.value) >= 0.05 or #change.gained > 0 or #change.lost > 0
end

-- Set bonuses that switch on or off; otherwise the item's set progress
local function AddSets(tip, r)
    if r.verdict == "UNUSABLE" then return end
    local current, info = r.current, r.info
    local sr, sg, sb = Unpack(SET_COLOR)
    local ownShown = false
    for _, change in ipairs(current.sets) do
        local set = ns.SetBonus.GetSet(change.setID)
        if set and SetMatters(change) then
            if change.setID == info.setID then ownShown = true end
            local vr, vg, vb = Unpack(change.value >= 0 and TONES.TAKE or TONES.DROP)
            tip:AddDoubleLine(("%s %d->%d/%d"):format(set.name, change.before, change.after, #set.items),
                Fmt(change.value), sr, sg, sb, vr, vg, vb)
            for _, effect in ipairs(change.gained) do
                local er, eg, eb = Unpack(TONES.TAKE)
                tip:AddLine(("  + (%d) %s"):format(effect.count, effect.text), er, eg, eb, true)
            end
            for _, effect in ipairs(change.lost) do
                local er, eg, eb = Unpack(TONES.DROP)
                tip:AddLine(("  - (%d) %s"):format(effect.count, effect.text), er, eg, eb, true)
            end
        end
    end
    local set = not ownShown and ns.SetBonus.GetSet(info.setID)
    if set then
        local count = ns.Character:SetCount(info.setID)
        for _, change in ipairs(current.sets) do
            if change.setID == info.setID then count = change.after end
        end
        local nextCount = ns.SetBonus.NextThreshold(info.setID, count)
        tip:AddLine(("%s %d/%d with this%s"):format(set.name, count, #set.items,
            nextCount and (", bonus at " .. nextCount) or ""), sr, sg, sb)
    end
end

-- While leveling: how long the item stays current against what it replaces,
-- and what that adds to the score
local function AddLongevity(tip, r)
    local life = r.current.longevity
    if NO_SCORE[r.verdict] or not life or math.abs(life.value) < 0.05 then return end
    local text = ("Lasts to level %d"):format(life.lasts)
    if life.yours then text = text .. (", yours to %d"):format(life.yours) end
    local lr, lg, lb = Unpack(LIFE_COLOR)
    local vr, vg, vb = Unpack(life.value >= 0 and TONES.TAKE or TONES.DROP)
    tip:AddDoubleLine(text, Fmt(life.value), lr, lg, lb, vr, vg, vb)
end

-- How the item is obtained, as far as the knowledge base has seen it:
-- "Source: Quest (The Defias Brotherhood), Vendor (Bob)"
-- withDetail: "Quest (The Defias Brotherhood)" for the Source line; without:
-- the tag ("quest") for the list
local function OriginText(origin, withDetail)
    local text = origin.tag
    if withDetail then
        text = ORIGIN_NAMES[origin.tag] or origin.tag
        if origin.detail then text = text .. " (" .. ShortName(origin.detail, MAX_NAME) .. ")" end
    end
    return Colored(ORIGIN_COLORS[origin.tag] or LIGHT, text)
end

local function AddSource(tip, r)
    local origins = ns.Compare.Origins(r.info)
    if #origins == 0 then return end
    local parts = {}
    for i = 1, math.min(2, #origins) do parts[i] = OriginText(origins[i], true) end
    tip:AddLine("Source: " .. table.concat(parts, ", "), 0.5, 0.5, 0.5, true)
end

-- Note, level band (while leveling) and manual spec in one grey line
local function AddNotes(tip, r)
    local parts = {}
    if r.current.note then parts[#parts + 1] = r.current.note end
    if r.leveling then parts[#parts + 1] = ns.Weights.BandText(r.spec) end
    if r.specSource == "manual" then parts[#parts + 1] = "spec set manually" end
    if r.specSource == "default" then parts[#parts + 1] = "no spec found - set it with " .. ns.SLASH .. " spec" end
    if #parts > 0 then tip:AddLine(table.concat(parts, " - "), 0.5, 0.5, 0.5, true) end
end

-- Best known items for the slot, and the hovered item's rank among them
local function AddBestSeen(tip, r)
    local settings = ns.db.tooltip
    if not settings.topList then return end
    local rank = ns.Compare.Rank(r.info, r.spec)
    if not rank or rank.total == 0 then return end

    local rankText = ""
    if rank.eligible then
        rankText = ("this #%d of %d"):format(rank.rank, rank.total)
    elseif (r.needLevel or 0) > r.level and r.verdict ~= "UNUSABLE" then
        rankText = ("this #%d at level %d"):format(rank.rank, r.needLevel)
    elseif r.verdict ~= "UNUSABLE" then
        rankText = ("this #%d of %d"):format(rank.rank, rank.total + 1)
    end
    local rc = (rank.rank == 1 and rankText ~= "") and TONES.TAKE or LIGHT
    local hr, hg, hb = Unpack(LIST_COLOR)
    tip:AddDoubleLine(("Best %s seen"):format(rank.label), rankText, hr, hg, hb, Unpack(rc))

    local gr, gg, gb = Unpack(GREY)
    for i = 1, math.min(settings.topCount, rank.total) do
        local e = rank.list[i]
        local isThis = (e.key == r.info.key)
        local max = e.partner and MAX_PAIR_NAME or MAX_NAME
        local left = ("%s%d. %s"):format(isThis and "> " or "   ", i, ItemText(e.entry, max))
        if e.partner then left = left .. " + " .. ItemText(e.partner.item, max) end
        -- Where you have it (worn, bags, bank) and how it is obtained
        local where = ns.Compare.WhereShort(e.entry, e.key)
        local origin = ns.Compare.Origins(e.entry)[1]
        if origin then
            if where == origin.tag then
                where = OriginText(origin)
            elseif ns.Compare.Location(e.entry, e.key) then
                where = where .. " " .. OriginText(origin)
            end
        end
        local right = ("%d %s"):format(math.floor(e.score + 0.5), where)
        local delta, verdict = ns.Compare.Improvement(e, r.spec)
        if delta then
            right = right .. "  " .. Colored(TONES[Tone(verdict)], Fmt(delta))
        end
        local lr, lg, lb = Unpack(isThis and WHITE or GREY)
        tip:AddDoubleLine(left, right, lr, lg, lb, gr, gg, gb)
    end
end

function VT:Render(owner, r)
    local tip = self:GetFrame(owner)
    tip:SetOwner(owner, "ANCHOR_NONE")
    AddHeader(tip, r)
    AddOtherSpecs(tip, r)
    AddStats(tip, r)
    AddSets(tip, r)
    AddLongevity(tip, r)
    AddSource(tip, r)
    AddNotes(tip, r)
    AddBestSeen(tip, r)
    tip:Show()
    tip.wchAnchor = nil
    self:Anchor(owner, tip)
    if self.driver then self.driver:Show() end
end

-- Hook --------------------------------------------------------------------

local function GetTooltipLink(tooltip)
    if TooltipUtil and TooltipUtil.GetDisplayedItem then
        local _, link = TooltipUtil.GetDisplayedItem(tooltip)
        if link then return link end
    end
    if tooltip.GetItem then
        local _, link = tooltip:GetItem()
        return link
    end
end

function VT:Update(tooltip)
    if not ns.db.tooltip.enabled then return self:Hide(tooltip) end
    local link = GetTooltipLink(tooltip)
    if not link then return self:Hide(tooltip) end

    ns.KB:Record(link, "tooltip", DetectOrigin(tooltip))
    local info = ns.ItemData.Parse(link)
    local result = info and ns.Compare.Evaluate(info, DetectContext(tooltip))
    if not result then return self:Hide(tooltip) end
    self:Render(tooltip, result)
end

local function OnItemTooltip(tooltip)
    if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
    local ok, err = pcall(VT.Update, VT, tooltip)
    if not ok then
        VT:Hide(tooltip)
        if not VT.errorShown then
            VT.errorShown = true
            ns.Print("tooltip error: " .. tostring(err))
        end
    end
end

function VT:OnEnable()
    self:CreateDriver()
    if TooltipDataProcessor and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItemTooltip)
    else
        GameTooltip:HookScript("OnTooltipSetItem", OnItemTooltip)
        ItemRefTooltip:HookScript("OnTooltipSetItem", OnItemTooltip)
    end
end

ns:RegisterCommand("tooltip", "", "turn the verdict tooltip on/off", function()
    ns.db.tooltip.enabled = not ns.db.tooltip.enabled
    if not ns.db.tooltip.enabled then
        for owner in pairs(VT.frames) do VT:Hide(owner) end
    end
    ns.Print("verdict tooltip", ns.db.tooltip.enabled and "on." or "off.")
end)
