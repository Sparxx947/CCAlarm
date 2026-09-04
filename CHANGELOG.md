# Changelog

## 0.2.0 — 2026-09-04

**Das Addon bringt jetzt eine Liste bekannter CC-Zauber mit** — es fängt also
nicht mehr bei null an.

Keine einzige ID ist geraten. `tools/fetch_cc_spells.py` verbindet zwei Quellen:

1. **Warcraft Logs** liefert, welche Debuffs in den acht Dungeons der laufenden
   Saison *tatsächlich* von Gegnern auf Spieler gewirkt werden — aus 25 Reports
   waren das 273 verschiedene.
2. **Wowhead** liefert je Zauber die Mechanik (`<th>Mechanic</th>`), also die
   Einstufung, die weder die Spiel-API noch die Logs hergeben.

Übrig bleiben **13 echte Kontrollverlust-Zauber**, mit Name, Mechanik und
Trefferzahl im Quelltext dokumentiert.

★ Die Liste wird **nicht** in die gespeicherten Daten kopiert, sondern
nachgeschlagen. Dadurch wirkt eine neue Liste sofort, und ein selbst entfernter
Zauber (`/ccalarm remove`) bleibt entfernt, statt beim nächsten Start
zurückzukommen.

- Gelerntes hat weiter Vorrang; die Saatliste ist nur der Startpunkt.
- **81 → 90 Prüfungen.**

*The addon now ships a list of known crowd-control spells, so it no longer starts
empty. No ID is guessed: Warcraft Logs supplies which debuffs enemies actually
apply to players across the current season's eight dungeons (273 distinct ones
from 25 reports), and Wowhead supplies each spell's mechanic — the classification
neither the game API nor the logs provide. Thirteen genuine crowd-control spells
remain, documented with name, mechanic and hit count. The list is looked up
rather than copied into saved data, so a new list takes effect immediately and a
spell removed by the player stays removed. 81 → 90 assertions.*

## 0.1.1 — 2026-09-04

**Behoben: `/ccalarm test` scheiterte immer.**

`ns.Test` stand im Quelltext **vor** `local function show` und griff damit auf
eine globale Variable gleichen Namens zu — also auf `nil`. Im Spiel schlug das
27-mal fehl (`attempt to call a nil value`), ohne dass Laden oder Syntaxprüfung
etwas gemerkt hätten.

- Der Prüfstand rief `ns.Test` **nie auf** — jetzt tut er es, ebenso
  `/ccalarm test` und jeden Knopf des Optionsfensters. 75 → 81 Prüfungen.
- Neues Gatter `check_scope.py`: meldet jeden Aufruf eines `local`, der erst
  weiter unten deklariert wird. Am echten Fehler nachgewiesen.

*Fixes `/ccalarm test`, which always failed: `ns.Test` sat above
`local function show` and therefore resolved the name against the global
environment, i.e. `nil` — 27 failures in game, invisible to loading and syntax
checks alike. The harness had never called `ns.Test`; it now does, along with the
slash command and every options-panel button (75 → 81 assertions), and a new
`check_scope.py` gate reports any call to a `local` declared further down.*

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
