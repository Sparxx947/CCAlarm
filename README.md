# CCAlarm

Warnt groß und laut, wenn **Heiler oder Tank** in Kontrollverlust geraten.
Für World of Warcraft Retail (Midnight, 12.1).

In Mythic+ entscheidet oft die eine Sekunde, in der niemand merkt, dass der
Heiler betäubt ist. CCAlarm zeigt das mitten im Blickfeld: roter Warntext,
darunter die Symbole der wirkenden Effekte mit ablaufender Restzeit, dazu ein Ton.

*Warns loudly when the healer or the tank is crowd-controlled, for World of
Warcraft Retail (Midnight, 12.1). In Mythic+ the second nobody notices the
healer is stunned is often the one that matters; CCAlarm puts it in the middle
of the screen — red warning text, the icons of the active effects with their
remaining time, and a sound.*

## Installieren

Den Ordner `CCAlarm` nach `Interface/AddOns/` kopieren und WoW **vollständig
neu starten** — neue Addons werden nur beim Start eingelesen, ein `/reload`
genügt nicht. Danach `/ccalarm test` aufrufen: Das zeigt einen Probealarm für
fünf Sekunden, damit Sitz und Ton stimmen, bevor es darauf ankommt.

Vorkonfigurieren muss man nichts.

*Copy the `CCAlarm` folder into `Interface/AddOns/` and restart WoW completely —
new addons are only read at startup, a `/reload` is not enough. Then run
`/ccalarm test` for a five-second dummy alert, so position and sound are right
before it matters. There is nothing to configure up front.*

## Wie es CC erkennt — und warum das nicht trivial ist

Seit Midnight ist der naheliegende Weg versperrt. Drei Möglichkeiten wurden
geprüft und verworfen:

| Weg | Warum nicht |
|---|---|
| Kampfprotokoll | `COMBAT_LOG_EVENT_UNFILTERED` gibt es nicht mehr |
| Aura-Klassifizierung | weder `C_UnitAuras` noch die Aurendaten tragen ein Feld für Kontrollverlust |
| `C_LossOfControl` für Mitspieler | liefert ausschließlich Daten über den Spieler selbst |

Übrig bleibt eine Liste von Zauber-IDs. **Diese Liste ist nicht fest verdrahtet,
sondern wird gelernt:** `LOSS_OF_CONTROL_ADDED` feuert für den Spieler und nennt
Blizzards eigene Einstufung (`locType`) samt Zauber-ID. Was einen selbst trifft,
trifft in denselben Dungeons auch Heiler und Tank — die Liste füllt sich also
beim Spielen und gilt ab dann für die ganze Gruppe.

Damit die erste Begegnung nicht verloren geht, merkt sich das Addon zusätzlich
jede noch unbekannte schädliche Aura auf Heiler oder Tank als **Kandidat**;
`/ccalarm kandidaten` zeigt sie mit Namen und ID zum Übernehmen.

`SCHOOL_INTERRUPT` und `DISARM` werden bewusst nie gelernt — sie hindern
niemanden am Laufen oder Heilen und erzeugten nur Lärm.

*Detecting crowd control on other players is not straightforward in Midnight.
The combat log event is gone, no aura API classifies crowd control, and
`C_LossOfControl` reports on the player only — which leaves a list of spell IDs.
That list is learned rather than hardcoded: `LOSS_OF_CONTROL_ADDED` fires for the
player carrying Blizzard's own `locType` classification together with the spell
ID, and whatever hits you in a dungeon hits the healer and tank in that same
dungeon, so the list fills itself through play and then covers the whole group.
Harmful auras seen on those roles that are not known yet are recorded as
candidates, listed by `/ccalarm candidates` for promotion.
`SCHOOL_INTERRUPT` and `DISARM` are never learned: neither stops anyone from
moving or healing.*

## Abhängigkeiten: keine

Das Addon bringt alles mit, was es braucht. `LibSharedMedia-3.0`,
`CallbackHandler-1.0` und `LibStub` liegen unter [`Libs/`](Libs/) bei — es setzt
**kein** anderes Addon voraus. Weil LibStub Bibliotheken teilt, gewinnt eine
neuere Fassung aus einem anderen Addon automatisch, und Schriften oder Töne, die
andere Addons anmelden, erscheinen zusätzlich in der Auswahl. Ein Gewinn, keine
Bedingung. `tools/check_selfcontained.py` hält das dauerhaft nach.

*No dependencies: the addon ships everything it needs. LibSharedMedia-3.0,
CallbackHandler-1.0 and LibStub are embedded under `Libs/`, so no other addon is
required. Since LibStub shares libraries, a newer copy from another addon wins
automatically, and fonts or sounds other addons register simply appear in the
lists as a bonus. `tools/check_selfcontained.py` enforces this.*

## Grenzen

Ehrlich benannt, damit niemand sich auf etwas verlässt, was das Addon nicht kann:

- **Am Anfang ist die Liste leer.** Sie füllt sich, sobald einen selbst zum
  ersten Mal ein bestimmter Effekt trifft — oder man einen Kandidaten übernimmt.
- **Private Auren und einige Encounter-Mechaniken sind für Addons unsichtbar.**
  Was Blizzard verbirgt, kann auch dieses Addon nicht sehen.
- **Nur Gruppenmitglieder.** Für einen selbst zeigt WoW seine eigene
  Kontrollverlust-Anzeige mitten im Bild.
- **Rollen kommen aus der Gruppenzuweisung** (`UnitGroupRolesAssigned`). Wer
  ohne zugewiesene Rolle unterwegs ist, wird nicht überwacht.

*Limitations, stated plainly: the list starts empty and fills as effects hit you
for the first time or as candidates are promoted; private auras and some
encounter mechanics are hidden from addons entirely; only group members are
watched, since WoW draws its own loss-of-control display for yourself; and roles
come from the group role assignment, so a member without an assigned role is not
watched.*

## Einstellen

Alles lässt sich im Spiel ändern — **Optionen → AddOns → CCAlarm**, oder direkt
mit `/ccalarm config`:

| Bereich | Einstellbar |
|---|---|
| Warntext | Schriftart, Größe (10–72), Farbe, Umriss (kein / dünn / dick) |
| Symbole | anzeigen, Größe (16–96), Höchstzahl (1–10) |
| Ton | an/aus, Auswahl aus allen bekannten Tönen, Knopf zum Anhören |
| Rollen | Heiler, Tank — einzeln |
| Zonen | Dungeon, Arena, offene Welt, Schlachtzug, Schlachtfeld |
| Position | **Lösen und ziehen**, festsetzen, zurücksetzen |

Beim Lösen wird der Rahmen sichtbar hinterlegt, damit man ihn auch ohne
laufenden Alarm greifen kann. Gespeichert wird die vollständige Verankerung —
die Anzeige sitzt also auch nach einem Wechsel von Auflösung oder UI-Skalierung
wieder richtig.

*Everything is configurable in game under Options → AddOns → CCAlarm, or with
`/ccalarm config`: font face, size, colour and outline for the warning text;
icon display, size and count; the alarm sound with a preview button; which roles
to watch; which zones to be active in; and the position, which is unlocked by a
button and dragged into place. While unlocked the frame is tinted so it can be
grabbed even with no alarm running, and the complete anchor is saved so the
display returns to the same spot after a resolution or UI scale change.*

## Befehle

Englisch ist die Grundform, die deutschen Wörter funktionieren ebenso.

| Befehl | Deutsch | Wirkung |
|---|---|---|
| `/ccalarm config` | `einstellungen` | Optionsfenster öffnen |
| `/ccalarm test` | | Probealarm für 5 Sekunden |
| `/ccalarm unlock` / `lock` | `loesen` / `festsetzen` | Rahmen verschiebbar machen |
| `/ccalarm reset` | `zuruecksetzen` | Position zurücksetzen |
| `/ccalarm status` | | an/aus, Rollen, Zahl der gelernten Zauber, gilt hier |
| `/ccalarm list` | `liste` | alle gelernten Zauber mit Einstufung |
| `/ccalarm candidates` | `kandidaten` | gesehene, noch unbekannte Auren |
| `/ccalarm add <id>` | `dazu` | Zauber-ID aufnehmen |
| `/ccalarm remove <id>` | `weg` | Zauber-ID entfernen |
| `/ccalarm clear` | `leeren` | Kandidatenliste leeren |
| `/ccalarm on` / `off` | `an` / `aus` | ein- und ausschalten |

*English is the primary form; the German words in the second column work as
aliases.*

## Anzeige

Roter Warntext oben mittig, darunter bis zu fünf Symbole à 50 px mit ablaufendem
Cooldown, dazu ein Ton. Aktiv in Dungeon, Arena und offener Welt; im Schlachtzug
und auf Schlachtfeldern still. Die Werte stehen in `CCAlarmDB` und lassen sich
dort ändern.

*Red warning text at the top centre, up to five 50 px icons with a running
cooldown underneath, plus a sound. Active in dungeons, arenas and the open
world; silent in raids and battlegrounds. The values live in `CCAlarmDB`.*

## Entwickeln und Prüfen

```
luac5.1 -p CCAlarm.lua Locales.lua tests/pruefstand.lua   # Syntax
lua5.1 tests/pruefstand.lua                                # Verhalten
python3 tools/check_toc.py                                 # .toc gegen den Dateibestand
python3 tools/check_selfcontained.py                       # keine Fremdabhaengigkeit
python3 tools/check_locales.py                             # Uebersetzungen gegen den Code
tools/package.sh                                           # dist/CCAlarm-<version>.zip
```

Dieselben Schritte laufen als GitHub-Action bei jedem Push.

Der **Prüfstand stellt die WoW-API nach**, sodass sich das Addon ohne WoW prüfen
lässt. Er prüft ausdrücklich **beide Richtungen** — dass alarmiert wird *und*
dass es still bleibt: bei Schadensausteilern, unbekannten Zaubern, zu kurzen
Auren, totem Heiler, im Schlachtzug und im abgeschalteten Zustand. Sein erster
Lauf fand einen echten Fehler: ohne `auraInstanceID` blieb der Ton aus.

`check_toc.py` fängt zwei Fehler ab, die sonst erst im Spiel auffallen: eine in
der `.toc` gelistete, aber fehlende Datei (das Addon lädt gar nicht) und eine
Lua-Datei, die im Repo liegt, ohne geladen zu werden (stiller Blindgänger).

*The test harness stubs the WoW API so the addon can be checked without the game,
and it asserts both directions — that the alarm fires and that it stays silent
for damage dealers, unknown spells, sub-second auras, a dead healer, raid
instances and when switched off. Its first run found a real bug where the sound
was skipped for auras without an `auraInstanceID`. `check_toc.py` catches two
mistakes that would otherwise only surface in game: a file listed in the `.toc`
that does not exist (the addon fails to load at all) and a Lua file present in
the repository that is never loaded.*

## Veröffentlichen

Ein Tag `v<version>` baut das Zip und legt eine GitHub-Release an. Der Workflow
bricht ab, wenn Tag und `## Version` in der `.toc` auseinanderlaufen oder eine
Prüfung rot ist.

*A `v<version>` tag builds the zip and creates a GitHub release; the workflow
refuses to publish when the tag and the `.toc` version disagree or any check
fails.*

## Lizenz

MIT — siehe [`LICENSE`](LICENSE).
