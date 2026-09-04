# Changelog

## 0.1.0 — 2026-09-04

Erste Fassung. Noch nichts davon war je veröffentlicht.

**Was es tut:** Warnt groß und laut, wenn **Heiler oder Tank** in Kontrollverlust
geraten — roter Warntext oben mittig, darunter die Symbole der wirkenden Effekte
mit ablaufender Restzeit, dazu ein Ton. Getrennte Töne für Heiler und Tank, damit
man ohne hinzusehen hört, wen es getroffen hat.

**Wie es CC erkennt:** Nicht über eine fest verdrahtete Liste, sondern gelernt.
`LOSS_OF_CONTROL_ADDED` feuert für den Spieler und nennt Blizzards eigene
Einstufung samt Zauber-ID; was einen selbst trifft, trifft in denselben Dungeons
auch Heiler und Tank. Noch unbekannte Auren auf diesen Rollen werden als
Kandidaten vermerkt und lassen sich übernehmen.

**Einstellbar im Spiel** unter *Optionen → AddOns → CCAlarm* bzw.
`/ccalarm config`: Schriftart, -größe, -farbe und Umriss, Symbolgröße und
-anzahl, Alarmton je Rolle mit Anhörknopf, überwachte Rollen und Zonen, sowie
die Position (Rahmen lösen und ziehen).

**Eigenständig:** `LibStub`, `CallbackHandler-1.0` und `LibSharedMedia-3.0`
liegen bei — es wird kein anderes Addon vorausgesetzt.

**Geprüft:** Prüfstand mit 75 Prüfungen, der ohne WoW läuft und beide Richtungen
abdeckt — dass alarmiert wird *und* dass es still bleibt. Dazu vier Gatter in der
CI: `.toc` gegen den Dateibestand samt Symbolformat, Eigenständigkeit,
Übersetzungen und personenbezogene Spuren.

*First version; nothing before this was ever released. Warns loudly when the
healer or tank is crowd-controlled, with separate sounds per role, learning the
relevant spell IDs from Blizzard's own loss-of-control data rather than a
hardcoded list. Fully configurable in game, ships its own libraries, and comes
with a 75-assertion offline test harness plus four CI gates.*
