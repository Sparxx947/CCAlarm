#!/usr/bin/env python3
"""check_locales.py -- prueft die Uebersetzungen gegen den Code.

Drei Fehler, die sonst erst im Spiel auffallen:
  * der Code fragt einen Schluessel ab, den es nirgends gibt -> der Nutzer sieht
    den rohen Schluesselnamen statt eines Textes
  * eine Uebersetzung definiert einen Schluessel, den niemand abfragt -> Ballast,
    meist ein Tippfehler
  * eine Sprache laesst Schluessel aus -> Rueckfall auf Englisch; erlaubt, aber
    es soll bewusst geschehen und nicht unbemerkt

Exit 1 bei den ersten beiden. Fehlende Uebersetzungen werden nur berichtet.
"""
import pathlib
import re
import sys

WURZEL = pathlib.Path(__file__).resolve().parent.parent
LOCALES = WURZEL / "Locales.lua"


def main() -> int:
    text = LOCALES.read_text(encoding="utf-8")

    # enUS steht vor der ersten Sprachweiche, alles danach sind Ueberschreibungen.
    trenner = text.find('if GetLocale() ==')
    if trenner < 0:
        print("keine Sprachweiche in Locales.lua gefunden", file=sys.stderr)
        return 1
    basis = set(re.findall(r'^L\["([^"]+)"\]', text[:trenner], re.M))

    sprachen = {}
    for treffer in re.finditer(r'if GetLocale\(\) == "(\w+)" then(.*?)\nend', text, re.S):
        sprachen[treffer.group(1)] = set(re.findall(r'L\["([^"]+)"\]\s*=', treffer.group(2)))

    benutzt = set()
    for datei in WURZEL.glob("*.lua"):
        if datei.name == "Locales.lua":
            continue
        benutzt |= set(re.findall(r'L\["([^"]+)"\]', datei.read_text(encoding="utf-8")))

    fehler = 0
    for schluessel in sorted(benutzt - basis):
        print(f"Code fragt ab, enUS kennt nicht: {schluessel}", file=sys.stderr)
        fehler += 1
    for schluessel in sorted(basis - benutzt):
        print(f"in enUS definiert, nirgends benutzt: {schluessel}", file=sys.stderr)
        fehler += 1
    for sprache, schluessel in sorted(sprachen.items()):
        fremd = schluessel - basis
        for k in sorted(fremd):
            print(f"{sprache} definiert einen Schluessel, den enUS nicht kennt: {k}",
                  file=sys.stderr)
            fehler += 1

    print(f"{len(benutzt)} Schluessel im Code, {len(basis)} in enUS")
    for sprache, schluessel in sorted(sprachen.items()):
        fehlend = basis - schluessel
        print(f"  {sprache}: {len(schluessel)} uebersetzt"
              + (f", {len(fehlend)} faellt auf enUS zurueck ({', '.join(sorted(fehlend))})"
                 if fehlend else ", vollstaendig"))

    return 1 if fehler else 0


if __name__ == "__main__":
    sys.exit(main())
