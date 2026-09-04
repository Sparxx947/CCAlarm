-- Locales.lua -- user-facing strings.
--
-- English is the default; other locales override individual keys. A missing
-- key falls back to English rather than showing a raw key, so an incomplete
-- translation degrades gracefully instead of breaking the display.

local ADDON, ns = ...

local L = setmetatable({}, {
    __index = function(_, key) return key end,
})
ns.L = L

-- enUS / default -------------------------------------------------------------
L["CC_ALERT_HEALER"]   = "HEALER"
L["CC_ALERT_TANK"]     = "TANK"
L["CC_ALERT_FORMAT"]   = "%s CC'D: %s"
L["CC_ALERT_MORE"]     = " (+%d)"

L["MSG_LEARNED"]       = "learned: %s (%d, %s)"
L["MSG_ON"]            = "is now on"
L["MSG_OFF"]           = "is now off"
L["MSG_HELP"]          = "commands: status | on | off | test | list | candidates | add <id> | remove <id> | clear"
L["MSG_STATUS"]        = "%s | roles: %s%s | known spells: %d | candidates: %d | active here: %s"
L["MSG_YES"]           = "yes"
L["MSG_NO"]            = "no"
L["MSG_TEST"]          = "test alert for 5 seconds -- this is what a real one looks like."
L["MSG_SEEDED"]          = "from the shipped list"
L["MSG_NOTHING_LEARNED"] = "nothing learned yet -- that happens by itself while playing."
L["MSG_NO_CANDIDATES"] = "no open candidates."
L["MSG_CANDIDATE_HINT"] = "  %d  %s   -- take it with /ccalarm add %d"
L["MSG_ADDED"]         = "%d added."
L["MSG_REMOVED"]       = "%d removed."
L["MSG_CLEARED"]       = "candidate list cleared."
L["MSG_NEED_ID"]       = "usage: /ccalarm %s <spellID>"
L["MSG_UNKNOWN"]       = "unknown: %s -- try /ccalarm help"
L["ROLE_HEALER_SHORT"] = "healer "
L["ROLE_TANK_SHORT"]   = "tank"

-- Options panel -------------------------------------------------------------
L["OPT_TITLE"]         = "CCAlarm"
L["OPT_GENERAL"]       = "General"
L["OPT_ENABLED"]       = "Enable CCAlarm"
L["OPT_ROLES"]         = "Watch these roles"
L["OPT_ROLE_HEALER"]   = "Healer"
L["OPT_ROLE_TANK"]     = "Tank"
L["OPT_ZONES"]         = "Active in"
L["OPT_ZONE_DUNGEON"]  = "Dungeons"
L["OPT_ZONE_ARENA"]    = "Arenas"
L["OPT_ZONE_RAID"]     = "Raids"
L["OPT_ZONE_BG"]       = "Battlegrounds"
L["OPT_ZONE_WORLD"]    = "Open world"

L["OPT_TEXT"]          = "Warning text"
L["OPT_SHOW_TEXT"]     = "Show warning text"
L["OPT_FONT"]          = "Font"
L["OPT_FONT_SIZE"]     = "Font size"
L["OPT_FONT_OUTLINE"]  = "Outline"
L["OPT_FONT_COLOR"]    = "Text colour"
L["OPT_OUTLINE_NONE"]  = "None"
L["OPT_OUTLINE_THIN"]  = "Thin"
L["OPT_OUTLINE_THICK"] = "Thick"

L["OPT_ICONS"]         = "Icons"
L["OPT_SHOW_ICONS"]    = "Show icons"
L["OPT_ICON_SIZE"]     = "Icon size"
L["OPT_MAX_ICONS"]     = "Maximum icons"

L["OPT_SOUND"]         = "Sound"
L["OPT_PLAY_SOUND"]    = "Play a sound"
L["OPT_SOUND_HEALER"]  = "Sound when the healer is hit"
L["OPT_SOUND_TANK"]    = "Sound when the tank is hit"
L["OPT_SOUND_TEST"]    = "Play"

L["OPT_POSITION"]      = "Position"
L["OPT_UNLOCK"]        = "Unlock and drag"
L["OPT_LOCK"]          = "Lock"
L["OPT_RESET_POS"]     = "Reset position"
L["OPT_UNLOCKED_HINT"] = "Drag the frame where you want it, then lock it again."
L["OPT_TEST"]          = "Test alert"
L["OPT_NO_LSM"]        = "LibSharedMedia was not found -- showing the built-in fonts and sounds only."

L["MSG_UNLOCKED"]      = "unlocked -- drag the frame, then /ccalarm lock"
L["MSG_LOCKED"]        = "locked."
L["MSG_POS_RESET"]     = "position reset."

-- deDE -----------------------------------------------------------------------
if GetLocale() == "deDE" then
    L["CC_ALERT_HEALER"]   = "HEILER"
    L["CC_ALERT_TANK"]     = "TANK"
    L["CC_ALERT_FORMAT"]   = "%s IN CC: %s"

    L["MSG_LEARNED"]       = "gelernt: %s (%d, %s)"
    L["MSG_ON"]            = "ist jetzt an"
    L["MSG_OFF"]           = "ist jetzt aus"
    L["MSG_HELP"]          = "Befehle: status | an | aus | test | liste | kandidaten | dazu <id> | weg <id> | leeren"
    L["MSG_STATUS"]        = "%s | Rollen: %s%s | bekannte Zauber: %d | Kandidaten: %d | hier aktiv: %s"
    L["MSG_YES"]           = "ja"
    L["MSG_NO"]            = "nein"
    L["MSG_TEST"]          = "Probealarm fuer 5 Sekunden -- so sieht es im Ernstfall aus."
    L["MSG_SEEDED"]          = "aus der mitgelieferten Liste"
    L["MSG_NOTHING_LEARNED"] = "noch nichts gelernt -- das kommt beim Spielen von selbst."
    L["MSG_NO_CANDIDATES"] = "keine offenen Kandidaten."
    L["MSG_CANDIDATE_HINT"] = "  %d  %s   -- uebernehmen mit /ccalarm dazu %d"
    L["MSG_ADDED"]         = "%d aufgenommen."
    L["MSG_REMOVED"]       = "%d entfernt."
    L["MSG_CLEARED"]       = "Kandidatenliste geleert."
    L["MSG_NEED_ID"]       = "Aufruf: /ccalarm %s <Zauber-ID>"
    L["MSG_UNKNOWN"]       = "unbekannt: %s -- /ccalarm hilfe"
    L["ROLE_HEALER_SHORT"] = "Heiler "
    L["ROLE_TANK_SHORT"]   = "Tank"

    -- Optionsfenster ---------------------------------------------------------
    L["OPT_GENERAL"]       = "Allgemein"
    L["OPT_ENABLED"]       = "CCAlarm aktivieren"
    L["OPT_ROLES"]         = "Diese Rollen ueberwachen"
    L["OPT_ROLE_HEALER"]   = "Heiler"
    L["OPT_ROLE_TANK"]     = "Tank"
    L["OPT_ZONES"]         = "Aktiv in"
    L["OPT_ZONE_DUNGEON"]  = "Dungeons"
    L["OPT_ZONE_ARENA"]    = "Arenen"
    L["OPT_ZONE_RAID"]     = "Schlachtzuegen"
    L["OPT_ZONE_BG"]       = "Schlachtfeldern"
    L["OPT_ZONE_WORLD"]    = "offener Welt"

    L["OPT_TEXT"]          = "Warntext"
    L["OPT_SHOW_TEXT"]     = "Warntext anzeigen"
    L["OPT_FONT"]          = "Schriftart"
    L["OPT_FONT_SIZE"]     = "Schriftgroesse"
    L["OPT_FONT_OUTLINE"]  = "Umriss"
    L["OPT_FONT_COLOR"]    = "Textfarbe"
    L["OPT_OUTLINE_NONE"]  = "kein"
    L["OPT_OUTLINE_THIN"]  = "duenn"
    L["OPT_OUTLINE_THICK"] = "dick"

    L["OPT_ICONS"]         = "Symbole"
    L["OPT_SHOW_ICONS"]    = "Symbole anzeigen"
    L["OPT_ICON_SIZE"]     = "Symbolgroesse"
    L["OPT_MAX_ICONS"]     = "Symbole hoechstens"

    L["OPT_SOUND"]         = "Ton"
    L["OPT_PLAY_SOUND"]    = "Ton abspielen"
    L["OPT_SOUND_HEALER"]  = "Ton, wenn es den Heiler trifft"
    L["OPT_SOUND_TANK"]    = "Ton, wenn es den Tank trifft"
    L["OPT_SOUND_TEST"]    = "Anhoeren"

    L["OPT_POSITION"]      = "Position"
    L["OPT_UNLOCK"]        = "Loesen und ziehen"
    L["OPT_LOCK"]          = "Festsetzen"
    L["OPT_RESET_POS"]     = "Position zuruecksetzen"
    L["OPT_UNLOCKED_HINT"] = "Rahmen an die gewuenschte Stelle ziehen, dann wieder festsetzen."
    L["OPT_TEST"]          = "Probealarm"
    L["OPT_NO_LSM"]        = "LibSharedMedia nicht gefunden -- es stehen nur die eingebauten Schriften und Toene zur Wahl."

    L["MSG_UNLOCKED"]      = "geloest -- Rahmen ziehen, danach /ccalarm lock"
    L["MSG_LOCKED"]        = "festgesetzt."
    L["MSG_POS_RESET"]     = "Position zurueckgesetzt."
end
