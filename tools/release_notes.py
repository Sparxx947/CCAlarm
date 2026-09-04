#!/usr/bin/env python3
"""release_notes.py -- schneidet den Abschnitt EINER Fassung aus dem Changelog.

Der Release-Workflow hat vorher die ganze CHANGELOG.md als Releasetext angehaengt.
Damit stand bei jeder Veroeffentlichung auch alles Frueheree drin, und der eigentliche
Inhalt ging unter.

Aufruf: release_notes.py <version> [ziel]
"""
import pathlib
import re
import sys

WURZEL = pathlib.Path(__file__).resolve().parent.parent


def main(argv: list[str]) -> int:
    if not argv:
        raise SystemExit(__doc__)
    version = argv[0].lstrip("v")
    ziel = pathlib.Path(argv[1]) if len(argv) > 1 else None

    text = (WURZEL / "CHANGELOG.md").read_text(encoding="utf-8")
    # Abschnitt laeuft von "## <version>" bis zur naechsten "## "-Zeile.
    muster = re.compile(r"^## " + re.escape(version) + r"\b.*?$(.*?)(?=^## |\Z)",
                        re.M | re.S)
    treffer = muster.search(text)
    if not treffer:
        print(f"Kein Changelog-Abschnitt fuer {version} gefunden -- ein Release "
              f"ohne Beschreibung waere schlechter als gar keiner.", file=sys.stderr)
        return 1

    abschnitt = treffer.group(1).strip()
    if not abschnitt:
        print(f"Abschnitt fuer {version} ist leer.", file=sys.stderr)
        return 1

    if ziel:
        ziel.parent.mkdir(parents=True, exist_ok=True)
        ziel.write_text(abschnitt + "\n", encoding="utf-8")
        print(f"{ziel}: {len(abschnitt.splitlines())} Zeilen fuer {version}")
    else:
        print(abschnitt)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
