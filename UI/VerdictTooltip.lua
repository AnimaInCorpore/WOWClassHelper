-- WOWClassHelper: compact verdict tooltip next to the item tooltip
--
-- When an equippable item is shown in GameTooltip (mouse-over) or
-- ItemRefTooltip (clicked chat link), a second tooltip appears below it:
--
--   [v] Equip now                     +62.6 (+108%)   action, score for your spec
--   vs. [Virtuous Crown]                    Holy 60   what it replaces
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
local GREY, LIGHT, WHITE = { 0.6, 0.6, 0.6 }, { 0.8, 0.8, 0.8 }, { 1, 1, 1 }

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
    for _, item in ipairs(current.replaced) do table.insert(names, item.link or item.name) end
    local gr, gg, gb = Unpack(GREY)
    tip:AddDoubleLine("vs. " .. (#names > 0 and table.concat(names, " + ") or "empty slot"),
        ("%s %d"):format(ns.Spec.DisplayName(r.spec), r.level), gr, gg, gb, gr, gg, gb)
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

local function StatText(c)
    local color = c.value > 0 and TONES.TAKE or c.value < 0 and TONES.DROP or GREY
    return ns.ItemData.StatLabel(c.stat) .. " " .. Colored(color, Fmt(c.delta) .. (c.capped and " (cap)" or ""))
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
        local left = ("%s%d. %s"):format(isThis and "> " or "   ", i, e.entry.link or e.entry.name or "?")
        local right = ("%d %s"):format(math.floor(e.score + 0.5), ns.Compare.WhereShort(e.entry, e.key))
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

    ns.KB:Record(link, "tooltip")
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
