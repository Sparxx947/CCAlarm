# Eingebettete Bibliotheken

Das Addon bringt alles mit, was es braucht — es setzt **kein** anderes Addon
voraus. Diese drei Bibliotheken sind dafür eingebettet; sie werden über
`LibStub` geteilt, das heißt: Ist eine neuere Fassung durch ein anderes Addon
bereits geladen, gewinnt die neuere, und es entsteht keine Doppelung.

| Bibliothek | Wofür | Herkunft |
|---|---|---|
| `LibStub` | Versionsverwaltung für die anderen beiden | [WoWAce](https://www.wowace.com/projects/libstub) |
| `CallbackHandler-1.0` | Ereignisse innerhalb von LibSharedMedia | [WoWAce](https://www.wowace.com/projects/callbackhandler) |
| `LibSharedMedia-3.0` | Verzeichnis der Schriften und Töne | [CurseForge](https://www.curseforge.com/wow/addons/libsharedmedia-3-0) |

LibSharedMedia bringt eigene Schriften und Töne mit, sodass die Auswahl auch
allein funktioniert. Sind andere Addons installiert, die dort Medien anmelden,
erscheinen deren Schriften und Töne zusätzlich — ein Gewinn, keine Bedingung.

*The addon ships everything it needs and requires no other addon. These three
libraries are embedded and shared through `LibStub`, so a newer copy loaded by
another addon simply wins and nothing is duplicated. LibSharedMedia brings its
own fonts and sounds, so the selection works standalone; media registered by
other addons show up as a bonus, never as a requirement.*
