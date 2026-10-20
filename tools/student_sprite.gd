extends SceneTree
## Genererer spillerens spriteark (assets/characters/student.png) fra pikselkart i tekst.
## Forfra-figuren er tegnet av designgruppa; resten (rygg, profil, gange) er laget ut fra den.
##
## Kjør fra prosjektmappa:
##   godot --headless --path . --script res://tools/student_sprite.gd
## Valgfritt: legg til  -- --preview=C:/sti/preview.png  for et forstørret kontrollbilde.
##
## Ark: 3 kolonner (steg A, stå, steg B) x 4 rader (ned, venstre, høyre, opp).
## Hver rute er 24x36 piksler, figuren står nederst i ruta (føttene på siste rad).

const OUT := "res://assets/characters/student.png"
const FW := 24
const FH := 36
## Kunsten er 20 piksler bred og plasseres midt i ruta.
const ART_X := 2

const PAL := {
	"c": Color8(0, 0, 0),         # omriss
	"f": Color8(116, 86, 74),     # hår
	"e": Color8(104, 77, 67),     # hår, skygge
	"g": Color8(147, 110, 95),    # hår, lys
	"h": Color8(93, 69, 60),      # hår, mørk
	"k": Color8(74, 53, 47),      # hår, mørkest
	"i": Color8(243, 179, 158),   # hud
	"W": Color8(255, 255, 255),   # øyeglans
	"m": Color8(59, 40, 36),      # øye
	"n": Color8(212, 122, 109),   # munn
	"G": Color8(189, 189, 189),   # lys grå ved øret
	"o": Color8(66, 66, 66),      # høyhalset genser / vrangbord
	"p": Color8(97, 97, 97),      # genser
	"v": Color8(47, 45, 45),      # genser, skygge
	"q": Color8(206, 88, 37),     # oransje
	"s": Color8(85, 35, 9),       # oransje, skygge
	"r": Color8(224, 224, 224),   # hvit stripe / såle
	"d": Color8(136, 136, 136),   # hvit stripe, skygge
	"t": Color8(65, 104, 41),     # grønn stripe
	"u": Color8(33, 49, 19),      # grønn, skygge
	"j": Color8(65, 80, 114),     # jeans
	"x": Color8(73, 89, 122),     # jeans, lys
	"y": Color8(56, 69, 99),      # jeans, mørk
	"Y": Color8(58, 71, 101),     # jeans, mørk 2
	"z": Color8(46, 57, 81),      # jeans, mørkest
	"A": Color8(63, 79, 199),     # blå sko-detalj
}

# Forfra, stå stille – nøyaktig etter originaltegningen (20x36, rad 0 er tom).
const FRONT := [
	"....................",
	".......cccccc.......",
	".....cceffgffcc.....",
	"....cffffgfffffc....",
	"...cfffffgfffeehc...",
	"...cfffiiiieeeeec...",
	"...cffiiiiiieeeec...",
	"..cfffiiiiiiiieeec..",
	"..cffiiiiiiiiiieec..",
	"..cfkieeeiieeeieec..",
	"..cfkiiWmiimWiikec..",
	"..cfGiiiiiiiiiiGec..",
	"..cfGiiiiiiiiiiGec..",
	"..cfGiiiinniiiiGfc..",
	"..cfkoiiiiiiiiokfc..",
	"..cfcooiiiiiioocfc..",
	"..cccooooooooooccc..",
	"..cppppooooooppppc..",
	".cppppppppppppppppc.",
	"cqqqqqqqqqqqqqqqqqqc",
	"crqqqsqqqqqqqqsqqqrc",
	"ctrrrdrqqqqqqrdrrrtc",
	"cqtttutrrrrrrtutttqc",
	".cqqqsqttttttqsqqqc.",
	".cpppvpqqqqqqpvpppc.",
	".ciiccppppppppcciic.",
	".ciiccoooooooocciic.",
	"..ccccjjjjjjjjcccc..",
	"....cjjxxyyxxjjc....",
	"....cjjxxyyxxjjc....",
	"....cYjxYzzYxjYc....",
	"....cYYYYzzYYYYc....",
	".....cccccccccc.....",
	".....cArrccrrAc.....",
	".....cArrccrrAc.....",
	"......ccc..ccc......",
]

# Bakfra, stå stille. Samme omriss som forfra; håret dekker hode og nakke.
const BACK := [
	"....................",
	".......cccccc.......",
	".....ccfggfffcc.....",
	"....cffggfffeffc....",
	"...cefggfeffeffec...",
	"...cefgffeffefehc...",
	"...cefegfeffefehc...",
	"..chefegfeffeffehc..",
	"..chefeffeffeffehc..",
	"..chefeffefffefehc..",
	"..chefeffeffeffehc..",
	"..chhefeffeffefhhc..",
	"..chhefeefeefeehhc..",
	"..chheeheeheehehkc..",
	"..ckhhehheehhehhkc..",
	"..ckkhhkhhkhhkhkkc..",
	"..ccckhkkhhkkhkccc..",
	"..cppccccccccccppc..",
	".cppppppppppppppppc.",
	"cqqqqqqqqqqqqqqqqqqc",
	"crqqqsqqqqqqqqsqqqrc",
	"ctrrrdrqqqqqqrdrrrtc",
	"cqtttutrrrrrrtutttqc",
	".cqqqsqttttttqsqqqc.",
	".cpppvpqqqqqqpvpppc.",
	".ciiccppppppppcciic.",
	".ciiccoooooooocciic.",
	"..ccccjjjjjjjjcccc..",
	"....cjjxxjjxxjjc....",
	"....cjjxxyyxxjjc....",
	"....cYjxYzzYxjYc....",
	"....cYYYYzzYYYYc....",
	".....cccccccccc.....",
	".....cvvvccvvvc.....",
	".....cArrccrrAc.....",
	"......ccc..ccc......",
]

# Profil mot venstre: hode (rad 0-16). Ansiktet er kolonne 2-8, øret (G) og håret bak.
const SIDE_HEAD := [
	"....................",
	".......cccccc.......",
	".....ccffggffcc.....",
	"....cffffgffeffc....",
	"...cfffeffgffefhc...",
	"...cfffffeffgffehc..",
	"..ciffffeffgffeehc..",
	"..ciiifeffffgfeehc..",
	"..ciiiiiikeffgfehc..",
	"..cieeeiikfeffgehc..",
	"..cimWiiikfeffgehc..",
	".ciiiiiiiGfeffgehc..",
	"..ciiiiiiGeefffehc..",
	"..cniiiiiGeheefehc..",
	"...ciiiiokheehehkc..",
	"....ccooohkhehkhkc..",
	"....cooooockhkhkcc..",
]

# Profil mot venstre: kropp uten arm (rad 17-26). Stripene ligger som midt på genseren forfra,
# én rad lavere enn på ermet, så armen skiller seg ut.
const SIDE_TORSO := [
	"....cooopppcccccc...",
	"....cppppppppppc....",
	"....cqqqqqqqqqqc....",
	"....cqqqqqqqqqqc....",
	"....cqqqqqqqqqqc....",
	"....crrrrrrrrrrc....",
	"....cttttttttttc....",
	"....cqqqqqqqqqqc....",
	"....cppppppppppc....",
	"....cooooooooooc....",
]

# Armen i profil (rad 18-27 når figuren står): farge og bredde per rad. Rad 0 er skulderen
# (uten omriss, går i ett med kroppen), rad 9 er omrisset under hånden.
const SIDE_ARM := ["p", "q", "q", "r", "t", "q", "p", "i", "i", ""]
## Ermet skilles fra kroppen med en skyggesøm (som forfra), ikke svart strek.
const ARM_SEAM := {"p": "v", "q": "s", "r": "d", "t": "u"}
const SIDE_ARM_W := [3, 3, 3, 3, 3, 3, 3, 2, 2, 2]
## Hvor mange piksler hver rad av armen flyttes bakover når armen svinger bak.
const SIDE_ARM_SWING := [0, 0, 0, 1, 1, 1, 1, 2, 2, 2]

# Profil mot venstre, stå stille: bein (rad 27-35).
const SIDE_LEGS_IDLE := [
	"....cccjjjjjcccc....",
	"......cjjxjjc.......",
	"......cjjxjyc.......",
	"......cyjxYyc.......",
	"......cYYzYYc.......",
	"......ccccccc.......",
	".....crrrAArc.......",
	"....crrrrrrrc.......",
	".....cccccccc.......",
]

# Profil mot venstre, steg (rad 28-35, kroppen har sunket 1 piksel):
# fremre fot flat på gulvet, bakre fot på tå med hælen løftet.
# Begge bein står i lyse farger her; det fjerne beinet mørkes i koden.
const SIDE_LEGS_STEP := [
	"....cccjjjjjcccc....",
	".....cjjxcjjxc......",
	"....cjjxc.cjjxc.....",
	"....cYYYc..cYYYc....",
	"...cccccc...cccc....",
	"..crrrAAc..crrAc....",
	".crrrrrrc.crrrrc....",
	"..ccccccc..cccc.....",
]



func _init() -> void:
	var sheet := Image.create_empty(FW * 3, FH * 4, false, Image.FORMAT_RGBA8)
	var frames := {
		0: [_walk_front(FRONT, false), _grid(FRONT), _walk_front(FRONT, true)],
		1: [_side(1), _side(0), _side(-1)],
		3: [_walk_front(BACK, false), _grid(BACK), _walk_front(BACK, true)],
	}
	frames[2] = []
	for g in frames[1]:
		frames[2].append(_mirror(g))
	for row: int in frames:
		for col in 3:
			_blit(sheet, frames[row][col], col * FW + ART_X, row * FH)
	var err := sheet.save_png(OUT)
	print("Lagret ", OUT, " (", err, ")")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--preview="):
			_preview(sheet, a.trim_prefix("--preview="))
	quit()


# ----------------------------------------------------------------------
# Rutenett-hjelpere (Array av Array med ett tegn per piksel)
# ----------------------------------------------------------------------

static func _grid(rows: Array) -> Array:
	var g: Array = []
	for r: String in rows:
		assert(r.length() == 20, "feil bredde (%d): %s" % [r.length(), r])
		var line: Array = []
		for ch in r:
			line.append(ch)
		g.append(line)
	return g


static func _copy(g: Array) -> Array:
	var out: Array = []
	for line: Array in g:
		out.append(line.duplicate())
	return out


static func _mirror(g: Array) -> Array:
	var out := _copy(g)
	for line: Array in out:
		line.reverse()
	return out


## Tegner en tekstblokk oppå rutenettet; mellomrom er gjennomsiktig (endrer ingenting).
static func _stamp(g: Array, x: int, y: int, block: Array) -> void:
	for dy in block.size():
		var s: String = block[dy]
		for dx in s.length():
			if s[dx] != " " and y + dy < g.size() and x + dx < 20 and x + dx >= 0:
				g[y + dy][x + dx] = s[dx]


static func _blit(img: Image, g: Array, ox: int, oy: int) -> void:
	for y in g.size():
		for x in 20:
			var ch: String = g[y][x]
			if ch != ".":
				img.set_pixel(ox + x, oy + y, PAL[ch])


# ----------------------------------------------------------------------
# Gange
# ----------------------------------------------------------------------

## Steg-rutene: kroppen synker 1 piksel (bob), én skulder/arm går opp og den andre ned,
## og foten som er på vei fram løftes.

## Flytter alt over beina (rad 0-26) én piksel ned. Beina blir én rad kortere.
static func _bob(g: Array) -> void:
	var src := _copy(g)
	for y in range(27, 0, -1):
		g[y] = src[y - 1].duplicate()
	g[0] = src[0].duplicate()
	for x in 20:
		g[0][x] = "."
		# Undersiden av hendene lå på rad 27 sammen med toppen av buksa.
		if src[27][x] == "c" and g[28][x] == ".":
			g[28][x] = "c"


## Flytter en arm (med skulder) dy piksler opp/ned. Gjelder rad 19-28 (etter bob),
## kolonne x0..x1. inner = kolonnen som skiller armen fra buksa.
static func _shift_arm(g: Array, x0: int, x1: int, inner: int, dy: int) -> void:
	var src := _copy(g)
	if dy > 0:
		# Skulderen blir stående, ermet strekkes én rad.
		for y in range(20, 30):
			for x in range(x0, x1 + 1):
				g[y][x] = src[y - 1][x]
	elif dy < 0:
		# Skulderen løftes over kroppen, under hånden blir det tomt.
		for y in range(18, 28):
			for x in range(x0, x1 + 1):
				g[y][x] = src[y + 1][x]
		for x in range(x0, x1 + 1):
			g[28][x] = "c" if x == inner else "."


## Løfter en fot 1 piksel (kolonne x0..x0+5) – foten som er på vei fram.
static func _lift_foot(g: Array, x0: int) -> void:
	for y in range(31, 36):
		for x in range(x0, x0 + 6):
			g[y][x] = g[y + 1][x] if y + 1 < 36 else "."


## Forfra/bakfra. right = høyre fot (i bildet) løftes, venstre arm svinger fram.
static func _walk_front(rows: Array, right: bool) -> Array:
	var g := _grid(rows)
	_bob(g)
	if right:
		_lift_foot(g, 10)
		_shift_arm(g, 0, 4, 4, 1)
		_shift_arm(g, 15, 19, 15, -1)
	else:
		_lift_foot(g, 4)
		_shift_arm(g, 0, 4, 4, -1)
		_shift_arm(g, 15, 19, 15, 1)
	return g


## Tegner armen i profil. Der armen knekker, dekker raden både forrige og denne
## posisjonen, så omrisset henger sammen (som en skrå strek) i stedet for å bli trappetrinn.
static func _draw_side_arm(g: Array, y0: int, swing: int) -> void:
	for i in SIDE_ARM.size():
		var o: int = SIDE_ARM_SWING[i] * swing
		var lo: int = 9 + o
		var hi: int = lo + SIDE_ARM_W[i] - 1
		if i > 0:
			var po: int = SIDE_ARM_SWING[i - 1] * swing
			if po != o and i < 9:
				lo = mini(lo, 9 + po)
				hi = maxi(hi, 9 + po + SIDE_ARM_W[i - 1] - 1)
		var y := y0 + i
		if i == 9:
			for x in range(lo, hi + 1):
				g[y][x] = "c"
			continue
		for x in range(lo, hi + 1):
			g[y][x] = SIDE_ARM[i]
		if i > 0:
			var edge: String = ARM_SEAM.get(SIDE_ARM[i], "c")
			g[y][lo - 1] = edge
			g[y][hi + 1] = edge


## Mørkner det fjerne beinet/skoen i profil.
static func _shade_far_leg(g: Array, x_from: int, x_to: int) -> void:
	const DARK := {"j": "y", "x": "Y", "y": "z", "Y": "z", "r": "G"}
	for y in range(29, 36):
		for x in range(x_from, x_to + 1):
			g[y][x] = DARK.get(g[y][x], g[y][x])


## swing: 0 = stå, 1 = steg A (nær arm bak, nært bein fram), -1 = steg B (omvendt).
static func _side(swing: int) -> Array:
	var rows: Array = []
	rows.append_array(SIDE_HEAD)
	rows.append_array(SIDE_TORSO)
	if swing == 0:
		rows.append_array(SIDE_LEGS_IDLE)
	else:
		# Kroppen har sunket 1 piksel: hode+kropp på rad 1-27, beina på rad 28-35.
		rows.push_front("....................")
		rows.append_array(SIDE_LEGS_STEP)
	var g := _grid(rows)
	var bob := 0 if swing == 0 else 1
	if swing == 1:
		_shade_far_leg(g, 10, 19)
	elif swing == -1:
		_shade_far_leg(g, 0, 9)
	# Armen: overarmen står, underarm og hånd svinger (nær arm motsatt av nært bein).
	_draw_side_arm(g, 18 + bob, swing)
	return g


# ----------------------------------------------------------------------
# Kontrollbilde
# ----------------------------------------------------------------------

static func _preview(sheet: Image, path: String) -> void:
	const S := 8
	var w := sheet.get_width()
	var h := sheet.get_height()
	var img := Image.create_empty(w * S, h * S, false, Image.FORMAT_RGBA8)
	for y in h * S:
		for x in w * S:
			var bg := Color8(60, 62, 66) if ((x / (S * 4)) + (y / (S * 4))) % 2 == 0 else Color8(48, 50, 54)
			if (x % (FW * S)) == 0 or (y % (FH * S)) == 0:
				bg = Color8(200, 60, 60)
			var c := sheet.get_pixel(x / S, y / S)
			img.set_pixel(x, y, bg.blend(c))
	img.save_png(path)
	print("Forhåndsvisning: ", path)
