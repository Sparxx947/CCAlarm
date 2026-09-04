#!/usr/bin/env bash
# package.sh -- baut das Auslieferungs-Zip so, wie WoW es erwartet:
# genau EIN Ordner "CCAlarm" auf oberster Ebene.
#
# Aufruf: tools/package.sh   -> dist/CCAlarm-<version>.zip
set -euo pipefail

wurzel="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$wurzel"

version="$(grep -m1 '^## Version:' CCAlarm.toc | sed 's/^## Version:[[:space:]]*//' | tr -d '\r')"
[ -n "$version" ] || { echo "keine Version in der .toc gefunden" >&2; exit 1; }

bau="$(mktemp -d)"
trap 'rm -rf "$bau"' EXIT
mkdir -p "$bau/CCAlarm"

# Nur das, was ins Spiel gehoert -- Pruefstand und Werkzeuge bleiben draussen.
cp CCAlarm.toc CCAlarm.lua Locales.lua Config.lua LICENSE README.md "$bau/CCAlarm/"
cp -r Libs "$bau/CCAlarm/"

mkdir -p dist
ziel="dist/CCAlarm-$version.zip"
rm -f "$ziel"
(cd "$bau" && zip -qr "$OLDPWD/$ziel" CCAlarm)

# Gegenprobe: genau ein Ordner oben, und die .toc liegt darin.
oben="$(unzip -Z1 "$ziel" | cut -d/ -f1 | sort -u)"
[ "$oben" = "CCAlarm" ] || { echo "Zip-Aufbau falsch: '$oben'" >&2; exit 1; }
unzip -Z1 "$ziel" | grep -qx "CCAlarm/CCAlarm.toc" || { echo ".toc fehlt im Zip" >&2; exit 1; }

# Jede in der .toc geladene Datei muss auch im Zip liegen -- sonst laedt das
# Addon beim Nutzer nur halb, was schwerer zu finden ist als gar nicht zu laden.
while read -r eintrag; do
  [ -n "$eintrag" ] || continue
  pfad="CCAlarm/$(printf '%s' "$eintrag" | tr '\\' '/')"
  unzip -Z1 "$ziel" | grep -qx "$pfad" || { echo "fehlt im Zip: $pfad" >&2; exit 1; }
done < <(grep -v '^#' CCAlarm.toc | grep -v '^[[:space:]]*$')

echo "$ziel  ($(unzip -Z1 "$ziel" | wc -l) Dateien, Version $version)"
