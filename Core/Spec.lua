-- WOWClassHelper: specialization and level detection
--
-- Forever classes have one talent tree with three spec sections side by
-- side, like the classic talent window. The section with the most points is
-- the spec. The talent nodes come from Data/Talents.lua (generated), the spec
-- names, roles and IDs from the class profile (Classes/*.lua).
local _, ns = ...

local Spec = {}
ns.Spec = Spec

-- Filled by Spec.Select from the class profile
Spec.KEYS = {}      -- spec keys in talent-window order, e.g. { "DISCIPLINE", "HOLY", "SHADOW" }
Spec.INFO = {}      -- key -> { name, short, role, icon, display, attack, id }
Spec.TALENTS = {}   -- key -> { { node ID, spell ID }, ... }
Spec.ALIASES = {}   -- lower-case word -> key, for the spec and best commands

local SPEC_IDS = {}   -- specialization ID (Forever and Retail) -> key
local TAB_ORDER = {}  -- spec keys in classic talent tab order
local DEFAULT

local talents   -- cached talent ranks, see Spec.Talents

function Spec.Select(class)
    Spec.KEYS, Spec.INFO, Spec.TALENTS, Spec.ALIASES = {}, {}, {}, {}
    SPEC_IDS = {}
    local data = ns.TalentData and ns.TalentData[class.token]
    for i, s in ipairs(class.specs) do
        local key = s.key
        Spec.KEYS[i] = key
        Spec.INFO[key] = s
        SPEC_IDS[s.id] = key
        for _, id in ipairs(s.retailIDs or {}) do SPEC_IDS[id] = key end
        local nodes = {}
        local section = data and data.specs[s.id]
        for _, n in ipairs(section and section.nodes or {}) do
            nodes[#nodes + 1] = { n[1], n[2], n[3] }
        end
        Spec.TALENTS[key] = nodes
        Spec.ALIASES[s.name:lower()] = key
        Spec.ALIASES[s.short:lower()] = key
        Spec.ALIASES[key:lower()] = key
    end
    for word, key in pairs(class.aliases or {}) do Spec.ALIASES[word] = key end
    TAB_ORDER = class.tabOrder or Spec.KEYS
    DEFAULT = class.defaultSpec or Spec.KEYS[#Spec.KEYS]
    talents = nil
end

local function SpecApi(name)
    return _G[name] or (C_SpecializationInfo and C_SpecializationInfo[name])
end

-- Ranks of one talent node: from the talent config if the client has one,
-- otherwise 1 if the talent's spell is known. Returns nil for secret values.
local function NodeRank(configID, nodeID, spellID)
    local rank = 0
    if configID and C_Traits and C_Traits.GetNodeInfo then
        local ok, info = pcall(C_Traits.GetNodeInfo, configID, nodeID)
        if ok and type(info) == "table" then
            if ns.IsSecret(info.ranksPurchased) or ns.IsSecret(info.activeRank) then return nil end
            rank = math.max(ns.Num(info.ranksPurchased) or 0, ns.Num(info.activeRank) or 0)
        end
    end
    if rank == 0 and IsPlayerSpell then
        local ok, known = pcall(IsPlayerSpell, spellID)
        if ok and known == true then rank = 1 end
    end
    return rank
end

-- Reads the whole tree. Returns points per spec section and ranks per talent
-- spell, or nil if the client hides the values (combat).
local function ReadTalents()
    local configID
    if C_ClassTalents and C_ClassTalents.GetActiveConfigID then
        local ok, id = pcall(C_ClassTalents.GetActiveConfigID)
        configID = ok and ns.Num(id) or nil
    end
    local points, ranks = {}, {}
    for key, nodes in pairs(Spec.TALENTS) do
        local bySpell = {}   -- a spell listed on two nodes counts once
        for _, node in ipairs(nodes) do
            local rank = NodeRank(configID, node[1], node[2])
            if not rank then return nil end
            bySpell[node[2]] = math.max(bySpell[node[2]] or 0, rank)
        end
        local total = 0
        for spellID, rank in pairs(bySpell) do
            total = total + rank
            if rank > 0 then ranks[spellID] = rank end
        end
        points[key] = total
    end
    return points, ranks
end

-- Talent data is read once and kept until the talents, spells or level
-- change (or for 10 seconds), because weights and spec detection ask often.
local MAX_AGE = 10

-- Marks the data as old; it stays as the fallback while values are secret
function Spec.InvalidateTalents()
    if talents then talents.stale = true end
end

local function Now() return GetTime and GetTime() or 0 end

-- { points = { SPEC = n }, ranks = { [spellID] = n }, signature = "..." }.
-- If the client hides the values (combat), the last readable result is kept.
function Spec.Talents()
    if talents and not talents.stale and Now() - talents.time < MAX_AGE then return talents end
    local points, ranks = ReadTalents()
    if not points then
        if talents then return talents end
        points, ranks = {}, {}
        for _, key in ipairs(Spec.KEYS) do points[key] = 0 end
        return { points = points, ranks = ranks, signature = "" }
    end
    local learned = {}
    for spellID, rank in pairs(ranks) do learned[#learned + 1] = spellID .. "=" .. rank end
    table.sort(learned)
    talents = { points = points, ranks = ranks, signature = table.concat(learned, ","), time = Now() }
    return talents
end

-- Talent points per spec section of the Forever talent tree, e.g.
-- { DISCIPLINE = 5, HOLY = 0, SHADOW = 1 }
function Spec.TalentPoints()
    return Spec.Talents().points
end

-- Learned ranks of a talent, by its spell ID (0 if not learned). Without a
-- talent config only "known or not" can be read, which counts as 1 rank.
function Spec.TalentRank(spellID)
    return Spec.Talents().ranks[spellID] or 0
end

-- Changes whenever a talent rank changes (for caches)
function Spec.TalentSignature()
    return Spec.Talents().signature
end

-- Forget the cached talents when they may have changed. Events a client
-- doesn't know are skipped.
do
    local frame = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED", "SPELLS_CHANGED",
                             "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD" }) do
        pcall(frame.RegisterEvent, frame, event)
    end
    frame:SetScript("OnEvent", Spec.InvalidateTalents)
end

-- The spec with strictly the most points, or nil on a tie or no points
local function MostPoints(points)
    local best, bestPoints, tie = nil, 0, false
    for _, key in ipairs(Spec.KEYS) do
        local p = points[key] or 0
        if p > bestPoints then
            best, bestPoints, tie = key, p, false
        elseif p == bestPoints and p > 0 then
            tie = true
        end
    end
    if tie then return nil end
    return best
end

-- Returns specKey, source  (or nil, "none" if nothing could be detected).
-- Like the classic talent window, the section with the most points decides;
-- the specialization API is used when there are no points (or a tie).
function Spec.Detect()
    local fromTalents = MostPoints(Spec.TalentPoints())
    if fromTalents then
        return fromTalents, "talents"
    end

    -- Modern specialization API
    local GetSpec, GetSpecInfo = SpecApi("GetSpecialization"), SpecApi("GetSpecializationInfo")
    if GetSpec and GetSpecInfo then
        local ok, index = pcall(GetSpec)
        index = ok and ns.Num(index)
        if index and index > 0 then
            local okInfo, specID = pcall(GetSpecInfo, index)
            if okInfo and SPEC_IDS[specID] then
                return SPEC_IDS[specID], "specialization"
            end
        end
    end

    -- Classic-style talent tabs: the tab with the most points wins
    if GetNumTalentTabs and GetTalentTabInfo then
        local ok, numTabs = pcall(GetNumTalentTabs)
        local points = {}
        for tab = 1, math.min(ok and ns.Num(numTabs) or 0, 3) do
            local r = { pcall(GetTalentTabInfo, tab) }
            if r[1] and TAB_ORDER[tab] then
                -- Classic returns (name, icon, pointsSpent, ...),
                -- later clients (id, name, description, icon, pointsSpent, ...).
                points[TAB_ORDER[tab]] = ns.Num(r[4]) or ns.Num(r[6]) or 0
            end
        end
        local best = MostPoints(points)
        if best then
            return best, "talent tabs"
        end
    end

    return nil, "none"
end

-- Returns the spec used for suggestions and where it came from.
function Spec.Get()
    local override = ns.char and ns.char.specOverride
    if override and Spec.INFO[override] then
        return override, "manual"
    end
    local spec, source = Spec.Detect()
    if spec then
        return spec, source
    end
    -- No spec yet (low level): the class profile's leveling spec
    return DEFAULT, "default"
end

function Spec.GetLevel()
    return UnitLevel("player") or 1
end

function Spec.GetMaxLevel()
    if GetMaxLevelForPlayerExpansion then
        local ok, maxLevel = pcall(GetMaxLevelForPlayerExpansion)
        if ok and type(maxLevel) == "number" and maxLevel > 0 then
            return maxLevel
        end
    end
    return 60
end

function Spec.IsLeveling()
    return Spec.GetLevel() < Spec.GetMaxLevel()
end

-- Name and role for display, e.g. "Holy (Healer)"
function Spec.Label(spec)
    local info = Spec.INFO[spec]
    return ("%s (%s)"):format(info.name, info.role)
end

-- What the tooltip calls a spec next to the level and in "Keep for ...":
-- the spec name, or the role for classes whose specs all have their own role
function Spec.DisplayName(spec)
    local info = Spec.INFO[spec]
    return info.display or info.name
end

-- "disc|holy|shadow"
function Spec.ChoiceText(sep)
    local names = {}
    for _, key in ipairs(Spec.KEYS) do names[#names + 1] = Spec.INFO[key].short:lower() end
    return table.concat(names, sep or "|")
end

-- "Disc 5, Holy 0, Shadow 1"
function Spec.PointsText(points)
    local parts = {}
    for _, key in ipairs(Spec.KEYS) do
        parts[#parts + 1] = ("%s %d"):format(Spec.INFO[key].short, points[key] or 0)
    end
    return table.concat(parts, ", ")
end

-- Spec key for a word typed by the player ("holy", "tank", ...), or nil
function Spec.FromAlias(word)
    return Spec.ALIASES[(word or ""):lower()]
end

ns:RegisterCommand("spec", function() return "[auto|" .. Spec.ChoiceText() .. "]" end,
    "show or override the spec used for suggestions", function(arg)
    arg = strtrim(arg or ""):lower()
    if arg == "auto" then
        ns.char.specOverride = false
    elseif Spec.FromAlias(arg) then
        ns.char.specOverride = Spec.FromAlias(arg)
    elseif arg ~= "" then
        ns.Print(("unknown spec '%s'. Use auto, %s."):format(arg, Spec.ChoiceText(", ")))
        return
    end
    local spec, source = Spec.Get()
    ns.Print(("spec: %s - source: %s, level %d/%d"):format(
        Spec.Label(spec), source, Spec.GetLevel(), Spec.GetMaxLevel()))
    ns.Print("talent points: " .. Spec.PointsText(Spec.TalentPoints()))
    if source == "default" then
        ns.Print(("no spec found, so %s is used. Set yours with %s spec %s."):format(
            Spec.INFO[spec].name, ns.SLASH, Spec.ChoiceText(", ")))
    end
end)
