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
    zeit    = 1000,        -- GetTime; steuerbar, weil der Sperr-Cache je Frame haelt
    geheim  = false,       -- was C_Secrets.ShouldAurasBeSecret antwortet
    wirft   = {},          -- unit -> true: der Aura-Aufruf wirft (wie im Spiel)
    wirftAlle = false,
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
GetTime = function() return Welt.zeit end
UnitName = function(u) return u end
UnitIsDeadOrGhost = function(u) return Welt.tot[u] or false end
UnitExists = function(u) return Welt.rollen[u] ~= nil end
UnitGroupRolesAssigned = function(u) return Welt.rollen[u] or "NONE" end
IsInInstance = function() return Welt.instanz ~= nil, Welt.instanz end
IsInRaid = function() return Welt.instanz == "raid" end
GetNumGroupMembers = function() local n=0 for _ in pairs(Welt.rollen) do n=n+1 end return n end
PlaySound = function() Toene = Toene + 1 end
PlaySoundFile = function() Toene = Toene + 1 end
UIParent = { GetName = function() return "UIParent" end }
LibStub = function() return nil end   -- LibSharedMedia bewusst nicht vorhanden
SOUNDKIT = { RAID_WARNING = 1, READY_CHECK = 2, UI_RAID_BOSS_WHISPER_WARNING = 3,
             UI_MAP_WAYPOINT_CHAT_SHARE = 4 }
C_Timer = { After = function() end }
C_Spell = { GetSpellName = function(id) return "Zauber" .. id end }
-- Im Spiel gibt GetAuraDataByIndex bei geheimen Auren nicht nil zurueck --
-- es WIRFT. Genau das stellt Welt.wirft nach; ein Rueckgabewert nil haette den
-- Fehler vom 04.09. (14004 Vorfaelle) nie reproduziert.
C_UnitAuras = {
    GetAuraDataByIndex = function(unit, i)
        if Welt.wirftAlle or Welt.wirft[unit] then
            error("GetAuraDataByIndex(): Auras cannot be accessed when secret "
                  .. "while tainted by 'CCAlarm'", 2)
        end
        return (Welt.auren[unit] or {})[i]
    end,
}
-- Bewusst NICHT von Anfang an gesetzt: Abschnitt 15 prueft auch die Fassung
-- ohne C_Secrets, in der nur die pcall-Sonde traegt.
C_Secrets = nil
C_LossOfControl = {
    GetActiveLossOfControlDataCount = function() return #Welt.loc end,
    GetActiveLossOfControlData = function(i) return Welt.loc[i] end,
}

local function nix() end

local function neuerRahmen()
    local f = {}
    f.SetSize = function(self, b, h) self.breite, self.hoehe = b, h end
    f.ClearAllPoints, f.SetFrameStrata = nix, nix
    f.RegisterEvent, f.UnregisterEvent = nix, nix
    f.SetFont = function(self, pfad, groesse, umriss)
        self.schrift = { pfad = pfad, groesse = groesse, umriss = umriss }
    end
    f.SetTextColor = function(self, r, g, b) self.farbe = { r = r, g = g, b = b } end
    f.SetText = function(self, t) self.inhalt = t end
    f.SetAllPoints, f.SetTexCoord, f.SetTexture = nix, nix, nix
    f.SetReverse, f.SetDrawEdge, f.SetCooldown, f.Clear = nix, nix, nix, nix
    f.SetMovable, f.SetClampedToScreen, f.RegisterForDrag = nix, nix, nix
    f.StartMoving, f.StopMovingOrSizing, f.EnableMouse = nix, nix, nix
    f.SetColorTexture = nix
    f.SetPoint = function(self, punkt, _, relativ, x, y)
        self.punkt, self.relativ, self.x, self.y = punkt, relativ, x, y
    end
    f.GetPoint = function(self)
        return self.punkt or "CENTER", UIParent, self.relativ or "TOP", self.x or 0, self.y or 0
    end
    f.skripte = {}
    f.SetScript = function(self, name, fn) self.skripte[name] = fn end
    f.GetScript = function(self, name) return self.skripte[name] end
    -- Rueckfall NUR fuer Methodennamen: Set*/Register*/Enable*/Clear*/Show*/Hide*
    -- sind bei WoW-Rahmen immer Funktionen. Datenfelder bleiben bewusst nil,
    -- damit ein fehlendes Feld auffaellt statt still zu einer Funktion zu werden.
    setmetatable(f, { __index = function(_, k)
        if type(k) == "string" and k:match("^Set") or k:match("^Register")
           or k:match("^Enable") or k:match("^Clear") or k:match("^Unregister") then
            return nix
        end
        return nil
    end })
    f.sichtbar = false
    f.Show = function(self) self.sichtbar = true end
    f.Hide = function(self) self.sichtbar = false end
    f.CreateFontString = function() return neuerRahmen() end
    f.CreateTexture = function() return neuerRahmen() end
    return f
end
local rahmen = {}
local dropdowns, knoepfe = {}, {}
CreateFrame = function(art, name)
    local f = neuerRahmen()
    f.art = art
    if art == "CheckButton" then
        f.text = neuerRahmen()
        f.SetChecked = function(self, v) self.gesetzt = v and true or false end
        f.GetChecked = function(self) return self.gesetzt end
    elseif art == "Slider" then
        f.SetMinMaxValues, f.SetValueStep, f.SetObeyStepOnDrag = nix, nix, nix
        f.SetWidth = nix
        f.GetName = function() return name end
        f.SetValue = function(self, v)
            self.wert = v
            local fn = self.skripte and self.skripte.OnValueChanged
            if fn then fn(self, v) end
        end
        -- OptionsSliderTemplate erzeugt $parentLow/High/Text als Globale
        if name then
            for _, teil in ipairs({ "Low", "High", "Text" }) do
                _G[name .. teil] = neuerRahmen()
            end
        end
    elseif art == "DropdownButton" then
        f.SetWidth = nix
        f.SetupMenu = function(self, gen) self.generator = gen end
        f.GenerateMenu = nix
        f.SetDefaultText = function(self, t) self.beschriftung = t end
        dropdowns[#dropdowns + 1] = f
    elseif art == "Button" then
        f.SetWidth = nix
        knoepfe[#knoepfe + 1] = f
    end
    if name then rahmen[name] = f end
    return f
end
_G = _G or {}
ColorPickerFrame = { GetColorRGB = function() return 1, 1, 1 end }
Settings = nil            -- kein Optionssystem: der Rueckfall muss tragen
InterfaceOptions_AddCategory = function() end
SLASH_CCALARM1, SlashCmdList = nil, {}

-- kleine Nachstellung von rootDescription: sammelt die Auswahlpunkte ein
local function menueAuslesen(dropdown)
    local eintraege = {}
    dropdown.generator(dropdown, {
        CreateRadio = function(_, text, istGewaehlt, setzen)
            eintraege[#eintraege + 1] = { text = text, gewaehlt = istGewaehlt, setzen = setzen }
        end,
    })
    return eintraege
end

-------------------------------------------------------------------------------
-- Addon laden
-------------------------------------------------------------------------------
local pfad = (arg and arg[0] or ""):match("^(.*)tests/") or "./"
local ns = {}
local ladeLocales = assert(loadfile(pfad .. "Locales.lua"))
local lade = assert(loadfile(pfad .. "CCAlarm.lua"))
local ladeConfig = assert(loadfile(pfad .. "Config.lua"))
local ladeSeed = assert(loadfile(pfad .. "Data/CCSpells.lua"))
ladeLocales("CCAlarm", ns)
ladeSeed("CCAlarm", ns)
lade("CCAlarm", ns)
ladeConfig("CCAlarm", ns)
local addon = rahmen["CCAlarmFrame"]

-- Der Ereignishandler wird ueber GetScript abgegriffen; dafuer schreibt die
-- Rahmen-Nachstellung jedes SetScript mit. Frueher wurde das Addon dafuer ein
-- zweites Mal geladen -- mit einer zweiten CreateFrame-Fassung, die spaeter
-- ergaenzte Rahmenarten nicht kannte und den Aufbau des Optionsfensters
-- scheitern liess.
local handler = addon:GetScript("OnEvent")
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

echtesPrint("\n=== 8. Schrift, Farbe, Position, Ton ===\n")
ruecksetzen()
pruefe("Schriftpfad faellt ohne LibSharedMedia auf die eingebaute zurueck",
       ns.FontPath() == "Fonts\\FRIZQT__.TTF")
CCAlarmDB.fontName = "Morpheus"
pruefe("bekannte eingebaute Schrift wird aufgeloest",
       ns.FontPath() == "Fonts\\MORPHEUS.TTF")
CCAlarmDB.fontName = "Gibt Es Nicht"
pruefe("unbekannte Schrift faellt zurueck statt nil zu liefern",
       ns.FontPath() == CCAlarmDB.fontPath)
CCAlarmDB.fontName = "Friz Quadrata TT"

local schriften = ns.FontList()
pruefe("Schriftliste ist nicht leer", #schriften >= 4)
local toene = ns.SoundList()
pruefe("Tonliste ist nicht leer", #toene >= 4)

Toene = 0
ns.PlayAlarm()
pruefe("PlayAlarm spielt etwas", Toene == 1)
CCAlarmDB.soundKit = "GIBT_ES_NICHT"
Toene = 0
ns.PlayAlarm()
pruefe("unbekannter Ton faellt auf RAID_WARNING zurueck", Toene == 1)
CCAlarmDB.soundKit = "RAID_WARNING"

-- Position: verschieben und zuruecksetzen
local anzeige = rahmen["CCAlarmDisplay"]
CCAlarmDB.point, CCAlarmDB.relativePoint = "TOPLEFT", "TOPLEFT"
CCAlarmDB.offsetX, CCAlarmDB.offsetY = 111, -222
ns.ApplyDisplay()
pruefe("Position wird angewendet", anzeige.punkt == "TOPLEFT" and anzeige.y == -222)
ns.ResetPosition()
pruefe("Zuruecksetzen stellt die Voreinstellung her",
       CCAlarmDB.point == "CENTER" and CCAlarmDB.offsetY == -220)

-- Ziehen speichert die neue Verankerung
CCAlarmDB.locked = false
anzeige.punkt, anzeige.relativ, anzeige.x, anzeige.y = "BOTTOM", "BOTTOM", 7, 9
anzeige:GetScript("OnDragStop")(anzeige)
pruefe("Ziehen speichert die Verankerung",
       CCAlarmDB.point == "BOTTOM" and CCAlarmDB.offsetX == 7 and CCAlarmDB.offsetY == 9)
ns.ResetPosition()
CCAlarmDB.locked = true

-- Loesen zeigt den Rahmen, Festsetzen versteckt ihn wieder
ns.SetUnlocked(true)
pruefe("geloest: Rahmen sichtbar", anzeigeSichtbar())
pruefe("geloest: nicht mehr gesperrt", CCAlarmDB.locked == false)
ns.SetUnlocked(false)
pruefe("festgesetzt: Rahmen wieder versteckt", not anzeigeSichtbar())

-- Ein laufender Alarm darf durch Festsetzen nicht verschwinden
ruecksetzen()
Welt.auren.party1 = { { spellId = 4321, duration = 4, expirationTime = 1004, icon = 1, name = "B" } }
handler(addon, "UNIT_AURA", "party1")
ns.SetUnlocked(false)
pruefe("laufender Alarm ueberlebt das Festsetzen", anzeigeSichtbar())

echtesPrint("\n=== 9. Mit vorhandener LibSharedMedia ===\n")
-- Die Bibliothek ist eingebettet, im Spiel also immer da. Hier wird sie
-- nachgestellt, damit auch dieser Weg geprueft ist und nicht nur der Rueckfall.
local LSM = {
    schriften = { ["Meine Schrift"] = "Interface\\Meine.ttf" },
    toene     = { ["Mein Ton"] = "Interface\\Mein.ogg" },
}
function LSM:List(art)
    local aus = {}
    for name in pairs(art == "font" and self.schriften or self.toene) do aus[#aus+1] = name end
    table.sort(aus)
    return aus
end
function LSM:Fetch(art, name)
    return (art == "font" and self.schriften or self.toene)[name]
end
LibStub = function(name) return name == "LibSharedMedia-3.0" and LSM or nil end

local function enthaelt(liste, gesucht)
    for _, x in ipairs(liste) do if x == gesucht then return true end end
    return false
end
pruefe("Schrift der Bibliothek steht in der Liste",
       enthaelt(ns.FontList(), "Meine Schrift"))
pruefe("eingebaute Schriften stehen WEITERHIN in der Liste",
       enthaelt(ns.FontList(), "Morpheus"))
pruefe("Ton der Bibliothek steht in der Liste",
       enthaelt(ns.SoundList(), "Mein Ton"))
-- Der eigentliche Fallstrick: LibSharedMedia meldet von sich aus nur "None" an.
-- Ohne Zusammenfuehren waere die Tonliste auf einer Einzelinstallation leer.
pruefe("eingebaute Toene stehen WEITERHIN in der Liste",
       enthaelt(ns.SoundList(), "Raid Warning"))
CCAlarmDB.fontName = "Meine Schrift"
pruefe("Schrift der Bibliothek wird aufgeloest",
       ns.FontPath() == "Interface\\Meine.ttf")
CCAlarmDB.fontName = "Gibt Es Nicht"
pruefe("unbekannte Schrift faellt trotz Bibliothek zurueck",
       ns.FontPath() == CCAlarmDB.fontPath)
CCAlarmDB.fontName = "Friz Quadrata TT"

CCAlarmDB.soundName = "Mein Ton"
Toene = 0
ns.PlayAlarm()
pruefe("Ton der Bibliothek wird abgespielt", Toene == 1)
CCAlarmDB.soundName = "Gibt Es Nicht"
Toene = 0
ns.PlayAlarm()
pruefe("unbekannter Ton faellt auf SOUNDKIT zurueck", Toene == 1)
LibStub = function() return nil end

echtesPrint("\n=== 10. Kommt die Einstellung an der Anzeige an? ===\n")
-- Bis hierher war nur geprueft, dass die Schrift richtig AUFGELOEST wird.
-- Eine Einstellung, die nichts bewirkt, ist gefaehrlicher als eine falsche --
-- also wird jetzt bis zum FontString durchverfolgt.
ruecksetzen()
local textFeld = rahmen["CCAlarmDisplay"].text
CCAlarmDB.fontName = "Morpheus"
CCAlarmDB.textSize = 44
CCAlarmDB.fontOutline = "THICKOUTLINE"
CCAlarmDB.fontColor = { r = 0.2, g = 0.4, b = 0.6 }
ns.ApplyDisplay()
pruefe("Schriftart erreicht die Anzeige", textFeld.schrift.pfad == "Fonts\\MORPHEUS.TTF")
pruefe("Schriftgroesse erreicht die Anzeige", textFeld.schrift.groesse == 44)
pruefe("Umriss erreicht die Anzeige", textFeld.schrift.umriss == "THICKOUTLINE")
pruefe("Farbe erreicht die Anzeige",
       textFeld.farbe.r == 0.2 and textFeld.farbe.g == 0.4 and textFeld.farbe.b == 0.6)

CCAlarmDB.fontOutline = "NONE"
ns.ApplyDisplay()
pruefe("Umriss 'kein' wird zu nil, nicht zur Zeichenkette 'NONE'",
       textFeld.schrift.umriss == nil)

CCAlarmDB.iconSize = 72
ns.ApplyDisplay()
pruefe("Symbolgroesse erreicht die Symbole",
       rahmen["CCAlarmDisplay"].icons[1].breite == 72)

-- Gegenprobe: schlaegt die Pruefung an, wenn die Einstellung NICHT ankaeme?
local vorher = textFeld.schrift.pfad
CCAlarmDB.fontName = "Skurri"
pruefe("ohne ApplyDisplay bleibt die Anzeige unveraendert (Pruefung ist wach)",
       textFeld.schrift.pfad == vorher)
ns.ApplyDisplay()
pruefe("nach ApplyDisplay ist sie geaendert",
       textFeld.schrift.pfad == "Fonts\\skurri.ttf")
CCAlarmDB.fontName = "Friz Quadrata TT"
CCAlarmDB.fontOutline = "OUTLINE"
CCAlarmDB.textSize = 32
CCAlarmDB.iconSize = 50

echtesPrint("\n=== 11. Optionsfenster: kommt der Klick bei der Einstellung an? ===\n")
ruecksetzen()
pruefe("Optionsfenster wurde angelegt", rahmen["CCAlarmOptionsPanel"] ~= nil)
local fenster = rahmen["CCAlarmOptionsPanel"]
fenster:GetScript("OnShow")()          -- baut das Fenster auf
pruefe("Bedienelemente wurden erzeugt", #dropdowns >= 3 and #knoepfe >= 4)

-- Das erste Auswahlfeld ist die Schriftart.
local schriftMenue = dropdowns[1]
local eintraege = menueAuslesen(schriftMenue)
pruefe("Schriftmenue bietet Eintraege an", #eintraege >= 4)

local morpheus
for _, e in ipairs(eintraege) do if e.text == "Morpheus" then morpheus = e end end
pruefe("Morpheus steht zur Wahl", morpheus ~= nil)

if morpheus then
    local textFeld = rahmen["CCAlarmDisplay"].text
    pruefe("Morpheus ist vorher NICHT gewaehlt", morpheus.gewaehlt() == false)
    morpheus.setzen()
    pruefe("Klick setzt die Einstellung", CCAlarmDB.fontName == "Morpheus")
    pruefe("Klick wirkt bis zur Anzeige durch",
           textFeld.schrift.pfad == "Fonts\\MORPHEUS.TTF")
    pruefe("danach ist Morpheus gewaehlt", morpheus.gewaehlt() == true)
end

-- Der Umriss ist ein eigenes Auswahlfeld mit uebersetzten Beschriftungen.
local umrissMenue = dropdowns[2]
local umrisse = menueAuslesen(umrissMenue)
local dick
for _, e in ipairs(umrisse) do if e.text == ns.L["OPT_OUTLINE_THICK"] then dick = e end end
pruefe("Umriss 'dick' steht zur Wahl", dick ~= nil)
if dick then
    dick.setzen()
    pruefe("uebersetzte Beschriftung wird auf den Schluessel zurueckgebildet",
           CCAlarmDB.fontOutline == "THICKOUTLINE")
end

-- Auswahlfeld 3 und 4 sind die Toene fuer Heiler und Tank.
pruefe("es gibt vier Auswahlfelder (Schrift, Umriss, zwei Toene)", #dropdowns >= 4)
if #dropdowns >= 4 then
    local heilerMenue = menueAuslesen(dropdowns[3])
    local tankMenue   = menueAuslesen(dropdowns[4])
    local function finde(liste, text)
        for _, e in ipairs(liste) do if e.text == text then return e end end
    end
    local e1, e2 = finde(heilerMenue, "Boss Whisper"), finde(tankMenue, "Map Ping")
    pruefe("Heiler-Tonmenue bietet die eingebauten Toene an", e1 ~= nil)
    pruefe("Tank-Tonmenue ebenso", e2 ~= nil)
    if e1 and e2 then
        e1.setzen(); e2.setzen()
        pruefe("Klick setzt den Heiler-Ton", CCAlarmDB.sounds.HEALER == "Boss Whisper")
        pruefe("Klick setzt den Tank-Ton getrennt davon", CCAlarmDB.sounds.TANK == "Map Ping")
        pruefe("die beiden Felder haben sich nicht gegenseitig ueberschrieben",
               CCAlarmDB.sounds.HEALER ~= CCAlarmDB.sounds.TANK)
    end
end
CCAlarmDB.sounds = { HEALER = "Raid Warning", TANK = "Ready Check" }

CCAlarmDB.fontName = "Friz Quadrata TT"
CCAlarmDB.fontOutline = "OUTLINE"
ns.ApplyDisplay()

echtesPrint("\n=== 12. Ein eigener Ton je Rolle ===\n")
ruecksetzen()
CCAlarmDB.sounds = { HEALER = "Raid Warning", TANK = "Ready Check" }
pruefe("Heiler hat seinen eigenen Ton", ns.SoundForRole("HEALER") == "Raid Warning")
pruefe("Tank hat einen anderen", ns.SoundForRole("TANK") == "Ready Check")
pruefe("ohne Rolle greift der allgemeine Ton", ns.SoundForRole(nil) == CCAlarmDB.soundName)
CCAlarmDB.sounds.TANK = nil
pruefe("fehlender Rolleneintrag faellt auf den allgemeinen zurueck",
       ns.SoundForRole("TANK") == CCAlarmDB.soundName)
CCAlarmDB.sounds.TANK = "Ready Check"

-- Welcher SOUNDKIT-Eintrag tatsaechlich gespielt wird, wird mitgeschrieben.
local gespielt
local altesPlaySound = PlaySound
PlaySound = function(id) gespielt = id; Toene = Toene + 1 end
ns.PlayAlarm("HEALER")
pruefe("Heiler-Alarm spielt RAID_WARNING", gespielt == SOUNDKIT.RAID_WARNING)
ns.PlayAlarm("TANK")
pruefe("Tank-Alarm spielt READY_CHECK", gespielt == SOUNDKIT.READY_CHECK)
pruefe("die beiden Toene sind wirklich verschieden",
       SOUNDKIT.RAID_WARNING ~= SOUNDKIT.READY_CHECK)

-- Und der Weg aus dem Kampf heraus: der Treffer bestimmt die Rolle.
ruecksetzen()
gespielt = nil
Welt.auren.party2 = { { spellId = 4321, duration = 4, expirationTime = 1004, icon = 1,
                        name = "B", auraInstanceID = 77 } }
handler(addon, "UNIT_AURA", "party2")
pruefe("CC auf dem Tank spielt den Tank-Ton", gespielt == SOUNDKIT.READY_CHECK)
ruecksetzen()
gespielt = nil
Welt.auren.party1 = { { spellId = 4321, duration = 4, expirationTime = 1004, icon = 1,
                        name = "B", auraInstanceID = 78 } }
handler(addon, "UNIT_AURA", "party1")
pruefe("CC auf dem Heiler spielt den Heiler-Ton", gespielt == SOUNDKIT.RAID_WARNING)
PlaySound = altesPlaySound

echtesPrint("\n=== 13. Probealarm (der Fehler vom 04.09.) ===\n")
-- ns.Test war nie aufgerufen worden. Im Spiel scheiterte es 27-mal, weil
-- ns.Test vor der Deklaration von show stand und damit auf ein globales,
-- leeres show zugriff. Ein Aufruf haette es sofort gezeigt.
ruecksetzen()
CCAlarmDB.locked = true
local ok, fehler = pcall(ns.Test)
pruefe("ns.Test laeuft ohne Fehler", ok)
if not ok then echtesPrint("      " .. tostring(fehler) .. "\n") end
pruefe("Probealarm macht die Anzeige sichtbar", anzeigeSichtbar())
pruefe("Probealarm spielt einen Ton", Toene >= 1)

ruecksetzen()
Toene = 0
local ok2 = pcall(SlashCmdList.CCALARM, "test")
pruefe("/ccalarm test laeuft ohne Fehler", ok2)
pruefe("/ccalarm test macht die Anzeige sichtbar", anzeigeSichtbar())

-- Auch der Knopf im Optionsfenster fuehrt dorthin
ruecksetzen()
local getroffen = false
for _, k in ipairs(knoepfe) do
    local fn = k:GetScript("OnClick")
    if fn then local o = pcall(fn); getroffen = getroffen or o end
end
pruefe("kein Knopf im Optionsfenster wirft einen Fehler", getroffen)

echtesPrint("\n=== 14. Mitgelieferte Saatliste ===\n")
ruecksetzen()
pruefe("Saatliste ist geladen und nicht leer",
       ns.SEED_SPELLS ~= nil and next(ns.SEED_SPELLS) ~= nil)
local saatId = next(ns.SEED_SPELLS)
pruefe("ein Zauber aus der Saatliste gilt als bekannt", ns.IsKnown(saatId) ~= nil)
pruefe("er steht NICHT in db.known (Saatliste wird nicht kopiert)",
       CCAlarmDB.known[saatId] == nil)

-- Er muss auch wirklich alarmieren
Welt.auren.party1 = { { spellId = saatId, duration = 4, expirationTime = 1004,
                        icon = 1, name = "Saat", auraInstanceID = 900 } }
handler(addon, "UNIT_AURA", "party1")
pruefe("CC aus der Saatliste loest Alarm aus", anzeigeSichtbar())

-- Und er darf nicht als Kandidat auftauchen
pruefe("bekannter Saatzauber wird kein Kandidat", CCAlarmDB.candidates[saatId] == nil)

-- Entfernen muss dauerhaft sein
SlashCmdList.CCALARM("remove " .. saatId)
pruefe("entfernter Saatzauber gilt nicht mehr als bekannt", ns.IsKnown(saatId) == nil)
pruefe("das Entfernen ist vermerkt (ueberlebt einen Neustart)",
       CCAlarmDB.rejected[saatId] == true)
-- Abschnitt 11 klickt jeden Knopf, auch "Loesen" -- der Rahmen bleibt dann
-- sichtbar. Fuer diese Pruefung wieder festsetzen, sonst misst sie den
-- Nachlass des vorherigen Abschnitts statt das Verhalten hier.
ns.SetUnlocked(false)
ruecksetzen()
Welt.auren.party1 = { { spellId = saatId, duration = 4, expirationTime = 1004,
                        icon = 1, name = "Saat", auraInstanceID = 901 } }
handler(addon, "UNIT_AURA", "party1")
pruefe("entfernter Saatzauber loest KEINEN Alarm mehr aus", not anzeigeSichtbar())

-- Wieder aufnehmen hebt das auf
SlashCmdList.CCALARM("add " .. saatId)
pruefe("Wiederaufnehmen hebt das Entfernen auf", ns.IsKnown(saatId) ~= nil)
CCAlarmDB.rejected = {}
CCAlarmDB.known[saatId] = nil

echtesPrint("\n=== 15. Geheime Auren in Mythic+ und PvP (der Fehler vom 04.09.) ===\n")
-- 14004 Vorfaelle an einem Abend: GetAuraDataByIndex wirft, sobald Blizzard die
-- Auren geheim haelt. Geprueft wird deshalb BEIDES -- dass kein Fehler mehr
-- durchschlaegt, UND dass der Alarm ohne Sperre unveraendert kommt. Ein Tor,
-- das immer sperrt, waere ebenso kaputt wie gar keins.
local MELDUNG = ns.L["MSG_AURAS_SECRET"]
local function meldungen()
    local n = 0
    for _, zeile in ipairs(Ausgabe) do
        if zeile:find(MELDUNG, 1, true) then n = n + 1 end
    end
    return n
end
local function auraAufHeiler(instanz)
    Welt.auren.party1 = { { spellId = 4321, duration = 4,
                            expirationTime = Welt.zeit + 4, icon = 1, name = "B",
                            auraInstanceID = instanz } }
end

CCAlarmDB.known[4321] = "STUN"

-- (a) C_Secrets meldet die Sperre
Welt.zeit = 2000
ruecksetzen()
C_Secrets = { ShouldAurasBeSecret = function() return Welt.geheim end }
Welt.geheim, Welt.wirftAlle = true, true
auraAufHeiler(1501)
local ok = pcall(handler, addon, "UNIT_AURA", "party1")
pruefe("gesperrte Auren werfen keinen Lua-Fehler mehr", ok)
pruefe("gesperrt: kein Alarm", not anzeigeSichtbar())
pruefe("gesperrt: es wird gesagt, statt still zu schweigen", meldungen() == 1)

-- (b) und zwar genau einmal, nicht bei jedem UNIT_AURA
Welt.zeit = 2001
pcall(handler, addon, "UNIT_AURA", "party1")
Welt.zeit = 2002
pcall(handler, addon, "UNIT_AURA", "party1")
pruefe("die Meldung kommt nur einmal je Instanz", meldungen() == 1)

-- (c) in der naechsten Instanz aber wieder
Welt.zeit = 2003
ruecksetzen()
auraAufHeiler(1502)
pcall(handler, addon, "UNIT_AURA", "party1")
pruefe("nach dem Zonenwechsel wird erneut gewarnt", meldungen() == 1)

-- (d) aeltere Fassung ohne C_Secrets: allein die pcall-Sonde muss tragen
Welt.zeit = 2004
ruecksetzen()
C_Secrets = nil
auraAufHeiler(1503)
local okSonde = pcall(handler, addon, "UNIT_AURA", "party1")
pruefe("ohne C_Secrets faengt die pcall-Sonde die Sperre ab", okSonde)
pruefe("ohne C_Secrets: kein Alarm", not anzeigeSichtbar())

-- (e) Sperre greift zwischen Tor und Aufruf: die Sonde auf "player" ist frei,
--     der Zugriff auf party1 wirft trotzdem. Ohne das pcall am Aufruf selbst
--     stuende hier wieder ein Lua-Fehler.
Welt.zeit = 2005
ruecksetzen()
Welt.wirftAlle = false
Welt.wirft = { party1 = true }
auraAufHeiler(1504)
local okMitten = pcall(handler, addon, "UNIT_AURA", "party1")
pruefe("Sperre mitten im Durchlauf wirft keinen Fehler", okMitten)
pruefe("Sperre mitten im Durchlauf: kein halbgarer Alarm", not anzeigeSichtbar())

-- (f) Gegenprobe: ohne jede Sperre muss der Alarm unveraendert kommen.
--     Sonst pruefte Abschnitt 15 nur, dass das Tor immer zu ist.
-- ACHTUNG Reihenfolge: ruecksetzen() feuert PLAYER_ENTERING_WORLD und damit
-- einen Scan. Wer die Sperrschalter erst danach loest, misst noch den
-- vorherigen Fall -- genau daran ist diese Gegenprobe beim Schreiben einmal
-- gescheitert.
Welt.zeit = 2006
Welt.wirft, Welt.wirftAlle, Welt.geheim = {}, false, false
C_Secrets = { ShouldAurasBeSecret = function() return Welt.geheim end }
ruecksetzen()
auraAufHeiler(1505)
local okFrei = pcall(handler, addon, "UNIT_AURA", "party1")
pruefe("ohne Sperre laeuft der Scan weiter", okFrei)
pruefe("ohne Sperre kommt der Alarm wie zuvor", anzeigeSichtbar())
pruefe("ohne Sperre wird nichts gemeldet", meldungen() == 0)

-- (g) /ccalarm status darf nicht an der Sperre scheitern und muss sie nennen
Welt.zeit = 2007
ruecksetzen()
Welt.geheim, Welt.wirftAlle = true, true   -- nach dem Scan aus ruecksetzen()
local okStatus = pcall(SlashCmdList.CCALARM, "status")
pruefe("/ccalarm status laeuft auch gesperrt", okStatus)
pruefe("/ccalarm status nennt die Sperre", meldungen() >= 1)

Welt.geheim, Welt.wirftAlle, Welt.wirft = false, false, {}
CCAlarmDB.known[4321] = nil

echtesPrint(("\n%d bestanden, %d gescheitert\n\n"):format(bestanden, gescheitert))
os.exit(gescheitert == 0 and 0 or 1)
