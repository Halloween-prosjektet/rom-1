# Grafikk og lyd – spesifikasjon for designgruppa

Alt i denne mappa er **plassholdere**, laget i kode av `tools/placeholder_art.gd`.
For å bytte inn ekte grafikk legger du en fil med **samme navn og samme størrelse**
oppå den gamle. Du trenger ikke endre noe i koden.

Stil: pikselgrafikk sett ovenfra (RPG Maker-stil). Spillet er 400×240 piksler og
skaleres 2× til Pi-skjermen (800×480). Én rute er 16×16 piksler.
Bruk PNG med gjennomsiktig bakgrunn. Ikke bruk kantutjevning (antialiasing).

## Tiles – `tiles/basement.png` (kjeller) og `tiles/school.png` (skolen)

128×32 piksler = 8 kolonner × 2 rader med ruter på 16×16. Begge filene har samme oppsett:

| Rute (kol, rad) | Innhold |
|---|---|
| (0,0) | Gulv, vanlig (brukes mest) |
| (1,0) (2,0) (3,0) | Gulvvarianter (sprekk, flekk, skitt), velges tilfeldig |
| (4,0) | Spesialgulv: `,` i kartet (våt flekk / rødt teppe) |
| (5,0) | Trapp: `=` i kartet |
| (6,0) | Ubrukt (svart) |
| (7,0) | Sjeldent mørkt gulv (rist) |
| (0,1) | Toppen av en vegg (sees ovenfra, nesten svart) |
| (1,1) (2,1) | Nederste del av veggflaten (rett over gulvet) + variant |
| (3,1) (4,1) | Øverste del av veggflaten + variant |
| (5,1)–(7,1) | Ledig |

Veggene tegnes automatisk: en vegg rett over gulv får "nederste flate", veggen over
den igjen får "øverste flate", resten får "topp".

## Personer – `characters/*.png`

48×96 piksler: 3 kolonner × 4 rader med figurer på 16×24.

- Kolonner: steg A, stå stille, steg B
- Rader: ned (mot kamera), venstre, høyre, opp (ryggen)

Filer: `student.png` (spilleren), `teacher.png`, `receptionist.png`.
Nye NPC-er: bruk `scenes/actors/npc.tscn` og sett `sheet` til et nytt ark.

## Rekvisitter – `props/*.png`

| Fil | Størrelse | Rammer |
|---|---|---|
| `crate.png` | 16×16 | 1 (kasse som kan dyttes) |
| `shelf.png` | 16×24 | 1 (hylle, stikker 8 px opp i ruta over) |
| `junk.png` | 64×16 | 4 varianter ved siden av hverandre (skjerm, PC, stol, kabler) |
| `box.png` | 32×16 | 2: lukket, åpnet (esker man leter i) |
| `door.png` | 32×32 | 2: lukket, åpen (16×32 hver) |
| `printer.png` | 32×24 | 2: normal, feil (den siste skriveren) |
| `printer_broken.png` | 32×16 | 2: normal, blinker (skriverne i intro) |
| `desk.png`, `counter.png` | 16×16 | 1 |
| `plant.png` | 16×24 | 1 |

## UI – `ui/`

- `dialogue_box.png` – 24×24, 9-slice med 6 px kant (dialogboksen)
- `arrow.png` – 24×24, pil som peker opp (D-pad, roteres automatisk)
- `action.png` – 36×36, handlingsknapp
- `portraits/<navn>.png` – *valgfritt*: portrett i dialogboksen, f.eks. `teacher.png`,
  `reception.png`, `student.png` (navnene står i `data/dialogue_no.json` under `names`)

## Font – `fonts/`

Legg en pikselfont som `fonts/main.ttf` (eller `.otf`), så brukes den overalt.

## Lyd – `audio/`

`.ogg`, `.wav` eller `.mp3` med samme navn. Spillet prøver `.ogg` først.

| Navn | Brukes til |
|---|---|
| `ambience_drone` | Bakgrunnsstemning i kjelleren (loop) |
| `hum` | Summing fra lysrør, skolen og sluttskjermen (loop) |
| `flicker` | Lysrør som blinker |
| `footstep` | Fottrinn |
| `push` / `bump` | Dytte kasse / kassen sitter fast |
| `door`, `door_slam`, `unlock`, `locked` | Dører |
| `rummage`, `item` | Lete i eske / finne nøkkel |
| `printer`, `error`, `static` | Skrivere |
| `sting`, `thud`, `whisper` | Skremmeeffekter |
| `blip` | Tekst som skrives i dialogboksen |
