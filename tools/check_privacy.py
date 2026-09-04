#!/usr/bin/env python3
"""check_privacy.py -- sucht personenbezogene Spuren, bevor das Repo oeffentlich wird.

Ein Addon-Repo entsteht meist auf dem eigenen Rechner; Pfade, Charakter- und
Kontonamen rutschen dabei leicht in Kommentare, Beispiele oder Testdaten.
Oeffentlich sind sie nicht mehr zurueckzuholen, deshalb prueft das hier
automatisch statt per Erinnerung.

Exit 1 bei einem Fund. Aufruf: python3 tools/check_privacy.py
"""
import pathlib
import re
import sys

WURZEL = pathlib.Path(__file__).resolve().parent.parent
UEBERSPRINGEN = {".git", "dist", "__pycache__"}
# Diese Datei enthaelt die Suchmuster selbst -- wuerde sie sich mitpruefen,
# meldete sie bei jedem Lauf ihre eigenen Realmnamen und waere wertlos.
NICHT_PRUEFEN = {"tools/check_privacy.py"}

MUSTER = [
    (r"/home/[a-z][a-z0-9_-]*", "Pfad im Heimverzeichnis"),
    (r"[Cc]:\\\\Users\\\\[A-Za-z]", "Windows-Benutzerpfad"),
    (r"\b[\w.+-]+@[\w-]+\.[\w.]+\b", "E-Mail-Adresse"),
    (r"steamapps/compatdata", "Steam-Installationspfad"),
    (r"\bDAVCON\b", "WoW-Kontoname"),
    (r"\b(Blackhand|Antonidas|Nozdormu|Arygos|Blackrock)\b", "Realmname"),
    (r"[A-Za-zÀ-ÿ]*[îìíïîêéèôóòûúùàáâãñÿ][A-Za-zÀ-ÿ]{2,}", "Name mit Sonderzeichen"),
]

# Woerter, die legitim Sonderzeichen tragen -- sonst meldet die Pruefung
# dauerhaft dieselben Treffer und wird ignoriert, was schlimmer waere.
ERLAUBT = {
    "für", "über", "läuft", "während", "möglich", "größe", "größer", "hört",
    "gehört", "zusätzlich", "ausschließlich", "schädliche", "übernehmen",
    "können", "müssen", "prüft", "prüfung", "prüfstand", "geprüft", "gefüllt",
    "füllt", "häufigste", "hängt", "später", "nächsten", "übrig", "übrigen",
    "wörter", "grün", "grüne", "räumt", "gelöscht", "erklärung", "änderung",
    "änderungen", "größen", "übersicht", "verfügbar", "künftig", "zurück",
    "ähnlich", "tatsächlich", "natürlich", "schließt", "schließlich",
}


def main() -> int:
    funde = 0
    for pfad in sorted(WURZEL.rglob("*")):
        if not pfad.is_file():
            continue
        if any(teil in UEBERSPRINGEN for teil in pfad.parts):
            continue
        try:
            text = pfad.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        rel = pfad.relative_to(WURZEL)
        if str(rel) in NICHT_PRUEFEN:
            continue
        for muster, was in MUSTER:
            for treffer in set(re.findall(muster, text)):
                wort = treffer if isinstance(treffer, str) else treffer[0]
                if was == "Name mit Sonderzeichen" and wort.lower() in ERLAUBT:
                    continue
                if was == "Name mit Sonderzeichen" and not wort[0].isupper():
                    continue
                print(f"{rel}: {was}: {wort}", file=sys.stderr)
                funde += 1

    if funde:
        print(f"\n{funde} Fund(e) -- vor einer Veroeffentlichung bereinigen.",
              file=sys.stderr)
        return 1
    print("keine personenbezogenen Spuren gefunden")
    return 0


if __name__ == "__main__":
    sys.exit(main())
