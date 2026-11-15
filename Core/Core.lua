-- WOWClassHelper: core bootstrap
-- Every file listed in the .toc receives the same two varargs:
-- the addon folder name and a private namespace table shared by all files.
--
-- The addon is the same for every class. Classes/<Class>.lua registers a
-- class profile (specs, stat weights, talents, usable armor and weapons)
-- with ns:RegisterClass; on load the profile of the player's class is
-- selected and handed to the generic modules in Core/ and UI/.
local addonName, ns = ...

ns.name = addonName
ns.modules = {}
ns.commands = {}
ns.Classes = {}          -- class token ("PRIEST") -> profile, see ns:RegisterClass
ns.SLASH = "/wch"

-- Defaults for the saved variables. Missing keys are filled in on load,
-- so you can add new settings here later without breaking old saves.
-- Account-wide (WOWClassHelperDB):
local defaults = {
    enabled = true,
    manaBar = {
        shown = false,       -- off by default: the player frame already shows mana
        locked = false,
        text = true,         -- show "current / max" on the bar
        timer = true,        -- show the five-second-rule timer below the bar
        point = { "CENTER", "UIParent", "CENTER", 0, -180 },
    },
    tooltip = {
        enabled = true,
        offspec = true,      -- show the score change for the other two specs
        statDiff = true,     -- show the biggest stat changes
        maxStatLines = 4,    -- number of stat changes (two per line)
        topList = true,      -- show the best known items for the slot and the item's rank
        topCount = 3,        -- entries in that list
    },
    legacy = {
        adventure = 0,       -- rank of the Legacy perk Thrill of Adventure (0-5), set with the legacy command
    },
    kb = {
        version = 1,
        items = {},          -- knowledge base, see Core/KnowledgeBase.lua
    },
    imported = {},           -- old addon name -> time its knowledge base was imported
}
ns.defaults = defaults

-- Per character (WOWClassHelperCharDB):
local charDefaults = {
    -- false = detect automatically, otherwise a spec key of the class, e.g. "HOLY"
    specOverride = false,
    owned = { bags = {}, bank = {} },   -- item key -> count, see Core/KnowledgeBase.lua
}
ns.charDefaults = charDefaults

local function ApplyDefaults(target, source)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            ApplyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

-- Midnight-era clients can return "secret" values in combat that addons may
-- display but not compare or calculate with.
function ns.IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value)
end

-- Returns value if it is a plain number, otherwise nil
function ns.Num(value)
    if type(value) == "number" and not ns.IsSecret(value) then
        return value
    end
    return nil
end

function ns.Print(...)
    print("|cff33ccffWOWClassHelper|r:", ...)
end

-- Modules register themselves with ns:RegisterModule(name, table).
-- A module may implement :OnInitialize() (saved vars ready, class selected)
-- and :OnEnable() (player is in the world and the class has a profile).
function ns:RegisterModule(name, module)
    module.name = name
    table.insert(self.modules, module)
    return module
end

-- Slash sub-commands: ns:RegisterCommand("name", "args", "help text", function(rest) end)
-- args may be a function returning the text (for class-dependent spec names).
function ns:RegisterCommand(name, args, help, func)
    self.commands[name] = { args = args, help = help, func = func }
end

-- Class profiles ----------------------------------------------------------
-- See Classes/Priest.lua for a fully commented profile.

function ns:RegisterClass(token, profile)
    profile.token = token
    self.Classes[token] = profile
    return profile
end

-- Hands the profile of a class to the generic modules. Called on load for
-- the player's class; the smoke test also calls it to switch classes.
function ns:SelectClass(token)
    local profile = self.Classes[token]
    self.classToken = token
    self.class = profile
    if not profile then return nil end
    self.Spec.Select(profile)
    self.Weights.Select(profile)
    self.ItemData.Select(profile)
    self.Compare.Select(profile)
    return profile
end

local function CallModules(method)
    for _, module in ipairs(ns.modules) do
        if module[method] then
            local ok, err = pcall(module[method], module)
            if not ok then
                ns.Print(("error in %s:%s - %s"):format(module.name, method, tostring(err)))
            end
        end
    end
end

-- Old addons ----------------------------------------------------------------
-- WOWPriest and WOWPaladin, which this addon replaces, kept their own
-- knowledge base. If one of them is still enabled, its saved variables are
-- loaded too, and the items it knows are copied over once.

local OLD_ADDONS = { { "WOWPriest", "WOWPriestDB" }, { "WOWPaladin", "WOWPaladinDB" } }

function ns.ImportOldAddons()
    for _, old in ipairs(OLD_ADDONS) do
        local name, var = old[1], old[2]
        local db = _G[var]
        if not ns.db.imported[name] and type(db) == "table" and type(db.kb) == "table"
            and type(db.kb.items) == "table" then
            local added = ns.KB:Import(db.kb.items)
            local rank = type(db.legacy) == "table" and tonumber(db.legacy.adventure)
            if rank and rank > 0 and (tonumber(ns.db.legacy.adventure) or 0) == 0 then
                ns.db.legacy.adventure = rank
            end
            ns.db.imported[name] = time()
            ns.Print(("imported %d items from the %s knowledge base. %s is no longer needed - disable it."):format(
                added, name, name))
        end
    end
end

-- Event handling --------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        WOWClassHelperDB = WOWClassHelperDB or {}
        WOWClassHelperCharDB = WOWClassHelperCharDB or {}
        ApplyDefaults(WOWClassHelperDB, defaults)
        ApplyDefaults(WOWClassHelperCharDB, charDefaults)
        ns.db = WOWClassHelperDB
        ns.char = WOWClassHelperCharDB
        local _, classFile = UnitClass("player")
        ns:SelectClass(classFile)
        CallModules("OnInitialize")
        self:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_LOGIN" then
        if not ns.class then
            ns.Print(("no profile for the class %s yet - the addon stays off."):format(tostring(ns.classToken)))
            return
        end
        local ok, err = pcall(ns.ImportOldAddons)
        if not ok then ns.Print("import of old addon data failed: " .. tostring(err)) end
        if ns.db.enabled then
            CallModules("OnEnable")
        end
        ns.Print(("loaded for %s. Type %s for options."):format(ns.class.name, ns.SLASH))
    end
end)

-- Slash commands --------------------------------------------------------

SLASH_WOWCLASSHELPER1 = "/wch"
SLASH_WOWCLASSHELPER2 = "/wowclasshelper"

SlashCmdList.WOWCLASSHELPER = function(msg)
    local cmd, rest = strtrim(msg or ""):match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()

    local entry = ns.commands[cmd]
    if entry and ns.class then
        entry.func(rest or "")
        return
    end
    if not ns.class then
        ns.Print(("no profile for the class %s yet."):format(tostring(ns.classToken)))
        return
    end

    ns.Print("commands:")
    local names = {}
    for name in pairs(ns.commands) do table.insert(names, name) end
    table.sort(names)
    for _, name in ipairs(names) do
        local c = ns.commands[name]
        local args = type(c.args) == "function" and c.args() or c.args
        local usage = args ~= "" and (name .. " " .. args) or name
        print(("  |cffffd100%s %s|r - %s"):format(ns.SLASH, usage, c.help))
    end
end
