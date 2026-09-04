#!/usr/bin/env python3
"""check_secret_auras.py -- findet ungeschuetzte Aufrufe der Auren-Schnittstellen.

Seit Midnight (12.x) haelt Blizzard in Mythic+ und PvP die Auren geheim, sobald
ein Addon im Aufrufweg steht. C_UnitAuras.GetAuraDataByIndex gibt dann nicht nil
zurueck -- es WIRFT. Ein ungeschuetzter Aufruf reisst damit den ganzen Durchlauf
ab, und zwar genau dort, wo CCAlarm gebraucht wird.

Am 2026-09-04 kostete das an einem Abend 14004 Fehler im Fehlerspeicher, und der
Alarm blieb in jedem Schluesselstein aus -- ohne dass jemand etwas bemerkt haette,
weil ein ausbleibender Alarm wie Ruhe aussieht.

Die Regel ist bewusst stur: jeder Aufruf einer auren-lesenden Schnittstelle
gehoert in ein pcall. Das Tor (aurasRestricted) davor ersetzt es NICHT -- die
Sperre kann zwischen Tor und Aufruf greifen.

Abschalten: CCALARM_SKIP_SECRET_CHECK=1 (dann warnt der Lauf nur).
Exit 1 bei einem Fund.
"""
import os
import pathlib
import re
import sys

WURZEL = pathlib.Path(__file__).resolve().parent.parent
DATEIEN = ["CCAlarm.lua", "Config.lua", "Locales.lua", "Data/CCSpells.lua"]

# Alles, was bei geheimen Auren wirft. Die alten Unit*-Funktionen stehen mit
# drin, damit ein spaeterer Rueckgriff auf sie nicht am Gatter vorbeikommt.
APIS = [
    r"C_UnitAuras\.GetAuraDataByIndex",
    r"C_UnitAuras\.GetAuraDataBySlot",
    r"C_UnitAuras\.GetAuraDataByAuraInstanceID",
    r"C_UnitAuras\.GetBuffDataByIndex",
    r"C_UnitAuras\.GetDebuffDataByIndex",
    r"AuraUtil\.ForEachAura",
    r"\bUnitAura\b",
    r"\bUnitBuff\b",
    r"\bUnitDebuff\b",
]
MUSTER = re.compile("|".join(APIS))


def ohne_kommentare(zeile: str) -> str:
    return re.sub(r"--.*$", "", zeile)


def geschuetzt(text: str, treffer: re.Match) -> bool:
    """Steht unmittelbar vor dem Namen ein pcall( bzw. xpcall(?"""
    davor = text[: treffer.start()].rstrip()
    return davor.endswith("pcall(")


def main() -> int:
    nachsichtig = os.environ.get("CCALARM_SKIP_SECRET_CHECK") == "1"
    funde = 0
    geprueft = 0

    for name in DATEIEN:
        pfad = WURZEL / name
        if not pfad.exists():
            continue
        geprueft += 1
        for i, zeile in enumerate(pfad.read_text(encoding="utf-8").splitlines()):
            text = ohne_kommentare(zeile)
            for treffer in MUSTER.finditer(text):
                if geschuetzt(text, treffer):
                    continue
                funde += 1
                print(
                    f"{name}:{i + 1}: '{treffer.group(0)}' ohne pcall -- "
                    f"bei geheimen Auren (Mythic+/PvP) wirft der Aufruf und "
                    f"bricht den Durchlauf ab. "
                    f"Regel: pcall({treffer.group(0)}, ...). "
                    f"Vorbei geht es mit CCALARM_SKIP_SECRET_CHECK=1",
                    file=sys.stderr,
                )

    if funde:
        if nachsichtig:
            print(f"WARNUNG: {funde} ungeschuetzte Aufrufe -- Pruefung abgeschaltet")
            return 0
        return 1

    print(f"Auren-Aufrufe alle abgesichert ({geprueft} Dateien geprueft)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
