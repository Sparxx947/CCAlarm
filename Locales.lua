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
end
