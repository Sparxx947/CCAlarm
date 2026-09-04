#!/usr/bin/env python3
"""check_toc.py -- prueft die .toc gegen das, was wirklich im Repo liegt.

Zwei Fehler, die sonst erst im Spiel auffallen:
  * eine in der .toc gelistete Datei fehlt -> das Addon laedt nicht
  * eine Lua-Datei liegt da, wird aber nicht geladen -> stiller Blindgaenger
Dazu die Interface-Version, damit sie nicht beim naechsten Patch vergessen wird.
"""
import pathlib
import re
import sys

WURZEL = pathlib.Path(__file__).resolve().parent.parent
ERWARTET = "120100"          # WoW 12.1


def main() -> int:
    toc = WURZEL / "CCAlarm.toc"
    if not toc.exists():
        print("CCAlarm.toc fehlt", file=sys.stderr)
        return 1
    text = toc.read_text(encoding="utf-8")

    interface = re.search(r"^##\s*Interface:\s*(.+)$", text, re.M)
    if not interface:
        print("keine Interface-Zeile in der .toc", file=sys.stderr)
        return 1
    versionen = [v.strip() for v in interface.group(1).split(",")]
    if ERWARTET not in versionen:
        print(f"Interface {versionen} enthaelt {ERWARTET} nicht", file=sys.stderr)
        return 1

    # WoW schreibt Pfade in der .toc mit Backslash; auf Linux/CI muss daraus ein
    # normaler Pfad werden, sonst meldet die Pruefung jede Bibliothek als fehlend.
    gelistet = [z.strip().replace("\\", "/") for z in text.splitlines()
                if z.strip() and not z.strip().startswith("#")]
    fehler = 0
    for datei in gelistet:
        if not (WURZEL / datei).exists():
            print(f"in der .toc gelistet, fehlt aber: {datei}", file=sys.stderr)
            fehler += 1

    # Nur die eigenen Dateien auf oberster Ebene; Bibliotheken bringen eigene
    # Hilfsdateien mit, die bewusst nicht geladen werden.
    vorhanden = {p.name for p in WURZEL.glob("*.lua")}
    ungenutzt = vorhanden - set(gelistet)
    for datei in sorted(ungenutzt):
        print(f"liegt im Repo, wird aber nicht geladen: {datei}", file=sys.stderr)
        fehler += 1

    if fehler:
        return 1
    print(f"toc in Ordnung: Interface {', '.join(versionen)}, "
          f"{len(gelistet)} Datei(en) geladen")
    return 0


if __name__ == "__main__":
    sys.exit(main())
