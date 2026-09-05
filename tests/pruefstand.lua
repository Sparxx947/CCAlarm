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
    kampf   = false,       -- InCombatLockdown
    keineContainer = false, -- Client ohne AuraContainer: CreateFrame wirft
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
-- Engine-seitige Toene (12.1): AddAuraSound nimmt Ton und Zauber-ID je Einheit
-- entgegen und spielt selbst. Hier wird nur Buch gefuehrt, wer angemeldet ist.
local Tonanmeldungen = {}   -- handle -> { unitToken, spellID, soundFileName }
local naechsterTon = 0
Enum = { UnitAuraSoundTrigger = { Added = 0, ApplicationsIncreased = 1, Removed = 2 } }
AuraContainerSortMethod = { AuraInstanceIDOnly = 1, Default = 0 }
InCombatLockdown = function() return Welt.kampf end
C_AddOns = {
    IsAddOnLoaded = function() return true end,
    LoadAddOn = function() return true end,
}
C_UnitAuras = {
    AddAuraSound = function(trigger, info)
        -- Wie im Spiel: waehrend des Kampfes in instanziiertem PvE verweigert.
        -- Die Sperre liegt bewusst HIER und nicht nur im Addon, sonst wuerde
        -- der Pruefstand eine Regel pruefen, die er selbst aufstellt.
        if Welt.kampf and (Welt.instanz == "party" or Welt.instanz == "raid"
                           or Welt.instanz == "scenario") then
            error("blocked action: AddAuraSound", 2)
        end
        naechsterTon = naechsterTon + 1
        Tonanmeldungen[naechsterTon] = {
            unitToken = info.unitToken, spellID = info.spellID,
            soundFileName = info.soundFileName, trigger = trigger,
        }
        return naechsterTon
    end,
    RemoveAuraSound = function(handle) Tonanmeldungen[handle] = nil end,
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
-- Alle erzeugten Auren-Container, in Erzeugungsreihenfolge.
local Container = {}

-- Der Container der 12.1-Engine: das Addon meldet Gruppen samt Filter an, setzt
-- eine Einheit und sieht die Auren NIE. Nachgestellt wird genau das -- was
-- gerendert wuerde, entscheidet hier niemand, denn das entscheidet im Spiel die
-- Engine. Geprueft werden kann nur, WAS ANGEMELDET wurde und AN WEM es haengt.
local function neuerContainer()
    local c = neuerRahmen()
    c.art = "AuraContainer"
    c.gruppen = {}
    c.unit = nil
    c.aktualisierungen = 0
    c.AddAuraGroup = function(self, key, filter, opts)
        self.gruppen[key] = { filter = filter, opts = opts,
                              budget = opts and opts.maxFrameCount or 0 }
        -- Der Erzeuger wird sofort ausgefuehrt, so wie die Engine ihn beim
        -- Anlegen der Schaltflaechen ausfuehrt: ein Fehler darin faellt hier
        -- auf und nicht erst im Schluesselstein.
        if opts and opts.initializeFrame then
            local knopf = neuerRahmen()
            knopf.SetIcon = function(self2, tex) self2.symbol = tex end
            knopf.SetDurationCooldown = function(self2, cd) self2.cd = cd end
            knopf.SetFlattensRenderLayers = nix
            knopf.texte = {}
            knopf.CreateFontString = function(self2)
                local fs = neuerRahmen()
                self2.texte[#self2.texte + 1] = fs
                return fs
            end
            opts.initializeFrame(knopf)
            self.gruppen[key].knopf = knopf
        end
    end
    c.SetAuraGroupMaxFrameCount = function(self, key, n)
        if self.gruppen[key] then self.gruppen[key].budget = n end
    end
    c.SetUnit = function(self, unit) self.unit = unit end
    c.GetUnit = function(self) return self.unit end
    c.UpdateAllAuras = function(self) self.aktualisierungen = self.aktualisierungen + 1 end
    Container[#Container + 1] = c
    return c
end

CreateFrame = function(art, name, parent, template)
    if art == "AuraContainer" then
        if Welt.keineContainer then error("unknown frame type 'AuraContainer'", 2) end
        return neuerContainer()
    end
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
local ladeContainer = assert(loadfile(pfad .. "Containers.lua"))
local ladeConfig = assert(loadfile(pfad .. "Config.lua"))
local ladeSeed = assert(loadfile(pfad .. "Data/CCSpells.lua"))
ladeLocales("CCAlarm", ns)
ladeSeed("CCAlarm", ns)
lade("CCAlarm", ns)
ladeContainer("CCAlarm", ns)
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

-- Container, die gerade an eine Einheit gebunden sind. "none" ist die
-- Null-Bindung der Engine und zaehlt als nicht gebunden.
local function gebundeneContainer(unit)
    local treffer = {}
    for _, c in ipairs(Container) do
        if c.unit and c.unit ~= "none" and (unit == nil or c.unit == unit) then
            treffer[#treffer + 1] = c
        end
    end
    return treffer
end

-- Der Text, den ein Beschriftungs-Container traegt: seine Gruppe hat genau eine
-- Schaltflaeche, und die traegt eine Fontstring. So sieht man, WAS im Ernstfall
-- auf dem Schirm stuende, ohne dass eine Aura gelesen wurde.
local function beschriftungen(unit)
    local out = {}
    for _, c in ipairs(gebundeneContainer(unit)) do
        local g = c.gruppen["cc"]
        local knopf = g and g.knopf
        for _, fs in ipairs((knopf and knopf.texte) or {}) do
            if fs.inhalt then out[#out + 1] = fs.inhalt end
        end
    end
    return out
end

local function tonAnmeldungenFuer(unit)
    local n = 0
    for _, eintrag in pairs(Tonanmeldungen) do
        if unit == nil or eintrag.unitToken == unit then n = n + 1 end
    end
    return n
end

echtesPrint("\n=== 1. Lernen aus Blizzards eigener Einstufung ===\n")
Welt.loc = { { spellID = 4321, locType = "STUN" } }
handler(addon, "LOSS_OF_CONTROL_ADDED")
pruefe("Betaeubung wird gelernt", CCAlarmDB.known[4321] == "STUN")

Welt.loc = { { spellID = 9999, locType = "SCHOOL_INTERRUPT" } }
handler(addon, "LOSS_OF_CONTROL_ADDED")
pruefe("Zauberschulsperre wird NICHT gelernt", CCAlarmDB.known[9999] == nil)

echtesPrint("\n=== 2. Ueberwachung von Heiler und Tank (Auren-Container) ===\n")
-- Seit 0.3.0 liest das Addon fuer den Alarm KEINE Auren mehr: es meldet der
-- Engine einen Filter an und die zeigt und toent selbst. Pruefbar ist damit
-- nicht mehr "steht etwas auf dem Schirm" -- das entscheidet die Engine --,
-- sondern WAS ANGEMELDET wurde und AN WEM es haengt. Genau das ist der
-- Unterschied zwischen "warnt in Mythic+" und "war dort immer still".
ruecksetzen()
handler(addon, "GROUP_ROSTER_UPDATE")
local heilerContainer = gebundeneContainer("party1")
local tankContainer   = gebundeneContainer("party2")
pruefe("Heiler wird ueberwacht", #heilerContainer >= 1)
pruefe("Tank wird ueberwacht", #tankContainer >= 1)
pruefe("Schadensausteiler wird NICHT ueberwacht", #gebundeneContainer("party3") == 0)

local ccGruppe = heilerContainer[1] and heilerContainer[1].gruppen["cc"]
pruefe("angemeldet ist Blizzards CC-Filter",
       ccGruppe ~= nil and ccGruppe.filter == "HARMFUL|CROWD_CONTROL")
pruefe("das Symbolbudget ist die Einstellung des Spielers",
       ccGruppe ~= nil and ccGruppe.budget == CCAlarmDB.maxIcons)

local heilerTexte = beschriftungen("party1")
local tankTexte   = beschriftungen("party2")
pruefe("beim Heiler steht der Heiler-Text bereit",
       heilerTexte[1] == ns.L["CC_LABEL_HEALER"])
pruefe("beim Tank steht der Tank-Text bereit",
       tankTexte[1] == ns.L["CC_LABEL_TANK"])

pruefe("fuer den Heiler sind Toene beim Spiel angemeldet", tonAnmeldungenFuer("party1") > 0)
pruefe("fuer den Tank ebenso", tonAnmeldungenFuer("party2") > 0)
pruefe("fuer den Schadensausteiler nicht", tonAnmeldungenFuer("party3") == 0)
-- Je bekanntem Zauber eine Anmeldung: die Engine kennt keinen Sammelfilter
-- fuer Toene, sie will die Zauber-ID.
local bekannte = 0
for id in pairs(CCAlarmDB.known) do if ns.IsKnown(id) then bekannte = bekannte + 1 end end
for id in pairs(ns.SEED_SPELLS or {}) do if ns.IsKnown(id) then bekannte = bekannte + 1 end end
pruefe("je bekanntem Zauber genau eine Anmeldung",
       tonAnmeldungenFuer("party1") == bekannte)

echtesPrint("\n=== 3. Gegenproben: wann NICHTS angemeldet wird ===\n")
ruecksetzen()
CCAlarmDB.roles.TANK = false
handler(addon, "GROUP_ROSTER_UPDATE")
pruefe("abgewaehlte Rolle wird nicht mehr ueberwacht", #gebundeneContainer("party2") == 0)
pruefe("und ihre Toene sind abgemeldet", tonAnmeldungenFuer("party2") == 0)
pruefe("die gewaehlte Rolle bleibt", #gebundeneContainer("party1") >= 1)
CCAlarmDB.roles.TANK = true
handler(addon, "GROUP_ROSTER_UPDATE")

ruecksetzen()
CCAlarmDB.sound = false
handler(addon, "GROUP_ROSTER_UPDATE")
pruefe("ohne Ton keine Anmeldung beim Spiel", tonAnmeldungenFuer() == 0)
pruefe("die Anzeige bleibt trotzdem", #gebundeneContainer("party1") >= 1)
CCAlarmDB.sound = true
handler(addon, "GROUP_ROSTER_UPDATE")

ruecksetzen()
Welt.auren.party1 = { { spellId = 777, duration = 4, expirationTime = 1004, icon = 1, name = "Unbekannt" } }
handler(addon, "UNIT_AURA", "party1")
pruefe("unbekannter Zauber landet als Kandidat", CCAlarmDB.candidates[777] == "Unbekannt")
pruefe("und wird NICHT als Ton angemeldet",
       (function()
            for _, e in pairs(Tonanmeldungen) do if e.spellID == 777 then return false end end
            return true
        end)())

ruecksetzen()
Welt.auren.party1 = { { spellId = 778, duration = 0.4, expirationTime = 1000.4, icon = 1, name = "Kurz" } }
handler(addon, "UNIT_AURA", "party1")
pruefe("zu kurze Aura wird kein Kandidat", CCAlarmDB.candidates[778] == nil)

echtesPrint("\n=== 4. Zonen ===\n")
ruecksetzen()
Welt.instanz = "raid"
handler(addon, "PLAYER_ENTERING_WORLD")
pruefe("im Schlachtzug wird nichts ueberwacht (so eingestellt)",
       #gebundeneContainer() == 0)
pruefe("und nichts angemeldet", tonAnmeldungenFuer() == 0)
Welt.instanz = "party"
handler(addon, "PLAYER_ENTERING_WORLD")
pruefe("im Schluesselstein wieder ueberwacht", #gebundeneContainer("party1") >= 1)

echtesPrint("\n=== 5. Wiederholte Laeufe melden nicht doppelt an ===\n")
ruecksetzen()
handler(addon, "GROUP_ROSTER_UPDATE")
local nachEinem = tonAnmeldungenFuer("party1")
for _ = 1, 5 do handler(addon, "GROUP_ROSTER_UPDATE") end
pruefe("fuenf Laeufe -> gleich viele Anmeldungen",
       tonAnmeldungenFuer("party1") == nachEinem)
local containerZahl = #Container
handler(addon, "GROUP_ROSTER_UPDATE")
pruefe("und kein neuer Container je Lauf", #Container == containerZahl)

echtesPrint("\n=== 5b. Der Kampf verweigert Ton-Anmeldungen ===\n")
-- Im Spiel weist die Engine AddAuraSound im Kampf innerhalb einer Instanz ab.
-- Wer das nicht abfaengt, verliert die Toene fuer den ganzen Lauf -- und merkt
-- es nicht, weil ein ausbleibender Alarm wie Ruhe aussieht.
ruecksetzen()
ns.Containers.ClearSounds()
Welt.kampf = true
handler(addon, "GROUP_ROSTER_UPDATE")
pruefe("im Kampf wird nichts angemeldet", tonAnmeldungenFuer() == 0)
pruefe("aber der Nachholbedarf ist vermerkt", ns.Containers.ConsumeSkipped() == true)
-- ConsumeSkipped hat den Vermerk geleert; der naechste Lauf setzt ihn neu.
handler(addon, "GROUP_ROSTER_UPDATE")
Welt.kampf = false
handler(addon, "PLAYER_REGEN_ENABLED")
pruefe("nach dem Kampf sind die Toene da", tonAnmeldungenFuer("party1") > 0)
pruefe("und der Nachholbedarf ist abgearbeitet", ns.Containers.ConsumeSkipped() == false)

echtesPrint("\n=== 6. Befehle ===\n")
SlashCmdList.CCALARM("dazu 555")
pruefe("/ccalarm dazu nimmt auf", CCAlarmDB.known[555] == "MANUAL")
SlashCmdList.CCALARM("weg 555")
pruefe("/ccalarm weg entfernt", CCAlarmDB.known[555] == nil)
SlashCmdList.CCALARM("aus")
ruecksetzen()
pruefe("abgeschaltet wird nichts mehr ueberwacht", #gebundeneContainer() == 0)
pruefe("abgeschaltet ist auch kein Ton mehr angemeldet", tonAnmeldungenFuer() == 0)
SlashCmdList.CCALARM("an")
pruefe("wieder eingeschaltet ist die Ueberwachung zurueck",
       #gebundeneContainer("party1") >= 1)

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

-- Der Rahmen selbst bleibt seit 0.3.0 IMMER sichtbar: er ist der Elternrahmen
-- der Auren-Container, und ein versteckter Elternrahmen nimmt sie mit. Sichtbar
-- ist an ihm nur, was ihn sichtbar MACHT -- der Griff beim Loesen und die
-- Beschriftung.
ns.SetUnlocked(true)
pruefe("geloest: Griff sichtbar", rahmen["CCAlarmDisplay"].grip.sichtbar == true)
pruefe("geloest: nicht mehr gesperrt", CCAlarmDB.locked == false)
ns.SetUnlocked(false)
pruefe("festgesetzt: Griff wieder weg", rahmen["CCAlarmDisplay"].grip.sichtbar == false)
pruefe("der Rahmen selbst bleibt (sonst waeren die Container blind)",
       anzeigeSichtbar())

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

PlaySound = altesPlaySound

-- Der Weg bis zur Engine: was tatsaechlich beim Spiel angemeldet wird, ist
-- eine DATEI je Rolle. Ein SOUNDKIT-Eintrag ist eine Tonpaket-Nummer und keine
-- Datei -- den nimmt AddAuraSound nicht an, und deshalb liegen zwei eigene
-- .ogg-Dateien bei. Ohne diesen Weg waere die Einstellung "eigener Ton je
-- Rolle" im Schluesselstein wirkungslos.
ruecksetzen()
CCAlarmDB.sounds = { HEALER = "CCAlarm Healer", TANK = "CCAlarm Tank" }
ns.Containers.ClearSounds()
handler(addon, "GROUP_ROSTER_UPDATE")
local function tonDateiFuer(unit)
    for _, e in pairs(Tonanmeldungen) do
        if e.unitToken == unit then return e.soundFileName end
    end
end
pruefe("beim Heiler ist die Heiler-Datei angemeldet",
       (tonDateiFuer("party1") or ""):match("alarm%-healer%.ogg") ~= nil)
pruefe("beim Tank die Tank-Datei",
       (tonDateiFuer("party2") or ""):match("alarm%-tank%.ogg") ~= nil)
pruefe("die beiden sind wirklich verschieden",
       tonDateiFuer("party1") ~= tonDateiFuer("party2"))

-- Ein SOUNDKIT-Ton laesst sich nicht uebergeben; dann muss der mitgelieferte
-- einspringen, statt dass gar nichts angemeldet wird.
CCAlarmDB.sounds = { HEALER = "Raid Warning", TANK = "Ready Check" }
pruefe("SOUNDKIT-Ton gilt als nicht engine-tauglich",
       ns.SoundIsEngineCapable("HEALER") == false)
pruefe("mitgelieferter Ton gilt als engine-tauglich",
       (function()
            CCAlarmDB.sounds.HEALER = "CCAlarm Healer"
            local ok2 = ns.SoundIsEngineCapable("HEALER")
            CCAlarmDB.sounds.HEALER = "Raid Warning"
            return ok2
        end)() == true)
ns.Containers.ClearSounds()
handler(addon, "GROUP_ROSTER_UPDATE")
pruefe("trotzdem wird eine Datei angemeldet (der Ersatz)",
       (tonDateiFuer("party1") or ""):match("%.ogg") ~= nil)
CCAlarmDB.sounds = { HEALER = "CCAlarm Healer", TANK = "CCAlarm Tank" }

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

-- Er muss auch wirklich beim Spiel als Ton angemeldet sein
ns.Containers.ClearSounds()
handler(addon, "GROUP_ROSTER_UPDATE")
local function tonFuerZauber(id)
    for _, e in pairs(Tonanmeldungen) do
        if e.spellID == id and e.unitToken == "party1" then return true end
    end
    return false
end
pruefe("Zauber aus der Saatliste ist beim Spiel angemeldet", tonFuerZauber(saatId))

-- Und er darf nicht als Kandidat auftauchen
pruefe("bekannter Saatzauber wird kein Kandidat", CCAlarmDB.candidates[saatId] == nil)

-- Entfernen muss dauerhaft sein
SlashCmdList.CCALARM("remove " .. saatId)
pruefe("entfernter Saatzauber gilt nicht mehr als bekannt", ns.IsKnown(saatId) == nil)
pruefe("das Entfernen ist vermerkt (ueberlebt einen Neustart)",
       CCAlarmDB.rejected[saatId] == true)
ns.SetUnlocked(false)
ruecksetzen()
-- Und das Entfernen muss bis zur Engine durchschlagen: bleibt die Anmeldung
-- stehen, spielt das Spiel den Ton weiter, obwohl das Addon den Zauber laengst
-- nicht mehr kennt -- ein Alarm, den niemand mehr abstellen kann.
ns.Containers.ClearSounds()
handler(addon, "GROUP_ROSTER_UPDATE")
pruefe("entfernter Saatzauber ist beim Spiel abgemeldet", not tonFuerZauber(saatId))

-- Wieder aufnehmen hebt das auf
SlashCmdList.CCALARM("add " .. saatId)
pruefe("Wiederaufnehmen hebt das Entfernen auf", ns.IsKnown(saatId) ~= nil)
CCAlarmDB.rejected = {}
CCAlarmDB.known[saatId] = nil

echtesPrint("\n=== 15. Geheime Auren in Mythic+ und PvP ===\n")
-- Bis 0.2.3 war das der Abschnitt "hier geht gar nichts": GetAuraDataByIndex
-- wirft, sobald Blizzard die Auren geheim haelt (14004 Vorfaelle an einem
-- Abend), und der Alarm blieb im Schluesselstein aus.
--
-- Seit 0.3.0 haengt der Alarm nicht mehr am Lesen. Geprueft wird deshalb das
-- Gegenteil von frueher: dass unter voller Sperre WEITER ueberwacht und
-- angemeldet wird. Wer hier "kein Alarm" erwartet, prueft den alten Fehler ab.
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

-- (a) volle Sperre: der Alarm steht trotzdem
Welt.zeit = 2000
ruecksetzen()
C_Secrets = { ShouldAurasBeSecret = function() return Welt.geheim end }
Welt.geheim, Welt.wirftAlle = true, true
ns.Containers.ClearSounds()
auraAufHeiler(1501)
local ok = pcall(handler, addon, "GROUP_ROSTER_UPDATE")
pruefe("gesperrte Auren werfen keinen Lua-Fehler mehr", ok)
pruefe("gesperrt: der Heiler wird weiter ueberwacht", #gebundeneContainer("party1") >= 1)
pruefe("gesperrt: der Tank ebenso", #gebundeneContainer("party2") >= 1)
pruefe("gesperrt: die Toene sind beim Spiel angemeldet", tonAnmeldungenFuer("party1") > 0)
pruefe("gesperrt: der Warntext steht bereit",
       beschriftungen("party1")[1] == ns.L["CC_LABEL_HEALER"])

-- (b) was die Sperre wirklich kostet: dazulernen geht hier nicht
local okSammeln = pcall(handler, addon, "UNIT_AURA", "party1")
pruefe("gesperrt: das Sammeln wirft keinen Fehler", okSammeln)
pruefe("gesperrt: es wird nichts gesammelt", next(CCAlarmDB.candidates) == nil)
pruefe("gesperrt: es wird auch nicht behauptet, der Alarm sei tot", meldungen() == 0)

-- (c) Sperre greift zwischen Tor und Aufruf: die Sonde auf "player" ist frei,
--     der Zugriff auf party1 wirft trotzdem.
Welt.zeit = 2005
ruecksetzen()
Welt.geheim, Welt.wirftAlle = false, false
Welt.wirft = { party1 = true }
auraAufHeiler(1504)
local okMitten = pcall(handler, addon, "UNIT_AURA", "party1")
pruefe("Sperre mitten im Durchlauf wirft keinen Fehler", okMitten)
pruefe("Sperre mitten im Durchlauf sammelt nichts Halbes",
       CCAlarmDB.candidates[4321] == nil)

-- (d) aeltere Fassung ohne C_Secrets: allein die pcall-Sonde muss tragen
Welt.zeit = 2004
ruecksetzen()
C_Secrets = nil
Welt.wirft, Welt.wirftAlle = {}, true
auraAufHeiler(1503)
local okSonde = pcall(handler, addon, "UNIT_AURA", "party1")
pruefe("ohne C_Secrets faengt die pcall-Sonde die Sperre ab", okSonde)
pruefe("ohne C_Secrets wird ebenfalls nichts gesammelt",
       next(CCAlarmDB.candidates) == nil)

-- (e) Gegenprobe: ohne Sperre muss das Sammeln wieder laufen. Sonst pruefte
--     dieser Abschnitt nur, dass das Tor immer zu ist.
Welt.zeit = 2006
Welt.wirft, Welt.wirftAlle, Welt.geheim = {}, false, false
C_Secrets = { ShouldAurasBeSecret = function() return Welt.geheim end }
ruecksetzen()
Welt.auren.party1 = { { spellId = 4322, duration = 4, expirationTime = 2010,
                        icon = 1, name = "Neu", auraInstanceID = 1505 } }
local okFrei = pcall(handler, addon, "UNIT_AURA", "party1")
pruefe("ohne Sperre laeuft das Sammeln weiter", okFrei)
pruefe("ohne Sperre landet der unbekannte Zauber als Kandidat",
       CCAlarmDB.candidates[4322] == "Neu")

-- (f) /ccalarm status darf nicht an der Sperre scheitern und muss sie nennen
Welt.zeit = 2007
ruecksetzen()
Welt.geheim, Welt.wirftAlle = true, true
local okStatus = pcall(SlashCmdList.CCALARM, "status")
pruefe("/ccalarm status laeuft auch gesperrt", okStatus)
pruefe("/ccalarm status nennt, was die Sperre kostet", meldungen() >= 1)

Welt.geheim, Welt.wirftAlle, Welt.wirft = false, false, {}
CCAlarmDB.known[4321] = nil

echtesPrint("\n=== 15a. Umstellung alter Toneinstellungen ===\n")
-- Alte Konfigurationen tragen SOUNDKIT-Namen. Die nimmt die Engine nicht an --
-- wer sie behaelt, hoert im Schluesselstein den Ersatzton statt seiner Wahl.
-- Umgestellt wird deshalb, aber NUR was noch auf der alten Vorgabe stand: eine
-- bewusst getroffene Wahl gehoert dem Spieler.
local alteDB = {
    sounds = { HEALER = "Raid Warning", TANK = "Ready Check" },
    soundName = "Raid Warning",
}
local gemerkt = CCAlarmDB
CCAlarmDB = alteDB
handler(addon, "ADDON_LOADED", "CCAlarm")
pruefe("alte Vorgabe des Heilers wird auf die Datei umgestellt",
       CCAlarmDB.sounds.HEALER == "CCAlarm Healer")
pruefe("alte Vorgabe des Tanks ebenso", CCAlarmDB.sounds.TANK == "CCAlarm Tank")
pruefe("die Umstellung ist vermerkt", CCAlarmDB.soundsMigrated == true)

local eigeneWahl = { sounds = { HEALER = "Boss Whisper", TANK = "Map Ping" } }
CCAlarmDB = eigeneWahl
handler(addon, "ADDON_LOADED", "CCAlarm")
pruefe("eine eigene Wahl bleibt unangetastet",
       CCAlarmDB.sounds.HEALER == "Boss Whisper" and CCAlarmDB.sounds.TANK == "Map Ping")

-- Und ein zweiter Start stellt nicht erneut um: wer nach der Umstellung
-- bewusst zurueckwechselt, will das behalten.
CCAlarmDB.sounds.HEALER = "Raid Warning"
handler(addon, "ADDON_LOADED", "CCAlarm")
pruefe("ein zweiter Start stellt nicht noch einmal um",
       CCAlarmDB.sounds.HEALER == "Raid Warning")
CCAlarmDB = gemerkt
handler(addon, "ADDON_LOADED", "CCAlarm")

echtesPrint("\n=== 15b. Nachtraeglich eingeschaltete Teile werden nachgebaut ===\n")
-- Wer den Warntext ausgeschaltet startet und ihn spaeter einschaltet, hat noch
-- keinen Beschriftungs-Container. Wird der nur beim Eintreffen einer NEUEN
-- Einheit gebaut, bleibt die Einstellung tot, bis sich die Gruppe aendert.
ruecksetzen()
CCAlarmDB.warningText = false
ns.Containers.Rebuild()
handler(addon, "GROUP_ROSTER_UPDATE")
pruefe("ohne Warntext traegt kein Container einen Text",
       #beschriftungen("party1") == 0)
CCAlarmDB.warningText = true
handler(addon, "GROUP_ROSTER_UPDATE")
pruefe("eingeschaltet wird der Text nachgebaut",
       beschriftungen("party1")[1] == ns.L["CC_LABEL_HEALER"])

echtesPrint("\n=== 16. Aussehen wird eingebacken, nicht nachtraeglich gesetzt ===\n")
-- Container-Schaltflaechen koennen nach ihrer Erzeugung nicht mehr umgestylt
-- werden -- unter geheimen Auren weist die Engine jeden Setter ab. Eine
-- geaenderte Optik muss deshalb neu bauen. Und NUR dann: ein Neubau je Klick
-- im Optionsfenster wuerde bei jedem Mal einen Satz Engine-Rahmen liegen
-- lassen, die nie wieder frei werden.
ruecksetzen()
ns.Containers.Rebuild()
handler(addon, "GROUP_ROSTER_UPDATE")
local vorher = #Container
ns.ApplyDisplay()
pruefe("unveraenderte Einstellung baut NICHTS neu", #Container == vorher)
CCAlarmDB.iconSize = 61
ns.ApplyDisplay()
pruefe("geaenderte Symbolgroesse baut neu", #Container > vorher)
local knopfGroesse
for _, c in ipairs(Container) do
    local g = c.gruppen and c.gruppen["cc"]
    if g and g.knopf and g.knopf.breite == 61 then knopfGroesse = g.knopf.breite end
end
pruefe("die neue Groesse steckt in den neuen Schaltflaechen", knopfGroesse == 61)
CCAlarmDB.iconSize = 50
ns.ApplyDisplay()

echtesPrint("\n=== 17. Client ohne Auren-Container ===\n")
-- Ein Client vor 12.1 kennt den Rahmentyp nicht: CreateFrame wirft. Das darf
-- das Addon nicht mitreissen, und es muss EINMAL gesagt werden -- sonst sucht
-- der Spieler den Fehler bei sich.
--
-- ACHTUNG Reihenfolge: dieser Abschnitt steht ZULETZT. Ein einmal
-- gescheiterter Container schaltet den Weg fuer die ganze Sitzung ab (im Spiel
-- richtig -- der Client wechselt nicht mitten im Betrieb), und jeder Abschnitt
-- danach haette nur noch leere Container gesehen.
ruecksetzen()
ns.Containers.ClearSounds()
Welt.keineContainer = true
ns.Containers.Rebuild()
local okOhne = pcall(handler, addon, "GROUP_ROSTER_UPDATE")
pruefe("fehlender Rahmentyp reisst nichts mit", okOhne)
local gesagt = 0
for _, zeile in ipairs(Ausgabe) do
    if zeile:find("12.1", 1, true) then gesagt = gesagt + 1 end
end
pruefe("es wird gesagt, dass hier nichts angezeigt werden kann", gesagt == 1)
for _ = 1, 3 do pcall(handler, addon, "GROUP_ROSTER_UPDATE") end
gesagt = 0
for _, zeile in ipairs(Ausgabe) do
    if zeile:find("12.1", 1, true) then gesagt = gesagt + 1 end
end
pruefe("und zwar genau einmal, nicht bei jedem Lauf", gesagt == 1)
Welt.keineContainer = false

echtesPrint(("\n%d bestanden, %d gescheitert\n\n"):format(bestanden, gescheitert))
os.exit(gescheitert == 0 and 0 or 1)
