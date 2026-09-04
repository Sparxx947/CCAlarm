-- CCAlarm -- warnt, wenn Heiler oder Tank in Kontrollverlust geraten.
--
-- Warum es dieses Addon gibt und wie es arbeitet:
--
-- In Midnight (12.x) gibt es COMBAT_LOG_EVENT_UNFILTERED nicht mehr, und die
-- Aura-API kennzeichnet nicht, ob eine Aura Kontrollverlust bedeutet -- weder
-- C_UnitAuras noch die Aurendaten selbst tragen dafuer ein Feld. Wer CC bei
-- Mitspielern erkennen will, braucht daher eine Liste von Zauber-IDs.
--
-- Diese Liste wird hier NICHT geraten, sondern gelernt: LOSS_OF_CONTROL_ADDED
-- feuert fuer den Spieler selbst und nennt Blizzards eigene Einstufung
-- (locType) samt Zauber-ID. Was einen selbst trifft, trifft in denselben
-- Dungeons auch Heiler und Tank -- die Liste fuellt sich also beim Spielen und
-- steht ab dann fuer die ganze Gruppe zur Verfuegung.
--
-- Damit die erste Begegnung nicht verloren geht, fuehrt das Addon zusaetzlich
-- eine Kandidatenliste: jede schaedliche Aura auf Heiler oder Tank, die es noch
-- nicht kennt, wird mit Namen und ID vermerkt und laesst sich per Befehl
-- uebernehmen.

local ADDON = ...
local CCAlarm = CreateFrame("Frame", "CCAlarmFrame")

-- Blizzards eigene Einstufungen aus LOSS_OF_CONTROL. SCHOOL_INTERRUPT und
-- DISARM sind bewusst NICHT dabei: sie hindern niemanden am Laufen oder Heilen
-- und wuerden nur Laerm erzeugen.
local RELEVANTE_TYPEN = {
    STUN = true, STUN_MECHANIC = true,
    FEAR = true, FEAR_MECHANIC = true,
    CONFUSE = true, SLEEP = true,
    CHARM = true, POSSESS = true,
    ROOT = true, SNARE = false,        -- Wurzeln ja, Verlangsamung nein
    SILENCE = true, PACIFY = true, PACIFYSILENCE = true,
    BANISH = true, HORROR = true,
}

local STANDARD = {
    aktiv          = true,
    rollen         = { HEALER = true, TANK = true },
    inDungeon      = true,
    inArena        = true,
    inWelt         = true,
    inRaid         = false,
    inSchlachtfeld = false,
    ton            = true,
    warntext       = true,
    symbole        = true,
    maxSymbole     = 5,
    symbolGroesse  = 50,
    symbolAbstand  = 2,
    textGroesse    = 32,
    versatzY       = -220,
    mindestdauer   = 1.0,   -- Sekunden; kuerzeres lohnt keinen Alarm
    lernen         = true,
    kandidaten     = true,
}

local db          -- CCAlarmDB, nach ADDON_LOADED gesetzt
local aktiveAlarme = {}   -- auraInstanceID -> true, verhindert Dauerfeuer
local anzeige             -- Rahmen, faul erzeugt

-------------------------------------------------------------------------------
-- Hilfen
-------------------------------------------------------------------------------

local function meldung(text, ...)
    print("|cffff3333CCAlarm|r: " .. string.format(text, ...))
end

local function kopiereFehlende(ziel, vorlage)
    for k, v in pairs(vorlage) do
        if type(v) == "table" then
            if type(ziel[k]) ~= "table" then ziel[k] = {} end
            kopiereFehlende(ziel[k], v)
        elseif ziel[k] == nil then
            ziel[k] = v
        end
    end
end

-- Gilt der Alarm hier? Bewusst nach Instanztyp, nicht nach Zonennamen.
local function zoneErlaubt()
    local drin, art = IsInInstance()
    if not drin then return db.inWelt end
    if art == "party" or art == "scenario" then return db.inDungeon end
    if art == "arena" then return db.inArena end
    if art == "raid" then return db.inRaid end
    if art == "pvp" then return db.inSchlachtfeld end
    return db.inWelt
end

-- Alle Gruppeneinheiten ausser dem Spieler selbst: fuer sich selbst hat man
-- Blizzards eigene Kontrollverlust-Anzeige mitten im Bild.
local function gruppenEinheiten()
    local aus = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do aus[#aus + 1] = "raid" .. i end
    else
        for i = 1, 4 do
            if UnitExists("party" .. i) then aus[#aus + 1] = "party" .. i end
        end
    end
    return aus
end

-------------------------------------------------------------------------------
-- Anzeige
-------------------------------------------------------------------------------

local function baueAnzeige()
    if anzeige then return anzeige end

    anzeige = CreateFrame("Frame", "CCAlarmAnzeige", UIParent)
    anzeige:SetSize(400, 60)
    anzeige:SetPoint("CENTER", UIParent, "TOP", 0, db.versatzY)
    anzeige:SetFrameStrata("HIGH")
    anzeige:Hide()

    anzeige.text = anzeige:CreateFontString(nil, "OVERLAY")
    anzeige.text:SetFont("Fonts\\FRIZQT__.TTF", db.textGroesse, "OUTLINE")
    anzeige.text:SetPoint("BOTTOM", anzeige, "TOP", 0, 4)
    anzeige.text:SetTextColor(1, 0.1, 0.1)

    anzeige.symbole = {}
    for i = 1, 10 do
        local s = CreateFrame("Frame", nil, anzeige)
        s:SetSize(db.symbolGroesse, db.symbolGroesse)
        s.tex = s:CreateTexture(nil, "ARTWORK")
        s.tex:SetAllPoints()
        s.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        s.cd = CreateFrame("Cooldown", nil, s, "CooldownFrameTemplate")
        s.cd:SetAllPoints()
        s.cd:SetReverse(true)
        s.cd:SetDrawEdge(false)
        s:Hide()
        anzeige.symbole[i] = s
    end
    return anzeige
end

local function ordneSymbole(anzahl)
    local breite = anzahl * db.symbolGroesse + (anzahl - 1) * db.symbolAbstand
    local x = -breite / 2 + db.symbolGroesse / 2
    for i = 1, anzahl do
        local s = anzeige.symbole[i]
        s:ClearAllPoints()
        s:SetPoint("CENTER", anzeige, "CENTER", x, 0)
        x = x + db.symbolGroesse + db.symbolAbstand
    end
end

-- treffer: Liste aus { name, rolle, aura }
local function zeige(treffer)
    local a = baueAnzeige()
    if #treffer == 0 then a:Hide(); return end

    if db.warntext then
        local erster = treffer[1]
        local rolle = erster.rolle == "HEALER" and "HEILER" or "TANK"
        local text = ("%s IN CC: %s"):format(rolle, erster.name)
        if #treffer > 1 then text = text .. (" (+%d)"):format(#treffer - 1) end
        a.text:SetText(text)
        a.text:Show()
    else
        a.text:Hide()
    end

    local n = 0
    if db.symbole then
        n = math.min(#treffer, db.maxSymbole, #a.symbole)
        ordneSymbole(n)
        for i = 1, n do
            local s, aura = a.symbole[i], treffer[i].aura
            s.tex:SetTexture(aura.icon)
            if aura.duration and aura.duration > 0 and aura.expirationTime then
                s.cd:SetCooldown(aura.expirationTime - aura.duration, aura.duration)
            else
                s.cd:Clear()
            end
            s:Show()
        end
    end
    for i = n + 1, #a.symbole do a.symbole[i]:Hide() end
    a:Show()
end

-------------------------------------------------------------------------------
-- Lernen: Blizzards eigene Einstufung uebernehmen
-------------------------------------------------------------------------------

local function lossOfControlDaten(i)
    -- Der Name dieser API hat sich ueber die Erweiterungen mehrfach geaendert;
    -- deshalb beide bekannten Formen versuchen, statt eine zu unterstellen.
    if C_LossOfControl and C_LossOfControl.GetActiveLossOfControlData then
        return C_LossOfControl.GetActiveLossOfControlData(i)
    end
    if C_LossOfControl and C_LossOfControl.GetEventInfo then
        return C_LossOfControl.GetEventInfo(i)
    end
    return nil
end

local function anzahlLossOfControl()
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

local function lerne()
    if not db.lernen then return end
    for i = 1, anzahlLossOfControl() do
        local d = lossOfControlDaten(i)
        local id  = d and (d.spellID or d.spellId)
        local typ = d and d.locType
        if id and typ and RELEVANTE_TYPEN[typ] and not db.bekannt[id] then
            local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id) or ("Zauber " .. id)
            db.bekannt[id] = typ
            db.kandidatenListe[id] = nil
            meldung("gelernt: %s (%d, %s)", name, id, typ)
        end
    end
end

-------------------------------------------------------------------------------
-- Pruefung der Gruppe
-------------------------------------------------------------------------------

local function pruefe()
    if not db.aktiv or not zoneErlaubt() then
        if anzeige then anzeige:Hide() end
        return
    end

    local treffer = {}
    for _, unit in ipairs(gruppenEinheiten()) do
        local rolle = UnitGroupRolesAssigned(unit)
        if db.rollen[rolle] and not UnitIsDeadOrGhost(unit) then
            local i = 1
            while true do
                local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HARMFUL")
                if not aura then break end
                local id = aura.spellId
                if id and db.bekannt[id] then
                    local dauer = aura.duration or 0
                    if dauer == 0 or dauer >= db.mindestdauer then
                        treffer[#treffer + 1] = {
                            name  = UnitName(unit) or "?",
                            rolle = rolle,
                            aura  = aura,
                        }
                        -- Schluessel gegen Dauerfeuer. auraInstanceID ist der
                        -- genaue Weg, fehlt aber bei manchen Auren -- dann auf
                        -- Einheit+Zauber ausweichen, statt stumm zu bleiben.
                        local schluessel = aura.auraInstanceID or (unit .. ":" .. id)
                        if not aktiveAlarme[schluessel] then
                            aktiveAlarme[schluessel] = true
                            if db.ton then PlaySound(SOUNDKIT.RAID_WARNING, "Master") end
                        end
                    end
                elseif id and db.kandidaten and not db.kandidatenListe[id] then
                    local dauer = aura.duration or 0
                    if dauer >= db.mindestdauer then
                        db.kandidatenListe[id] = aura.name or ("Zauber " .. id)
                    end
                end
                i = i + 1
            end
        end
    end
    zeige(treffer)
end

-------------------------------------------------------------------------------
-- Befehle
-------------------------------------------------------------------------------

local function befehl(eingabe)
    local wort, rest = eingabe:match("^(%S*)%s*(.-)$")
    wort = (wort or ""):lower()

    if wort == "" or wort == "hilfe" then
        meldung("Befehle: status | an | aus | test | liste | kandidaten | dazu <id> | weg <id> | leeren")
        return
    elseif wort == "an" or wort == "aus" then
        db.aktiv = (wort == "an")
        meldung("ist jetzt %s", db.aktiv and "an" or "aus")
        if not db.aktiv and anzeige then anzeige:Hide() end
        return
    elseif wort == "status" then
        local n, k = 0, 0
        for _ in pairs(db.bekannt) do n = n + 1 end
        for _ in pairs(db.kandidatenListe) do k = k + 1 end
        meldung("%s | Rollen: %s%s | bekannte Zauber: %d | Kandidaten: %d | hier aktiv: %s",
            db.aktiv and "an" or "aus",
            db.rollen.HEALER and "Heiler " or "", db.rollen.TANK and "Tank" or "",
            n, k, zoneErlaubt() and "ja" or "nein")
        return
    elseif wort == "test" then
        -- Alarmweg nachweisen, ohne auf echten CC zu warten.
        local aura = { icon = 136071, duration = 5, expirationTime = GetTime() + 5 }
        zeige({ { name = UnitName("player") or "Test", rolle = "HEALER", aura = aura } })
        if db.ton then PlaySound(SOUNDKIT.RAID_WARNING, "Master") end
        C_Timer.After(5, function() if anzeige then anzeige:Hide() end end)
        meldung("Probealarm fuer 5 Sekunden -- so sieht es im Ernstfall aus.")
        return
    elseif wort == "liste" then
        local n = 0
        for id, typ in pairs(db.bekannt) do
            local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id) or "?"
            meldung("  %d  %s  (%s)", id, name, typ)
            n = n + 1
        end
        if n == 0 then meldung("noch nichts gelernt -- das kommt beim Spielen von selbst.") end
        return
    elseif wort == "kandidaten" then
        local n = 0
        for id, name in pairs(db.kandidatenListe) do
            meldung("  %d  %s   -- uebernehmen mit /ccalarm dazu %d", id, name, id)
            n = n + 1
        end
        if n == 0 then meldung("keine offenen Kandidaten.") end
        return
    elseif wort == "dazu" then
        local id = tonumber(rest)
        if not id then meldung("Aufruf: /ccalarm dazu <Zauber-ID>"); return end
        db.bekannt[id] = "MANUELL"
        db.kandidatenListe[id] = nil
        meldung("%d aufgenommen.", id)
        return
    elseif wort == "weg" then
        local id = tonumber(rest)
        if not id then meldung("Aufruf: /ccalarm weg <Zauber-ID>"); return end
        db.bekannt[id] = nil
        meldung("%d entfernt.", id)
        return
    elseif wort == "leeren" then
        db.kandidatenListe = {}
        meldung("Kandidatenliste geleert.")
        return
    end
    meldung("unbekannt: %s -- /ccalarm hilfe", wort)
end

-------------------------------------------------------------------------------
-- Ereignisse
-------------------------------------------------------------------------------

CCAlarm:RegisterEvent("ADDON_LOADED")
CCAlarm:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        CCAlarmDB = CCAlarmDB or {}
        db = CCAlarmDB
        kopiereFehlende(db, STANDARD)
        db.bekannt = db.bekannt or {}
        db.kandidatenListe = db.kandidatenListe or {}

        self:UnregisterEvent("ADDON_LOADED")
        self:RegisterEvent("UNIT_AURA")
        self:RegisterEvent("GROUP_ROSTER_UPDATE")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("LOSS_OF_CONTROL_ADDED")
        self:RegisterEvent("LOSS_OF_CONTROL_UPDATE")

        SLASH_CCALARM1 = "/ccalarm"
        SlashCmdList.CCALARM = befehl
        return
    end

    if event == "LOSS_OF_CONTROL_ADDED" or event == "LOSS_OF_CONTROL_UPDATE" then
        lerne()
        return
    end

    if event == "UNIT_AURA" then
        -- Nur Gruppeneinheiten interessieren; alles andere waere Dauerlast.
        if type(arg1) ~= "string" then return end
        if not (arg1:match("^party%d$") or arg1:match("^raid%d+$")) then return end
    end

    if event == "PLAYER_ENTERING_WORLD" then wipe(aktiveAlarme) end
    pruefe()
end)
