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
PlaySoundFile = function() Toene = Toene + 1 end
UIParent = { GetName = function() return "UIParent" end }
LibStub = function() return nil end   -- LibSharedMedia bewusst nicht vorhanden
SOUNDKIT = { RAID_WARNING = 1, READY_CHECK = 2, UI_RAID_BOSS_WHISPER_WARNING = 3,
             UI_MAP_WAYPOINT_CHAT_SHARE = 4 }
C_Timer = { After = function() end }
C_Spell = { GetSpellName = function(id) return "Zauber" .. id end }
C_UnitAuras = {
    GetAuraDataByIndex = function(unit, i) return (Welt.auren[unit] or {})[i] end,
}
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
ladeLocales("CCAlarm", ns)
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

pruefe("Schriftliste kommt aus der Bibliothek",
       ns.FontList()[1] == "Meine Schrift")
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

CCAlarmDB.fontName = "Friz Quadrata TT"
CCAlarmDB.fontOutline = "OUTLINE"
ns.ApplyDisplay()

echtesPrint(("\n%d bestanden, %d gescheitert\n\n"):format(bestanden, gescheitert))
os.exit(gescheitert == 0 and 0 or 1)
