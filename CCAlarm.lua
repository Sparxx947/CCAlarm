-- CCAlarm -- warns when the healer or the tank is crowd-controlled.
--
-- How the alarm works, and why it works this way:
--
-- Since 0.3.0 the alarm does not read auras at all. It declares what it wants
-- to Blizzard's engine and the engine does the rest -- see Containers.lua for
-- the whole picture:
--
--   * an AuraContainer per watched unit with the filter HARMFUL|CROWD_CONTROL
--     draws the icons and the warning text,
--   * C_UnitAuras.AddAuraSound plays the sound when a known CC spell lands.
--
-- That is what makes it work inside Mythic+ and PvP, where Blizzard keeps auras
-- secret from addons entirely (12.x). Reading them there is impossible -- the
-- API throws -- and until 0.2.3 this addon was therefore silent in every single
-- keystone.
--
-- What is left in THIS file next to the settings, the options and the display
-- frame: the spell list, and it is no longer what decides whether something is
-- shown. Blizzard's own CROWD_CONTROL flag does that. The list is what the
-- engine-side SOUND is bound to, because AddAuraSound wants a spell ID.
--
-- The list is not hardcoded, it is learned: LOSS_OF_CONTROL_ADDED fires for the
-- player and carries Blizzard's own classification (locType) together with the
-- spell ID. Whatever hits you in a dungeon hits the healer and the tank in that
-- same dungeon. On top of that, every harmful aura seen on a healer or tank
-- that is not known yet is recorded as a candidate (collect below) -- outside
-- Mythic+, which is the one thing secrecy still costs.

local ADDON, ns = ...
local L = ns.L
local CCAlarm = CreateFrame("Frame", "CCAlarmFrame")

-- Blizzard's own loss-of-control categories. SCHOOL_INTERRUPT and DISARM are
-- deliberately absent: neither stops anyone from moving or healing, so alerting
-- on them would only add noise.
local RELEVANT_TYPES = {
    STUN = true, STUN_MECHANIC = true,
    FEAR = true, FEAR_MECHANIC = true,
    CONFUSE = true, SLEEP = true,
    CHARM = true, POSSESS = true,
    ROOT = true, SNARE = false,        -- roots yes, slows no
    SILENCE = true, PACIFY = true, PACIFYSILENCE = true,
    BANISH = true, HORROR = true,
}

local DEFAULTS = {
    enabled       = true,
    roles         = { HEALER = true, TANK = true },
    -- Font: LibSharedMedia name when available, otherwise the path is used.
    fontName      = "Friz Quadrata TT",
    fontPath      = "Fonts\\FRIZQT__.TTF",
    fontOutline   = "OUTLINE",
    fontColor     = { r = 1, g = 0.1, b = 0.1 },
    -- Position of the display. Saved as a full anchor so the frame lands in the
    -- same spot on any resolution the player switches to.
    point         = "CENTER",
    relativePoint = "TOP",
    offsetX       = 0,
    locked        = true,
    -- Sound. soundName is the general one; sounds[role] overrides it per role,
    -- so healer and tank can be told apart without looking at the screen.
    soundName     = "CCAlarm Healer",
    sounds        = { HEALER = "CCAlarm Healer", TANK = "CCAlarm Tank" },
    soundKit      = "RAID_WARNING",
    inDungeon     = true,
    inArena       = true,
    inWorld       = true,
    inRaid        = false,
    inBattleground = false,
    sound         = true,
    warningText   = true,
    icons         = true,
    maxIcons      = 5,
    iconSize      = 50,
    iconSpacing   = 2,
    textSize      = 32,
    offsetY       = -220,
    minDuration   = 1.0,   -- seconds; anything shorter is not worth an alarm
    learn         = true,
    collect       = true,  -- record unknown auras as candidates
}

local db              -- CCAlarmDB, set on ADDON_LOADED
local display             -- frame, built lazily

-------------------------------------------------------------------------------
-- Media
--
-- LibSharedMedia is embedded (see Libs/), so the addon carries its own font and
-- sound registry and depends on no other addon. Because LibStub shares
-- libraries, media registered by other addons appear in the lists as well --
-- a bonus, never a requirement. The built-in table below is the last resort
-- should the library fail to load at all.
-------------------------------------------------------------------------------

local BUILTIN_FONTS = {
    ["Friz Quadrata TT"] = "Fonts\\FRIZQT__.TTF",
    ["Arial Narrow"]     = "Fonts\\ARIALN.TTF",
    ["Morpheus"]         = "Fonts\\MORPHEUS.TTF",
    ["Skurri"]           = "Fonts\\skurri.ttf",
}

-- Sounds that ship with the client, addressed through SOUNDKIT rather than as
-- files. Every entry here is in active use by other addons, so these are known
-- to exist rather than assumed.
--
-- These are ALWAYS offered, even when LibSharedMedia is present: the library
-- itself registers exactly one sound ("None"), so relying on it alone would
-- leave the selection empty on an installation with no other addons -- a
-- setting that exists but cannot do anything.
local BUILTIN_SOUNDS = {
    ["Raid Warning"]   = "RAID_WARNING",
    ["Ready Check"]    = "READY_CHECK",
    ["Boss Whisper"]   = "UI_RAID_BOSS_WHISPER_WARNING",
    ["Map Ping"]       = "UI_MAP_WAYPOINT_CHAT_SHARE",
    ["Waypoint Gone"]  = "UI_MAP_WAYPOINT_REMOVE",
    ["Invite Refused"] = "IG_PLAYER_INVITE_DECLINE",
    ["Menu Open"]      = "IG_MAINMENU_OPEN",
    ["Tab"]            = "IG_CHARACTER_INFO_TAB",
}

-- CCAlarm's own sound files. They exist because the engine-side alarm
-- (C_UnitAuras.AddAuraSound, see Containers.lua) takes a FILE NAME: the
-- SOUNDKIT entries above are sound kit ids, not files, and cannot be handed to
-- it. Two of them, so healer and tank stay apart without looking at the screen.
local BUNDLED_SOUNDS = {
    ["CCAlarm Healer"] = "Interface\\AddOns\\CCAlarm\\Media\\alarm-healer.ogg",
    ["CCAlarm Tank"]   = "Interface\\AddOns\\CCAlarm\\Media\\alarm-tank.ogg",
}
ns.BUNDLED_SOUNDS = BUNDLED_SOUNDS

local function lsm()
    return LibStub and LibStub("LibSharedMedia-3.0", true) or nil
end
ns.LSM = lsm

-- Sorted list of selectable font names, plus the resolved path for each.
-- Both lists MERGE the built-ins with whatever the library knows, rather than
-- choosing one source. Picking only the library would empty the sound list on a
-- lone installation; picking only the built-ins would throw away every font and
-- sound the player's other addons provide.
local function merge(builtin, mediatype)
    local seen, names = {}, {}
    for name in pairs(builtin) do
        seen[name] = true
        names[#names + 1] = name
    end
    local media = lsm()
    if media then
        for _, name in ipairs(media:List(mediatype) or {}) do
            if not seen[name] then
                seen[name] = true
                names[#names + 1] = name
            end
        end
    end
    table.sort(names)
    return names
end

function ns.FontList()
    local names = merge(BUILTIN_FONTS, "font")
    local paths, media = {}, lsm()
    for _, name in ipairs(names) do
        paths[name] = BUILTIN_FONTS[name]
                      or (media and media:Fetch("font", name, true))
    end
    return names, paths
end

function ns.SoundList()
    local all = {}
    for name in pairs(BUILTIN_SOUNDS) do all[name] = true end
    for name in pairs(BUNDLED_SOUNDS) do all[name] = true end
    return merge(all, "sound")
end

-- The engine-side alarm needs a sound FILE for a role. A bundled file and a
-- library entry both qualify; a SOUNDKIT name does not, and neither does a
-- library entry that is a number (LibSharedMedia carries sound kit and file ids
-- as plain numbers). Whatever cannot be resolved falls back to the bundled file
-- for that role, so the alarm is never silent just because the chosen sound
-- cannot be handed to the engine. ns.SoundIsEngineCapable tells the two apart
-- for /ccalarm status.
function ns.SoundFileForRole(role)
    local name = ns.SoundForRole(role)
    if name and BUNDLED_SOUNDS[name] then return BUNDLED_SOUNDS[name] end
    local media = lsm()
    if media and name then
        local file = media:Fetch("sound", name, true)
        if type(file) == "string" and file ~= "" then return file end
    end
    return (role == "TANK") and BUNDLED_SOUNDS["CCAlarm Tank"]
                            or BUNDLED_SOUNDS["CCAlarm Healer"]
end

-- Whether the configured sound itself reaches the engine, or the bundled
-- stand-in is doing the work.
function ns.SoundIsEngineCapable(role)
    local name = ns.SoundForRole(role)
    if name and BUNDLED_SOUNDS[name] then return true end
    local media = lsm()
    if media and name then
        local file = media:Fetch("sound", name, true)
        return type(file) == "string" and file ~= ""
    end
    return false
end

-- Resolve the configured font to a usable path. Falls back step by step rather
-- than returning nil, because SetFont with a nil path throws.
local function fontPath()
    if db.fontName and BUILTIN_FONTS[db.fontName] then return BUILTIN_FONTS[db.fontName] end
    local media = lsm()
    if media and db.fontName then
        local path = media:Fetch("font", db.fontName, true)
        if path then return path end
    end
    return db.fontPath or "Fonts\\FRIZQT__.TTF"
end
ns.FontPath = fontPath

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

local function say(text, ...)
    print("|cffff3333CCAlarm|r: " .. string.format(text, ...))
end
ns.Say = say

local function fillMissing(target, template)
    for k, v in pairs(template) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then target[k] = {} end
            fillMissing(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end
end

-- Gated by instance type rather than zone name, which is language independent.
local function zoneAllowed()
    local inside, kind = IsInInstance()
    if not inside then return db.inWorld end
    if kind == "party" or kind == "scenario" then return db.inDungeon end
    if kind == "arena" then return db.inArena end
    if kind == "raid" then return db.inRaid end
    if kind == "pvp" then return db.inBattleground end
    return db.inWorld
end
ns.ZoneAllowed = zoneAllowed

-- Every group unit except the player: for yourself Blizzard already draws its
-- own loss-of-control display across the middle of the screen.
local function groupUnits()
    local out = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do out[#out + 1] = "raid" .. i end
    else
        for i = 1, 4 do
            if UnitExists("party" .. i) then out[#out + 1] = "party" .. i end
        end
    end
    return out
end
ns.GroupUnits = groupUnits

-- Secret values (Midnight 12.x): inside Mythic+ and PvP the aura APIs refuse to
-- answer once an addon sits anywhere in the call path. GetAuraDataByIndex does
-- not return nil then -- it THROWS. Unguarded that produced 14004 errors in a
-- single dungeon evening (2026-09-04) and aborted every scan on the way.
--
-- Blizzard's own query comes first, the pcall probe stays as a fallback for
-- builds without C_Secrets. Neither is a data source: when they say
-- "restricted", other group members' auras cannot be read at all.
--
-- The cache is ASYMMETRIC on purpose. Only the RESTRICTED answer is kept, and
-- only for the current frame, because that is the branch whose probe builds a
-- real Lua error -- constructing the error is the expensive part, and scan()
-- runs on every UNIT_AURA. A stale "free" answer would send the scan straight
-- into a hard error the moment restriction engages mid-frame; a stale
-- "restricted" costs one skipped frame. Same reasoning as EllesmereUI's
-- AuraKit, which has carried this shape through the whole 12.x cycle.
local restrictedStamp = -1
local function aurasRestricted()
    local now = GetTime()
    if C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() then
        restrictedStamp = now
        return true
    end
    if now == restrictedStamp then return true end
    if pcall(C_UnitAuras.GetAuraDataByIndex, "player", 1, "HELPFUL") then
        return false
    end
    restrictedStamp = now
    return true
end

-------------------------------------------------------------------------------
-- Display
-------------------------------------------------------------------------------

local function buildDisplay()
    if display then return display end

    display = CreateFrame("Frame", "CCAlarmDisplay", UIParent)
    display:SetSize(400, 60)
    display:SetFrameStrata("HIGH")
    display:SetMovable(true)
    display:SetClampedToScreen(true)
    display:RegisterForDrag("LeftButton")
    display:SetScript("OnDragStart", function(self)
        if not db.locked then self:StartMoving() end
    end)
    display:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Store the anchor the frame actually ended up with, so it returns to
        -- the same place regardless of resolution or UI scale changes.
        local point, _, relativePoint, x, y = self:GetPoint()
        db.point, db.relativePoint, db.offsetX, db.offsetY = point, relativePoint, x, y
    end)
    -- The frame itself STAYS SHOWN from here on. It is the parent of the aura
    -- containers (Containers.lua), and a hidden parent hides them with it --
    -- the alarm would be built, bound and silent. Nothing of it is visible on
    -- its own: the grip only appears while unlocked, and text and icons only
    -- during a test.
    display:Show()

    -- Backdrop shown only while unlocked, so there is something to grab when
    -- no alarm is on screen.
    display.grip = display:CreateTexture(nil, "BACKGROUND")
    display.grip:SetAllPoints()
    display.grip:SetColorTexture(0, 0.6, 1, 0.25)
    display.grip:Hide()

    display.text = display:CreateFontString(nil, "OVERLAY")
    display.text:SetPoint("BOTTOM", display, "TOP", 0, 4)

    display.icons = {}
    for i = 1, 10 do
        local icon = CreateFrame("Frame", nil, display)
        icon:SetSize(db.iconSize, db.iconSize)
        icon.tex = icon:CreateTexture(nil, "ARTWORK")
        icon.tex:SetAllPoints()
        icon.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        icon.cd = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
        icon.cd:SetAllPoints()
        icon.cd:SetReverse(true)
        icon.cd:SetDrawEdge(false)
        icon:Hide()
        display.icons[i] = icon
    end

    ns.ApplyDisplay()
    return display
end

-- Push every visual setting onto the frame. Called after building it and again
-- whenever the options panel changes something, so there is exactly one place
-- that knows how a setting reaches the screen.
function ns.ApplyDisplay()
    if not display then return end
    display:ClearAllPoints()
    display:SetPoint(db.point or "CENTER", UIParent,
                     db.relativePoint or "TOP", db.offsetX or 0, db.offsetY or -220)
    display.text:SetFont(fontPath(), db.textSize, db.fontOutline ~= "NONE" and db.fontOutline or nil)
    local c = db.fontColor or {}
    display.text:SetTextColor(c.r or 1, c.g or 0.1, c.b or 0.1)
    for _, icon in ipairs(display.icons) do
        icon:SetSize(db.iconSize, db.iconSize)
    end
    display:EnableMouse(not db.locked)
    if db.locked then display.grip:Hide() else display.grip:Show() end
    -- Container buttons bake their look in at creation and cannot be restyled
    -- afterwards, so a changed look has to rebuild them. ApplySettings decides
    -- whether anything actually changed -- rebuilding on every call would leak
    -- a batch of engine frames per click in the options panel.
    if ns.Containers then ns.Containers.ApplySettings() end
end

-- Unlocking shows the frame with its grip so it can be dragged even when no
-- alarm is active; locking hides it again unless an alarm is running.
function ns.SetUnlocked(unlocked)
    db.locked = not unlocked
    local frame = buildDisplay()
    ns.ApplyDisplay()
    if unlocked then
        frame.text:SetText(L["OPT_TITLE"])
        frame.text:Show()
        frame:Show()
    elseif not frame.shownByAlarm then
        -- Locking only takes the caption away; the frame stays as the
        -- containers' parent.
        frame.text:Hide()
    end
end

function ns.ResetPosition()
    db.point, db.relativePoint = DEFAULTS.point, DEFAULTS.relativePoint
    db.offsetX, db.offsetY = DEFAULTS.offsetX, DEFAULTS.offsetY
    ns.ApplyDisplay()
end

function ns.GetDB() return db end


-- Which sound belongs to a role. Falls back to the general one, so an older
-- saved configuration without per-role entries keeps working.
function ns.SoundForRole(role)
    return (role and db.sounds and db.sounds[role]) or db.soundName
end

-- One place that decides what an alarm sounds like. Built-in SOUNDKIT entries
-- are checked first: they are addressed by constant and always available, while
-- a library sound is a file that may have gone away with the addon providing it.
function ns.PlayAlarm(role)
    local name = ns.SoundForRole(role)
    if name and BUNDLED_SOUNDS[name] then
        PlaySoundFile(BUNDLED_SOUNDS[name], "Master")
        return
    end
    if name and BUILTIN_SOUNDS[name] and SOUNDKIT[BUILTIN_SOUNDS[name]] then
        PlaySound(SOUNDKIT[BUILTIN_SOUNDS[name]], "Master")
        return
    end
    local media = lsm()
    if media and name then
        local file = media:Fetch("sound", name, true)
        if file and file ~= 1 then PlaySoundFile(file, "Master"); return end
    end
    PlaySound(SOUNDKIT[db.soundKit or "RAID_WARNING"] or SOUNDKIT.RAID_WARNING, "Master")
end

local function layoutIcons(count)
    local width = count * db.iconSize + (count - 1) * db.iconSpacing
    local x = -width / 2 + db.iconSize / 2
    for i = 1, count do
        local icon = display.icons[i]
        icon:ClearAllPoints()
        icon:SetPoint("CENTER", display, "CENTER", x, 0)
        x = x + db.iconSize + db.iconSpacing
    end
end

-- hits: list of { name, role, aura }
local function show(hits)
    local frame = buildDisplay()
    if #hits == 0 then
        frame.shownByAlarm = false
        frame.text:Hide()
        for _, icon in ipairs(frame.icons) do icon:Hide() end
        return
    end

    if db.warningText then
        local first = hits[1]
        local role = first.role == "HEALER" and L["CC_ALERT_HEALER"] or L["CC_ALERT_TANK"]
        local text = string.format(L["CC_ALERT_FORMAT"], role, first.name)
        if #hits > 1 then text = text .. string.format(L["CC_ALERT_MORE"], #hits - 1) end
        frame.text:SetText(text)
        frame.text:Show()
    else
        frame.text:Hide()
    end

    local shown = 0
    if db.icons then
        shown = math.min(#hits, db.maxIcons, #frame.icons)
        layoutIcons(shown)
        for i = 1, shown do
            local icon, aura = frame.icons[i], hits[i].aura
            icon.tex:SetTexture(aura.icon)
            if aura.duration and aura.duration > 0 and aura.expirationTime then
                icon.cd:SetCooldown(aura.expirationTime - aura.duration, aura.duration)
            else
                icon.cd:Clear()
            end
            icon:Show()
        end
    end
    for i = shown + 1, #frame.icons do frame.icons[i]:Hide() end
    frame.shownByAlarm = true
    frame:Show()
end

-- ACHTUNG Reihenfolge: ns.Test ruft show() auf, und show ist ein local. Stand
-- diese Funktion vorher im Datei, war show dort noch nicht deklariert -- der
-- Aufruf landete auf einer globalen Variable und damit auf nil. Genau das ist
-- am 2026-09-04 im Spiel passiert (27 Vorfaelle). Alles, was show benutzt,
-- gehoert hinter dessen Deklaration.
-- Shown by the test button and by /ccalarm test. One implementation, so the
-- panel cannot drift from the command.
function ns.Test()
    local aura = { icon = 136071, duration = 5, expirationTime = GetTime() + 5 }
    show({ { name = UnitName("player") or "Test", role = "HEALER", aura = aura } })
    if db.sound then ns.PlayAlarm("HEALER") end
    C_Timer.After(5, function()
        if display then
            display.shownByAlarm = false
            display.text:Hide()
            for _, icon in ipairs(display.icons) do icon:Hide() end
        end
    end)
end

-------------------------------------------------------------------------------
-- Learning: take Blizzard's own classification
-------------------------------------------------------------------------------

-- The name of this API has changed across expansions, so try both known forms
-- rather than assuming one of them.
local function lossOfControlData(i)
    if C_LossOfControl and C_LossOfControl.GetActiveLossOfControlData then
        return C_LossOfControl.GetActiveLossOfControlData(i)
    end
    if C_LossOfControl and C_LossOfControl.GetEventInfo then
        return C_LossOfControl.GetEventInfo(i)
    end
    return nil
end

local function lossOfControlCount()
    if C_LossOfControl then
        if C_LossOfControl.GetActiveLossOfControlDataCount then
            return C_LossOfControl.GetActiveLossOfControlDataCount()
        end
        if C_LossOfControl.GetNumEvents then
            return C_LossOfControl.GetNumEvents()
        end
    end
    return 0
end

-- Ist dieser Zauber als Kontrollverlust bekannt?
--
-- Die Saatliste (Data/CCSpells.lua) wird NICHT in db.known kopiert, sondern
-- hier nachgeschlagen. Zwei Gruende: Eine neue Saatliste wirkt sofort, ohne
-- dass alte Eintraege in der Datenbank haengen bleiben -- und ein vom Spieler
-- entfernter Zauber (db.rejected) bliebe beim Kopieren nicht entfernt, sondern
-- kaeme beim naechsten Login zurueck.
function ns.IsKnown(id)
    if not id then return nil end
    if db.rejected and db.rejected[id] then return nil end
    return db.known[id] or (ns.SEED_SPELLS and ns.SEED_SPELLS[id])
end

local function spellName(id)
    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(id) or ("spell " .. id)
    end
    return "spell " .. id
end

local function learn()
    if not db.learn then return false end
    local learned = false
    for i = 1, lossOfControlCount() do
        local data = lossOfControlData(i)
        local id   = data and (data.spellID or data.spellId)
        local kind = data and data.locType
        if id and kind and RELEVANT_TYPES[kind] and not db.known[id]
           and not (ns.SEED_SPELLS and ns.SEED_SPELLS[id]) then
            db.known[id] = kind
            db.candidates[id] = nil
            learned = true
            say(L["MSG_LEARNED"], spellName(id), id, kind)
        end
    end
    return learned
end

-------------------------------------------------------------------------------
-- Scanning the group
-------------------------------------------------------------------------------

-- Collecting candidates -- NOT the alarm.
--
-- Since 0.3.0 the alarm itself is engine-side (Containers.lua): Blizzard's own
-- CROWD_CONTROL filter decides what is shown and the engine plays the sound, so
-- neither needs an aura read and both work inside a keystone. What this pass
-- still does is watch for harmful auras the spell list has never seen, so the
-- engine-side SOUND -- which is bound to spell IDs -- can be told about them.
--
-- It runs only where auras are readable, and it raises nothing on its own. A
-- pass that finds nothing is not a silent alarm; the alarm is elsewhere.
local function collect()
    if not db.enabled or not db.collect or not zoneAllowed() then return end
    if aurasRestricted() then return end

    for _, unit in ipairs(groupUnits()) do
        local role = UnitGroupRolesAssigned(unit)
        if db.roles[role] and not UnitIsDeadOrGhost(unit) then
            local i = 1
            while true do
                -- Second line of defence: restriction can engage between the
                -- gate above and this call. Stop the whole pass -- the
                -- remaining units would throw just the same.
                local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HARMFUL")
                if not ok then
                    restrictedStamp = GetTime()
                    return
                end
                if not aura then break end
                local id = aura.spellId
                if id and not ns.IsKnown(id) and not db.candidates[id] then
                    local duration = aura.duration or 0
                    if duration >= db.minDuration then
                        db.candidates[id] = aura.name or ("spell " .. id)
                    end
                end
                i = i + 1
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Slash commands. English is primary, German aliases are accepted so the
-- addon stays usable in the language its user thinks in.
-------------------------------------------------------------------------------

local ALIASES = {
    hilfe = "help", an = "on", aus = "off", liste = "list",
    kandidaten = "candidates", dazu = "add", weg = "remove", leeren = "clear",
    einstellungen = "config", optionen = "config", loesen = "unlock",
    festsetzen = "lock", zuruecksetzen = "reset",
}

local function command(input)
    local word, rest = input:match("^(%S*)%s*(.-)$")
    word = ALIASES[(word or ""):lower()] or (word or ""):lower()

    if word == "" or word == "help" then
        say(L["MSG_HELP"])
    elseif word == "on" or word == "off" then
        db.enabled = (word == "on")
        say(db.enabled and L["MSG_ON"] or L["MSG_OFF"])
        -- Refresh takes the containers down when the addon is switched off,
        -- and brings them back when it is switched on.
        ns.Containers.Refresh()
    elseif word == "status" then
        local known, candidates = 0, 0
        local gezaehlt = {}
        for id in pairs(db.known) do
            if ns.IsKnown(id) then gezaehlt[id] = true end
        end
        for id in pairs(ns.SEED_SPELLS or {}) do
            if ns.IsKnown(id) then gezaehlt[id] = true end
        end
        for _ in pairs(gezaehlt) do known = known + 1 end
        for _ in pairs(db.candidates) do candidates = candidates + 1 end
        say(L["MSG_STATUS"],
            db.enabled and L["MSG_ON"] or L["MSG_OFF"],
            db.roles.HEALER and L["ROLE_HEALER_SHORT"] or "",
            db.roles.TANK and L["ROLE_TANK_SHORT"] or "",
            known, candidates,
            zoneAllowed() and L["MSG_YES"] or L["MSG_NO"])
        -- What the engine is actually doing for us right now. A watched count
        -- of 0 in a party, or 0 registered sounds with the sound switched on,
        -- is the difference between "quiet" and "broken" -- and nothing else
        -- can show it, because the alarm itself is invisible to the addon.
        say(L["MSG_ENGINE_STATUS"], ns.Containers.WatchedCount(), ns.Containers.SoundCount())
        for _, role in ipairs({ "HEALER", "TANK" }) do
            if db.roles[role] and not ns.SoundIsEngineCapable(role) then
                say(L["MSG_SOUND_SUBSTITUTE"],
                    role == "HEALER" and L["ROLE_HEALER_SHORT"] or L["ROLE_TANK_SHORT"])
            end
        end
        -- Not the alarm any more: what secrecy costs here is the learning.
        if aurasRestricted() then say(L["MSG_AURAS_SECRET"]) end
    elseif word == "test" then
        -- Prove the alarm path without waiting for real crowd control.
        ns.Test()
        say(L["MSG_TEST"])
    elseif word == "config" or word == "options" then
        ns.OpenOptions()
    elseif word == "unlock" or word == "lock" then
        ns.SetUnlocked(word == "unlock")
        say(word == "unlock" and L["MSG_UNLOCKED"] or L["MSG_LOCKED"])
    elseif word == "reset" then
        ns.ResetPosition()
        say(L["MSG_POS_RESET"])
    elseif word == "list" then
        local count, gesehen = 0, {}
        for id, kind in pairs(db.known) do
            if ns.IsKnown(id) then
                gesehen[id] = true
                say("  %d  %s  (%s)", id, spellName(id), kind)
                count = count + 1
            end
        end
        for id, kind in pairs(ns.SEED_SPELLS or {}) do
            if not gesehen[id] and ns.IsKnown(id) then
                say("  %d  %s  (%s, %s)", id, spellName(id), kind, L["MSG_SEEDED"])
                count = count + 1
            end
        end
        if count == 0 then say(L["MSG_NOTHING_LEARNED"]) end
    elseif word == "candidates" then
        local count = 0
        for id, name in pairs(db.candidates) do
            say(L["MSG_CANDIDATE_HINT"], id, name, id)
            count = count + 1
        end
        if count == 0 then say(L["MSG_NO_CANDIDATES"]) end
    elseif word == "add" or word == "remove" then
        local id = tonumber(rest)
        if not id then say(L["MSG_NEED_ID"], word); return end
        if word == "add" then
            db.known[id] = "MANUAL"
            db.candidates[id] = nil
            if db.rejected then db.rejected[id] = nil end
            say(L["MSG_ADDED"], id)
        else
            db.known[id] = nil
            -- Merken, dass der Spieler ihn nicht will: sonst greift beim
            -- naechsten Start wieder die Saatliste.
            db.rejected = db.rejected or {}
            db.rejected[id] = true
            say(L["MSG_REMOVED"], id)
        end
    elseif word == "clear" then
        db.candidates = {}
        say(L["MSG_CLEARED"])
    else
        say(L["MSG_UNKNOWN"], word)
    end
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

CCAlarm:RegisterEvent("ADDON_LOADED")
CCAlarm:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        CCAlarmDB = CCAlarmDB or {}
        db = CCAlarmDB
        fillMissing(db, DEFAULTS)
        db.known = db.known or {}
        db.candidates = db.candidates or {}
        db.rejected = db.rejected or {}

        -- 0.3.0: the alarm is played by the engine now, and that takes a sound
        -- FILE. The old defaults were SOUNDKIT entries, which it will not
        -- accept. Anyone still on those defaults never chose them, so they are
        -- moved to the bundled files -- once, and marked, so a later change
        -- back is not undone on the next login. A sound the player actually
        -- picked is left alone; /ccalarm status says when it cannot be handed
        -- to the engine.
        if not db.soundsMigrated then
            db.soundsMigrated = true
            local wasDefault = {
                HEALER = (db.sounds.HEALER == "Raid Warning"),
                TANK   = (db.sounds.TANK == "Ready Check"),
            }
            if wasDefault.HEALER then db.sounds.HEALER = "CCAlarm Healer" end
            if wasDefault.TANK then db.sounds.TANK = "CCAlarm Tank" end
            if db.soundName == "Raid Warning" then db.soundName = "CCAlarm Healer" end
        end

        self:UnregisterEvent("ADDON_LOADED")
        self:RegisterEvent("UNIT_AURA")
        self:RegisterEvent("GROUP_ROSTER_UPDATE")
        self:RegisterEvent("PLAYER_ROLES_ASSIGNED")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("LOSS_OF_CONTROL_ADDED")
        self:RegisterEvent("LOSS_OF_CONTROL_UPDATE")
        -- The engine refuses sound registrations while the player is in combat
        -- inside an instance, which is every pull. This is the event that redoes
        -- the ones it turned away.
        self:RegisterEvent("PLAYER_REGEN_ENABLED")

        SLASH_CCALARM1 = "/ccalarm"
        SlashCmdList.CCALARM = command
        if ns.RegisterOptions then ns.RegisterOptions() end
        -- The anchor has to exist before the containers can be parented to it.
        ns.Containers.SetAnchor(buildDisplay())
        ns.Containers.Refresh()
        return
    end

    if event == "LOSS_OF_CONTROL_ADDED" or event == "LOSS_OF_CONTROL_UPDATE" then
        -- A newly learned spell has to reach the engine-side sound, or it stays
        -- a spell the addon knows about and the alarm never plays for.
        if learn() then ns.Containers.Refresh() end
        return
    end

    if event == "UNIT_AURA" then
        -- Only group units matter; anything else would be constant load.
        if type(arg1) ~= "string" then return end
        if not (arg1:match("^party%d$") or arg1:match("^raid%d+$")) then return end
        collect()
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        -- Only when a pass was actually turned away, so leaving combat in the
        -- open world does not re-register a thousand sounds for nothing.
        if ns.Containers.ConsumeSkipped() then ns.Containers.Refresh() end
        return
    end

    -- Roster, roles and zone all change WHICH units are watched, and the zone
    -- also changes whether they are watched at all.
    ns.Containers.Refresh()
    collect()
end)
