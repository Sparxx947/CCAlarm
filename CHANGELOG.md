# Changelog

## 1.1.0 — 2026-09-04

Einstellungen im Spiel, und das Addon steht jetzt vollständig für sich.

- **Optionsfenster** unter *Optionen → AddOns → CCAlarm* (oder `/ccalarm config`):
  Schriftart, -größe, -farbe und Umriss, Symbolgröße und -anzahl, Alarmton mit
  Anhörknopf, überwachte Rollen und Zonen.
- **Rahmen verschiebbar**: *Lösen und ziehen*, danach wieder festsetzen. Die
  Verankerung wird vollständig gespeichert, die Anzeige sitzt also auch nach
  einem Wechsel von Auflösung oder Skalierung wieder richtig.
  Auch über `/ccalarm unlock` / `lock` / `reset`.
- **Alarmton wählbar** statt fest — mit `/ccalarm config` anhörbar.
- ★ **Keine Fremdabhängigkeit mehr.** LibSharedMedia, CallbackHandler und
  LibStub sind eingebettet; das Addon funktioniert allein. Sind andere Addons
  vorhanden, die dort Schriften und Töne anmelden, erscheinen sie zusätzlich.
- Neue Prüfungen: Eigenständigkeit (`check_selfcontained.py`) und
  Übersetzungen gegen den Code (`check_locales.py`), beide in der CI.
  Prüfstand von 15 auf **39 Prüfungen**.

*Options panel under Options → AddOns → CCAlarm (or `/ccalarm config`): font
face, size, colour and outline, icon size and count, a selectable alarm sound
with a preview button, watched roles and zones. The display frame can be
unlocked and dragged, and its full anchor is stored so it returns to the same
place after a resolution or scale change. The addon no longer depends on
anything else: LibSharedMedia, CallbackHandler and LibStub are embedded, and
media registered by other addons appear as a bonus. Two new checks —
self-containment and locale completeness — run in CI; the test harness grew from
15 to 39 assertions.*

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
