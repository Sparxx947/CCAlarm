#!/usr/bin/env python3
"""check_scope.py -- findet Aufrufe eines local VOR seiner Deklaration.

In Lua bindet ein Funktionsrumpf beim Erzeugen an das, was an dieser Stelle im
Quelltext sichtbar ist. Steht "local function show" weiter unten, greift eine
weiter oben definierte Funktion auf die GLOBALE Variable gleichen Namens zu --
also auf nil. Der Fehler zeigt sich erst beim Aufruf zur Laufzeit, nicht beim
Laden, und keine Syntaxpruefung sieht ihn.

Genau das ist am 2026-09-04 passiert: ns.Test stand vor "local function show"
und scheiterte im Spiel 27-mal mit "attempt to call a nil value".

Exit 1 bei einem Fund.
"""
import pathlib
import re
import sys

WURZEL = pathlib.Path(__file__).resolve().parent.parent
DATEIEN = ["CCAlarm.lua", "Config.lua", "Locales.lua"]


def ohne_kommentare(zeile: str) -> str:
    return re.sub(r"--.*$", "", zeile)


def main() -> int:
    fehler = 0
    for name in DATEIEN:
        pfad = WURZEL / name
        if not pfad.exists():
            continue
        zeilen = pfad.read_text(encoding="utf-8").splitlines()

        # Wo wird welcher local deklariert?
        deklariert = {}
        for i, zeile in enumerate(zeilen):
            for treffer in re.finditer(r"^\s*local\s+function\s+(\w+)\s*\(", zeile):
                deklariert.setdefault(treffer.group(1), i)
            for treffer in re.finditer(r"^\s*local\s+(\w+)\s*=\s*function", zeile):
                deklariert.setdefault(treffer.group(1), i)

        for funktion, zeilennr in deklariert.items():
            muster = re.compile(r"\b" + re.escape(funktion) + r"\s*\(")
            for i in range(zeilennr):
                text = ohne_kommentare(zeilen[i])
                if muster.search(text):
                    print(f"{name}:{i + 1}: ruft '{funktion}' auf, "
                          f"deklariert erst in Zeile {zeilennr + 1} -- "
                          f"das trifft die globale Variable (nil)", file=sys.stderr)
                    fehler += 1

    if fehler:
        return 1
    print(f"Gueltigkeitsbereiche in Ordnung ({len(DATEIEN)} Dateien geprueft)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
