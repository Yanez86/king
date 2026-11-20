# Il glossario dei suggerimenti annidati (docs/TECH.md): per ogni cosa del gioco il titolo e un testo BBCode coi
# collegamenti ([url=tipo:NOME]) alle cose che nomina, fatto dalle tabelle di main.gd, così resta sempre vero. Tipi:
# tech (ricerca), law (legge), build (mobile o struttura), item (oggetto, Res), room (tipo di stanza), cond
# (condizione), trait (talento), skill (abilità), work (lavoro), concept (CONCEPTS). Vedi content e link.
extends RefCounted

const LINK_COLOR := "e8c34a"
const DIM := "b8b0a0"
const KINDS := ["tech", "law", "build", "item", "room", "cond", "trait", "skill", "work", "concept"]
# I concetti, che non stanno in una tabella: titolo e testo (in inglese, tradotti dal .po). Nel testo {tipo:NOME} è un
# collegamento, col nome della cosa
const CONCEPTS := {
	"authority": ["Authority", "The ruler gathers it governing from the {build:THRONE} in a {room:THRONE_ROOM}, one an hour (more when happy, less when gloomy); every day also one for each step of the {concept:titles} and one every 20 {concept:splendor}. Laws are paid in authority: once to codify them, then to enact them on a {concept:seals}."],
	"study": ["Study", "Colonists write it at a {build:DESK} in a {room:STUDY} (the Study column): one point a page. Study goes into one common pool and is spent on research; from tier II a research also takes a book ({item:NOTEBOOK}, {item:TOME}, {item:CODEX})."],
	"seals": ["Seals", "Laws in force sit on seals: as many laws at once as the seals of your title ({concept:titles}). Enacting a law takes a free seal and 10 {concept:authority}."],
	"titles": ["Titles", "Lordship (2 seals), Barony (3), County (4), Kingdom (5). A realm rises with {concept:splendor} and colonists: barony 15 and 6, county 35 and 10, kingdom 60 and 15. Some laws need a higher title."],
	"splendor": ["Splendor", "The sum of the decorations in the colony that count, each worth some splendor (a {build:FLOWER_BED} 1, a {build:FOUNTAIN} 6, a {build:STATUE} 8). It raises the realm's {concept:titles}, gives one {concept:authority} a day every 20, and brings wanderers sooner; it costs upkeep at the feasts."],
	"comfort": ["Comfort", "From 0 to 10, given by the furniture and the floor of a room (stone counts half again). At 5 nothing changes; lower, sleep, cooking and crafting take longer and food burns more often; higher, faster. Cold and rain take it away; a hot {item:STEW} halves that."],
	"happiness": ["Happiness", "Colonists are happier with good food ({item:MEAL}, {item:FINE_MEAL}, {item:STEW}), a table, comfort, feasts and some laws; mourning, raw food and hard laws make them sadder. Unhappy colonists may storm off or protest."],
}

var main  # main.gd


func _init(m) -> void:
	main = m


# il collegamento a `key` ("tipo:NOME"), col nome della cosa (o `text`) in oro, sottolineato, con l'icona davanti se c'è
func link(key: String, text := "") -> String:
	var said := text if text != "" else title_of(key)
	return "[url=%s][color=#%s]%s%s[/color][/url]" % [key, LINK_COLOR, icon_of(key), said]


func key_of(kind: String, names: Dictionary, value: int) -> String:
	return "%s:%s" % [kind, names.keys()[value]]


func tech(t) -> String: return link(key_of("tech", main.Tech, t))
func law(l) -> String: return link(key_of("law", main.Law, l))
func build(b) -> String: return link(key_of("build", main.Build, b))
func item(r) -> String: return link(key_of("item", main.Res, r))
func room(k) -> String: return link(key_of("room", main.RoomKind, k))


# [tipo, valore] di `key`, o [] se non è una cosa del gioco
func parse(key: String) -> Array:
	var parts := key.split(":")
	if parts.size() != 2 or parts[0] not in KINDS:
		return []
	if parts[0] == "concept":
		return ["concept", parts[1]] if CONCEPTS.has(parts[1]) else []
	var names: Dictionary = {"tech": main.Tech, "law": main.Law, "build": main.Build, "item": main.Res,
		"room": main.RoomKind, "cond": main.Cond, "trait": main.Trait, "skill": main.Skill, "work": main.Work}[parts[0]]
	return [parts[0], names[parts[1]]] if names.has(parts[1]) else []


func title_of(key: String) -> String:
	var p := parse(key)
	if p.is_empty():
		return key
	match p[0]:
		"tech": return main.tech_name(p[1])
		"law": return main.law_name(p[1])
		"build": return main.named(main.Build, p[1])
		"item": return main.named(main.Res, p[1], "item")
		"room": return main.named(main.RoomKind, p[1])
		"cond": return main.named(main.Cond, p[1])
		"trait": return main.named(main.Trait, p[1])
		"skill": return main.named(main.Skill, p[1], "skill")
		"work": return main.named(main.Work, p[1], "work")
		"concept": return tr(CONCEPTS[p[1]][0])
	return key


# l'icona 16x16 davanti al nome, se la cosa ne ha una sua
func icon_of(key: String) -> String:
	var p := parse(key)
	if p.is_empty():
		return ""
	var img := func(path: String, region := Rect2()) -> String:
		if region.has_area():
			return "[img width=16 height=16 region=%d,%d,%d,%d]%s[/img] " % [region.position.x, region.position.y, region.size.x, region.size.y, path]
		return "[img width=16 height=16]%s[/img] " % path
	match p[0]:
		"item":
			return img.call(main.ICONS[p[1]].resource_path) if main.ICONS.has(p[1]) else ""
		"tech":
			return img.call(main.TECHS_SHEET.resource_path, Rect2(p[1] * 16, 0, 16, 16))
		"law":
			return img.call(main.LAWS_SHEET.resource_path, Rect2(p[1] * 16, 0, 16, 16))
		"cond":
			return img.call(main.CONDITIONS_SHEET.resource_path, Rect2(p[1] * 16, 0, 16, 16))
		"skill":
			return img.call(main.SKILLS_SHEET.resource_path, Rect2(p[1] * 8, 0, 8, 8))
		"work":
			return img.call(main.WORK_ICONS[p[1]].resource_path)
		"concept":
			return {"authority": img.call(main.AUTHORITY_ICON.resource_path), "study": img.call(main.STUDY_ICON.resource_path)}.get(p[1], "")
	return ""


# [titolo, testo] di `key`; [] se non è una cosa del gioco
func content(key: String) -> Array:
	var p := parse(key)
	if p.is_empty():
		return []
	var body: String = call("about_" + p[0], p[1])
	return [title_of(key), body.strip_edges()]


# una riga "Etichetta: a, b, c" coi collegamenti; niente se la lista è vuota
func line(label: String, links: Array) -> String:
	return "" if links.is_empty() else "\n%s %s" % [tr(label), ", ".join(links)]


func dim(text: String) -> String:
	return "[color=#%s]%s[/color]" % [DIM, text]


# i {tipo:NOME} di un testo come collegamenti
func linked(text: String) -> String:
	var out := ""
	var rest := text
	while rest.contains("{"):
		var a := rest.find("{")
		var b := rest.find("}", a)
		out += rest.substr(0, a)
		var key := rest.substr(a + 1, b - a - 1)
		out += link(key) if not parse(key).is_empty() else key
		rest = rest.substr(b + 1)
	return out + rest


# --- per tipo ---

func about_tech(t: int) -> String:
	var data: Dictionary = main.TECHS[t]
	var text: String = tr(data["info"])
	var cost := linked(tr("Tier %s: %d {concept:study}") % [["I", "II", "III", "IV"][data["tier"] - 1], data["cost"]])
	if data["tier"] > 1:
		cost += tr(" and a %s") % item(main.BOOKS[data["tier"] - 2])
	text += "\n\n" + cost
	text += line("Needs:", data.get("needs", []).map(tech))
	var opens: Array = data.get("builds", []).map(build) + data.get("makes", []).map(item) + data.get("rooms", []).map(room) \
		+ main.LAWS.keys().filter(func(l): return main.LAWS[l].get("needs", -1) == t).map(law)
	text += line("Unlocks:", opens)
	text += line("Leads to:", main.TECHS.keys().filter(func(o): return t in main.TECHS[o].get("needs", [])).map(tech))
	var block: String = main.research_block(t)
	text += "\n" + dim(tr("Studied") if block == tr("Studied") else (tr("Can be studied now") if block == "" else block))
	return text


func about_law(l: int) -> String:
	var data: Dictionary = main.LAWS[l]
	var mood: Dictionary = data.get("mood", {})
	var who := mood.keys().map(func(k): return "%s %s" % [{"all": tr("everyone"), "guests": tr("adventurers"), "ruler": tr("the ruler"),
		"hunters": tr("bow carriers"), "foreigners": tr("foreigners"), "sworn": tr("the sworn")}.get(k,
		link(key_of("trait", main.Trait, k)) if k is int else ""), main.signed(mood[k])])
	var text: String = tr(data["info"])
	if not who.is_empty():
		text += "\n" + link("concept:happiness") + ": " + ", ".join(who)
	text += "\n\n" + linked(tr("Codify: %d {concept:authority}, once. Enact: %d {concept:authority} and a free {concept:seals}.") % [data["cost"], main.ENACT_COST])
	var needs := []
	if data.get("tier", 0) > 0:
		needs.append(link("concept:titles", tr(main.TITLES[data["tier"]]["realm"])))
	if data.has("after"):
		needs.append(law(data["after"]))
	if data.has("needs"):
		needs.append(tech(data["needs"]))
	if data.has("piece"):
		needs.append(build(data["piece"]))
	text += line("Needs:", needs)
	var state: String = tr("In force") if main.enacted.has(l) else (tr("Codified") if main.codified.has(l) else main.codify_block(l))
	text += "\n" + dim(state if state != "" else tr("Can be codified now"))
	return text


func about_build(b: int) -> String:
	var text: String = tr(main.BUILD_INFO.get(b, ""))
	var cost: Dictionary = main.cost_of([b, main.BUILD_RES.get(b, main.Res.WOOD)])
	var parts := cost.keys().map(func(r): return "%d %s" % [cost[r], item(r)])
	text += "\n\n" + tr("Cost:") + " " + ", ".join(parts) + (tr(" a tile") if not main.FURNITURE.has(b) else "")
	if main.FURNITURE.has(b):
		var size: Vector2i = main.FURNITURE[b]
		text += dim("  %dx%d" % [size.x, size.y])
	var t: int = main.tech_for("builds", b)
	text += line("Research:", [tech(t)] if t >= 0 else [])
	text += line("Needed by:", main.ROOM_NEEDS.keys().filter(func(k): return main.ROOM_NEEDS[k].has(b)).map(room))
	var station: int = main.role(b)
	var made: Array = []
	for r in main.RECIPES:
		if r[1] == station and item(r[0]) not in made:
			made.append(item(r[0]))
	if station == main.Build.CAMPFIRE:
		made.push_front(item(main.Res.MEAL))
	text += line("Makes:", made)
	if main.STATION_ROOM.has(station):
		text += line("Works in:", [room(main.STATION_ROOM[station])])
	var extra := PackedStringArray()
	if main.HEAT.has(b):
		extra.append(tr("+%d °C in the room") % main.HEAT[b])
	if main.COMFORT.has(b):
		extra.append(linked(tr("{concept:comfort} %s") % str(main.COMFORT[b]).trim_suffix(".0")))
	if main.SPLENDOR.has(b):
		extra.append(linked(tr("{concept:splendor} %d") % main.SPLENDOR[b]))
	if not extra.is_empty():
		text += "\n" + ", ".join(extra)
	return text


func about_item(r: int) -> String:
	var text: String = tr(main.KIND_NAMES[main.ITEM_KIND[r]])
	if main.FOOD.has(r):
		text += ". " + tr("Fills %d") % main.FOOD[r]
		text += (tr(", keeps %s days outdoors") % str(main.SHELF_LIFE[r]).trim_suffix(".0")) if main.SHELF_LIFE.has(r) else tr(", never spoils")
		if main.POISON.has(r):
			text += tr(", may poison (%d–%d%%)") % [roundi(main.POISON[r][0] * 100), roundi(main.POISON[r][1] * 100)]
		if main.FOOD_BONUS.has(r):
			text += ". " + cond(main.FOOD_BONUS[r])
	var made := PackedStringArray()
	for rec in main.RECIPES:
		if rec[0] == r:
			var needs := (rec[3] as Dictionary).keys().map(func(k): return "%d %s" % [rec[3][k], tr("vegetables") if k == main.ANY_VEG
				else (tr("meat or fish") if k == main.ANY_FLESH else item(k))])
			made.append(tr("at the %s from %s") % [build(rec[1]), " + ".join(needs)])
	if r in [main.Res.MEAL, main.Res.FINE_MEAL]:
		made.append(tr("at the %s from 2 raw foods") % build(main.Build.CAMPFIRE))
	text += line("Made:", Array(made))
	var used := []
	for rec in main.RECIPES:
		if (rec[3] as Dictionary).has(r) or (rec[3] as Dictionary).keys().any(func(k): return main.GROUPS.get(k, []).has(r)):
			if item(rec[0]) not in used:
				used.append(item(rec[0]))
	text += line("Used for:", used)
	var t: int = main.tech_for("makes", r)
	text += line("Research:", [tech(t)] if t >= 0 else [])
	return text


func about_room(k: int) -> String:
	var needs: Dictionary = main.ROOM_NEEDS.get(k, {})
	var text := tr({main.RoomClass.WORK: "A work room: you can tick its workers.", main.RoomClass.RESIDENCE: "A residence: you can tick its owners.",
		main.RoomClass.SERVICE: "A room for everyone, with its own purpose."}.get(main.ROOM_CLASS.get(k, -1), "A room."))
	text += line("Needs:", needs.keys().map(func(b): return ("%d %s" % [needs[b], build(b)]) if needs[b] > 1 else build(b)))
	var t: int = main.tech_for("rooms", k)
	text += line("Research:", [tech(t)] if t >= 0 else [])
	return text


func cond(k: int) -> String: return link(key_of("cond", main.Cond, k))


func about_cond(k: int) -> String:
	var info: Array = main.COND_INFO[k]
	var text := tr(info[4])
	var facts := PackedStringArray()
	if info[0] > 0:
		facts.append(tr("%s days") % str(info[0]).trim_suffix(".0"))
	if info[1] != 1.0:
		facts.append(tr("work %s") % ("%+d%%" % roundi((info[1] - 1.0) * 100)))
	if info[2] != 1.0:
		facts.append(tr("stress %s") % ("%+d%%" % roundi((info[2] - 1.0) * 100)))
	if info[3] != 0.0:
		facts.append(link("concept:happiness") + " " + main.signed(info[3]))
	if not facts.is_empty():
		text += "\n" + ", ".join(facts)
	return text


func about_trait(t: int) -> String:
	return tr(main.TRAIT_INFO[t])


func about_skill(s: int) -> String:
	var made := []
	for r in main.RECIPES:
		if r[2] == s and item(r[0]) not in made:
			made.append(item(r[0]))
	var text := tr("Levels 0 to 10: at 0 a job takes half as long again, at 10 half the time. It rises by working.")
	return text + line("Makes:", made)


func about_work(w: int) -> String:
	return tr(main.WORK_INFO[w]) + "\n" + dim(tr("A column of the Jobs window: who does it first."))


func about_concept(name: String) -> String:
	return linked(tr(CONCEPTS[name][1]))

