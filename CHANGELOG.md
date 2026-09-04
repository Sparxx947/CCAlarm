# Changelog

## 1.2.0 — 2026-09-04

Ein eigener Ton je Rolle — und ein Fehler behoben, den das Einbetten der
Bibliothek erst geschaffen hatte.

- **Getrennte Alarmtöne für Heiler und Tank.** So hört man ohne hinzusehen, wen
  es getroffen hat. Beide im Optionsfenster wählbar, jeder mit eigenem
  Anhörknopf. Fehlt ein Eintrag, greift der allgemeine Ton — ältere
  Konfigurationen laufen also weiter.
- ★ **Behoben: Die Tonliste wäre auf einer Einzelinstallation leer gewesen.**
  LibSharedMedia meldet von sich aus genau *einen* Ton an („None"). Seit die
  Bibliothek eingebettet ist, wurde ausschließlich deren Liste genutzt — der
  eingebaute Rückfall griff nur noch, wenn sie fehlte, also nie. Beide Listen
  werden jetzt **zusammengeführt**: Die eingebauten Schriften und Töne stehen
  immer zur Wahl, Medien anderer Addons kommen hinzu.
- Acht eingebaute Töne statt vier, alle über `SOUNDKIT` angesprochen und damit
  ohne Datei verfügbar.
- **57 → 69 Prüfungen**, darunter der ganze Weg: CC auf dem Tank spielt den
  Tank-Ton, CC auf dem Heiler den Heiler-Ton.

*Separate alarm sounds for healer and tank, each selectable with its own preview
button, falling back to the general sound when unset. Fixes a bug introduced by
embedding LibSharedMedia: the library registers exactly one sound of its own
("None"), and since embedding it the code used only its list, so the sound
selection would have been empty on an installation with no other addons. Both
lists are now merged, so the built-ins are always offered and other addons' media
are added on top. Eight built-in sounds instead of four, all addressed through
SOUNDKIT. 57 → 69 assertions.*

## 1.1.1 — 2026-09-04

Die Schriftwahl war schon da — jetzt ist auch belegt, dass sie ankommt.

- **Behoben:** `SetDefaultText` wurde ungesichert aufgerufen. Es gibt die
  Methode nicht auf jedem Client; dort wäre der Aufbau des Optionsfensters
  daran zerbrochen. Jetzt abgesichert, wie es andere Addons auch tun.
- Der Prüfstand verfolgte bisher nur, ob die Schrift richtig **aufgelöst** wird
  — nicht, ob sie an der Anzeige **ankommt**. Eine Einstellung, die nichts
  bewirkt, wäre schlimmer als eine falsche. Jetzt wird bis zum FontString
  durchgeprüft: Schriftart, Größe, Umriss, Farbe, Symbolgröße — samt Gegenprobe,
  dass die Prüfung eine ausbleibende Wirkung auch bemerkt.
- Neu geprüft ist auch das **Optionsfenster selbst**: Es wird aufgebaut, das
  Schriftmenü ausgelesen, ein Eintrag angeklickt, und nachgewiesen, dass der
  Klick bis zur Anzeige durchschlägt.
- Der Prüfstand lud das Addon zweimal, mit zwei verschiedenen Rahmen-Nachbauten
  — der zweite kannte neue Rahmenarten nicht. Entfernt.
- **39 → 57 Prüfungen.**

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
