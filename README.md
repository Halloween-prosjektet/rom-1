# rom-1 – Kjelleren: Intro + Etasje -1

Halloween-prosjekt, Elvebakken VGS. Dette er **stasjon 1**: intro-cutscenen og første
kjelleretasje. Spillet kjører på en Raspberry Pi 4 med berøringsskjerm. Når spilleren
kommer fram til skriveren nederst i kjelleren, "feiler" den i spillet, og en **ekte
skriver skriver ut et ark med feilkoden**. Koden er nøkkelen til neste stasjon (etasje -2).

Laget i **Godot 4.7** (Compatibility-renderer, nødvendig for Pi 4).

## Spillflyt

1. **Tittelskjerm** – trykk for å starte.
2. **Navneskjerm** – gruppa skriver inn navnet sitt (skjermtastatur med Æ/Ø/Å, vanlig
   tastatur virker også). Navnet brukes i dialogen, på utskriften og på resultatlista.
3. **Intro (cutscene)** – læreren ber deg skrive ut et dokument. Alle skriverne er ødelagte.
   Resepsjonen sier at det står en skriver som virker i kjelleren.
4. **Etasje -1** – klokka oppe til høyre starter når man kommer ned. Mørke ganger,
   flimrende lys, et lager med kasser som må dyttes unna (dytte-gåte med knappen
   "Tilbakestill rommet") og et helt mørkt arkiv. Døra til skriverrommet lyser innerst i
   arkivgangen, men er låst – nøkkelen ligger i en av eskene i arkivet.
5. **Skriveren** – klokka stopper, skriveren "feiler" og den ekte skriveren skriver ut
   feilkoden (+ gruppenavn og tid).
6. **Sluttskjerm** – viser gruppenavn og tid. **"Ny gruppe"** starter rett på nytt for
   neste gruppe (kontrollskriptet kan også sende `RESET`).

## Resultater / tidtaking

Hver gruppe som når skriveren lagres som én linje i
`~/.local/share/godot/app_userdata/Kjelleren - Etasje -1/resultater.csv`:

```
tidspunkt,stasjon,gruppe,millisekunder,tid
2026-10-31 18:04:12,rom-1,"Gruppe 7",60742,01:00.7
```

Tiden måles fra man kommer ned i kjelleren (etter introen) til man bruker skriveren.

## Kontroller

- **Berøring:** trykk på en rute for å gå dit, trykk på en ting for å gå bort og undersøke
  den. D-pad og `!`-knapp vises når en berøringsskjerm er koblet til.
- **Tastatur:** piltaster / WASD + E / Space / Enter.
- **Gamepad / arkadeknapper:** D-pad / venstre stikke + A.
- Inputs defineres i `scripts/autoload/game_state.gd` (`_setup_input`).
- **Berøringskontroller av/på:** knappen nede til høyre på tittelskjermen. Valget lagres
  i `user://station.cfg` og huskes etter omstart. Standard settes i `config/defaults.cfg`
  (`touch_controls`).
- **Ganghastighet:** `step_time` (sekunder per rute, lavere = raskere). Spilleren: velg
  `Player`-noden i `scenes/actors/player.tscn` → Inspector → *Step Time*.
  Standard for alle figurer (0.22) står i `scripts/world/actor.gd`.

## Mappestruktur

```
assets/        Grafikk og lyd (plassholdere). Se assets/README.md for størrelser.
config/        defaults.cfg – feilkode, skrivernavn, UDP-port osv.
data/          dialogue_no.json (ALL tekst), maps/*.txt (nivåene som ASCII-kart)
scenes/        Scener (tittel, intro, etasje -1, sluttskjerm, rekvisitter, HUD)
scripts/       autoload/ (globale systemer), world/ (rutenett, spiller, triggere),
               props/ (kasser, dører, esker, skriver), scenes/, ui/
tools/         Generator for plassholder-grafikk og lyd
```

### Endre ting uten å kode

- **Tekst/dialog:** `data/dialogue_no.json`.
- **Grafikk/lyd:** bytt fil i `assets/` (samme navn og størrelse).
- **Kartet:** `data/maps/level_minus1.txt` – tegnforklaring står øverst i
  `scripts/world/level_map.gd`. Unike ting (esker med nøkkel, dør, skriver,
  triggere med tekst/lyd, gåterommet) flyttes i Godot-editoren under
  `Entities` / `Triggers` i `scenes/level_minus1/level_minus1.tscn`.
  Triggere vises som oransje rektangler i editoren.
- **Plassholdere på nytt:** åpne `tools/run_placeholder_generator.gd` og velg
  File › Run. Den lager bare filer som mangler, så den overskriver ikke ekte grafikk.

## Innstillinger på Pi-en (`station.cfg`)

`config/defaults.cfg` følger med i spillet. For å endre noe på Pi-en uten å eksportere
på nytt, lag `station.cfg` **i samme mappe som spillfila** med nøklene du vil endre:

```ini
[station]
error_code="E-0451"          ; avtal koden med gruppa som lager etasje -2!
printer_name="HP_LaserJet"   ; se navn med: lpstat -p   (tom = standardskriver)
print_enabled=true
on_error_command=["python3", "/home/pi/blink.py"]   ; valgfritt, f.eks. LED via GPIO

[display]
touch_controls="on"
```

Hvis utskriften feiler, vises koden på sluttskjermen i stedet
(`show_code_if_print_fails=true`).

## Kobling mot kontrollskriptet (StationLink)

Laget for gruppa som lager kontrollskriptet som synkroniserer Pi-ene.

- **Status-fil:** `~/.local/share/godot/app_userdata/Kjelleren - Etasje -1/station_status.json`
  oppdateres ved hver faseendring:
  `{"station":"rom-1","phase":"done","group":"Gruppe 7","time_ms":60742,"time":"01:00.7","finished":true,"timestamp":...}`.
  Faser: `title`, `name`, `intro`, `level`, `printing`, `done`.
- **UDP-port 4242** (kan endres med `status_port`):
  - `RESET` → spillet går tilbake til tittelskjermen, svarer `OK`
  - `STATUS` → svarer med JSON som over (med gruppenavn og tid så langt)

```bash
echo -n STATUS | nc -u -w1 <pi-ip> 4242
echo -n RESET  | nc -u -w1 <pi-ip> 4242
```

## Eksportere til Raspberry Pi 4

1. Godot: *Editor › Manage Export Templates* → last ned templates for 4.7.
2. *Project › Export* → velg **Raspberry Pi (Linux arm64)** → *Export Project*
   (lager `build/pi/kjelleren.arm64`).
3. Kopier fila til Pi-en (f.eks. `/home/pi/kjelleren/`) og kjør `chmod +x kjelleren.arm64`.
4. Skriver: `sudo apt install cups`, `sudo usermod -aG lpadmin pi`, legg til skriveren
   på `http://localhost:631`, test med `echo test | lp`.
5. Autostart (Raspberry Pi OS / labwc): legg til
   `/home/pi/kjelleren/kjelleren.arm64` i `~/.config/labwc/autostart`.

## Utvikling

- Godot AI-pluginen (`addons/godot_ai`) er bare et editorverktøy for AI-assistert
  utvikling; spillet trenger den ikke.
- Kjør enkeltscener med F6 for å teste (f.eks. `scenes/level_minus1/level_minus1.tscn`).
