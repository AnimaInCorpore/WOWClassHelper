-- WOWClassHelper: mana bar with five-second-rule timer
--
-- WoW Forever has no secondary resource like Holy Power: its power types are
-- mana, rage, focus, energy, combo points and happiness (checked in the
-- Forever dataset). Mana from Spirit only regenerates fully when no mana was
-- spent for five seconds (the "five-second rule"); talents like Meditation,
-- Reverence or Mindfulness let part of it continue while casting.
--
-- Only classes whose profile says mana = true get the bar; it is off by
-- default because the player frame already shows mana.
--
-- The bar shows current mana. Below it, a thin timer runs down for five
-- seconds after every spell that costs mana (orange). When it turns green,
-- full Spirit regeneration is active again.
--
-- Midnight / WoW Forever note: in combat some API results can be "secret
-- values" that addons may display but not compare or calculate with.
-- StatusBars take secret values directly, so this module never does
-- arithmetic or comparisons on the mana values themselves.
local _, ns = ...

local ManaBar = ns:RegisterModule("ManaBar", {})
ns.ManaBar = ManaBar

local POWER_TYPE = (Enum.PowerType and Enum.PowerType.Mana) or 0
local POWER_TOKEN = "MANA"
local WIDTH, HEIGHT, TIMER_HEIGHT = 180, 14, 4
local RULE_SECONDS = 5

local MANA_COLOR  = { 0.20, 0.45, 1.00 }
local RULE_COLOR  = { 1.00, 0.65, 0.15 }   -- timer running: Spirit regeneration paused
local REGEN_COLOR = { 0.30, 0.85, 0.40 }   -- timer done: full regeneration

-- Casts that cost no mana but still fire UNIT_SPELLCAST_SUCCEEDED
local FREE_SPELLS = {
    [5019] = true,   -- Shoot (wand)
    [6603] = true,   -- Auto Attack
    [75]   = true,   -- Auto Shot
    [2764] = true,   -- Throw
    [3018] = true,   -- Shoot (bow, gun, crossbow)
}

local GetSpellPowerCost = (C_Spell and C_Spell.GetSpellPowerCost) or GetSpellPowerCost

-- Did this spell cost mana? Unknown or secret answers count as yes:
-- a timer that starts too often is better than one that never starts.
local function CostsMana(spellID)
    if ns.IsSecret(spellID) then return true end
    if type(spellID) ~= "number" or FREE_SPELLS[spellID] then return false end
    if not GetSpellPowerCost then return true end
    local ok, costs = pcall(GetSpellPowerCost, spellID)
    if not ok or type(costs) ~= "table" then return true end
    for _, cost in ipairs(costs) do
        local powerType, amount = ns.Num(cost.type), ns.Num(cost.cost)
        if powerType == nil or amount == nil then return true end
        if powerType == POWER_TYPE and amount > 0 then return true end
    end
    return false
end

function ManaBar:OnInitialize()
    self.settings = ns.db.manaBar
end

function ManaBar:OnEnable()
    if not (ns.class and ns.class.mana) then return end
    self:CreateFrame()
    self:RegisterEvents()
    self:Refresh()
end

function ManaBar:CreateFrame()
    if self.frame then return end

    local f = CreateFrame("Frame", "WOWClassHelperManaBarFrame", UIParent, "BackdropTemplate")
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    f:SetBackdropColor(0, 0, 0, 0.6)
    f:SetBackdropBorderColor(0, 0, 0, 1)

    local bar = CreateFrame("StatusBar", nil, f)
    bar:SetPoint("TOPLEFT", 2, -2)
    bar:SetSize(WIDTH, HEIGHT)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    bar:SetStatusBarColor(MANA_COLOR[1], MANA_COLOR[2], MANA_COLOR[3])
    f.bar = bar

    local text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("CENTER")
    f.text = text

    local timer = CreateFrame("StatusBar", nil, f)
    timer:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -1)
    timer:SetSize(WIDTH, TIMER_HEIGHT)
    timer:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    timer:SetMinMaxValues(0, RULE_SECONDS)
    f.timer = timer

    -- Dragging (blocked while locked or in combat)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(frame)
        if not self.settings.locked and not InCombatLockdown() then
            frame:StartMoving()
        end
    end)
    f:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        local point, _, relPoint, x, y = frame:GetPoint()
        self.settings.point = { point, "UIParent", relPoint, x, y }
    end)

    self.frame = f
    self:StopRule()
end

-- Five-second rule ----------------------------------------------------------

local function OnUpdate(frame)
    local remaining = (ManaBar.ruleEnd or 0) - GetTime()
    if remaining <= 0 then
        ManaBar:StopRule()
    else
        frame.timer:SetValue(remaining)
    end
end

function ManaBar:StartRule()
    self.ruleEnd = GetTime() + RULE_SECONDS
    local f = self.frame
    if not f then return end
    f.timer:SetStatusBarColor(RULE_COLOR[1], RULE_COLOR[2], RULE_COLOR[3])
    f.timer:SetValue(RULE_SECONDS)
    f:SetScript("OnUpdate", OnUpdate)
end

function ManaBar:StopRule()
    self.ruleEnd = nil
    local f = self.frame
    if not f then return end
    f:SetScript("OnUpdate", nil)
    f.timer:SetStatusBarColor(REGEN_COLOR[1], REGEN_COLOR[2], REGEN_COLOR[3])
    f.timer:SetValue(RULE_SECONDS)
end

-- Mana --------------------------------------------------------------------

function ManaBar:UpdatePower()
    local f = self.frame
    if not f then return end

    local current = UnitPower("player", POWER_TYPE)
    local maxPower = UnitPowerMax("player", POWER_TYPE)

    f.bar:SetMinMaxValues(0, maxPower)
    f.bar:SetValue(current)

    if self.settings.text then
        -- May fail if the client refuses to format secret values
        if not pcall(f.text.SetFormattedText, f.text, "%d / %d", current, maxPower) then
            f.text:SetText("")
        end
    end
end

-- Re-apply settings (position, visibility, lock, text, timer) and redraw.
function ManaBar:Refresh()
    local f = self.frame
    if not f then return end

    local s = self.settings
    f:SetSize(WIDTH + 4, HEIGHT + 4 + (s.timer and (TIMER_HEIGHT + 1) or 0))
    f.timer:SetShown(s.timer)
    f.text:SetShown(s.text)

    local p = s.point
    f:ClearAllPoints()
    f:SetPoint(p[1], _G[p[2]] or UIParent, p[3], p[4], p[5])
    f:EnableMouse(not s.locked)
    f:SetShown(s.shown)

    self:UpdatePower()
end

function ManaBar:RegisterEvents()
    local events = CreateFrame("Frame")
    events:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    events:RegisterUnitEvent("UNIT_MAXPOWER", "player")
    events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")

    events:SetScript("OnEvent", function(_, event, _, arg2, arg3)
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            -- args: unit, castGUID, spellID
            if CostsMana(arg3) then self:StartRule() end
            return
        end
        if (event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER")
            and not ns.IsSecret(arg2) and arg2 ~= POWER_TOKEN then
            return
        end
        self:UpdatePower()
    end)
end

-- Commands ----------------------------------------------------------------

local function Run(fn)
    return function(arg)
        if not ManaBar.frame then
            ns.Print(("%s have no mana bar."):format(ns.class and ns.class.plural or "You"))
            return
        end
        fn(arg)
        ManaBar:Refresh()
    end
end

ns:RegisterCommand("lock", "", "lock the mana bar", Run(function()
    ns.db.manaBar.locked = true
    ns.Print("mana bar locked.")
end))

ns:RegisterCommand("unlock", "", "unlock the mana bar (drag to move)", Run(function()
    ns.db.manaBar.locked = false
    ns.Print("mana bar unlocked - drag to move.")
end))

ns:RegisterCommand("toggle", "", "show/hide the mana bar", Run(function()
    ns.db.manaBar.shown = not ns.db.manaBar.shown
    ns.Print("mana bar", ns.db.manaBar.shown and "shown." or "hidden.")
end))

ns:RegisterCommand("timer", "", "show/hide the five-second-rule timer", Run(function()
    ns.db.manaBar.timer = not ns.db.manaBar.timer
    ns.Print("five-second-rule timer", ns.db.manaBar.timer and "shown." or "hidden.")
end))

ns:RegisterCommand("reset", "", "reset the mana bar position", Run(function()
    ns.db.manaBar.point = { unpack(ns.defaults.manaBar.point) }
    ns.Print("mana bar position reset.")
end))
