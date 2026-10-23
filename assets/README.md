# Grafikk og lyd – spesifikasjon for designgruppa

Alt i denne mappa er **plassholdere**, laget i kode av `tools/placeholder_art.gd`
(unntatt spilleren, `characters/student.png` – se under).
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

`school.png` brukes nå bare i minnet i introen (skriveren i går).

## Introen – `intro/`

Resepsjonen og trappa ned til kjelleren, laget fra illustrasjonen designgruppa tegnet:
`intro/source/reception_illustration.webp` (240×135, skalert opp ~3,5×). Godot importerer
ikke `source/`-mappa. `tools/intro_art.gd` finner de ekte pikslene igjen, skjærer ut delene
og bygger rommet (400×240, én skjerm) rundt illustrasjonen:

| Fil | Størrelse | Innhold |
|---|---|---|
| `reception_bg.png` | 400×240 | Vegg, flisgulv og teppe. Illustrasjonen står 80 px inn; vegg og gulv er forlenget til sidene med de samme mønstrene, og nederst er det grå fliser som ved inngangen |
| `reception.png` | 92×80 | Resepsjonsvinduet (uten resepsjonisten) |
| `receptionist.png` | 14×23 | Resepsjonisten |
| `stairs.png` | 55×50 | Trappa ned til kjelleren |
| `plant_pot.png`, `wall_art.png` | | Potten med ansikt og "hjernen" på veggen (pulserer i spillet) |
| `cabinet.png` | 24×46 | Glassmonteren, tegnet etter bildet av resepsjonen |
| `thought_bubble.png` | 60×16 | Tankeboble, 3 ruter (. .. ...) |

Lag filene på nytt (f.eks. etter en ny versjon av illustrasjonen):

```
godot --headless --path . --script res://tools/intro_art.gd
```

Plasseringene står øverst i skriptet (`OFS`, `R_*`) og må stemme med nodene under `Wall`
i `scenes/intro/intro.tscn`. Hvor man kan gå står i `data/maps/intro.txt`
(scenen tegner ingen tiles, bare bakgrunnsbildet).

## Personer – `characters/*.png`

Alle personark har 4 rader: ned (mot kamera), venstre, høyre, opp (ryggen).
NPC-ene har 3 kolonner: steg A, stå stille, steg B.
Figuren står nederst i ruta (føttene på nederste pikselrad).

| Fil | Arkstørrelse | Rute | Merknad |
|---|---|---|---|
| `student.png` (spilleren) | 144×144 | 24×36 | Ekte grafikk, 6 kolonner (se under). Figuren er 20 px bred. |
| `teacher.png`, `receptionist.png` | 48×96 | 16×24 | Plassholdere |

### Spilleren – `student.png`

Lages av `tools/student_sprite.gd` fra animasjonene designgruppa leverte, som ligger i
`characters/student_src/` (Godot importerer ikke den mappa):

| Kildefil | Innhold |
|---|---|
| `PlayerWalkDown/Left/Up.png` | 16 ruter à 240×135 (tegnet i 3× størrelse), 4 ulike gangtegninger |
| `PlayerIdleAnim.png` | 12 ruter: står forfra, rute 6 er et blunk |
| `PlayerIdleLeft.png`, `PlayerIdleUp.png` | 1 rute hver |

Høyre speiles fra venstre. Kolonnene i arket:

| 0 | 1 | 2–5 |
|---|---|---|
| står | blunk (bare forfra) | gangsyklus, to tegninger per steg |

Kolonnene velges på `Player`-noden i `scenes/actors/player.tscn` (`stand_col`,
`blink_col`, `walk_cols`, og `hframes` på `Sprite`). Får dere nye tegninger, bytt filene i
`student_src/` (samme navn og rutestørrelse) og lag arket på nytt:

```
godot --headless --path . --script res://tools/student_sprite.gd
```

Åpne deretter prosjektet i Godot (eller kjør `godot --headless --path . --import`) så det
nye arket importeres.

Bytter du til en annen rutestørrelse, må `offset` på `Sprite` i scenen justeres så føttene
havner nederst i ruta (spilleren: `scenes/actors/player.tscn`, `offset = (0, 8 - høyde/2)`).
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

### Tittelskjermen – `ui/title_*.png`

Panorama av kjellergangen sett fra siden. Lagene glir med ulik fart (parallakse).

| Fil | Størrelse | Innhold |
|---|---|---|
| `title_sky.png` | 600×64 | Natthimmel og bakke utenfor – ses bare gjennom vinduene |
| `title_wall.png` | 800×240 | Selve gangen. Vinduene må være **gjennomsiktige hull** |
| `title_front.png` | 1040×240 | Nesten svarte silhuetter i forgrunnen (søyler, kabler, kasser) |
| `title_shadow.png` | 48×32 | 3 ruter à 16×32: bein steg A, bein steg B, hode som titter inn |
| `title_figure.png` | 16×40 | Skikkelsen i døråpningen / under lampa (lyse øyne) |
| `title_fog.png` | 256×48 | Tåke som flislegges sidelengs |

Lyset fra lysrørene tegnes av spillet. Bytter du `title_wall.png`, flytt markørene
`Lamps`, `Windows`, `DoorEyes`, `PrinterLed` og `ExitSign` under `Pano/Wall` i
`scenes/title.tscn` så de stemmer med den nye tegningen.

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
