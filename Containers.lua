-- Containers.lua -- the display and sound path that survives Mythic+.
--
-- Why this file exists:
--
-- Until 0.2.3 CCAlarm read the auras of the healer and the tank itself. Inside
-- Mythic+ and PvP Blizzard keeps auras secret from addons (12.x), so that path
-- cannot see anything there and 0.2.3 could only say so out loud. It never
-- warned in a keystone at all.
--
-- The way out is not a workaround for the aura APIs -- there is none. It is to
-- stop reading auras for the alarm and let the engine do both halves:
--
--   * Display: an AuraContainer per watched unit, declared with the filter
--     "HARMFUL|CROWD_CONTROL". The engine tracks, filters and renders; the
--     addon never sees an aura. Blizzard's own CROWD_CONTROL flag decides what
--     counts, so this covers crowd control the spell list has never heard of.
--
--   * Warning text: a second container on the same filter whose buttons carry
--     nothing but a fontstring. The engine shows and hides the button with the
--     aura it matched, so the text appears exactly while the unit is
--     controlled -- again without a single aura read.
--
--   * Sound: C_UnitAuras.AddAuraSound registers a file per unit and spell ID.
--     The engine plays it when such an aura lands. This one IS spell-ID bound,
--     which is what the learned list is still good for, and it needs a sound
--     FILE: SOUNDKIT constants are sound kit ids, not files, and the engine
--     takes a name. Hence the two bundled .ogg files under Media/.
--
-- The old scan path is not a fallback for any of this. It no longer raises
-- alarms at all; it only keeps collecting candidates where auras are readable.
-- One alarm path, the same one everywhere, so nothing rots unseen.

local ADDON, ns = ...
local L = ns.L

-- The engine's own null binding. A container with no unit must land here and
-- never on "player" -- that is a unit whose auras really do stream.
local NO_UNIT = "none"
local GROUP_KEY = "cc"
-- Filter tokens combine with AND. HARMFUL alone would be every debuff.
local CC_FILTER = "HARMFUL|CROWD_CONTROL"
-- Containers are born at this budget: the engine allocates a group's buttons
-- from the count it is DECLARED with, and raising the number later conjures
-- none. The user's maxIcons only ever re-budgets down from here.
local ICON_CEILING = 10
-- One CC aura is enough to warrant the warning text; more would repeat it.
local LABEL_ICONS = 1

ns.Containers = {}
local C = ns.Containers

local anchor                -- the movable CCAlarm frame, set by ns.Containers.SetAnchor
local entries = {}          -- unit -> { role, icons, label }
local parked = {}           -- containers kept for reuse; engine frames are never freed
local soundIDs = {}         -- unit -> { registration handle, ... }
local soundStamp            -- what the current registrations were made with
local engineOK              -- nil = not asked yet
local engineReported = false

local function getDB() return ns.GetDB() end

-------------------------------------------------------------------------------
-- Engine availability
-------------------------------------------------------------------------------

-- Asked once. A client without the 12.1 container API is not an error worth
-- spamming about -- the addon says it once and stays quiet.
local function engineReady()
    if engineOK ~= nil then return engineOK end
    engineOK = false
    if not (CreateFrame and C_UnitAuras and C_UnitAuras.AddAuraSound) then return false end
    if C_AddOns and C_AddOns.LoadAddOn and not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
    end
    engineOK = true
    return true
end

-- Set to false by the first creation that throws, so a build whose template is
-- named differently costs one failed call rather than one per refresh.
local function engineFailed(err)
    engineOK = false
    if engineReported then return end
    engineReported = true
    ns.Say(L["MSG_NO_CONTAINERS"], tostring(err))
end

function C.Supported()
    return engineReady() and engineOK == true
end

-------------------------------------------------------------------------------
-- Button initializers
--
-- initializeFrame is the ONLY place a container button may be styled: once
-- auras are secret the buttons are forbidden to addons, and every later setter
-- on them is refused. Whatever a button is born with is what it keeps for the
-- whole dungeon, so the current settings are baked in at creation and a
-- settings change rebuilds rather than restyles.
-------------------------------------------------------------------------------

local function iconInitializer(size)
    return function(button)
        if button.SetFlattensRenderLayers then button:SetFlattensRenderLayers(true) end
        button:SetSize(size, size)
        -- No mouse: the buttons sit in the middle of the screen and would
        -- otherwise swallow clicks meant for whatever is behind them.
        pcall(button.SetMouseClickEnabled, button, false)
        pcall(button.SetMouseMotionEnabled, button, false)

        -- Create and style every region BEFORE registering it: each Set*
        -- registration immediately runs the engine's display update, and an
        -- unstyled fontstring has no font assigned and hard-errors in there.
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints(button)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

        local cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        cd:SetAllPoints(button)
        cd:SetReverse(true)
        cd:SetDrawEdge(false)
        cd:SetHideCountdownNumbers(true)

        button:SetIcon(icon)
        button:SetDurationCooldown(cd)
    end
end

local function labelInitializer(text, size, outline, color)
    return function(button)
        if button.SetFlattensRenderLayers then button:SetFlattensRenderLayers(true) end
        -- The button carries nothing but the fontstring; its size is only the
        -- box the engine lays out, the text is what is seen.
        button:SetSize(1, 1)
        pcall(button.SetMouseClickEnabled, button, false)
        pcall(button.SetMouseMotionEnabled, button, false)

        local fs = button:CreateFontString(nil, "OVERLAY")
        fs:SetFont(ns.FontPath(), size, outline)
        fs:SetTextColor(color.r or 1, color.g or 0.1, color.b or 0.1)
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(1, -1)
        fs:SetText(text)
        fs:SetPoint("CENTER", button, "CENTER", 0, 0)
    end
end

-------------------------------------------------------------------------------
-- Containers
-------------------------------------------------------------------------------

local function createContainer(kind, role)
    if not engineReady() then return nil end
    local db = getDB()

    local ok, frame = pcall(CreateFrame, "AuraContainer", nil, anchor, "CustomAuraContainerTemplate")
    if not ok or not frame then
        engineFailed(frame)
        return nil
    end

    -- Built hidden: a container parses the moment it becomes visible, and one
    -- built shown parses before its group carries the real filter.
    frame:Hide()
    if frame.SetIgnoreParentScale then frame:SetIgnoreParentScale(true) end
    frame:SetSize(1, 1)

    local size = (kind == "label") and (db.textSize or 32) or (db.iconSize or 50)
    local spacing = (kind == "label") and 0 or (db.iconSpacing or 2)

    local init
    if kind == "label" then
        local text = (role == "HEALER") and L["CC_LABEL_HEALER"] or L["CC_LABEL_TANK"]
        init = labelInitializer(text, size, db.fontOutline ~= "NONE" and db.fontOutline or nil,
                                db.fontColor or {})
    else
        init = iconInitializer(size)
    end

    local added = pcall(frame.AddAuraGroup, frame, GROUP_KEY, CC_FILTER, {
        maxFrameCount = (kind == "label") and LABEL_ICONS or ICON_CEILING,
        initializeFrame = init,
        sortMethod = AuraContainerSortMethod and AuraContainerSortMethod.AuraInstanceIDOnly or nil,
        layout = {
            elementWidth = size, elementHeight = size,
            elementSpacing = spacing, lineSpacing = spacing,
        },
    })
    if not added then
        engineFailed("AddAuraGroup")
        return nil
    end

    -- Unit LAST: assigning it re-evaluates the container's event registrations,
    -- and those are gated on the container having a group. Set before the group
    -- is declared, UNIT_AURA stays unregistered.
    frame:SetUnit(NO_UNIT)
    return { frame = frame, kind = kind, role = role, size = size }
end

-- A container is never freed -- engine frames are permanent -- so one that is
-- no longer needed is pointed at nobody and kept for the next unit in the same
-- role. The style is baked in at creation, which is why the pool is keyed by
-- kind AND role: a healer label may never come back as a tank label.
local function poolKey(kind, role, size)
    return kind .. ":" .. role .. ":" .. tostring(size)
end

local function release(item)
    if not item then return end
    item.frame:SetUnit(NO_UNIT)
    item.frame:Hide()
    local key = poolKey(item.kind, item.role, item.size)
    parked[key] = parked[key] or {}
    table.insert(parked[key], item)
end

local function acquire(kind, role)
    local db = getDB()
    local size = (kind == "label") and (db.textSize or 32) or (db.iconSize or 50)
    local key = poolKey(kind, role, size)
    local list = parked[key]
    if list and #list > 0 then
        return table.remove(list)
    end
    return createContainer(kind, role)
end

-- Both halves are needed when the OCCUPANT behind a token changes: the token
-- string is the same string, so the container sees no change and would keep
-- showing the previous player's auras. Pointing it at nobody and back is a
-- change it does see.
local function bind(item, unit)
    local frame = item.frame
    frame:SetUnit(NO_UNIT)
    frame:SetUnit(unit)
    frame:Show()
    if frame.UpdateAllAuras then pcall(frame.UpdateAllAuras, frame) end
end

-------------------------------------------------------------------------------
-- Layout
--
-- Container sizes must never be read: they may be secret. Chaining each
-- container to the previous one lays them out without asking any of them how
-- big it is, and an empty container collapses, so the row only takes room for
-- units that are actually controlled.
-------------------------------------------------------------------------------

local function layout()
    local db = getDB()
    local order = {}
    for unit in pairs(entries) do order[#order + 1] = unit end
    table.sort(order)   -- pairs order would swap the rows between refreshes

    local previous
    for _, unit in ipairs(order) do
        local item = entries[unit].icons
        if item then
            item.frame:ClearAllPoints()
            if previous then
                item.frame:SetPoint("LEFT", previous.frame, "RIGHT", db.iconSpacing or 2, 0)
            else
                item.frame:SetPoint("CENTER", anchor, "CENTER", 0, 0)
            end
            previous = item
        end
        -- Every label of one role lands on the same point: identical texts on
        -- top of each other read as one label, which is an OR across units.
        local label = entries[unit].label
        if label then
            label.frame:ClearAllPoints()
            local y = (entries[unit].role == "HEALER") and 6 or -((db.textSize or 32) + 8)
            label.frame:SetPoint("TOP", anchor, "TOP", 0, y)
        end
    end
end

-------------------------------------------------------------------------------
-- Sound
--
-- Engine-side: the addon cannot see the aura land, but the engine can play a
-- file when a spell it knows lands on a unit it knows. Registrations are per
-- unit and spell ID, so they are redone whenever the roster, the sound or the
-- spell list changes -- and NOT while the engine refuses them.
-------------------------------------------------------------------------------

-- AddAuraSound is refused in combat inside instanced PvE, where it raises a
-- blocked action rather than failing quietly. Outside instances combat has no
-- say. An allow-list, so a kind of place nobody thought of costs a sound rather
-- than a blocked call.
local COMBAT_SAFE = { none = true, pvp = true, arena = true }

local function canRegister()
    if not (C_UnitAuras and C_UnitAuras.AddAuraSound and Enum and Enum.UnitAuraSoundTrigger) then
        return false
    end
    local _, kind = IsInInstance()
    if COMBAT_SAFE[kind or "none"] then return true end
    return not InCombatLockdown()
end
C.CanRegisterSounds = canRegister

-- Whether a pass with work to do was turned away, so the end of combat knows
-- there is something to redo.
local soundsSkipped = false
function C.ConsumeSkipped()
    local skipped = soundsSkipped
    soundsSkipped = false
    return skipped
end

local function removeSounds(unit)
    local ids = soundIDs[unit]
    if not ids then return end
    soundIDs[unit] = nil
    for i = #ids, 1, -1 do
        pcall(C_UnitAuras.RemoveAuraSound, ids[i])
    end
end

local function clearSounds()
    for unit in pairs(soundIDs) do removeSounds(unit) end
    soundStamp = nil
end
C.ClearSounds = clearSounds

-- Every spell the addon considers crowd control, seed list and learned list
-- together, minus the ones the player removed.
local function knownSpells()
    local out = {}
    local db = getDB()
    for id in pairs(db.known or {}) do
        if ns.IsKnown(id) then out[id] = true end
    end
    for id in pairs(ns.SEED_SPELLS or {}) do
        if ns.IsKnown(id) then out[id] = true end
    end
    return out
end

local function registerSounds(unit, role, spells)
    if soundIDs[unit] then return end
    local file = ns.SoundFileForRole(role)
    if not file then return end
    local ids = {}
    local info = {
        unitToken = unit,
        soundFileName = file,
        outputChannel = "Master",
    }
    for id in pairs(spells) do
        info.spellID = id
        local ok, handle = pcall(C_UnitAuras.AddAuraSound, Enum.UnitAuraSoundTrigger.Added, info)
        if ok and handle then ids[#ids + 1] = handle end
    end
    soundIDs[unit] = ids
end

-- A stamp of everything baked into a registration. When it changes, every unit
-- has to be registered again; the unit set alone is handled incrementally.
local function soundGeneration(spells)
    local db = getDB()
    local count = 0
    for _ in pairs(spells) do count = count + 1 end
    return table.concat({
        db.sound and "1" or "0",
        tostring(ns.SoundFileForRole("HEALER")),
        tostring(ns.SoundFileForRole("TANK")),
        tostring(count),
    }, "|")
end

local function refreshSounds(spells)
    local db = getDB()
    local wanted = db.enabled and db.sound and ns.ZoneAllowed()

    if not canRegister() then
        -- Only worth noting when there is work: an idle pass being turned away
        -- must not make the end of combat redo nothing.
        if wanted or next(soundIDs) ~= nil then soundsSkipped = true end
        return
    end

    if not wanted then
        clearSounds()
        return
    end

    local generation = soundGeneration(spells)
    if generation ~= soundStamp then
        clearSounds()
        soundStamp = generation
    end

    for unit in pairs(soundIDs) do
        if not entries[unit] then removeSounds(unit) end
    end
    for unit, entry in pairs(entries) do
        registerSounds(unit, entry.role, spells)
    end
end

-------------------------------------------------------------------------------
-- Refresh
-------------------------------------------------------------------------------

function C.SetAnchor(frame)
    anchor = frame
end

-- Which group members are watched right now: the roles the user picked, and
-- never the player's own unit (C_LossOfControl already covers that, and a
-- warning about oneself is what the screen already shows).
local function watchedUnits()
    local db = getDB()
    local out = {}
    for _, unit in ipairs(ns.GroupUnits()) do
        local role = UnitGroupRolesAssigned(unit)
        if db.roles[role] then out[unit] = role end
    end
    return out
end

-- Rebuilds the container set against the current roster. Called on roster
-- changes, on zone changes, when the options change, and after combat for the
-- sounds the engine refused during the pull.
function C.Refresh()
    if not anchor then return end
    local db = getDB()

    if not C.Supported() then
        return
    end

    local wanted = (db.enabled and db.icons ~= nil and ns.ZoneAllowed()) and watchedUnits() or {}
    if not db.enabled or not ns.ZoneAllowed() then wanted = {} end

    -- Units that dropped out
    for unit, entry in pairs(entries) do
        if not wanted[unit] or wanted[unit] ~= entry.role then
            release(entry.icons)
            release(entry.label)
            entries[unit] = nil
            removeSounds(unit)
        end
    end

    -- Units that came in, and parts that a setting only now asks for. Both in
    -- one pass: switching the warning text on for a unit that is ALREADY
    -- watched has to build its label container too, and an "only when the unit
    -- is new" branch would leave that setting dead until the roster changed.
    for unit, role in pairs(wanted) do
        local entry = entries[unit]
        if not entry then
            entry = { role = role }
            entries[unit] = entry
        end
        if db.icons and not entry.icons then
            entry.icons = acquire("icons", role)
            if entry.icons then bind(entry.icons, unit) end
        end
        if db.warningText and not entry.label then
            entry.label = acquire("label", role)
            if entry.label then bind(entry.label, unit) end
        end
    end

    -- Budgets: the group was declared at the ceiling, so this is the setting
    -- the user actually asked for, and 0 hides the group without freeing it.
    local budget = math.max(0, math.min(db.maxIcons or 5, ICON_CEILING))
    for _, entry in pairs(entries) do
        if entry.icons then
            pcall(entry.icons.frame.SetAuraGroupMaxFrameCount, entry.icons.frame, GROUP_KEY,
                  db.icons and budget or 0)
        end
        if entry.label then
            pcall(entry.label.frame.SetAuraGroupMaxFrameCount, entry.label.frame, GROUP_KEY,
                  db.warningText and LABEL_ICONS or 0)
        end
    end

    layout()
    refreshSounds(knownSpells())
end

-- Everything a button carries from birth. A change here can only be applied by
-- building new buttons; anything not in this stamp is re-driven live and must
-- NOT be in it, or every options click would leak a batch of engine frames.
local function styleFingerprint()
    local db = getDB()
    local c = db.fontColor or {}
    return table.concat({
        tostring(db.iconSize), tostring(db.textSize), tostring(db.fontOutline),
        tostring(db.fontName), tostring(db.fontPath),
        tostring(c.r), tostring(c.g), tostring(c.b),
        tostring(db.iconSpacing),
    }, "|")
end

local styleStamp

-- Called whenever the options change. Three outcomes, not two: rebuild when the
-- baked-in look moved, refresh when only live settings did, and do neither when
-- nothing changed at all.
function C.ApplySettings()
    if not anchor then return end
    local stamp = styleFingerprint()
    if stamp ~= styleStamp then
        styleStamp = stamp
        C.Rebuild()
        return
    end
    C.Refresh()
end

-- A settings change bakes into the buttons, which cannot be restyled once they
-- exist. Everything is dropped and built again from the current settings.
function C.Rebuild()
    for unit, entry in pairs(entries) do
        release(entry.icons)
        release(entry.label)
        entries[unit] = nil
    end
    parked = {}
    clearSounds()
    C.Refresh()
end

-- How many units are watched right now, for /ccalarm status.
function C.WatchedCount()
    local n = 0
    for _ in pairs(entries) do n = n + 1 end
    return n
end

-- How many sound registrations stand right now, so status can tell a silent
-- engine apart from one that simply has nothing to play.
function C.SoundCount()
    local n = 0
    for _, ids in pairs(soundIDs) do n = n + #ids end
    return n
end
