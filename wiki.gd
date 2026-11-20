# Wiki del gioco: una pagina per argomento, [titolo, testo ricco (BBCode di RichTextLabel)]. La apre il tasto Wiki
# della barra in basso; i numeri vengono da main.gd: se cambiano là, vanno cambiati qui e nelle traduzioni.
# Traduzioni: locale/wiki_<lingua>.gd (per ora wiki_it.gd), con le stesse pagine nello stesso ordine (vedi pages).
const PAGES := [
	["Basics", """[color=#e8c34a]Your lordship[/color]
King is a medieval colony sim. You are the ruler of a small lordship, but you never move anyone by hand: you mark trees to chop and boulders to mine, plan buildings, choose what the workshops make and pass laws. Colonists pick their jobs by themselves, following their needs and their daily routine.

[color=#e8c34a]The start[/color]
• Your ruler, made on the new-game page, and three colonists stand in a clearing. Nothing is built yet: no rooms, no warehouse.
• Next to them, 60 [img=center]res://art/icon_coin.png[/img] lie on the grass: build a warehouse and haulers carry them in (you can only spend what is in a warehouse).
• An abandoned weapon (a sword, an axe or a bow) lies in the grass 15–25 tiles from the clearing.
• Besides the lakes, a stream crosses the map from edge to edge, 22–30 tiles from the clearing: shallow water you can wade (here and there a deep pool), with fish. The water mill stands on its bank (see Crafting & Equipment). Colonies founded before it have no stream.
• From day 10 wolves may come, rarely (see Combat & Wolves).
• If every colonist dies, the colony has fallen.

[color=#e8c34a]Events[/color]
At midnight the narrator picks at most one event for the day, each as often as it is due; it happens at its hour. The chronicle tells it and the calendar marks it.
• Threats: the wolves, announced by their howling (see Combat & Wolves), and the cold wave, which the weather decides two and a half days ahead (see the forecast). Between a threat or a misfortune and the next there are at least 3 days of truce; no threats while someone lies downed or wolves are still around.
• Visits: the wanderers (see Colonists), the wandering scholar (see Knowledge), the livestock dealer (see Livestock), the pilgrim.
• Good fortune: a bumper harvest (summer and autumn, with sown fields, every 40 days on average and never within 30: for 10 days the fields yield half as much again); a herd of 4–6 deer (not in winter, every 25 days: those nobody hunts leave after 2 days); inspiration (a grown-up colonist with at least 60 happiness is Inspired for a day, every 15 days); the pilgrim's gift (with a throne room, every 30 days: a pilgrim walks to the throne, leaves 20–40 [img=center]res://art/icon_coin.png[/img] and +5 authority, then goes).
• Misfortunes: rats (every 25 days and never within 15, when a warehouse or pantry holds at least 20 raw food: they eat a quarter of it, in the one that holds the most); a thief at night (from day 15, every 30 days, with at least 20 [img=center]res://art/icon_coin.png[/img] in the warehouses: with the Night Watch law and the watch awake the thief is caught, +5 authority; otherwise a quarter of the coins go, at most 50); a fever (from day 10, every 20 days, every 10 in winter: a colonist has a Fever for 3 days).
• When the colony struggles (the food in the warehouses lasts less than 3 days, or the average happiness is under 40) good fortune comes twice as often.

[color=#e8c34a]Time[/color]
• The day and the hour are in the top bar, on the right (hover them for the season and the year). The game starts at 8:00 on Crown Day, Year 1; a day lasts 4 minutes at normal speed, an hour 10 seconds.
• The year has 365 days: Crown Day (New Year), then four seasons of three 30-day months, each closed by a feast day outside the months. Spring: Thaw, Sowing, Blossom, then the Flower Feast. Summer: Highsun, Haying, Ripening, then the Sickle Feast. Autumn: Reaping, Leaffall, Mists, then the Hearth Feast. Winter: Frost, Deepsnow, Longnight, then the Candle Feast.
• Night lasts from 18:00 to 6:00: lamps and lanterns light up.
• The speed buttons at the top right: pause, 1x, 2x, 3x. Or the keys: Space pauses (and from pause goes back to 1x), 1, 2 and 3 set the speed. The options menu pauses the game too.
• Times in this wiki are seconds at 1x, for a worker of skill level 5 (see Skills).

[color=#e8c34a]Top bar[/color]
Your arms and the name of your realm (click: the ruler's sheet), the items in your warehouses, colonists (those away on expeditions too), beds and splendor; on the right WOLVES and EXPEDITION when there are any, the day and the hour (hover: season, year and the order you are giving; click: the calendar), the weather, then the speed buttons, full screen, the Wiki and the options.

[color=#e8c34a]Inhabitants[/color]
Click the number of colonists (or its icon) for the list of everyone, group by group, each in a box with the group's color: sex, age and what they are doing right now.
• Colonists, your ruler first, and the babies.
• Foreigners: new colonists still Foreigner (and for how long), wanderers who came to ask to stay, suitors.
• At the inn: the adventurers, with class, level, fee and expeditions, and when they leave if nobody hires them.
• On expeditions: every party, where it went and the day it is due back, adventurers and colonists. Until they are back you don't know how it is going.
Hover a figure for the sheet; click a name to open it. Click the number again to close the list."""],

	["Controls", """[color=#e8c34a]Camera[/color]
• Drag with the right mouse button to move the view; the mouse wheel zooms.
• On a trackpad, two fingers move the view and a pinch zooms.

[color=#e8c34a]Mouse[/color]
• With Select (the arrow), a left click opens things: a colonist's sheet, a room's sign, a workstation's menu, the notice board, a desk (Knowledge) or a throne (Laws). A click elsewhere closes the sheet.
• With an order chosen (Build, Destroy, Mine...), drag a rectangle with the left button to mark the area.
• The box at the bottom right tells what is under the mouse: logs left in a tree, how fresh a pile of food is, and so on.
• Windows can be dragged around; the X closes them.

[color=#e8c34a]Bottom bar[/color]
A key works like a click on its button (press it again to close).
[table=4]
[cell]Select[/cell][cell]Q[/cell][cell]Build[/cell][cell]B[/cell]
[cell]Destroy[/cell][cell]X[/cell][cell]Mine[/cell][cell]M[/cell]
[cell]Chop[/cell][cell]C[/cell][cell]Uproot[/cell][cell]U[/cell]
[cell]Harvest[/cell][cell]H[/cell][cell]Garden[/cell][cell]P[/cell]
[cell]Fish[/cell][cell]F[/cell][cell]Hunt[/cell][cell]T[/cell]
[cell]Jobs[/cell][cell]J[/cell][cell]Resources[/cell][cell]I[/cell]
[cell]Knowledge[/cell][cell]K[/cell][cell]Laws[/cell][cell]G[/cell]
[cell]Rooms lens[/cell][cell]L[/cell][cell]Heat lens[/cell][cell]N[/cell]
[cell]Soil lens[/cell][cell]O[/cell][cell]Cut ice[/cell][cell]Y[/cell]
[cell]Roofs[/cell][cell]V[/cell][cell]Wiki[/cell][cell]F1[/cell]
[cell]Pasture[/cell][cell]A[/cell][cell]Hay[/cell][cell]Z[/cell]
[/table]
• Jobs: who does what first (see Colonists), and the work waiting. Resources: what is in your warehouses.
• Knowledge shows up with your first study, Laws with the throne room. The Wiki button is in the top bar.

[color=#e8c34a]Fixed keys[/color]
• Space: pause; 1, 2, 3: speed.
• E and R: turn the next piece of furniture left or right.
• Esc: the options (also the gear at the top right).

[color=#e8c34a]Options[/color]
• System: language, load another colony, back to the main menu, quit the game. Video: window size and fullscreen (also the screen button at the top right).
• Keybindings: click a command's key, then press the new one. Esc cancels, Delete or Backspace leaves it without a key, Reset restores the defaults. Space, 1-3, E, R and Esc can't be taken. Your keys are saved.
• Debug: to try the game out (Advance 12 hours).

[color=#e8c34a]Saving[/color]
• The game saves by itself: when the colony is founded, at every dawn (6:00), and when you go back to the main menu, quit or close the window. "Saved" shows at the top. There is no saving by hand: a colony is one story.
• Every colony keeps its last 3 saves; if the newest one is damaged, the one before is used.
• On the title screen, Continue picks up the colony you played last and Colonies lists them all, with the realm, the date, the ruler and the colonists. Load game in the options does the same during a game (this colony is saved first); Delete removes a colony with all its saves and asks twice.
• A loaded colony starts paused: Space to go on. A fallen colony is not saved: Continue takes you back to its last dawn."""],

	["Colonists", """Click a colonist for their sheet: health, needs (the arrows show which way each one is going), skills, traits, conditions, equipment and the 24 hours of their routine.

[color=#e8c34a]Needs[/color]
All of them go from 0 to 100.
• Food: -90 a day. Under 30 they go and eat (see Food & Cooking).
• Rest: -100 a day awake. Under 30 they look for a free bed; at 10 they drop everything and sleep where they stand. 8 hours of sleep fill it, at comfort 5.
• Fun: -120 a day awake. Under 30 they take a break, even in work hours: an hour by a campfire, or a stroll nearby.
• Comfort: while asleep it moves toward the comfort of where they lie (see Rooms); outdoors that is 0.
• Stress: +30 a day while working (fighting and fleeing too), +5 for every wolf bite; -60 a day asleep, eating, relaxing or idle. 100 is the limit.
• Happiness: drifts toward the average of food, rest, fun, comfort and calm (100 minus stress), plus or minus conditions and laws. The ruler's happiness sets how much authority they gather.

[color=#e8c34a]Routine[/color]
Every hour is sleep, work or free time. The usual day: sleep 22–6, breakfast at 6, work 7–12 and 13–18 with lunch between, a free evening, and at most 8 hours of work. Traits and laws change it.
• Sleep hours: to bed, or on the ground if no bed is free. They stay down even when rested, then get up with at least 80 rest.
• Work hours: they take jobs. When the shift or their hours are over, they stop as soon as their hands are free. Every hour they also stop for an urgent need: hunger (if there is food), tiredness (if a bed is free), boredom.
• Free time: a snack if food is under 60, then they relax.

[color=#e8c34a]Priorities[/color]
The table at the top of Jobs (J): one row per colonist, one column per kind of work (hover the icons). Each cell is 1 (first) to 4 (last), or – for never; click for later, right click for sooner. At the start everything is 3.
• A colonist takes the work with the best number that has something to do; with equal numbers, the one further left; of each kind of work, the nearest.
• The columns: doctor (only after Medicine), cook, craft (forge, workbench, spinning wheel, carpenter's bench), chop, mine (and cut ice), gather (bushes, flax, herbs, uprooting), farm, fish, hunt, build (and furnish, repair roofs), haul (and bury the dead), govern (only the ruler), study.
• Before the table: picking up equipment; the ruler to the throne and the study's workers to their desks, if you ticked them on the sign. A roof on fire comes before everything, for everyone.

[color=#e8c34a]Health[/color]
• 0–100, healing 30 a day (60 asleep). A bar over the head shows the wounded.
• At 0 a colonist is downed: on the ground, doing nothing, healing 40 a day. At 30 they stand up.
• The dead stay on the ground for 2 days, unless they are buried; their gear drops beside them and the others mourn for 3 days.
• Ointment, the infirmary, doctors and graves: see Medicine & Death.

[color=#e8c34a]Age[/color]
• The sheet shows each colonist's age, next to their sex. The pace of life is chosen on the new-game page: Fast, a year older every season, four times as fast as the calendar, so generations go by (children grow up in 4 years); or Real, a year older every year, like the calendar (16 years to grow up, a pregnancy of 9 true months). The numbers below are in years of life, whichever the pace.
• Your ruler starts between 20 and 30, the other colonists and the adventurers between 18 and 40.
• From 60, on every birthday they may die of old age: 4% at 60, 24% at 70, 44% at 80.

[color=#e8c34a]New colonists[/color]
The colony grows with children (see The Ruler & House), with adventurers who stay (see Adventurers) and with wanderers. Splendor draws people; a crowded colony draws fewer.
• Wanderers come one group at a time from day 10: on average every 30 days, divided by (1 + splendor / 20); above 8 colonists the wait doubles for every 4 more (twice as long at 12, four times at 16). At 15 splendor about every 17 days.
• Alone (70%), a married couple (15%) or a family (15%: a parent or a couple, with a child of 4–11). Adults are 16–45, with 4 skill points and 0–2 traits; one group in four brings a tool (pickaxe, axe, sickle or bow).
• They walk in from the map edge to the throne room (or to a fire, or to the clearing) and ask to stay: Welcome or Send away. Close the window and the question waits on their sheet (Answer…) for 2 days, then they leave. Meanwhile they don't work, eat from your warehouses and sleep at the inn (or on the ground).
• Welcomed, they are colonists, Foreigner for 5 days (-5 happiness, work 10% slower). A family keeps its ties: the couple is married, the child has their parents."""],

	["Skills", """Fifteen skills, with levels from 0 to 10 (a star at 10). Colonists start at 0 and rise by working; your ruler gets 12 points on the new-game page.

[color=#e8c34a]Speed[/color]
A job takes 1.5 times as long at level 0, the normal time at level 5 and half at level 10 (1.4 at level 1, 1.3 at level 2...). Most work also depends on conditions, and sleep, cooking, crafting and study on room comfort.

[color=#e8c34a]What each skill does[/color]
[table=2]
[cell]Gathering[/cell][cell]picking bushes, flax and herbs, the garden[/cell]
[cell]Mining[/cell][cell]mining boulders[/cell]
[cell]Woodcutting[/cell][cell]chopping trees[/cell]
[cell]Construction[/cell][cell]building: 2 s a tile or a piece[/cell]
[cell]Smithing[/cell][cell]at the furnace and the anvil[/cell]
[cell]Tailoring[/cell][cell]spinning wheel and workbench[/cell]
[cell]Cooking[/cell][cell]meals: speed, burnt, fine[/cell]
[cell]Fishing[/cell][cell]casting and catching[/cell]
[cell]Hunting[/cell][cell]aiming and hitting game[/cell]
[cell]Melee[/cell][cell]blows in a fight; dodging bites[/cell]
[cell]Ranged[/cell][cell]bow shots; making bows[/cell]
[cell]Research[/cell][cell]writing pages of study[/cell]
[cell]Lockpicking[/cell][cell]adventurers only: traps, locks[/cell]
[cell]Medicine[/cell][cell]making ointment, treating the sick[/cell]
[cell]Husbandry[/cell][cell]eggs, milking, shearing, slaughtering[/cell]
[/table]
With a bow a hunter aims with the better of Hunting and Ranged. At a workstation a low level ruins more items, at the campfire it burns more meals.

[color=#e8c34a]Experience[/color]
You learn by working, in proportion to the work: 0.28 experience points (XP) for every second of work in this wiki, at every swing of the axe or the pickaxe, berry picked, sowing, cast (even an empty one), piece built or repaired, meal, item, page, shot or blow. A hunting shot counts for Hunting and Ranged. In an 8-hour shift a colonist at level 0 gets about 15 points (fewer when they walk a lot).
• From level n to n+1 takes 10 × (n+1) points: 10 for the first, 150 up to 5, 550 up to 10. Points left over count toward the next level.
• Hover the level on the sheet: the points, and how many are missing for the next.
• Youths (12–15) learn twice as fast. Adventurers grow with their expeditions, not this way."""],

	["Traits", """Colonists have 0–2 traits, never two that clash. Hover a trait in the sheet for its effect.
[table=3]
[cell][color=#d9c48a]Trait[/color][/cell][cell][color=#d9c48a]Effect[/color][/cell][cell][color=#d9c48a]Ruler[/color][/cell]
[cell]Glutton[/cell][cell]hunger +50%, eats at 50[/cell][cell]+2[/cell]
[cell]Sleepwalker[/cell][cell]wanders off asleep[/cell][cell]+2[/cell]
[cell]Hothead[/cell][cell]work stress +50%, tantrums[/cell][cell]+2[/cell]
[cell]Lazy[/cell][cell]works 6 hours at most[/cell][cell]+2[/cell]
[cell]Workaholic[/cell][cell]up to 12 hours, free time too[/cell][cell]-2[/cell]
[cell]Early bird[/cell][cell]2 hours earlier: sleeps 20–4[/cell][cell]0[/cell]
[cell]Night owl[/cell][cell]sleeps 10–18, works at night[/cell][cell]0[/cell]
[cell]Sleepyhead[/cell][cell]sleeps 10 hours, until 8[/cell][cell]+2[/cell]
[cell]Tireless[/cell][cell]sleeps 0–6, tires 25% slower[/cell][cell]-2[/cell]
[cell]Fun-loving[/cell][cell]bored twice as fast, stops at 17[/cell][cell]+2[/cell]
[cell]Ascetic[/cell][cell]never needs fun[/cell][cell]-2[/cell]
[cell]Small appetite[/cell][cell]hunger -40%, never snacks[/cell][cell]-2[/cell]
[cell]Easygoing[/cell][cell]half the stress from work[/cell][cell]-2[/cell]
[cell]Napper[/cell][cell]naps 13–14, to bed at 23[/cell][cell]0[/cell]
[cell]Restless[/cell][cell]an hour off after 2 of work[/cell][cell]+2[/cell]
[/table]
Ruler: the skill points the trait gives (+2) or costs (-2) on the new-game page.

[color=#e8c34a]More[/color]
• Glutton: in free time snacks under 85 food, feels the food conditions twice as much and hates raw food (Ate raw).
• Sleepwalker: every hour of sleep, 1 chance in 10 of walking a few tiles and sleeping there, on the ground.
• Hothead: at 90 stress storms off for two hours, while the stress falls four times as fast.
• Workaholic: also gets bored half as fast.

[color=#e8c34a]Never together[/color]
Glutton and Small appetite, Lazy and Workaholic, Early bird and Night owl, Sleepyhead and Tireless, Fun-loving and Ascetic, Hothead and Easygoing."""],

	["Conditions", """Effects that last a while, shown as icons under the traits in the sheet (hover: what they do and the hours left).
[table=4]
[cell][color=#d9c48a]Condition[/color][/cell][cell][color=#d9c48a]Lasts[/color][/cell][cell][color=#d9c48a]Work[/color][/cell][cell][color=#d9c48a]Happiness[/color][/cell]
[cell]Poisoned[/cell][cell]1 day[/cell][cell]50% slower[/cell][cell]-20[/cell]
[cell]Well fed[/cell][cell]½ day[/cell][cell]10% faster[/cell][cell]+5[/cell]
[cell]Feasted[/cell][cell]½ day[/cell][cell]20% faster[/cell][cell]+10[/cell]
[cell]At table[/cell][cell]½ day[/cell][cell]–[/cell][cell]+5[/cell]
[cell]Ate raw[/cell][cell]½ day[/cell][cell]–[/cell][cell]-10[/cell]
[cell]Mourning[/cell][cell]3 days[/cell][cell]–[/cell][cell]-15[/cell]
[cell]Festive[/cell][cell]3 days[/cell][cell]–[/cell][cell]+10[/cell]
[cell]Wedding[/cell][cell]2 days[/cell][cell]–[/cell][cell]+10[/cell]
[cell]Pregnant[/cell][cell]¾ year of life[/cell][cell]20% slower at the end[/cell][cell]–[/cell]
[cell]Royal mourning[/cell][cell]7 days[/cell][cell]–[/cell][cell]-20[/cell]
[cell]Coronation[/cell][cell]2 days[/cell][cell]–[/cell][cell]+10[/cell]
[cell]Foreigner[/cell][cell]5 days[/cell][cell]10% slower[/cell][cell]-5[/cell]
[cell]Inspired[/cell][cell]1 day[/cell][cell]20% faster[/cell][cell]+5[/cell]
[cell]Fever[/cell][cell]3 days[/cell][cell]50% slower[/cell][cell]-10[/cell]
[cell]Treated[/cell][cell]1 day[/cell][cell]–[/cell][cell]–[/cell]
[cell]Farewell[/cell][cell]as the mourning[/cell][cell]–[/cell][cell]+5[/cell]
[cell]Warmed[/cell][cell]half a day[/cell][cell]–[/cell][cell]–[/cell]
[/table]
• Poisoned: from raw food, more likely the closer it is to rotting.
• Well fed: after a meal; stress from work -25%. Feasted: after a fine meal; stress from work -50%. A new meal replaces the condition of the last one.
• At table: ate sitting on a chair beside a table.
• Ate raw: a glutton who had to eat raw food. A glutton feels Well fed, Feasted, At table and Ate raw twice as much.
• Mourning: a colonist has died; stress from work +25%. A day less once they are buried (see Medicine & Death).
• Festive: after a feast day, with the Harvest feast law (see Laws).
• Wedding: everyone, when the ruler marries.
• Pregnant: in the last third she works 20% more slowly.
• Royal mourning: the ruler has died, instead of Mourning; stress from work +25%. Coronation: everyone, when the new ruler is crowned.
• Foreigner: whoever came from outside and stayed, an adventurer or a wanderer (see Adventurers).
• Inspired: now and then a grown-up colonist with at least 60 happiness has a bright idea (see Basics, Events).
• Fever: now and then a colonist falls ill (see Basics, Events) and tires twice as fast. It doesn't spread; a doctor cures it within half a day.
• Treated: a doctor took care of them; health comes back twice as fast (see Medicine & Death).
• Warmed: had a hot stew; cold and rain take away half as much comfort.
• Farewell: they went to the funeral, with the Funerals law: as long as that mourning lasts, it weighs 5 less (see Medicine & Death).
The laws in force that a colonist likes or dislikes show here too, with their icon."""],

	["The Ruler & House", """[color=#e8c34a]New game[/color]
Two pages come before the map.
• Your House: the house name (your ruler's surname), the colony's name, the pace of life (see Colonists, Age) and the coat of arms: shape, division, field and second field, ordinary and charge, each with its tincture. The dice roll a name or a whole coat of arms.
• Your Ruler: name, an optional nickname, sex, hair and its color, a beard (men only), tunic and cape (they follow the first two tinctures of the arms until you pick them), up to 2 traits that don't clash, and 12 skill points, at most 3 in one skill (no Lockpicking).
• Traits move points: flaws give 2 (Glutton, Sleepwalker, Hothead, Lazy, Sleepyhead, Fun-loving, Restless), virtues cost 2 (Workaholic, Tireless, Ascetic, Small appetite, Easygoing); Early bird, Night owl and Napper are free.
The other two colonists come at random: skills at 0, 0–2 traits.

[color=#e8c34a]In the game[/color] [img=center]res://art/icon_crown.png[/img]
• The ruler is the first colonist and lives like the others: needs, routine, work, fights. They can die.
• Title: Lord or Lady. The top bar shows "Lordship of" your colony, beside your arms: click it for the ruler's sheet. Banners fly your arms.
• Only the ruler governs: on a throne, in a throne room, they gather authority for the laws (see Laws). A happy ruler (70 or more) gathers 25% more, a gloomy one (30 or less) half.
• The title grows with the colony, never goes down, and passes to the heir. It needs both splendor and colonists (children and those on expeditions count; babies and adventurers don't):
[table=5]
[cell][color=#d9c48a]Title[/color][/cell][cell][color=#d9c48a]Splendor[/color][/cell][cell][color=#d9c48a]Colonists[/color][/cell][cell][color=#d9c48a]Seals[/color][/cell][cell][color=#d9c48a]Authority a day[/color][/cell]
[cell]Lordship[/cell][cell]–[/cell][cell]–[/cell][cell]2[/cell][cell]+1[/cell]
[cell]Barony[/cell][cell]15[/cell][cell]6[/cell][cell]3[/cell][cell]+2[/cell]
[cell]County[/cell][cell]35[/cell][cell]10[/cell][cell]4[/cell][cell]+3[/cell]
[cell]Kingdom[/cell][cell]60[/cell][cell]15[/cell][cell]5[/cell][cell]+4[/cell]
[/table]
A window and the chronicle announce it; the realm's name, the ruler's title and the crown on the arms change. The Laws window shows what the next title needs.

[color=#e8c34a]Marriage[/color]
• An adult ruler (16 or older) without a living spouse can marry: "Arrange a marriage…" on the ruler's sheet lists the adult colonists of the other sex without a spouse. Those with less than 50 happiness say no, and the list tells you why.
• The wedding: everyone gets Wedding (+10 happiness for 2 days), +10 authority, and the chronicle tells it. Each spouse may enter the other's rooms. The sheet shows the spouse, with a cross once they have died: a widowed ruler can marry again.
• Give the couple a room with two beds: children will come from sharing it.
• Suitors: while the ruler can marry and there is an inn, about every 20 days someone of the other sex from another house comes to the inn, with their arms and a dowry (20–80 coins, sometimes a notebook, ingots or steel). They wait 5 days and always say yes: married, they become a colonist and the dowry stays in the colony. They sleep in the inn's beds and don't work.

[color=#e8c34a]Children[/color] [img=center]res://art/baby.png[/img]
• A married couple sleeping in the same room may have a child: 1% a night, while she is 16 to 40 (half from 35). She is Pregnant for three quarters of a year of life (68 days at the fast pace, 274 at the real one), working more slowly in the last third, then for a year of life no other child.
• The chronicle tells the birth and a window asks for the name (the dice rolls one). The child takes the house's name and colors, the hair of a parent, and each of their traits at 50% (at most two, never clashing).
• Up to 3 a baby: not a colonist yet. They sleep in a cradle (Home, 4 wood), their parents' first, or the mother carries them.
• From 4 a child: they only gather and haul, at half speed, take no weapons or armor and always run from wolves. They look smaller.
• From 12 a youth: everything but building, mining, chopping and hunting.
• At 16 they come of age: every kind of work, and some boys grow a beard.
• The parents' sheet lists their children, the children's sheet their parents.

[color=#e8c34a]Succession[/color]
• When the ruler dies, the crown goes to their eldest living child, boy or girl; without children to their living spouse, then to a brother or sister.
• Everyone gets Royal mourning for 7 days; then the heir is crowned: Coronation for everyone and +20 authority.
• An heir under 16 waits with a regent: a living parent, or else the adult with the most skills. The regent governs and their title is Regent; the heir's sheet says "Heir of". On their 16th birthday the heir is crowned. If the regent dies another takes over; if the heir dies, the next in line.
• "The house…" on a colonist's sheet opens the family tree: the rulers in order, grouped by house, each with their years of reign, spouse and children (the dead with a cross), and the regent if there is one.
• Nobody left: the house is over. A window asks who will rule among the adults (the one with the most skills, until you choose): their house begins, with their surname and new arms. The title stays with the realm."""],

	["Building", """[color=#e8c34a]How to build[/color] [img=center]res://art/icon_wood.png[/img] [img=center]res://art/icon_stone.png[/img]
• Press Build, pick Structures or one of the five furniture categories (Home; Fire and warmth; Crafts and stores; Court and defense; Decorations, with the relics), then a piece: hover its button for the cost and the comfort or splendor it gives.
• Walls and floors are made of wood or stone (stone after the Masonry research). Doors, furniture and decorations have their own material.
• Drag on the map: the plan shows in blue. Walls go only along the border of the rectangle, so one drag outlines a room; floors, paths and doors fill it. Drawing over your unconfirmed plan replaces it: that is how to put a door into a wall you are planning.
• Furniture goes one piece at a time, where you let go of the button. E and R (or the arrows in the bar) turn it; the preview is red where it doesn't fit.
• Press Build in the middle of the bottom to confirm: only then do colonists start. The red X erases cells from the plan, even confirmed ones. Closing Build without confirming throws the plan away.
• The builder fetches the material from a pile (on the ground or in a warehouse) and needs 2 s a tile or a piece. A piece made of two materials (lamp, lantern) takes a trip for each: what is already there waits at the site, and goes back on the ground if you cancel the plan.
• Destroy (X): drag over structures and furniture to pull them down at once. The material is lost.
• Pieces you haven't researched yet have no button.

[color=#e8c34a]Where[/color]
Not on water, trees, rock, bushes or weeds (uproot them first), nor on items lying on the ground. Furniture stands on bare ground, floors and paths, never on other furniture; walls and doors never on furniture.

[color=#e8c34a]Structures[/color]
[table=3]
[cell]Wall[/cell][cell]5 wood or stone a tile[/cell][cell]blocks the way[/cell]
[cell]Floor[/cell][cell]2 wood or stone a tile[/cell][cell]room comfort[/cell]
[cell]Door[/cell][cell]5 wood[/cell][cell]rooms need one[/cell]
[cell]Path[/cell][cell]1 stone a tile[/cell][cell]trodden earth[/cell]
[cell]Plaster[/cell][cell]1 stone a tile[/cell][cell]over a wooden wall: insulates more[/cell]
[/table]

[color=#e8c34a]Furniture[/color]
[table=3]
[cell][color=#d9c48a]Piece[/color][/cell][cell][color=#d9c48a]Cost[/color][/cell][cell][color=#d9c48a]Research[/color][/cell]
[cell]Bed (2x1)[/cell][cell]10 wood[/cell][cell]–[/cell]
[cell]Table (2x2)[/cell][cell]10 wood[/cell][cell]–[/cell]
[cell]Chair[/cell][cell]3 wood[/cell][cell]–[/cell]
[cell]Campfire[/cell][cell]5 wood[/cell][cell]–[/cell]
[cell]Desk[/cell][cell]10 wood[/cell][cell]–[/cell]
[cell]Throne[/cell][cell]12 wood[/cell][cell]–[/cell]
[cell]Lamp[/cell][cell]2 wood, 1 coal[/cell][cell]Lanterns[/cell]
[cell]Furnace[/cell][cell]20 stone[/cell][cell]Forge[/cell]
[cell]Anvil[/cell][cell]10 iron[/cell][cell]Forge[/cell]
[cell]Workbench[/cell][cell]15 wood[/cell][cell]Tailoring[/cell]
[cell]Spinning wheel[/cell][cell]10 wood[/cell][cell]Hunting[/cell]
[cell]Carpenter bench[/cell][cell]15 wood[/cell][cell]Hunting[/cell]
[cell]Notice board[/cell][cell]8 wood[/cell][cell]Inn[/cell]
[cell]Bookshelf[/cell][cell]12 wood[/cell][cell]Bookshelf[/cell]
[cell]Hearth[/cell][cell]15 stone[/cell][cell]Masonry[/cell]
[cell]Wall hides[/cell][cell]2 hides[/cell][cell]Hunting[/cell]
[cell]Door curtain[/cell][cell]2 hides[/cell][cell]Hunting[/cell]
[cell]Tapestry[/cell][cell]4 flax[/cell][cell]Loom[/cell]
[cell]Tiled stove[/cell][cell]20 stone[/cell][cell]Tiled stove[/cell]
[cell]Ice pit (2x2)[/cell][cell]20 stone[/cell][cell]Icehouse[/cell]
[cell]Compost heap[/cell][cell]6 wood[/cell][cell]Manuring[/cell]
[cell]Cradle[/cell][cell]4 wood[/cell][cell]–[/cell]
[cell]Training dummy[/cell][cell]6 wood[/cell][cell]Training dummy[/cell]
[cell]Weapon rack[/cell][cell]6 wood, 1 ingot[/cell][cell]Barracks[/cell]
[cell]Target[/cell][cell]4 wood, 2 flax[/cell][cell]Barracks[/cell]
[cell]Lock bench[/cell][cell]4 wood, 2 ingots[/cell][cell]Barracks[/cell]
[cell]Medicine chest[/cell][cell]8 wood[/cell][cell]Medicine[/cell]
[cell]Grave (1x2)[/cell][cell]4 wood[/cell][cell]–[/cell]
[/table]
Hearth, hides, tapestry and tiled stove hang against a wall at their back, the curtain against a door: turn them toward it. Decorations: see Splendor."""],

	["Rooms", """A room is an area closed by walls (rock and deep water count too) with at least one door to the outside, smaller than 400 tiles. Once it's finished a sign appears on the wall by the door: click it to name the room, see its comfort, choose its type, ban it and tick its owners or workers.

[color=#e8c34a]Types[/color]
The list shows only the types whose furniture is inside. Take that furniture away and the room loses its type, with its owners or workers.
[table=3]
[cell][color=#d9c48a]Type[/color][/cell][cell][color=#d9c48a]Needs[/color][/cell][cell][color=#d9c48a]Kind[/color][/cell]
[cell]Warehouse[/cell][cell]nothing[/cell][cell]service[/cell]
[cell]Bedroom[/cell][cell]1 bed[/cell][cell]residence[/cell]
[cell]Dormitory[/cell][cell]2 beds[/cell][cell]residence[/cell]
[cell]Kitchen[/cell][cell]campfire or hearth[/cell][cell]work[/cell]
[cell]Forge[/cell][cell]furnace, anvil[/cell][cell]work[/cell]
[cell]Workshop[/cell][cell]workbench[/cell][cell]work[/cell]
[cell]Carpentry[/cell][cell]carpenter bench[/cell][cell]work[/cell]
[cell]Inn[/cell][cell]bed, table, notice board[/cell][cell]service[/cell]
[cell]Study[/cell][cell]desk[/cell][cell]work[/cell]
[cell]Throne room[/cell][cell]throne[/cell][cell]work[/cell]
[cell]Icehouse[/cell][cell]ice pit; stone walls, no fire[/cell][cell]service[/cell]
[cell]Armory[/cell][cell]2 training dummies, weapon rack[/cell][cell]work[/cell]
[cell]Archery range[/cell][cell]2 targets; at least 8 tiles long[/cell][cell]work[/cell]
[cell]Infirmary[/cell][cell]bed, medicine chest[/cell][cell]service[/cell]
[cell]Stable[/cell][cell]manger[/cell][cell]service[/cell]
[/table]
• Residence: it can have owners. One with owners is closed to everyone else, even just to walk through.
• Work: it can have workers. For now they matter in a study (they study before any other job) and in a throne room (only the ruler).
• Service: shared by all.
• Banned: nobody goes in, not even the owners.
• Workstations work only inside their room: the campfire in a kitchen, furnace and anvil in a forge, workbench and spinning wheel in a workshop, the carpenter bench in a carpentry.
• Colonists sleep in any bed but those of an inn, which are for adventurers, and those of an infirmary, which are for the sick.

[color=#e8c34a]Warehouses[/color]
Haulers carry loose items into warehouses, 10 at a time; with no warehouse nobody hauls. Only what is in a warehouse counts as stored: the top bar, Resources, the coins you pay, the books for research. A tile holds one kind of item: 100 wood or coins, 50 of most materials and raw food, 20 meals, 10 tools, weapons, armor or books, 5 relics. Food rots half as fast inside, and slower still in the cold (see Roofs & Heat).

[color=#e8c34a]Comfort[/color]
0–10, shown on the sign. Bed and table +1; chair, lamp, campfire, hearth and bench +0.5; a floor +1 if it paves the whole room (half the room, half a point); stone counts 1.5 times. Outdoors it is 0.
At 5 nothing changes. Below, sleep, cooking, crafting and study take longer (20% at 0); above, less (20% at 10). Low comfort also burns meals and ruins items more often. With fewer than 6 tiles for each person in the room, comfort drops in proportion.

[color=#e8c34a]Rooms lens[/color]
The Rooms lens (L) tints every room with the color of its type and shows its owners or workers: hover them for their sheet."""],

	["Roofs & Heat", """[color=#e8c34a]Roofs[/color]
• Every finished room gets its own roof over its walls and doors; V lifts them all to look inside. Roofs have height: they rise over the room and can hide up to three tiles behind it. An L-shaped room gets two roofs. The ridge runs along the long side: a roof taller than wide has it north to south and a gable over the front wall; a wide one east to west, with a small gable over the door if the house is at least 7 tiles wide and 4 deep.
• With roofs on, the front wall is a tall facade: half-timbering on wood, coursed stone on stone, a window every two tiles, an arched door.
• Whoever walks behind a house shows through a round hole in its roof; those inside stay covered, except the colonist whose sheet is open.
• Roofs follow the walls: shingles over wooden walls, clay tiles over stone (the majority of the room's walls; doors count as wood).
• Snow lies on roofs as on the ground, but the heat leaking out of a warm room melts it, first around the chimneys. Wet roofs are darker, eaves drip in the rain and grow icicles below zero.

[color=#e8c34a]Wear and repairs[/color]
• Every roof tile wears with time, shingles twice as fast as tiles: lichens first, then shifted tiles and moss, at last a hole with the rafters showing. Without storms a shingle tile lasts about a year, a clay one two.
• Storms tear tiles off, and the chronicle says so; heavy snow on a wide roof that doesn't melt it can break through.
• Under a hole it rains and snows, it is as cold as outside and food rots as in the open.
• Worn tiles are a job for builders (Repair): 1 wood for shingles, 1 stone for tiles, 3 s each.

[color=#e8c34a]Temperature[/color]
• Under a roof a room moves from the outdoor temperature toward 15 °C (5 °C in warehouses and pantries, 0 °C in an icehouse with ice) as much as its walls insulate: wood and doors 50%, plastered wood 60%, stone 70%, rock 85%. Hides on the walls (+5% each, up to 3), a curtain at the door (+10%) and tapestries (+5% each, up to 3) add to it, up to 90%.
• Fires add heat: campfire +8 °C, hearth +12, furnace +15, tiled stove +10. The hearth and the furnace pass half their heat to the room behind the wooden wall at their back; stone stops it. The tiled stove passes all of it, through stone too.
• In summer a fountain takes 3 °C off its room when it's hotter than 20 °C outside.
• Below 12 °C, every 4 °C take a point of comfort. The canopy bed's curtains keep 4 °C more for whoever sleeps in it.
• The room sign shows the degrees; hover it for the reckoning.

[color=#e8c34a]Heat lens[/color]
The Heat lens (N) tints rooms by temperature: red warm, yellow cool without a malus, then blues for every point of comfort the cold takes, white below zero (food doesn't rot there). It shows the degrees and the malus of every room, how much every fire heats, an arrow where heat goes through a wall and a cross where stone stops it. Hover a room for the reckoning. It turns itself on while you place a fire, a piece that insulates or plaster.

[color=#e8c34a]Hearth and chimneys[/color]
• The hearth (Masonry, 15 stone) goes against a wall and does what a campfire does: a kitchen takes either, the same recipes, colonists gather around it. Smoking is a quarter faster at a campfire, where the smoke stays.
• Hearths and furnaces have a stone chimney on the wall at their back, a campfire under a roof a wooden vent. Smoke rises from there: thin when the fire is idle, thicker while cooking, dark from the furnace, dense while smoking.

[color=#e8c34a]Food and the cold[/color]
• Food rots in proportion to the temperature: at full pace at 15 °C, twice as fast at 30 °C, not at all at 0 °C or below. A warehouse halves it, a pantry or an icehouse cuts it to a third.
• The icehouse (Icehouse research): stone or rock walls, no fire, an ice pit. Mark water with the Ice order (Y): when it freezes, colonists cut blocks (Mining) while the pits have room, and haulers bring them to the pits. While there is ice the room tends to 0 °C. Ice melts with the heat that gets through the walls, and faster under a hole in the roof.

[color=#e8c34a]Fire[/color]
• A campfire under a shingle roof can set it alight (2% a day), and so can lightning in a storm. A burning tile burns for 4 hours and becomes a hole; meanwhile the fire passes to the shingles beside it, of other roofs too. Clay tiles don't burn.
• Everyone fights a fire first: they fetch a bucket at the water and throw it, 2 hours off the fire each."""],

	["Food & Cooking", """[color=#e8c34a]Eating[/color]
• Hungry colonists (under 30 food; the glutton at 50) take the nearest food: fine meals first, then stew, meals, bread, cheese, raw food only when there is none of those (vegetables, fish, meat, smoked, then turnips, cabbages, beans and preserves, which keep longer). In free time they also snack under 60.
• If a chair beside a table is free within 20 tiles, they carry the food there and eat sitting: +5 happiness (At table).

[color=#e8c34a]Food[/color]
[table=4]
[cell][color=#d9c48a]Food[/color][/cell][cell][color=#d9c48a]Fills[/color][/cell][cell][color=#d9c48a]Lasts[/color][/cell][cell][color=#d9c48a]Poison[/color][/cell]
[cell][img=center]res://art/icon_veg.png[/img] Vegetables[/cell][cell]35[/cell][cell]3 days[/cell][cell]5–40%[/cell]
[cell][img=center]res://art/icon_fish.png[/img] Fish[/cell][cell]30[/cell][cell]1.5 days[/cell][cell]10–50%[/cell]
[cell][img=center]res://art/icon_meat.png[/img] Meat[/cell][cell]40[/cell][cell]2 days[/cell][cell]15–60%[/cell]
[cell][img=center]res://art/icon_turnip.png[/img] Turnip[/cell][cell]35[/cell][cell]10 days[/cell][cell]2–30%[/cell]
[cell][img=center]res://art/icon_cabbage.png[/img] Cabbage[/cell][cell]35[/cell][cell]14 days[/cell][cell]2–30%[/cell]
[cell][img=center]res://art/icon_beans.png[/img] Beans[/cell][cell]40[/cell][cell]60 days[/cell][cell]1–15%[/cell]
[cell][img=center]res://art/icon_meal.png[/img] Meal[/cell][cell]100[/cell][cell]3 days[/cell][cell]–[/cell]
[cell][img=center]res://art/icon_fine_meal.png[/img] Fine meal[/cell][cell]100[/cell][cell]3 days[/cell][cell]–[/cell]
[cell][img=center]res://art/icon_stew.png[/img] Stew[/cell][cell]100[/cell][cell]3 days[/cell][cell]–[/cell]
[cell][img=center]res://art/icon_bread.png[/img] Bread[/cell][cell]60[/cell][cell]8 days[/cell][cell]–[/cell]
[cell][img=center]res://art/icon_preserves.png[/img] Preserves[/cell][cell]35[/cell][cell]120 days[/cell][cell]1–10%[/cell]
[cell][img=center]res://art/icon_egg.png[/img] Eggs[/cell][cell]25[/cell][cell]10 days[/cell][cell]5–30%[/cell]
[cell][img=center]res://art/icon_milk.png[/img] Milk[/cell][cell]20[/cell][cell]1 day[/cell][cell]5–40%[/cell]
[cell][img=center]res://art/icon_cheese.png[/img] Cheese[/cell][cell]50[/cell][cell]60 days[/cell][cell]–[/cell]
[/table]
• Lasts: on the ground outdoors at 15 °C; in a warehouse twice as long. Warmer it rots faster, colder slower, below zero not at all (see Roofs & Heat). Then the pile rots away. Piles that mix take the average freshness. Hover a pile: Fresh, Stale or Almost rotten, and the days left.
• Raw food may leave you Poisoned: the lower chance when it's fresh, the higher when it's almost rotten.
• A meal makes you Well fed, a fine meal Feasted (see Conditions). Stew makes you Well fed and Warmed: for half a day cold and rain take away half as much comfort. Bread only fills you up. Preserves are eaten and cooked like raw food.

[color=#e8c34a]Cooking[/color]
• At a campfire or a hearth inside a kitchen. The cook takes 2 raw foods from one pile (vegetables, fish or meat), cooks for 8 s and carries the meal to a warehouse.
• Click the campfire: Keep N meals (8 at the start, 2 a head). Cooks cook while there are fewer meals than that, counting those on the ground, in warehouses and in hand.
• Burnt, and the food is lost: 6% for every Cooking level below 6, plus 3% for every point of kitchen comfort below 5 (minus above). At level 0 in a kitchen of comfort 5: 36%.
• Fine meal: 5% for every level above 5, plus 2% for every point of comfort above 5 (minus below): 25% at level 10.
• The time also depends on the kitchen's comfort and the cook's conditions.

[color=#e8c34a]The stone oven[/color] [img=center]res://art/icon_bread.png[/img]
After the Stone oven research (Land II): 2x1, 20 stone, in a kitchen; it warms the room like a campfire. Click it for its menu: bread from 2 flour (3 loaves, 10 s; Keep 8 at the start), stew from 2 vegetables of one kind (berries, turnips, cabbages or beans) and 1 meat or fish, smoked too (2 stews, 12 s), preserves from 2 vegetables of one kind (2 jars, 10 s). It takes first what rots first. Burnt and fine as at the fire: a fine stew comes out as fine meals."""],

	["Gathering", """Mark what to take with the orders of the bottom bar, dragging a rectangle; marked things carry a faint icon. What is gathered falls at the worker's feet, and when the job is done they carry it to a warehouse.

[color=#e8c34a]Chop (C)[/color] [img=center]res://art/icon_wood.png[/img]
Trees: oak 28 wood, pine 35, birch 20. A stroke every 10 s gives 5.

[color=#e8c34a]Mine (M)[/color] [img=center]res://art/icon_stone.png[/img]
Boulders of 1x1, 2x1 or 2x2 tiles, 5 stone a tile. A stroke every 15 s gives 5. Iron and coal veins are 1x1 boulders (hover: "Iron vein", "Coal vein") that give 5 iron or 5 coal instead of stone.

[color=#e8c34a]Uproot (U)[/color]
Weeds, bushes, flax and herbs go in 1.5 s. Clear them before building there.

[color=#e8c34a]Harvest (H)[/color] [img=center]res://art/icon_veg.png[/img] [img=center]res://art/icon_flax.png[/img] [img=center]res://art/icon_herbs.png[/img]
Bushes, flax and medicinal herbs. A ripe bush has 5 berries (vegetables), flowering flax 5 flax, flowering herbs 5 herbs, picked one every 5 s. Nothing flowers in winter. They grow back in 2 days and the mark stays: they are picked every time. Marking Uproot removes the Harvest mark, and the other way round.

[color=#e8c34a]Garden (P)[/color] [img=center]res://art/icon_veg.png[/img]
• After the Garden research. Drag over open grass, outside rooms, to make garden plots: weeds and bushes have to go first, and nothing can be built on a plot. Turnips and cabbages grow in alternate rows.
• A colonist sows a plot in 4 s (Gathering, like every job time). Turnips ripen in 60 days, cabbages in 90, broad beans in 100; then the plot is sown again. On average soil a plot gives 30 turnips, 45 cabbages or 20 beans.
• Turnips and cabbages keep far longer than berries, dried beans longest of all: the winter food (see Food).
• With the Mill research, grain too [img=center]res://art/icon_grain.png[/img]: 100 days, 25 a plot, and it tires the soil (−12). Grain is not eaten and never rots: the miller grinds it into flour.

[color=#e8c34a]Fields and rotation[/color]
• Garden plots that touch make a field, with a sign on its top left plot. Click the field: its name, its timeline for this year, what it grows next year, the last harvest; "Plan the fields…" opens the planning.
• The planning is a chart of the year, one row per field: every crop is a bar as long as it grows, sown on its day. Striped, the cold soil before late Thaw; blue, winter. Click an empty spot to add a crop: it starts right after the one before, and the crops that would not end before winter (or before the next one) are greyed out. Click a crop to change it or remove it, a field's name for ready rotations (turnips every year; the classic one: cabbages, then turnips, then beans, then a fallow year) and for the cycle, one to four years. ◀ ▶ show the years ahead.
• At New Year every field moves to the next year of its cycle. A colonist sows a crop on its day, as soon as the plot is free and the soil mild; a crop that would no longer ripen before winter is skipped. What is already sown finishes growing; new plots next to a field take its plan. Without a plan, turnips, as many as fit in the year.

[color=#e8c34a]The soil[/color]
• Every tile has its own fertility, which you can't see. It is richer near water and poorer beside rock; felling a tree leaves rich humus. The richer the soil, the bigger the harvest.
• Every harvest tires the soil: cabbages most, turnips less, while beans give it back. At New Year the garden rests, and a plot with no harvest all year (fallow) recovers a lot.
• The same crop twice in a row on a plot gives a quarter less, from the third time half: alternate them.
• Hints: on poor soil the plants grow pale and yellowish; the sign says the last harvest a plot; at the Hearth Feast the chronicle sums up the year's harvest, with the year before.
• Farmers learn: a colonist with Gathering 5 or more knows the soil of the plots they sow or harvest, and the sign says what the farmers think of it (poor, average, rich).
• Research shows it: Soil survey gives the soil lens (O), poor, average or rich on every tile, and the band on the signs; the Almanac five bands, and whether a field is growing richer or poorer than a year ago; the Land register the exact numbers (on the lens, close up) and the next harvest of every field.
• Sowing starts when the ground is mild (a daily average of 6 °C, from late Thaw) and only if the crop ripens before winter: cabbages are not sown in the last 90 days before winter, turnips in the last 60. On the first day of winter the frost takes whatever is still in the fields.
• Destroy (X) removes plots.

[color=#e8c34a]Manure[/color] [img=center]res://art/icon_compost.png[/img]
• After the Manuring research (Land I, 80, after Garden). Build a compost heap (6 wood): from then on rotten food and uprooted weeds become rot [img=center]res://art/icon_rot.png[/img], which haulers take to the heap; left outside, it seeps into the ground in 5 days. In the heap, in 10 days every 4 rot make a compost.
• The charcoal kiln leaves an ash [img=center]res://art/icon_ash.png[/img] every time.
• Farmers fertilize: from 15 days before a plot is sown they spread a compost on it (+15 fertility), or an ash when the compost is gone (+5). Once for every sowing. Untick "Fertilize before sowing" on a field's sign to skip it.
• Green manure: a crop of the planning, 60 days. Beans not harvested but ploughed in while flowering: no food, but +20 fertility, twice as much as the beans you eat.

[color=#e8c34a]Fish (F)[/color] [img=center]res://art/icon_fish.png[/img]
Mark water tiles. The fisher stands beside them (in shallow water too) and casts every 10 s: a fish 30% of the time, +6% for every Fishing level. A spot has 4 fish, then it's empty for a day; the mark stays.

[color=#e8c34a]Hunt (T)[/color] [img=center]res://art/icon_meat.png[/img] [img=center]res://art/icon_hide.png[/img]
• Drag over animals to mark them. Hunting needs a bow: a hunter without one fetches a free bow and puts down what they held. If there is none, a bow gets made, once you can make them (Jobs says "needs a bow").
• The hunter shoots from up to 8 tiles, aiming 4 s a shot. To hit: 30%, +5% a level, -5% for every tile of distance; then +10% for the bow and +5% for a leather hood.
• An arrow does 14 damage. Hit or missed, the animal runs 8 tiles away at double speed, and the hunter follows. Killed, it leaves meat and hide.
[table=4]
[cell][color=#d9c48a]Animal[/color][/cell][cell][color=#d9c48a]Health[/color][/cell][cell][color=#d9c48a]Meat, hide[/color][/cell][cell][color=#d9c48a]Speed[/color][/cell]
[cell]Rabbit[/cell][cell]10[/cell][cell]3, 1[/cell][cell]2 tiles/s[/cell]
[cell]Deer[/cell][cell]20[/cell][cell]10, 3[/cell][cell]1.5 tiles/s[/cell]
[cell]Wolf[/cell][cell]30[/cell][cell]5, 2[/cell][cell]3 tiles/s[/cell]
[/table]
Animals roam outside rooms and water, born more than 15 tiles from the clearing: 6 rabbits and 3 deer at first, then a new one every half day while there are fewer than 12. A marked wolf, shot at, attacks the hunter."""],

	["Livestock", """[color=#e8c34a]The pasture (A)[/color] [img=center]res://art/icon_pasture.png[/img]
• After the Husbandry research (Land I, 100, after Hunting). Drag over open grass, outside rooms, like the garden: a fence draws itself along the edge, for free. Destroy removes it. Nothing is built on a pasture but the coop.
• Every tile has its grass, up to 100: it grows back 20 a day when the soil is mild (as for sowing), not in winter. The more it is grazed, the more earth shows. Hover a tile for its grass; click it for the herd.

[color=#e8c34a]The animals[/color]
[table=6]
[cell][color=#d9c48a]Animal[/color][/cell][cell][color=#d9c48a]A pair[/color][/cell][cell][color=#d9c48a]Pasture[/color][/cell][cell][color=#d9c48a]Young[/color][/cell][cell][color=#d9c48a]Gives[/color][/cell][cell][color=#d9c48a]Slaughtered[/color][/cell]
[cell]Hen[/cell][cell]12 [img=center]res://art/icon_coin.png[/img][/cell][cell]1 tile[/cell][cell]3 chicks every 30 days[/cell][cell]an egg a day[/cell][cell]2 meat[/cell]
[cell]Pig[/cell][cell]30 [img=center]res://art/icon_coin.png[/img][/cell][cell]2 tiles[/cell][cell]4 piglets every 60 days[/cell][cell]–[/cell][cell]15 meat, 1 hide[/cell]
[cell]Sheep[/cell][cell]30 [img=center]res://art/icon_coin.png[/img][/cell][cell]2 tiles[/cell][cell]a lamb a year, in spring[/cell][cell]milk every 2 days, 3 wool a year[/cell][cell]6 meat, 2 hides[/cell]
[cell]Cow[/cell][cell]60 [img=center]res://art/icon_coin.png[/img][/cell][cell]4 tiles[/cell][cell]a calf a year, in spring[/cell][cell]2 milk a day[/cell][cell]20 meat, 4 hides[/cell]
[/table]
Sheep and cows only after the Stable research; calves grow up in 60 days.
• They stay in the pasture, walking toward the grass. Every animal loses 50 fed a day and gets it back grazing: it needs the grass of its pasture tiles (20 each a day). Hover an animal: sex, age, how fed it is.
• Young: a fed grown-up female (30 or more), a fed grown-up male of her kind, and room in the pasture (young count too). They grow up in 30 days and are drawn smaller.
• At 0 fed for 3 days an animal starves to death; the chronicle tells of it. In winter the grass doesn't grow back.
• Wolves go after the animals in the pasture too. A pasture closed by a palisade (with its gate) is safe.

[color=#e8c34a]The livestock dealer[/color]
With a pasture, from Thaw to the end of autumn, every 15 days or so he stops for a day (from 9:00). Click the pasture: he sells 2–3 pairs (a male and a female, grown up) at the price above, and buys a grown-up for a quarter of the price of a pair. You pay and get paid in [img=center]res://art/icon_coin.png[/img] from the warehouses. What you buy goes into the pasture.

[color=#e8c34a]The coop[/color] [img=center]res://art/icon_egg.png[/img]
2x1, 8 wood, only on the pasture. At dawn, outside winter, every grown-up fed hen lays an egg in a coop: 8 hens a coop; a coop holds 12 eggs. Without a coop, no eggs. Eggs are raw food: 25, they keep 10 days, 5–30% poison; they cook into meals.

[color=#e8c34a]Husbandry (the column)[/color]
Whoever has the Husbandry column, in this order:
• collects the eggs at the coop (2 s) and carries them to a warehouse;
• milks grown-up ewes and cows (5 s), milk and all;
• in summer shears the grown-up sheep, once a year (10 s): 3 wool each;
• slaughters the animals beyond those you keep (8 s): click the pasture, Keep N grown-ups for each kind (6 at the start). Spare males go first (one is kept), then the oldest; never the young. Meat and hide fall on the spot.
All of it teaches the Husbandry skill. Milk is raw food (20, keeps a day); at the campfire 3 milk make a cheese (10 s): 50, it keeps 60 days. The livestock dealer buys wool (4 [img=center]res://art/icon_coin.png[/img] each) and cheese (6), all you have in the warehouses.

[color=#e8c34a]Hay (Z)[/color] [img=center]res://art/icon_hay.png[/img]
After the Stable research (Land II, 250 and a notebook, after Husbandry). Mark open meadow outside the pasture: from sowing time to the end of summer the farmers (the Farm column) mow the tiles where the grass is tall, 3 s a tile (a sickle is 25% faster): 4 hay each. The grass grows back in 20 days; the mark stays. Hay never rots.

[color=#e8c34a]The stable[/color]
A room with at least one manger (2x1, 6 wood). Haulers carry hay to the mangers, 20 a tile, even from the warehouses. In winter, and while it snows, the animals go into the stable: a cow takes 4 tiles, a sheep or a pig 2; the bigger ones first. There they eat hay: a cow 3 a day, a sheep or a pig 1; hens stay by the coop and eat ¼ from any manger. Whoever has no place stays out in the cold and gets hungry twice as fast. Hover an animal for its winter stall.
In the stable the animals leave manure (a cow 1 a day, a sheep or a pig 1 every 2 days, hens 1 every 4): haulers carry it to a warehouse, and farmers spread it before sowing, before compost and ash: +20 fertility."""],

	["Crafting & Equipment", """[color=#e8c34a]Workstations[/color]
Click a station for its menu: one row for every recipe you know, with its ingredients and Keep N. Things get made while there are fewer than N around (on the ground, in warehouses, in hand, being made); Keep counts for every station of the kind. Equipment is also made for the colonists with an empty slot, and a bow when animals are marked and nobody has one. At the start: Keep 10 ingots, 2 bowstrings, 3 ointments, 10 flour, 8 bread, 8 meals, 0 of the rest.
The crafter brings the ingredients one by one, then works. The time depends on skill, room comfort and conditions; an item may be ruined, losing the ingredients, as often as a meal burns.
[table=4]
[cell][color=#d9c48a]Item[/color][/cell][cell][color=#d9c48a]Station[/color][/cell][cell][color=#d9c48a]Needs[/color][/cell][cell][color=#d9c48a]Time[/color][/cell]
[cell]Ingot[/cell][cell]furnace[/cell][cell]1 iron, 1 coal[/cell][cell]6 s[/cell]
[cell]Bowstring[/cell][cell]spinning wheel[/cell][cell]2 flax[/cell][cell]8 s[/cell]
[cell]Leather armor[/cell][cell]workbench[/cell][cell]4 hide[/cell][cell]20 s[/cell]
[cell]Leather hood[/cell][cell]workbench[/cell][cell]2 hide[/cell][cell]12 s[/cell]
[cell]Bow[/cell][cell]carpenter bench[/cell][cell]3 wood, 1 bowstring[/cell][cell]15 s[/cell]
[cell]Pickaxe[/cell][cell]anvil[/cell][cell]2 ingots, 2 wood[/cell][cell]15 s[/cell]
[cell]Axe[/cell][cell]anvil[/cell][cell]2 ingots, 2 wood[/cell][cell]15 s[/cell]
[cell]Sickle[/cell][cell]anvil[/cell][cell]1 ingot, 1 wood[/cell][cell]10 s[/cell]
[cell]Helmet[/cell][cell]anvil[/cell][cell]3 ingots[/cell][cell]20 s[/cell]
[cell]Chainmail[/cell][cell]anvil[/cell][cell]6 ingots[/cell][cell]30 s[/cell]
[cell]Sword[/cell][cell]anvil[/cell][cell]3 ingots, 1 wood[/cell][cell]20 s[/cell]
[cell]Dagger[/cell][cell]anvil[/cell][cell]1 ingot, 1 wood[/cell][cell]12 s[/cell]
[cell]Ointment[/cell][cell]campfire[/cell][cell]2 herbs[/cell][cell]10 s[/cell]
[cell]Flour (2)[/cell][cell]water mill[/cell][cell]2 grain[/cell][cell]4 s[/cell]
[cell]Bread (3)[/cell][cell]oven[/cell][cell]2 flour[/cell][cell]10 s[/cell]
[cell]Stew (2)[/cell][cell]oven[/cell][cell]2 vegetables, 1 meat or fish[/cell][cell]12 s[/cell]
[cell]Preserves (2)[/cell][cell]oven[/cell][cell]2 vegetables[/cell][cell]10 s[/cell]
[cell]Cheese[/cell][cell]campfire[/cell][cell]3 milk[/cell][cell]10 s[/cell]
[/table]
Skill: Smithing at furnace and anvil, Tailoring at spinning wheel and workbench, Ranged at the carpenter bench, Medicine for the ointment, Cooking at the mill and the oven.

[color=#e8c34a]The water mill[/color] [img=center]res://art/icon_flour.png[/img]
After the Mill research: 2x2, 20 wood and 10 stone, in the open, on the bank of the stream (lakes don't flow): turn it until the whole side of its wheel lies along the stream. The miller grinds grain into flour there; nothing is ever ruined, and comfort doesn't count. When the stream freezes the wheel stands still, and its menu says so.

[color=#e8c34a]Equipment[/color]
Three slots: hands, body, head. A colonist with an empty slot fetches a piece by themselves, before any other job. In their hands they want the tool of their best skill among Mining, Woodcutting, Gathering, Hunting and Melee. Nobody trades a piece for a better one; only a hunter swaps for a bow.
[table=4]
[cell][color=#d9c48a]Piece[/color][/cell][cell][color=#d9c48a]Slot[/color][/cell][cell][color=#d9c48a]Armor[/color][/cell][cell][color=#d9c48a]Effect[/color][/cell]
[cell]Pickaxe[/cell][cell]hands[/cell][cell]–[/cell][cell]mining 25% faster[/cell]
[cell]Axe[/cell][cell]hands[/cell][cell]–[/cell][cell]chopping 25% faster[/cell]
[cell]Sickle[/cell][cell]hands[/cell][cell]–[/cell][cell]picking, uprooting 25% faster[/cell]
[cell]Bow[/cell][cell]hands[/cell][cell]–[/cell][cell]to hunt; shoots in a fight[/cell]
[cell]Sword[/cell][cell]hands[/cell][cell]–[/cell][cell]melee damage 15[/cell]
[cell]Dagger[/cell][cell]hands[/cell][cell]–[/cell][cell]melee damage 10; the burglar's[/cell]
[cell]Leather armor[/cell][cell]body[/cell][cell]2[/cell][cell]-25% stress outdoors[/cell]
[cell]Chainmail[/cell][cell]body[/cell][cell]5[/cell][cell]all work 10% slower[/cell]
[cell]Leather hood[/cell][cell]head[/cell][cell]1[/cell][cell]+5% to hit with a bow[/cell]
[cell]Helmet[/cell][cell]head[/cell][cell]3[/cell][cell]mining 10% faster[/cell]
[/table]
Tools hit too: pickaxe 10, axe 12, sickle 8, bare hands 5. Armor: see Combat & Wolves.
A colonist with a class takes the gear of their class instead, even in place of a tool: see Combat & Wolves."""],

	["Combat & Wolves", """[color=#e8c34a]Wolves[/color]
• The first pack can come on day 10. A pack announces itself: at midnight the howling (in the chronicle, and in the forecast: Wolves in N h, with a paw print), then at 22:00 the wolves, almost a day to call everyone in and shut the doors. Then one every 15 days on average and never within a week of the last one, nor within 3 days of another threat or misfortune, nor while someone lies downed or wolves are still around: 2–3 wolves from a map edge, one more for every 5 colonists. They smell the colony from 70 tiles away. In the top bar you see WOLVES while they are around.
• They chase the nearest colonist or adventurer standing outside the rooms: walls protect, wolves never come in. With nobody standing outside, they go for whoever lies downed outdoors.
• A bite every 1.5 s does 8 damage and lands 70% of the time, -3% for every Melee level of the victim. Every bite also gives +5 stress.
• A pack with nobody to chase leaves after a day.

[color=#e8c34a]Fighting back[/color]
• A colonist with a wolf within 12 tiles drops everything and fights the nearest one. Under 40 health they run instead to the nearest room they can enter and wait there; with no room in reach, they fight.
• Melee: a blow every 1.5 s, landing 50% of the time, +5% for every Melee level above 5 (less below). The damage is that of what they hold: sword 15, axe 12, pickaxe 10, dagger 10, sickle 8, bare hands 5.
• Bow: a shot every 2 s from up to 8 tiles, aimed like a hunter's but with Ranged only; 14 damage. Hit or missed, the wolf turns on the shooter.
• Armor: -6% damage for every point, at most -80%. Chainmail and helmet (8 points) take off 48%.
• A dead wolf leaves 5 meat and 2 hide.

[color=#e8c34a]Downed and dead[/color]
• At 0 health a colonist falls. The bite that downs them kills 25% of the time, -3% for every point of armor (at least 5%).
• Downed, they heal 40 a day and stand up at 30. A wolf that finds them outdoors, with nobody else standing, kills them with the first bite.
• The dead drop their gear; the body stays 2 days, unless it is buried (see Medicine & Death). The other colonists mourn for 3 days (Mourning). If every colonist dies, the colony has fallen.

[color=#e8c34a]The barracks and classes[/color]
• With the Barracks research a colonist can take the class of an adventurer: Class… on their sheet. The classes that can't be given are greyed out, with the reason.
• It takes a grown-up colonist (adventurers already have theirs), the room of the class and enough in its weapon: warrior 3 Melee and an armory; archer 3 Ranged and an archery range; burglar 2 Melee and an armory (Lockpicking is learned only with the class).
• The level is half the skill of the class (Melee, Ranged, Lockpicking), from 1 to 5. The sheet and the census say "Archer of the colony, level 2". Taking the class off or changing it is free: the skill stays.
• The gear of the class, fetched by themselves, even in place of a tool: the warrior a sword, then a shield, chainmail (or leather armor) and a helmet; the archer a bow, leather armor and hood; the burglar a dagger, leather armor and hood. Equipment that is missing gets made at the stations.
• Quiver, mask and sack are the kit of the class: you see them, nobody makes them. The hood takes the color of the class: green the archer, dark the burglar."""],

	["Medicine & Death", """[color=#e8c34a]Medicinal herbs[/color] [img=center]res://art/icon_herbs.png[/img]
Small plants with white flowers scattered in the meadows (hover: Medicinal herbs), about one every 150 tiles of grass. Mark them with Harvest (H): 5 herbs a plant, picked like berries; they flower again in 2 days, never in winter. Herbs don't spoil.

[color=#e8c34a]Ointment[/color] [img=center]res://art/icon_ointment.png[/img]
• After the Herbalism research (Lore I, 100). At a kitchen's campfire or hearth: 2 herbs, 10 s, with the Medicine skill; Keep 3 at the start.
• A colonist standing with less than 60 health fetches one from a pile and spreads it on (3 s): +30 health. After hunger, before work; guests don't, and nobody does while fighting.

[color=#e8c34a]The infirmary[/color] [img=center]res://art/icon_doctor.png[/img]
• After the Medicine research (Lore II, 300 and a notebook, after Herbalism). A room with a bed and a medicine chest (8 wood) can be an infirmary. Its beds are only for the sick: the downed, those under 50 health, those with a fever.
• In an infirmary bed health comes back 50% faster: 60 a day downed, 90 asleep.
• Bed rest: whoever is under 50 health or has a fever goes to a free infirmary bed, even in work hours, and stays there until they are back at 80 and the fever is gone (they still get up to eat).

[color=#e8c34a]Doctors[/color]
The Doctor column, the first of the table (Jobs, J): whoever has it does, in this order, nearest first:
• Rescue: a colonist downed outside a bed, if an infirmary bed is free. The doctor carries them on their shoulders and lays them in the bed. With no free bed, they treat them where they lie.
• Treat: whoever is downed, or in bed wounded (under 80) or with a fever, and not yet treated. First the doctor fetches an ointment from a pile, if there is one; then 8 s beside the patient (Medicine skill, which it teaches). Treated, for a day health comes back twice as fast; with the ointment also +30 at once (a downed colonist stands up). A treated fever passes within half a day.
• A doctor doesn't treat themselves (they spread their own ointment), and two doctors never go to the same patient. At the end of the shift a doctor carrying someone carries them to the bed first.

[color=#e8c34a]Graves[/color]
• A grave (1x2, 4 wood, from the start) is an open pit with a wooden cross, on open ground only: not in a room, not on a floor or a path.
• The dead stay where they fell for 2 days. With an empty grave, a hauler (not a child) carries the body there on their shoulders and buries it (5 s): the pit becomes a mound. Hover the grave: who lies there, the day they died, their age, how they died.
• Buried, the mourning they left is a day shorter: 2 days instead of 3, and the royal mourning 6 instead of 7 (the coronation comes a day earlier). A later death keeps its full mourning.
• Nobody buries those who die on an expedition: there is no body.

[color=#e8c34a]Funerals and the memorial[/color]
• With the Funerals law (Feasts, 30, a grave on the map): when one of the colony is buried, at 18 that day (at once if it's already evening, the next day if they were buried after 22) every colonist who is awake, standing and not fighting drops what they do and gathers around the grave for two hours. Afterwards they have Farewell: as long as that mourning lasts it weighs 5 less (Mourning -10, Royal mourning -15). The chronicle tells of it.
• The memorial of the fallen (Statuary): a stone stele, 10 stone, 2 splendor. While there is one on the map, every new mourning is a day shorter (2 days, or 1 once buried; the royal one 6, or 5)."""],

	["Splendor", """Splendor is the sum of the finished decorations that count, plus 5 for every famous adventurer around. The total is in the top bar.
• Only inside the colony: in a room, within 2 tiles of a wall, a door, a floor or a path, or inside the palisade. Out in the fields a decoration gives nothing.
• Flower beds, planters, benches and lanterns count only with no other of the same kind within 4 tiles (the oldest wins); the banner only once. Build different decorations, not many of the same.
• Hover a decoration: how much splendor it gives, or why it gives none.
• Upkeep: at every season's feast (Flower, Sickle, Hearth, Candle) the colony pays half a coin for every point of splendor beyond the first 15, from the warehouses, the most precious decorations first. An unpaid one is neglected: half its splendor, duller. Unpaid again at the next feast, it falls into ruin: no splendor, grey, until a builder repairs it with 1 of its material (then it is neglected until paid). Relics cost nothing and never decay. Hover the splendor in the top bar for the next upkeep.
For now it does two things:
• Adventurers arrive stronger: level 1, +1 for every 10 splendor, ±1 at random (from 1 to 5).
• +1 authority a day for every 20 splendor.
[table=4]
[cell][color=#d9c48a]Decoration[/color][/cell][cell][color=#d9c48a]Splendor[/color][/cell][cell][color=#d9c48a]Cost[/color][/cell][cell][color=#d9c48a]Research[/color][/cell]
[cell]Flower bed[/cell][cell]1[/cell][cell]3 wood[/cell][cell]Decor[/cell]
[cell]Planter[/cell][cell]1[/cell][cell]5 stone[/cell][cell]Decor[/cell]
[cell]Bench[/cell][cell]1[/cell][cell]6 wood[/cell][cell]Decor[/cell]
[cell]Lantern[/cell][cell]1[/cell][cell]3 wood, 1 coal[/cell][cell]Lanterns[/cell]
[cell]Banner[/cell][cell]2, once[/cell][cell]4 wood[/cell][cell]–[/cell]
[cell]Fountain[/cell][cell]6[/cell][cell]30 stone[/cell][cell]Fountain[/cell]
[cell]Statue[/cell][cell]8[/cell][cell]40 stone[/cell][cell]Statuary[/cell]
[cell]Memorial[/cell][cell]2[/cell][cell]10 stone[/cell][cell]Statuary[/cell]
[cell]Chalice[/cell][cell]3[/cell][cell]the relic[/cell][cell]–[/cell]
[cell]Old banner[/cell][cell]4[/cell][cell]the relic[/cell][cell]–[/cell]
[cell]Bust[/cell][cell]5[/cell][cell]the relic[/cell][cell]–[/cell]
[cell]Crown[/cell][cell]6[/cell][cell]the relic[/cell][cell]–[/cell]
[/table]
• The bench (2x1) also gives +0.5 room comfort. The lantern lights the roads at night. The banner flies the arms of your house; only the first gives splendor, the others are just decoration. Fountain and statue take 2x2 tiles.
• Relics are found only by adventurers, in ruins. They come home as items: build them from the furniture bar, one relic for each piece."""],

	["Adventurers", """[color=#e8c34a]The inn[/color]
• The Inn research unlocks the notice board. A room with a bed, a table and a notice board can become an inn.
• Every inn bed lets one adventurer stay. Inn beds are theirs only, and they sleep nowhere else: with no inn bed free, on the ground.

[color=#e8c34a]Arrivals[/color]
• About every 2 days (±½) one comes in from the map edge, if an inn bed is free (the beds of those away count as taken).
• Level: 1, +1 for every 10 splendor, ±1 at random, from 1 to 5.
• They wait 3 days to be hired, then leave. Back from an expedition they rest 2 days, and can be hired again.
• They don't work: they eat your food, relax, and fight wolves like colonists (they can die). Click one for their sheet: class, level, fee, expeditions.

[color=#e8c34a]Classes[/color]
• Warrior: Melee 2 a level. Sword, shield (+3 armor), leather armor (chainmail from level 3), helmet. In ruins takes a double share of the wounds.
• Archer: Ranged 2 a level. Bow, quiver, leather armor and hood. Shoots first: the whole party takes 25% fewer wounds; takes half a share.
• Burglar: Lockpicking 2 a level, Melee 1 a level. Dagger, mask, sack, leather armor and hood. Disarms traps and opens locked chests; the sack brings home 50% more.

[color=#e8c34a]Pay[/color] [img=center]res://art/icon_coin.png[/img]
Hiring costs 10 coins, +5 a level (15–35), paid from your warehouses when you send them. Back home they keep 30% of the coins they found. +1 level every 2 expeditions back, up to 5.

[color=#e8c34a]Their traits[/color]
One each, and 3 times in 10 also a colonist trait.
[table=2]
[cell]Greedy[/cell][cell]asks 25% more[/cell]
[cell]Loyal[/cell][cell]keeps no share of the coins[/cell]
[cell]Reckless[/cell][cell]party turns back for them under 20[/cell]
[cell]Coward[/cell][cell]party turns back when under 60[/cell]
[cell]Lucky[/cell][cell]one more item in every chest[/cell]
[cell]Cartographer[/cell][cell]finds maps 3 times as often[/cell]
[cell]Jinxed[/cell][cell]every trap hits them; asks 25% less[/cell]
[cell]Berserker[/cell][cell]weapon counts double; +50% wounds[/cell]
[cell]Stout[/cell][cell]a third fewer wounds[/cell]
[cell]Stealthy[/cell][cell]slips past monsters 1 time in 4[/cell]
[cell]Medic[/cell][cell]+6 health to all after each room[/cell]
[cell]Forager[/cell][cell]the party eats a third less[/cell]
[cell]Pathfinder[/cell][cell]the journey takes half the time[/cell]
[cell]Keen-eyed[/cell][cell]+30% to disarm traps[/cell]
[cell]Scholar[/cell][cell]a level every trip; books twice as often[/cell]
[cell]Famous[/cell][cell]+5 splendor while on the map[/cell]
[/table]
With a medic standing, whoever falls is carried home. Stealth doesn't work on the guardian of the treasure.

[color=#e8c34a]Staying[/color]
• An adventurer back at the inn from their third expedition, with 60 happiness or more, asks to stay as a colonist. A window asks you: Welcome or No. Close it and the question waits on their sheet (Answer…) while they are at the inn; hired, they take it back.
• Said no, they ask again after 3 more expeditions.
• Welcomed, they become a colonist: they work, have their priorities and sleep in the colonists' beds. They keep their skills, traits and gear, which is now the colony's: the warrior's shield becomes a real shield in its slot, the burglar takes off mask and sack, the archer keeps the quiver. A famous one still gives splendor; the other adventurer traits only count on expeditions. The sheet says "Once a warrior, level 3".
• For 5 days they are a Foreigner: -5 happiness, work 10% slower."""],

	["Ruins & Expeditions", """[color=#e8c34a]The notice board[/color]
Click it: the coins and provisions in store, then everything in boxes. On the left who waits at the inn, two boxes a row: class and level, traits, fee (and the colonists of the crown's company, if you have it). On the right the Party: 4 places. Click a box, or drag it there, to put them in the party; click them in the party, or drag them back, to leave them home. Under the party the ruins you know, each with its danger, the rooms cleared and, once the party has someone, what the trip costs (fees, provisions, days) and its Send button; below them the expeditions away, with their figures and the day they are due back. At the bottom the last page of the chronicle.

[color=#e8c34a]Expeditions[/color]
• Provisions: one a head for every day of the trip (there, ½ day for every room left, back), first from the crown's granary, then from warehouses, meals before raw food. Short of them, the party leaves anyway and goes hungry: -20 health a day each.
• They walk to the map edge and leave together; in the top bar you see EXPEDITION. You read how it went in their diary when they're back (and in the Chronicle, with hirings and deaths).
• In the ruin, a room every ½ day: empty (25%), a trap (20%), monsters (35%), a chest (15%) or a collapse (5%: they turn back).
• Monsters: strength 5 for every point of danger. The weaker the party (weapon skill plus armor of each), the deeper the wounds; then each one's armor softens them.
• Traps: the best lockpicker disarms one 20% of the time, +8% a level; if not, someone takes 15 damage for every point of danger.
• Chests: coins and one of the ruin's items, or 35% of the time a book. Half are locked, and open only for Lockpicking of at least 2 for every point of danger.
• The last room is the treasure, with its guardian (double strength): three times the coins, its books and the map of the next ruin. If it stays locked, that room is left for next time.
• They turn back when someone drops under 40 health, when the provisions won't cover another room and the way home, or after a collapse.
• At 0 health one dies half the time; otherwise the others carry them home with 5 health (alone, they die). If all fall the expedition is lost: you'll know at twice the time it should have taken.
• Home again, they go to the inn and leave the loot there for your haulers, minus their share of the coins.
• Cleared rooms stay cleared: the next party starts from there. A ruin with no rooms left is explored.

[color=#e8c34a]The crown's company[/color]
With the Crown company research (Road III, 500 and a tome, after Renowned inn) your colonists go too.
• On the notice board, under those waiting at the inn, the colonists who can go: adults, not the ruler, nobody downed or pregnant. Pick them like the adventurers; at least one adventurer must go.
• They ask no fee and keep no share of the coins. Away they don't work, but they still count for the title.
• In the ruin a former adventurer fights like their old class; the others with the better of Melee and Ranged, taking an average share of the wounds. +1 experience in their weapon for every fight.
• Back home they walk to the inn with the others, then go back to work. A colonist who dies in a ruin is mourned when the news comes (with the party, or when it is given up for lost): Mourning and -5 authority.

[color=#e8c34a]Ruins[/color]
At first you know only the tower. Every treasure holds the map of the next ruin, and any chest may (15%) hold the map of one you don't know yet. Travel is one way.
[table=4]
[cell][color=#d9c48a]Ruin[/color][/cell][cell][color=#d9c48a]Danger[/color][/cell][cell][color=#d9c48a]Rooms[/color][/cell][cell][color=#d9c48a]Travel[/color][/cell]
[cell]Ruined tower[/cell][cell]1[/cell][cell]3[/cell][cell]½ day[/cell]
[cell]Abandoned mine[/cell][cell]2[/cell][cell]5[/cell][cell]1 day[/cell]
[cell]Crypt[/cell][cell]3[/cell][cell]6[/cell][cell]1 day[/cell]
[cell]Ruined fort[/cell][cell]4[/cell][cell]8[/cell][cell]2 days[/cell]
[cell]Buried monastery[/cell][cell]3[/cell][cell]6[/cell][cell]1½ days[/cell]
[/table]
Coins in a chest, its item, its book, and the treasure's books:
• Tower: 10–25; 10 wood, 10 stone or 5 iron; notebooks; 2 notebooks.
• Mine: 20–45; 10 iron, 10 coal, 4 ingots or a pickaxe; notebooks; 2 notebooks.
• Crypt: 35–70; a sword, a helmet, leather armor, 6 ingots, the chalice or the bust; notebooks or tomes; a tome.
• Fort: 60–120; chainmail, 2 swords, a helmet, 10 ingots, the old banner or the crown; tomes, 1 in 4 a codex; a codex.
• Monastery: 5–20; always a book: half notebooks, a quarter tomes, a quarter codices; a tome and a codex."""],

	["Knowledge", """[color=#e8c34a]Study[/color] [img=center]res://art/icon_study.png[/img]
• A room with a desk can become a study; the desk needs no research. One colonist at a desk writes pages: every page is +1 study for the colony's shared pool and +1 Research XP.
• A page takes 2.5 s, more or less with room comfort and conditions. From 19:00 to 6:00, without a lamp in the room, it takes 50% longer; every bookshelf in the room takes off 10% (up to 3).
• The study's workers study before any other job and stay at the desk all their shift. The others write a page only when there is nothing else to do.

[color=#e8c34a]The Knowledge window[/color]
Press K or click a desk: your study and the books in your warehouses, then the tree: a box for every research, with its cost (study, and from tier II a book; in red what you don't have yet). A gold border: studied; green: you can study it now; faded: the research it needs comes first. Every research sits to the right of those it needs, linked to them by a line with an arrow, gold once the needed one is studied; branches are bands, one below the other, and the links between branches cross them. Hover a box for what it unlocks, its tier and what is missing (its links light up); click it to research it at once. It spends the study and, from tier II, a book from a warehouse:
• Tier II: a notebook [img=center]res://art/icon_notebook.png[/img]. Tier III: a tome [img=center]res://art/icon_tome.png[/img]. Tier IV: a codex [img=center]res://art/icon_codex.png[/img].
Books come only from ruins (see Ruins & Expeditions).
What you haven't researched has no build button, and its recipes don't show at the stations. From the start you have wooden walls and floors, doors, paths, beds, tables, chairs, campfires, banners, desks, thrones, relics and meals.

[color=#e8c34a]The tree[/color]
• [color=#d9c48a]Garden[/color] (Land I, 80): garden plots and fields with their rotation; turnips in 60 days, cabbages in 90, broad beans in 100.
• [color=#d9c48a]Mill[/color] (Land I, 100, after Garden): grain in the fields, the water mill on the bank of the stream, flour.
• [color=#d9c48a]Stone oven[/color] (Land II, 300 and a notebook, after Garden): the oven in the kitchen; bread, stew, preserves.
• [color=#d9c48a]Manuring[/color] (Land I, 80, after Garden): the compost heap, rot and ash, fertilizing, green manure.
• [color=#d9c48a]Soil survey[/color] (Land I, 60, after Garden): the soil lens, in three bands.
• [color=#d9c48a]Almanac[/color] (Land II, 250 and a notebook, after Soil survey): five bands, and the trend of every field.
• [color=#d9c48a]Land register[/color] (Land III, 450 and a tome, after Almanac): the soil's numbers and the next harvest.
• [color=#d9c48a]Husbandry[/color] (Land I, 100, after Hunting): the pasture, the coop, the livestock dealer; hens and pigs; the Husbandry column.
• [color=#d9c48a]Stable[/color] (Land II, 250 and a notebook, after Husbandry): the stable and its mangers, hay, manure; sheep and cows, milk, cheese, wool.
• [color=#d9c48a]Hunting[/color] (Land I, 50): spinning wheel and carpenter bench; bowstrings and bows; hides on the walls and door curtains.
• [color=#d9c48a]Icehouse[/color] (Land II, 250 and a notebook, after Cold store): the icehouse, the ice pit, cutting ice.
• [color=#d9c48a]Forge[/color] (Fire I, 60): furnace and anvil; ingots, pickaxe, axe, sickle.
• [color=#d9c48a]Tailoring[/color] (Fire I, 50): workbench; leather armor and hood.
• [color=#d9c48a]Loom[/color] (Fire II, 200 and a notebook, after Tailoring): the tapestry.
• [color=#d9c48a]Tiled stove[/color] (Fire II, 300 and a notebook, after Charcoal and Masonry): the tiled stove.
• [color=#d9c48a]Masonry[/color] (Stone I, 60): stone walls and floors; the hearth; plaster.
• [color=#d9c48a]Decor[/color] (Stone I, 40): flower bed, planter, bench.
• [color=#d9c48a]Fountain[/color] (Stone II, 250 and a notebook, after Decor): the fountain.
• [color=#d9c48a]Statuary[/color] (Stone III, 500 and a tome, after Masonry): the statue and the memorial of the fallen.
• [color=#d9c48a]Iron arms[/color] (Iron I, 80, after Forge): sword and helmet.
• [color=#d9c48a]Chainmail[/color] (Iron II, 300 and a notebook, after Iron arms): chainmail.
• [color=#d9c48a]Barracks[/color] (Iron II, 250 and a notebook, after Training dummy): weapon rack, target and lock bench; armory and archery range; the classes of the colonists; the dagger.
• [color=#d9c48a]Inn[/color] (Road I, 40): the notice board; the laws Loot tax and Lodging tax.
• [color=#d9c48a]Crown company[/color] (Road III, 500 and a tome, after Renowned inn): colonists go on expeditions with the adventurers.
• [color=#d9c48a]Bookshelf[/color] (Lore I, 60): the bookshelf.
• [color=#d9c48a]Herbalism[/color] (Lore I, 100): the ointment, from medicinal herbs.
• [color=#d9c48a]Medicine[/color] (Lore II, 300 and a notebook, after Herbalism): the medicine chest, the infirmary and the doctors.
• [color=#d9c48a]Lanterns[/color] (Lore I, 40): lamp and lantern."""],

	["Laws", """[color=#e8c34a]Authority[/color] [img=center]res://art/icon_authority.png[/img]
• Only the ruler gathers it, holding audience on a throne in a throne room: +1 an hour, 25% more with happiness 70 or more, half with 30 or less. It counts as work.
• The ruler goes to the throne first if you tick them as the throne room's worker; otherwise only when there is nothing else to do.
• Every day +1 for the title (Lordship) and +1 for every 20 splendor; +5 for every harvest feast.

[color=#e8c34a]The Laws window[/color]
Press G or click the throne: authority, seals, the crown's granary, then the laws by kind. Hover a law for what it does and who likes it.
• Codify a law once, paying its cost in authority. Then Enact it: 10 authority and a free seal. A Lordship has 2 seals.
• Laws of the same group (taxes, shifts, justice, welcome) exclude each other: enacting one replaces the other.
• Revoking is free, but the law can't be enacted again for 3 days.
• Every law in force changes the happiness of the colonists (some traits feel it differently) or of the adventurers. It shows among the conditions in the sheet.
• The crown's granary is filled by the Tithe, and nothing in it rots. Expedition provisions come from it first.

[color=#d9c48a]Treasury[/color]
• Exemption (30, taxes): no tithe, the granary stays empty. Everyone +5.
• Tithe (40, taxes): one piece in ten of all that is gathered, fished, hunted, cooked and made goes to the granary. Everyone -3.
• Loot tax (40, Inn research): adventurers keep 20% of the coins, not 30%; a quarter fewer come, and never the greedy. Adventurers -5.
• Lodging tax (30, Inn research): every adventurer waiting at the inn leaves a coin a night, and waits a day less. Adventurers -3.
[color=#d9c48a]Work[/color]
• Long shifts (40, shifts): up to 10 hours of work a day (the lazy 7, the workaholic still 12); stress from work +25%. Everyone -5, workaholic +3; lazy, fun-loving and restless -10.
• Short day (40, shifts): at most 6 hours of work; stress from work -25%. Everyone +8, workaholic -5.
• Day of rest (30): on days 7, 14, 21... nobody works but the cooks. Everyone +6, workaholic -5, ascetic 0.
[color=#d9c48a]Order[/color]
• Curfew (40): from 21:00 free time becomes sleep. Everyone -2, fun-loving -10, early bird +3.
[color=#d9c48a]People[/color]
• Closed gates (30, welcome): nobody asks to stay, adventurers or wanderers (see Colonists, New colonists). Everyone +5.
• Open gates (40, welcome): adventurers ask to stay after 2 expeditions, wanderers come twice as often; newcomers are Foreigners for 10 days, not 5. Foreigners -5.
• Oath (80, a Barony): whoever stays goes to the throne room and kneels an hour, then swears loyalty: 10 authority, and they are no foreigner (without a throne room, they swear where they stand; without the authority, they stay a foreigner). The sworn +5.
[color=#d9c48a]Feasts[/color]
• Harvest feast (40): on the five feast days of the calendar (see Time) nobody works but the cooks. The next day every colonist is Festive (+10 happiness for 3 days) and you get 5 authority.
• Funerals (30; needs a grave on the map): when one of the colony is buried, the funeral at 18 (see Medicine & Death)."""],
]


# le pagine nella lingua del gioco: locale/wiki_<lingua>.gd se c'è, se no queste (in inglese)
static func pages() -> Array:
	var path := "res://locale/wiki_%s.gd" % TranslationServer.get_locale().get_slice("_", 0)
	return load(path).PAGES if ResourceLoader.exists(path) else PAGES
