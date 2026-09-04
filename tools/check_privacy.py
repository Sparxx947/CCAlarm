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
# Libs/ enthaelt unveraenderten Fremdcode; die Adressen darin sind
# Urheberangaben der Autoren, nicht Spuren aus diesem Rechner. Sie werden
# ausgelassen, aber im Bericht genannt, damit die Ausnahme sichtbar bleibt.
UEBERSPRINGEN = {".git", "dist", "__pycache__", "Libs", ".cache"}
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


ERLAUBTE_AUTOREN = {
    "Sparxx947 <79375757+Sparxx947@users.noreply.github.com>",
    "Sparxx <79375757+Sparxx947@users.noreply.github.com>",
    "GitHub <noreply@github.com>",
    "github-actions[bot] <41898282+github-actions[bot]@users.noreply.github.com>",
}


def pruefe_historie() -> int:
    """Die Git-Historie ist nach einer Veroeffentlichung nicht mehr zurueckzuholen.

    Klarname und private Adresse landen dort leicht: Sie stehen in der globalen
    Git-Konfiguration und wirken in jedem Repo, in dem nichts anderes gesetzt
    ist. In Dateien faellt so etwas beim Lesen auf, in der Historie nie.
    """
    import subprocess
    try:
        lauf = subprocess.run(
            # --all, nicht nur der aktuelle Zweig: Sicherungszweige und die
            # Reste von filter-branch tragen die alte Angabe sonst unbemerkt
            # weiter und wandern beim naechsten "push --all" doch nach draussen.
            ["git", "-C", str(WURZEL), "log", "--all",
             "--format=%an <%ae>%n%cn <%ce>%n%B"],
            capture_output=True, text=True, check=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("  (kein Git-Verlauf pruefbar)", file=sys.stderr)
        return 0
    zeilen = [z.strip() for z in lauf.stdout.splitlines() if z.strip()]

    # Autorzeilen haben die Form "Name <adresse>"; alles andere ist Commit-Text.
    autoren = {z for z in zeilen if z.endswith(">") and " <" in z}
    fremde = autoren - ERLAUBTE_AUTOREN
    for autor in sorted(fremde):
        print(f"Historie: unerwarteter Autor {autor}", file=sys.stderr)

    # Auch der TEXT eines Commits kann eine Identitaet tragen: GitHub haengt
    # beim Squash-Merge eine "Co-authored-by:"-Zeile mit der Adresse des
    # Zweig-Autors an. Die ueberlebt jedes Umschreiben der Autorfelder.
    for muster, was in MUSTER:
        for treffer in set(re.findall(muster, lauf.stdout)):
            wort = treffer if isinstance(treffer, str) else treffer[0]
            if was in ("Name mit Sonderzeichen", "Realmname"):
                continue
            if any(wort in a for a in ERLAUBTE_AUTOREN):
                continue
            print(f"Historie: {was} im Commit-Text: {wort}", file=sys.stderr)
            fremde = fremde | {wort}
    if fremde:
        print("  Hinweis: eine bereits nach GitHub gepushte Angabe bleibt ueber\n"
              "  refs/pull/<nr>/head erreichbar, auch nachdem der Zweig geloescht\n"
              "  wurde. Umschreiben allein genuegt dann nicht.", file=sys.stderr)
    return len(fremde)


def main() -> int:
    funde = pruefe_historie()
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
    libs = WURZEL / "Libs"
    anzahl = len([p for p in libs.rglob("*") if p.is_file()]) if libs.is_dir() else 0
    print("keine personenbezogenen Spuren gefunden, Historie sauber"
          + (f" (Libs/ mit {anzahl} Fremddatei(en) ausgelassen)" if anzahl else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
