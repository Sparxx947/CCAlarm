# CCAlarm

Ein WoW-Addon (Retail 12.1 / Midnight), das groß und laut warnt, wenn
**Heiler oder Tank** in Kontrollverlust geraten.

## Installieren

Den Ordner `CCAlarm` mit `CCAlarm.lua` und `CCAlarm.toc` nach
`Interface/AddOns/` kopieren, WoW **vollständig neu starten** (kein `/reload` —
neue Addons werden nur beim Start eingelesen), dann `/ccalarm test` aufrufen.

Es ist nichts vorzukonfigurieren: Das Addon lernt die nötigen Zauber im Spiel.

## Warum es das Addon gibt

MiniAuras wurde am 2026-09-04 entfernt (Überschneidung mit InterruptTrack bei
den Unterbrechungen). Damit fiel auch die CC-Meldung für Heiler weg, die es
sonst nirgends gibt: InterruptTrack kennt weder `LOSS_OF_CONTROL` noch
CC-Auren, [HealerCC](https://www.curseforge.com/wow/addons/healer-cc) deckt nur
Heiler ab, und [Portal Authority](https://www.curseforge.com/wow/addons/portal-authority)
ist seit April 2026 nicht mehr gepflegt.

## Wie es CC erkennt — ohne geratene Zauber-IDs

Drei Wege wurden geprüft und verworfen:

| Weg | Warum nicht |
|---|---|
| Kampfprotokoll | `COMBAT_LOG_EVENT_UNFILTERED` gibt es in Midnight nicht mehr |
| Aura-Klassifizierung | weder `C_UnitAuras` noch die Aurendaten tragen ein CC-Feld (alle 15 genutzten Funktionen geprüft) |
| `C_LossOfControl` für Mitspieler | liefert nur Daten über den Spieler selbst |

Übrig bleibt: eine Liste von Zauber-IDs. **Diese Liste wird nicht geraten,
sondern gelernt.** `LOSS_OF_CONTROL_ADDED` feuert für den Spieler selbst und
nennt Blizzards eigene Einstufung (`locType`) samt Zauber-ID. Was einen selbst
trifft, trifft in denselben Dungeons auch Heiler und Tank — die Liste füllt sich
also beim Spielen und gilt ab dann für die ganze Gruppe.

Damit die erste Begegnung nicht verloren geht, führt das Addon zusätzlich eine
**Kandidatenliste**: jede schädliche Aura auf Heiler oder Tank, die es noch
nicht kennt, wird mit Namen und ID vermerkt und lässt sich per Befehl
übernehmen.

`SCHOOL_INTERRUPT` und `DISARM` werden bewusst **nicht** gelernt — sie hindern
niemanden am Laufen oder Heilen und erzeugten nur Lärm.

## Befehle

| Befehl | Wirkung |
|---|---|
| `/ccalarm test` | Probealarm für 5 Sekunden — zeigt Sitz und Ton, ohne auf echten CC zu warten |
| `/ccalarm status` | an/aus, überwachte Rollen, Zahl der gelernten Zauber, gilt hier |
| `/ccalarm liste` | alle gelernten Zauber mit Einstufung |
| `/ccalarm kandidaten` | gesehene, noch unbekannte Auren auf Heiler/Tank |
| `/ccalarm dazu <id>` | Zauber-ID aufnehmen |
| `/ccalarm weg <id>` | Zauber-ID entfernen |
| `/ccalarm an` / `aus` | ein- und ausschalten |

## Anzeige

Übernimmt die Maße, die in MiniAuras eingestellt waren: roter Warntext
(Friz Quadrata 32, Umriss) oben mittig bei Y −220, darunter bis zu 5 Symbole
à 50 px mit ablaufendem Cooldown, dazu ein Ton. Aktiv in Dungeon, Arena und
offener Welt; im Schlachtzug und Schlachtfeld still.

## Prüfstand

```
luac5.1 -p CCAlarm.lua tests/pruefstand.lua   # Syntax
lua5.1 tests/pruefstand.lua                   # Verhalten
python3 tools/check_toc.py                    # .toc gegen den Dateibestand
```

Dieselben drei Schritte laufen als GitHub-Action bei jedem Push.
`check_toc.py` fängt zwei Fehler ab, die sonst erst im Spiel auffallen — eine
gelistete Datei fehlt (Addon lädt nicht) oder eine Lua-Datei liegt da, ohne
geladen zu werden (stiller Blindgänger) — und erinnert an die Interface-Version
beim nächsten Patch. Alle drei Alarmpfade sind an erfundenen Fehlern nachgewiesen.

Stellt die WoW-API nach und prüft **beide Richtungen** — 15 Prüfungen:
dass alarmiert wird (Heiler, Tank, Ton, genau einmal pro Aura) und dass **nicht**
alarmiert wird (Schadensausteiler, unbekannter Zauber, zu kurze Aura, toter
Heiler, Schlachtzug, abgeschaltet). Der erste Lauf fand einen echten Fehler:
ohne `auraInstanceID` blieb der Ton aus.

*CCAlarm warns loudly when the healer or tank is crowd-controlled — the
replacement for MiniAuras' `HealerCrowdControl`, extended to tanks. Detecting CC
on other players is not straightforward in Midnight: the combat log event is
gone, no aura API classifies crowd control, and `C_LossOfControl` only reports on
the player. The addon therefore works from a spell-ID list that it **learns**
rather than guesses: `LOSS_OF_CONTROL_ADDED` fires for the player with
Blizzard's own `locType` classification, and what hits you in a dungeon also hits
the healer and tank, so the list fills itself through play and then covers the
whole group. Auras seen on the healer or tank that are not yet known are
recorded as candidates to be promoted with a command. `SCHOOL_INTERRUPT` and
`DISARM` are deliberately never learned. Slash commands are listed above;
`/ccalarm test` proves placement and sound without waiting for real crowd
control. The display reproduces the sizes that were configured in MiniAuras. The
offline test harness stubs the WoW API and checks both directions — that the
alarm fires and that it stays silent when it should — 15 assertions, and its
first run found a real bug where the sound was skipped for auras without an
`auraInstanceID`.*
