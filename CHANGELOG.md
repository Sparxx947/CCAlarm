# Changelog

## 1.0.0 — 2026-09-04

Erste Fassung.

- Warnt, wenn **Heiler oder Tank** in Kontrollverlust geraten: roter Warntext
  oben mittig, bis zu fünf Symbole mit ablaufendem Cooldown, Ton.
- Lernt die CC-Zauber-IDs aus `LOSS_OF_CONTROL_ADDED`, also aus Blizzards
  eigener Einstufung — es sind keine IDs fest verdrahtet.
- Führt eine Kandidatenliste für noch unbekannte Auren auf Heiler und Tank.
- `SCHOOL_INTERRUPT` und `DISARM` werden bewusst nicht gelernt.
- Aktiv in Dungeon, Arena und offener Welt; im Schlachtzug und Schlachtfeld
  still. Alles über `/ccalarm` einstellbar.
- Prüfstand mit 15 Prüfungen, der ohne WoW läuft.

*First release. Warns when the healer or tank is crowd-controlled, learns the
relevant spell IDs from Blizzard's own loss-of-control classification instead of
hardcoding them, keeps a candidate list for auras it does not know yet, and ships
an offline test harness with 15 assertions.*
