#!/usr/bin/env python3
"""check_selfcontained.py -- das Addon muss allein lauffaehig sein.

Stehende Vorgabe: Es darf nicht davon abhaengen, was sonst installiert ist.
Drei Wege, auf denen sich eine Abhaengigkeit einschleicht:

  * eine Zeile "## Dependencies" oder "## RequiredDeps" in der .toc
  * ein LibStub("...")-Aufruf auf eine Bibliothek, die nicht eingebettet ist
  * eine eingebettete Bibliothek, die in der .toc gar nicht geladen wird
    (dann fehlt sie zur Laufzeit, obwohl sie im Ordner liegt)

Exit 1 bei einem Fund.
"""
import pathlib
import re
import sys

WURZEL = pathlib.Path(__file__).resolve().parent.parent
TOC = WURZEL / "CCAlarm.toc"
LIBS = WURZEL / "Libs"


def main() -> int:
    text = TOC.read_text(encoding="utf-8")
    geladen = [z.strip().replace("\\", "/") for z in text.splitlines()
               if z.strip() and not z.strip().startswith("#")]
    fehler = 0

    for zeile in text.splitlines():
        if re.match(r"^##\s*(Dependencies|RequiredDeps)\s*:", zeile, re.I):
            print(f"die .toc verlangt ein anderes Addon: {zeile.strip()}", file=sys.stderr)
            fehler += 1

    # Welche Bibliotheken liegen bei?
    eingebettet = {p.name for p in LIBS.iterdir() if p.is_dir()} if LIBS.is_dir() else set()

    # Welche werden im Code angefordert?
    angefordert = set()
    for datei in list(WURZEL.glob("*.lua")):
        inhalt = datei.read_text(encoding="utf-8")
        angefordert |= set(re.findall(r'LibStub\(\s*"([^"]+)"', inhalt))

    for name in sorted(angefordert):
        if name not in eingebettet:
            print(f"LibStub(\"{name}\") wird benutzt, liegt aber nicht unter Libs/",
                  file=sys.stderr)
            fehler += 1

    for name in sorted(eingebettet):
        treffer = [z for z in geladen if z.startswith(f"Libs/{name}/")]
        if not treffer:
            print(f"Libs/{name} liegt da, wird aber in der .toc nicht geladen",
                  file=sys.stderr)
            fehler += 1

    if fehler:
        return 1
    print(f"eigenstaendig: keine Fremdabhaengigkeit, "
          f"{len(eingebettet)} Bibliothek(en) eingebettet und geladen "
          f"({', '.join(sorted(eingebettet))})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
