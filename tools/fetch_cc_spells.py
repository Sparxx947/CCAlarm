#!/usr/bin/env python3
"""fetch_cc_spells.py -- baut die Saatliste der CC-Zauber aus zwei Quellen.

Das Addon lernt CC-Zauber im Spiel aus Blizzards eigener Einstufung. Bis das
greift, ist die Liste leer. Dieses Werkzeug fuellt sie vor -- ohne eine einzige
ID zu raten:

  1. WARCRAFT LOGS liefert, welche Debuffs in den Dungeons der laufenden
     Saison TATSAECHLICH von Gegnern auf Spieler gewirkt werden. Das ist der
     entscheidende Filter: nicht "was koennte CC sein", sondern "was trifft
     dort wirklich jemanden". Aus 425.000 Zaubern werden so ein paar hundert.
  2. WOWHEAD liefert je Zauber die Mechanik als Tabellenzeile
     "<th>Mechanic</th> <td>Stunned</td>". Das ist die Einstufung, die weder
     die Spiel-API noch die Logs hergeben.

Ergebnis: Data/CCSpells.lua. Aufruf: python3 tools/fetch_cc_spells.py [--limit N]
"""
import argparse
import gzip
import json
import pathlib
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request

WURZEL = pathlib.Path(__file__).resolve().parent.parent
CACHE = WURZEL / ".cache"
ZONE = 55           # Mythic+ Season 2 (live); frozen=false, 8 Begegnungen

# Mechaniken, die jemanden wirklich am Handeln hindern. Verlangsamungen,
# Zauberschulsperren und Entwaffnen sind bewusst NICHT dabei -- sie hindern
# niemanden am Laufen oder Heilen und erzeugten nur Laerm.
CC_MECHANIKEN = {
    "Stunned": "STUN", "Fleeing": "FEAR", "Horrified": "HORROR",
    "Incapacitated": "CONFUSE", "Asleep": "SLEEP", "Charmed": "CHARM",
    "Rooted": "ROOT", "Silenced": "SILENCE", "Pacified": "PACIFY",
    "Pacified and silenced": "PACIFYSILENCE", "Banished": "BANISH",
    "Polymorphed": "CONFUSE", "Shackled": "STUN", "Frozen": "STUN",
    "Turned": "FEAR", "Disoriented": "CONFUSE",
}

# Wowhead weist alles ab, was nicht wie eine echte Navigation aussieht -- ein
# blosser User-Agent bekommt 403, unabhaengig davon, ob es die Seite gibt.
BROWSER = {
    "User-Agent": ("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
                   "(KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    "Accept-Encoding": "gzip, deflate",
    "sec-ch-ua": '"Chromium";v="128", "Not;A=Brand";v="24"',
    "sec-ch-ua-mobile": "?0",
    "sec-ch-ua-platform": '"Linux"',
    "Sec-Fetch-Dest": "document",
    "Sec-Fetch-Mode": "navigate",
    "Sec-Fetch-Site": "none",
    "Sec-Fetch-User": "?1",
    "Upgrade-Insecure-Requests": "1",
    "Connection": "close",
}


def wcl(frage: str) -> dict:
    """Eine GraphQL-Abfrage ueber wcl-get. Nur lesend, das Werkzeug erzwingt es."""
    lauf = subprocess.run(["wcl-get", "frage", frage, "--roh"],
                          capture_output=True, text=True)
    if lauf.returncode != 0:
        raise SystemExit(f"wcl-get scheiterte: {lauf.stderr.strip()[:200]}")
    return json.loads(lauf.stdout)


def wowhead(spell_id: int) -> str:
    """Seite eines Zaubers, mit Zwischenspeicher -- Wowhead soll nicht
    fuer jeden Lauf erneut befragt werden."""
    CACHE.mkdir(exist_ok=True)
    datei = CACHE / f"spell-{spell_id}.html"
    if datei.exists() and time.time() - datei.stat().st_mtime < 30 * 86400:
        return datei.read_text(encoding="utf-8", errors="replace")
    # Wowhead wirft bei zu dichter Folge 403. Ohne Wiederholung fehlen die
    # betroffenen Zauber im Ergebnis, ohne dass es auffaellt -- beim ersten Lauf
    # waren das 14 Stueck.
    letzter = None
    for versuch in range(4):
        try:
            req = urllib.request.Request(f"https://www.wowhead.com/spell={spell_id}",
                                         headers=dict(BROWSER))
            with urllib.request.urlopen(req, timeout=30) as antwort:
                roh = antwort.read()
                if (antwort.headers.get("Content-Encoding") or "").lower() == "gzip":
                    roh = gzip.decompress(roh)
            text = roh.decode("utf-8", "replace")
            datei.write_text(text, encoding="utf-8")
            # 2 s Grundabstand: Bei 0,6 s antwortet Wowhead reihenweise mit 403.
            # Nachgemessen -- dieselben IDs gehen mit 2 s Abstand alle durch, es
            # ist also Drosselung und nicht die einzelne Seite.
            time.sleep(2.0)
            return text
        except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError) as fehler:
            letzter = fehler
            time.sleep(5.0 * (versuch + 1))
    raise letzter


MECHANIK = re.compile(r"<th>\s*Mechanic\s*</th>\s*<td>\s*([^<]+?)\s*</td>", re.I)


GESCHEITERT: list[int] = []


def mechanik_von(spell_id: int):
    try:
        treffer = MECHANIK.search(wowhead(spell_id))
    except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError) as fehler:
        print(f"    {spell_id}: nicht abrufbar ({fehler})", file=sys.stderr)
        GESCHEITERT.append(spell_id)
        return None
    return treffer.group(1) if treffer else None


def kandidaten(limit: int) -> dict[int, dict]:
    """Debuffs, die NPCs in der laufenden Saison auf Spieler wirken."""
    zone = wcl('{ worldData { zone(id: %d) { name encounters { id name } } } }' % ZONE)
    begegnungen = {e["id"]: e["name"] for e in zone["worldData"]["zone"]["encounters"]}
    print(f"  Zone: {zone['worldData']['zone']['name']}, "
          f"{len(begegnungen)} Dungeons")

    berichte = wcl('{ reportData { reports(zoneID: %d, limit: %d) '
                   '{ data { code } } } }' % (ZONE, limit))
    codes = [r["code"] for r in berichte["reportData"]["reports"]["data"]]
    print(f"  {len(codes)} Reports")

    gefunden: dict[int, dict] = {}
    for nr, code in enumerate(codes, 1):
        kopf = wcl('{ reportData { report(code: "%s") { '
                   'fights { id encounterID startTime endTime } '
                   'masterData { actors { id type } abilities { gameID name } } } } }' % code)
        bericht = (kopf.get("reportData") or {}).get("report")
        # Nicht jeder Report gibt Stammdaten her (privat, unvollstaendig, noch
        # in Verarbeitung). Ohne sie laesst sich Gegner nicht von Spieler
        # unterscheiden -- also ueberspringen statt den ganzen Lauf abbrechen.
        stamm = (bericht or {}).get("masterData") or {}
        if not bericht or not stamm.get("actors"):
            print(f"    [{nr}/{len(codes)}] {code}: keine Stammdaten -- uebersprungen")
            continue
        typen = {a["id"]: a["type"] for a in stamm["actors"]}
        namen = {a["gameID"]: a["name"] for a in (stamm.get("abilities") or [])}
        kaempfe = [f for f in (bericht.get("fights") or [])
                   if f.get("encounterID") in begegnungen]
        if not kaempfe:
            continue
        anfang = min(f["startTime"] for f in kaempfe)
        ende = max(f["endTime"] for f in kaempfe)
        ereignisse = wcl('{ reportData { report(code: "%s") { events('
                         'dataType: Debuffs, hostilityType: Friendlies, '
                         'startTime: %d, endTime: %d, limit: 10000) '
                         '{ data } } } }' % (code, anfang, ende))
        daten = (((ereignisse.get("reportData") or {}).get("report") or {})
                 .get("events") or {}).get("data") or []
        dungeon_je_kampf = {f["id"]: begegnungen.get(f["encounterID"], "?") for f in kaempfe}
        neu = 0
        for e in daten:
            if e.get("type") != "applydebuff":
                continue
            if typen.get(e.get("sourceID")) != "NPC" or typen.get(e.get("targetID")) != "Player":
                continue
            sid = e["abilityGameID"]
            eintrag = gefunden.setdefault(sid, {"name": namen.get(sid, "?"),
                                                "treffer": 0, "dungeons": set()})
            eintrag["treffer"] += 1
            d = dungeon_je_kampf.get(e.get("fight"))
            if d:
                eintrag["dungeons"].add(d)
            neu += 1
        print(f"    [{nr}/{len(codes)}] {code}: {len(daten)} Ereignisse, "
              f"{neu} von NPCs auf Spieler")
    return gefunden


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--limit", type=int, default=12,
                   help="Zahl der ausgewerteten Reports (Standard 12)")
    args = p.parse_args()

    print("== 1. Warcraft Logs: was trifft dort wirklich Spieler? ==")
    roh = kandidaten(args.limit)
    print(f"  {len(roh)} verschiedene Debuffs von Gegnern auf Spieler\n")

    print("== 2. Wowhead: welche davon sind Kontrollverlust? ==")
    treffer = {}
    for nr, (sid, info) in enumerate(sorted(roh.items(), key=lambda x: -x[1]["treffer"]), 1):
        mech = mechanik_von(sid)
        if mech and mech in CC_MECHANIKEN:
            treffer[sid] = dict(info, mechanik=mech, art=CC_MECHANIKEN[mech])
            print(f"    {sid:8d}  {mech:22s} {info['name'][:38]}")
        if nr % 25 == 0:
            print(f"    ... {nr}/{len(roh)} geprueft")
    print(f"\n  {len(treffer)} von {len(roh)} sind Kontrollverlust")
    if GESCHEITERT:
        # Ein unvollstaendiges Ergebnis, das sich vollstaendig gibt, ist
        # schlimmer als ein offensichtlich fehlendes.
        print(f"  ACHTUNG: {len(GESCHEITERT)} Zauber waren nicht abrufbar und "
              f"fehlen daher moeglicherweise: {GESCHEITERT[:10]}", file=sys.stderr)

    if not treffer:
        print("KEIN einziger Treffer -- das ist verdaechtig, nichts geschrieben.",
              file=sys.stderr)
        return 1

    ziel = WURZEL / "Data" / "CCSpells.lua"
    ziel.parent.mkdir(exist_ok=True)
    zeilen = [
        "-- CCSpells.lua -- ERZEUGT von tools/fetch_cc_spells.py, nicht von Hand aendern.",
        "--",
        "-- Saatliste der CC-Zauber. Keine ID ist geraten:",
        "--   * Warcraft Logs sagt, welche Debuffs in der laufenden Saison",
        "--     tatsaechlich von Gegnern auf Spieler gewirkt werden.",
        "--   * Wowhead liefert je Zauber die Mechanik.",
        "--",
        "-- Das Addon LERNT weiter aus LOSS_OF_CONTROL_ADDED; diese Liste ist nur",
        "-- der Startpunkt und ueberschreibt Gelerntes nie.",
        "",
        "local ADDON, ns = ...",
        "",
        "ns.SEED_SPELLS = {",
    ]
    for sid, info in sorted(treffer.items(), key=lambda x: -x[1]["treffer"]):
        name = info["name"].replace('"', "'")
        zeilen.append(f'    [{sid}] = "{info["art"]}",'
                      f'  -- {name} ({info["mechanik"]}, {info["treffer"]}x)')
    zeilen += ["}", ""]
    ziel.write_text("\n".join(zeilen) + "\n", encoding="utf-8")
    print(f"  geschrieben: {ziel.relative_to(WURZEL)} ({len(treffer)} Zauber)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
