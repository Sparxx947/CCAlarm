-- pruefstand.lua -- laesst CCAlarm ohne WoW laufen und prueft sein Verhalten.
-- Aufruf: lua5.1 tests/pruefstand.lua
--
-- Der Prueflauf deckt beide Richtungen ab: dass der Alarm kommt, wenn er soll,
-- UND dass er ausbleibt, wenn er nicht soll. Ein Test, der nur den guten Fall
-- zeigt, beweist nichts.

-------------------------------------------------------------------------------
-- WoW-API nachstellen
-------------------------------------------------------------------------------
local Welt = {
    instanz = "party",
    rollen  = { party1 = "HEALER", party2 = "TANK", party3 = "DAMAGER" },
    auren   = {},          -- unit -> Liste von Aurentabellen
    tot     = {},
    loc     = {},          -- aktive Kontrollverluste des Spielers
}
local Ausgabe, Toene = {}, 0

function print(...)
    local t = {}
    for i = 1, select("#", ...) do t[#t+1] = tostring((select(i, ...))) end
    Ausgabe[#Ausgabe+1] = table.concat(t, " ")
end
local echtesPrint = io.write

wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
GetLocale = function() return "enUS" end
GetTime = function() return 1000 end
UnitName = function(u) return u end
UnitIsDeadOrGhost = function(u) return Welt.tot[u] or false end
UnitExists = function(u) return Welt.rollen[u] ~= nil end
UnitGroupRolesAssigned = function(u) return Welt.rollen[u] or "NONE" end
IsInInstance = function() return Welt.instanz ~= nil, Welt.instanz end
IsInRaid = function() return Welt.instanz == "raid" end
GetNumGroupMembers = function() local n=0 for _ in pairs(Welt.rollen) do n=n+1 end return n end
PlaySound = function() Toene = Toene + 1 end
SOUNDKIT = { RAID_WARNING = 1 }
C_Timer = { After = function() end }
C_Spell = { GetSpellName = function(id) return "Zauber" .. id end }
C_UnitAuras = {
    GetAuraDataByIndex = function(unit, i) return (Welt.auren[unit] or {})[i] end,
}
C_LossOfControl = {
    GetActiveLossOfControlDataCount = function() return #Welt.loc end,
    GetActiveLossOfControlData = function(i) return Welt.loc[i] end,
}

local function neuerRahmen()
    local f = {}
    local function nix() end
    f.SetSize, f.SetPoint, f.ClearAllPoints, f.SetFrameStrata = nix, nix, nix, nix
    f.SetScript, f.RegisterEvent, f.UnregisterEvent = nix, nix, nix
    f.SetFont, f.SetTextColor, f.SetText = nix, nix, nix
    f.SetAllPoints, f.SetTexCoord, f.SetTexture = nix, nix, nix
    f.SetReverse, f.SetDrawEdge, f.SetCooldown, f.Clear = nix, nix, nix, nix
    f.sichtbar = false
    f.Show = function(self) self.sichtbar = true end
    f.Hide = function(self) self.sichtbar = false end
    f.CreateFontString = function() return neuerRahmen() end
    f.CreateTexture = function() return neuerRahmen() end
    return f
end
local rahmen = {}
CreateFrame = function(_, name)
    local f = neuerRahmen()
    if name then rahmen[name] = f end
    return f
end
SLASH_CCALARM1, SlashCmdList = nil, {}

-------------------------------------------------------------------------------
-- Addon laden
-------------------------------------------------------------------------------
local pfad = (arg and arg[0] or ""):match("^(.*)tests/") or "./"
local ns = {}
local ladeLocales = assert(loadfile(pfad .. "Locales.lua"))
local lade = assert(loadfile(pfad .. "CCAlarm.lua"))
ladeLocales("CCAlarm", ns)
lade("CCAlarm", ns)
local addon = rahmen["CCAlarmFrame"]

-- SetScript war ein Platzhalter; den echten Handler abgreifen
local handler
do
    local f = neuerRahmen()
    f.SetScript = function(_, _, fn) handler = fn end
    -- neu laden, diesmal mit greifendem SetScript
    for k in pairs(rahmen) do rahmen[k] = nil end
    CreateFrame = function(_, name)
        local r = (name == "CCAlarmFrame") and f or neuerRahmen()
        if name then rahmen[name] = r end
        return r
    end
    lade("CCAlarm", ns)
    addon = rahmen["CCAlarmFrame"]
end
assert(handler, "Ereignishandler nicht gefunden")

CCAlarmDB = nil
handler(addon, "ADDON_LOADED", "CCAlarm")
assert(CCAlarmDB, "Datenbank nicht angelegt")

-------------------------------------------------------------------------------
-- Pruefungen
-------------------------------------------------------------------------------
local bestanden, gescheitert = 0, 0
local function pruefe(was, bedingung)
    if bedingung then bestanden = bestanden + 1; echtesPrint("  OK    " .. was .. "\n")
    else gescheitert = gescheitert + 1; echtesPrint("  FEHLT " .. was .. "\n") end
end
local function anzeigeSichtbar()
    local a = rahmen["CCAlarmDisplay"]
    return a and a.sichtbar or false
end
local function ruecksetzen()
    Welt.auren = {}; Toene = 0; Ausgabe = {}
    wipe(CCAlarmDB.candidates)
    handler(addon, "PLAYER_ENTERING_WORLD")
end

echtesPrint("\n=== 1. Lernen aus Blizzards eigener Einstufung ===\n")
Welt.loc = { { spellID = 4321, locType = "STUN" } }
handler(addon, "LOSS_OF_CONTROL_ADDED")
pruefe("Betaeubung wird gelernt", CCAlarmDB.known[4321] == "STUN")

Welt.loc = { { spellID = 9999, locType = "SCHOOL_INTERRUPT" } }
handler(addon, "LOSS_OF_CONTROL_ADDED")
pruefe("Zauberschulsperre wird NICHT gelernt", CCAlarmDB.known[9999] == nil)

echtesPrint("\n=== 2. Alarm bei Heiler und Tank ===\n")
ruecksetzen()
Welt.auren.party1 = { { spellId = 4321, duration = 4, expirationTime = 1004, icon = 1, name = "Betaeubung" } }
handler(addon, "UNIT_AURA", "party1")
pruefe("Heiler im CC loest Alarm aus", anzeigeSichtbar())
pruefe("Ton wurde gespielt", Toene == 1)

ruecksetzen()
Welt.auren.party2 = { { spellId = 4321, duration = 4, expirationTime = 1004, icon = 1, name = "Betaeubung" } }
handler(addon, "UNIT_AURA", "party2")
pruefe("Tank im CC loest Alarm aus", anzeigeSichtbar())

echtesPrint("\n=== 3. Gegenproben: wann NICHT alarmiert wird ===\n")
ruecksetzen()
Welt.auren.party3 = { { spellId = 4321, duration = 4, expirationTime = 1004, icon = 1, name = "Betaeubung" } }
handler(addon, "UNIT_AURA", "party3")
pruefe("Schadensausteiler im CC loest KEINEN Alarm aus", not anzeigeSichtbar())

ruecksetzen()
Welt.auren.party1 = { { spellId = 777, duration = 4, expirationTime = 1004, icon = 1, name = "Unbekannt" } }
handler(addon, "UNIT_AURA", "party1")
pruefe("unbekannter Zauber loest KEINEN Alarm aus", not anzeigeSichtbar())
pruefe("unbekannter Zauber landet als Kandidat", CCAlarmDB.candidates[777] == "Unbekannt")

ruecksetzen()
Welt.auren.party1 = { { spellId = 4321, duration = 0.4, expirationTime = 1000.4, icon = 1, name = "Kurz" } }
handler(addon, "UNIT_AURA", "party1")
pruefe("zu kurze Aura loest KEINEN Alarm aus", not anzeigeSichtbar())

ruecksetzen()
Welt.tot.party1 = true
Welt.auren.party1 = { { spellId = 4321, duration = 4, expirationTime = 1004, icon = 1, name = "Betaeubung" } }
handler(addon, "UNIT_AURA", "party1")
pruefe("toter Heiler loest KEINEN Alarm aus", not anzeigeSichtbar())
Welt.tot.party1 = nil

echtesPrint("\n=== 4. Zonen ===\n")
ruecksetzen()
Welt.instanz = "raid"
Welt.auren.party1 = { { spellId = 4321, duration = 4, expirationTime = 1004, icon = 1, name = "Betaeubung" } }
handler(addon, "UNIT_AURA", "party1")
pruefe("im Schlachtzug still (so eingestellt)", not anzeigeSichtbar())
Welt.instanz = "party"

echtesPrint("\n=== 5. Kein Dauerfeuer ===\n")
ruecksetzen()
Welt.auren.party1 = { { spellId = 4321, duration = 4, expirationTime = 1004, icon = 1,
                        name = "Betaeubung", auraInstanceID = 42 } }
for _ = 1, 5 do handler(addon, "UNIT_AURA", "party1") end
pruefe("fuenf Aktualisierungen -> genau ein Ton", Toene == 1)

echtesPrint("\n=== 6. Befehle ===\n")
SlashCmdList.CCALARM("dazu 555")
pruefe("/ccalarm dazu nimmt auf", CCAlarmDB.known[555] == "MANUAL")
SlashCmdList.CCALARM("weg 555")
pruefe("/ccalarm weg entfernt", CCAlarmDB.known[555] == nil)
SlashCmdList.CCALARM("aus")
ruecksetzen()
Welt.auren.party1 = { { spellId = 4321, duration = 4, expirationTime = 1004, icon = 1, name = "B" } }
handler(addon, "UNIT_AURA", "party1")
pruefe("abgeschaltet bleibt es still", not anzeigeSichtbar())
SlashCmdList.CCALARM("an")

echtesPrint("\n=== 7. Englische Befehle und Sprachrueckfall ===\n")
SlashCmdList.CCALARM("add 556")
pruefe("/ccalarm add nimmt auf", CCAlarmDB.known[556] == "MANUAL")
SlashCmdList.CCALARM("remove 556")
pruefe("/ccalarm remove entfernt", CCAlarmDB.known[556] == nil)
SlashCmdList.CCALARM("ADD 557")
pruefe("Grossschreibung stoert nicht", CCAlarmDB.known[557] == "MANUAL")
SlashCmdList.CCALARM("remove 557")
pruefe("uebersetzter Text vorhanden", ns.L["MSG_ADDED"] ~= "MSG_ADDED")
pruefe("fehlender Schluessel faellt auf sich selbst zurueck",
       ns.L["GIBT_ES_NICHT"] == "GIBT_ES_NICHT")

echtesPrint(("\n%d bestanden, %d gescheitert\n\n"):format(bestanden, gescheitert))
os.exit(gescheitert == 0 and 0 or 1)
