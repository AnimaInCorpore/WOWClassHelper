-- WOWClassHelper: entry in the AddOn compartment (the button below the minimap)
--
-- The TOC fields AddonCompartmentFunc / ...OnEnter / ...OnLeave point to the
-- three global functions below; the icon comes from ## IconTexture.
--   Mouse-over: class and current spec, level band, knowledge base size
--   Click:      menu with spec override, display toggles and reports
local _, ns = ...

local Compartment = {}
ns.Compartment = Compartment

local function RunCommand(name, arg)
    local cmd = ns.commands[name]
    if cmd then cmd.func(arg or "") end
end

local function KnowledgeBaseSize()
    local count = 0
    for _ in pairs(ns.KB.items or {}) do count = count + 1 end
    return count
end

-- Menu --------------------------------------------------------------------

local function BuildMenu(_, root)
    local db, char = ns.db, ns.char
    root:CreateTitle("WOWClassHelper - " .. ns.class.name)

    -- Spec used for suggestions
    root:CreateTitle("Spec for suggestions")
    local detected = ns.Spec.Detect()
    local autoText = "Automatic" .. (detected and (" - " .. ns.Spec.Label(detected)) or "")
    root:CreateRadio(autoText,
        function() return not char.specOverride end,
        function() char.specOverride = false end)
    for _, key in ipairs(ns.Spec.KEYS) do
        root:CreateRadio(ns.Spec.Label(key),
            function() return char.specOverride == key end,
            function() char.specOverride = key end)
    end

    root:CreateDivider()
    root:CreateCheckbox("Verdict tooltip",
        function() return db.tooltip.enabled end,
        function() RunCommand("tooltip") end)
    root:CreateCheckbox("Show other specs",
        function() return db.tooltip.offspec end,
        function() db.tooltip.offspec = not db.tooltip.offspec end)
    root:CreateCheckbox("Show stat changes",
        function() return db.tooltip.statDiff end,
        function() db.tooltip.statDiff = not db.tooltip.statDiff end)
    root:CreateCheckbox("Show best items seen",
        function() return db.tooltip.topList end,
        function() db.tooltip.topList = not db.tooltip.topList end)
    if ns.ManaBar and ns.ManaBar.frame then
        root:CreateCheckbox("Mana bar",
            function() return db.manaBar.shown end,
            function() RunCommand("toggle") end)
        root:CreateCheckbox("Five-second-rule timer",
            function() return db.manaBar.timer end,
            function() RunCommand("timer") end)
        root:CreateCheckbox("Lock mana bar",
            function() return db.manaBar.locked end,
            function() RunCommand(db.manaBar.locked and "unlock" or "lock") end)
    end

    root:CreateDivider()
    root:CreateButton("Show my stats", function() RunCommand("stats") end)
    root:CreateButton("Knowledge base summary", function() RunCommand("kb") end)
    root:CreateButton("Debug report", function() RunCommand("debug") end)
end

function Compartment.OpenMenu(owner)
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(owner, BuildMenu)
    else
        -- No modern menu API: fall back to the command list in chat
        SlashCmdList.WOWCLASSHELPER("")
    end
end

-- Mouse-over tooltip ------------------------------------------------------

function Compartment.ShowTooltip(owner)
    local spec, source = ns.Spec.Get()
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:AddLine("WOWClassHelper", 0.20, 0.80, 1.00)
    GameTooltip:AddDoubleLine("Class", ns.class.name, 0.8, 0.8, 0.8, 1, 1, 1)
    GameTooltip:AddDoubleLine("Spec", ns.Spec.Label(spec) .. (source == "manual" and " (manual)" or ""),
        0.8, 0.8, 0.8, 1, 1, 1)
    GameTooltip:AddDoubleLine("Level", ("%d - %s"):format(ns.Spec.GetLevel(), ns.Weights.BandText(spec)),
        0.8, 0.8, 0.8, 1, 1, 1)
    GameTooltip:AddDoubleLine("Knowledge base", KnowledgeBaseSize() .. " items", 0.8, 0.8, 0.8, 1, 1, 1)
    GameTooltip:AddDoubleLine("Verdict tooltip", ns.db.tooltip.enabled and "on" or "off",
        0.8, 0.8, 0.8, 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Click for options", 0.5, 0.8, 1)
    GameTooltip:Show()
end

-- Globals referenced by the TOC ---------------------------------------------
-- Called as func(addonName, mouseButton, menuButtonFrame) and
-- onEnter/onLeave(addonName, menuButtonFrame).

function WOWClassHelper_OnAddonCompartmentClick(_, _, button)
    if not ns.db or not ns.class then return end
    GameTooltip:Hide()
    Compartment.OpenMenu(button or UIParent)
end

function WOWClassHelper_OnAddonCompartmentEnter(_, button)
    if not ns.db or not ns.class then return end
    local ok = pcall(Compartment.ShowTooltip, button or UIParent)
    if not ok then GameTooltip:Hide() end
end

function WOWClassHelper_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end
