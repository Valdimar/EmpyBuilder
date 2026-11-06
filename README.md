# EmpyBuilder

A Windower 4 addon for the **Abyssea stages of the Empyrean weapons: Lv80, Lv85 and Lv90**.
Each stage's trial needs a pile of one Abyssea NM's drop (50 for Lv80 and Lv85, 75 for Lv90).
Pick the weapon(s) you're building and EmpyBuilder shows, in a display window:

- which stage each weapon is on, worked out from the weapon in your bags,
- how many of that stage's NM item you have, e.g. **13 / 50** (every bag counted),
- the NM's whole pop chain, checked live against your bags and key items,
- `RED!!!` alerts on the key items that need a red proc.

## Install

1. Copy the `EmpyBuilder` folder into `Windower4/addons/` (remove the old `ChlorisPop` folder).
2. In game: `//lua load EmpyBuilder`.
3. A small window pops up asking which weapon you're building. Click one or more, then
   **Save**. That choice is saved for that character.
4. Drag the tracker window by its header or body; the position is saved. Click the header to
   minimize.

## Picking your weapon

The first time each character logs in with EmpyBuilder (or whenever it has no saved choice),
a picker window opens in the middle of the screen:

```
EMPYBUILDER   Which Empyrean weapon are you building?
Click to pick one or more, then Save (saved for Valdimar).

     Weapon       Type          Lv80 item (x50)            Have
 [ ] Verethragna  H2H           2Lf. Chloris Bud           0 / 50
 [ ] Twashtar     Dagger        Glavoid Shell              0 / 50
 [x] Redemption   Scythe        2Lf. Chloris Bud           13 / 50 (9 in inv)
 ...
   [ Save ]  1 picked
   [ Not now ]  ask again next time, or //empy pick
```

- Click a weapon to tick or untick it (more than one is fine). The row under the mouse is
  highlighted, and clicks on the picker don't reach the game.
- **Save** stores the list for that character and closes the picker.
- **Not now** closes it; it asks again the next time you log in or load the addon.
- `//empy pick` opens it again any time to change your weapons.

You can also name a weapon in chat: `//empy weapon Rhongomiant` or `//empy weapon polearm`.
Weapons are matched by:

- **Name**, or its first letters (`//empy weapon redem`).
- **Type**: `hand-to-hand` / `h2h`, `dagger`, `sword`, `great sword` / `gs`, `axe`,
  `great axe` / `ga`, `scythe`, `polearm` / `lance` / `spear`, `katana`, `great katana` / `gk`,
  `club`, `staff`, `bow`, `gun`. Each type is one Empyrean weapon.
- **Close spellings**: `//empy weapon Rhongomaint` says *taking "Rhongomaint" as Rhongomiant*.

If a word fits more than one (`great`), chat lists the choices instead of guessing.

Each character's list is kept in `addons/EmpyBuilder/data/<CharacterName>.xml`, so your mules
can build different weapons. `//empy add` / `remove` / `clear` change the same list. A list
saved by an earlier version is moved over to the character automatically.

**The window only appears in Abyssea - La Theine, Konschtat and Tahrongi**, the three zones
the Lv80 NMs live in, and hides everywhere else. Your counts and key items are still tracked
outside (chat lines still work, and `//empy weapons` shows your counts anywhere).
`//empy where abyssea` shows it in any Abyssea zone; `//empy where always` shows it everywhere.

## Items by weapon and stage

| Weapon | Type | Lv80 (x50) | Lv85 (x50) | Lv90 (x75) |
| --- | --- | --- | --- | --- |
| Verethragna | Hand-to-Hand | 2Lf. Chloris Bud (Chloris) | Ulhuadshi's Fang (Ulhuadshi) | Dragua's Scale (Dragua) |
| Redemption | Scythe | 2Lf. Chloris Bud (Chloris) | Ulhuadshi's Fang (Ulhuadshi) | Dragua's Scale (Dragua) |
| Rhongomiant | Polearm | 2Lf. Chloris Bud (Chloris) | Ulhuadshi's Fang (Ulhuadshi) | Dragua's Scale (Dragua) |
| Twashtar | Dagger | Glavoid Shell (Glavoid) | Itzpapalotl's Scale (Itzpapalotl) | Orthrus's Claw (Orthrus) |
| Ukonvasara | Great Axe | Glavoid Shell (Glavoid) | Itzpapalotl's Scale (Itzpapalotl) | Orthrus's Claw (Orthrus) |
| Almace | Sword | Helm of Briareus (Briareus) | Sobek's Skin (Sobek) | Apademak's Horn (Apademak) |
| Kannagi | Katana | Helm of Briareus (Briareus) | Sobek's Skin (Sobek) | Apademak's Horn (Apademak) |
| Caladbolg | Great Sword | Carabosse's Gem (Carabosse) | Cirein-croin's Lantern (Cirein-croin) | Isgebind's Heart (Isgebind) |
| Masamune | Great Katana | Carabosse's Gem (Carabosse) | Cirein-croin's Lantern (Cirein-croin) | Isgebind's Heart (Isgebind) |
| Armageddon | Gun | Carabosse's Gem (Carabosse) | Cirein-croin's Lantern (Cirein-croin) | Isgebind's Heart (Isgebind) |
| Farsha | Axe | Fistule Discharge (Fistule) | Bukhis's Wing (Bukhis) | Alfard's Fang (Alfard) |
| Gambanteinn | Club | Fistule Discharge (Fistule) | Bukhis's Wing (Bukhis) | Alfard's Fang (Alfard) |
| Gandiva | Bow | Fistule Discharge (Fistule) | Bukhis's Wing (Bukhis) | Alfard's Fang (Alfard) |
| Hvergelmir | Staff | Kukulkan's Fang (Kukulkan) | Sedna's Tusk (Sedna) | Azdaja's Horn (Azdaja) |

Zones: Lv80 NMs are in La Theine, Konschtat and Tahrongi; Lv85 in Attohwa (Ulhuadshi,
Itzpapalotl), Misareaux (Sobek, Cirein-croin) and Vunkerl (Sedna, Bukhis); Lv90 in Altepa
(Dragua, Orthrus), Uleguerand (Apademak, Isgebind) and Grauberg (Alfard, Azdaja).

Weapons that share an NM share one section in the window, but each weapon needs its own
50 (or 75).

## Stages: building all the way to Lv90

EmpyBuilder works out each weapon's stage from the highest-level copy of it in your bags:
none means you're working on Lv80, a Lv80 copy means Lv85, a Lv85 copy means Lv90, and Lv90
or higher means done. When you trade up, the window moves on to the next NM by itself and
chat says so (`Redemption is Lv80 now: next is 50 Ulhuadshi's Fang from Ulhuadshi
(Abyssea - Attohwa)`).

- `//empy stage` lists every stage of the weapons you're building, with your counts.
- `//empy stage 85 redemption` sets a stage by hand (`80`, `85`, `90` or `done`); leave the
  weapon off to set every weapon. `//empy stage auto` goes back to reading your bags. A stage
  set by hand clears itself once your bags show you're past it.
- `//empy next redemption` moves a weapon to its next stage, e.g. right after you trade.
- `//empy full` turns on the **full build** view: besides the stage you're on, the window also
  lists the NMs still ahead for each weapon, marked `LATER`, with just their item count. Handy
  for picking up Lv85/Lv90 items early. `//empy full off` goes back.
- `//empy path twashtar` prints all three stages for one weapon in chat.

The window appears in all nine Abyssea zones with Empyrean NMs.

## Pop chains

| NM | Pop | Key items (NM that drops it → what pops that NM ← where it drops) |
| --- | --- | --- |
| **Chloris** | ??? (I-8) | Torn bat wing (Treble Noctules, I-9: Bloody Fang ← Blood Bat, Exorcised Skull ← Cannered Noz ← Baleful Skull) · Gory scorpion claw (Hedetet, F-7: Venomous Scorpion Stinger ← Canyon Scorpion, Acidic Humus ← Gancanagh ← Alkaline Humus) · Veinous hecteyes eyelid (Ophanim, G-9: Bloodshot Hecteye ← Beholder, Shriveled Wing ← Halimede ← H.Q. Clionid Wing, Tarnished Pincer ← Vetehinen ← H.Q. Limule Pincer) · Mossy adamantoise shell (Chukwa, timed) |
| **Glavoid** | ??? (I-5) | Fat-lined cockatrice skin (Alectryon, H-8: Cockatrice Tailmeat ← Cluckatrice, Quivering Eft Egg ← Abas ← Eft Egg) · Luxuriant manticore mane (Muscaliet, I-6: Resilient Mane ← Hieracosphinx, Smooth Whisker ← Tefenet ← Shocking Whisker) · Sticky gnat wing (Adze, timed) · Sodden sandworm husk (Minhocao, timed) |
| **Briareus** | ??? (G-6) | Dented Gigas shield (Adamastor, C-4: Trophy Shield ← Bathyal Gigas) · Warped Gigas armband (Pantagruel, F-7: Oversized Sock ← Hadal Gigas) · Severed Gigas collar (Grandgousier, F-10: Massive Armband ← Demersal Gigas) |
| **Carabosse** | ??? (H-7) | Pellucid fly eye (La Theine Liege, I-7: Transparent Insect Wing ← Plateau Glider) · Shimmering pixie pinion (Baba Yaga, H-7: Piceous Scale ← Farfadet) |
| **Kukulkan** | ??? (H-5) | Mucid ahriman eyeball (Arimaspi, K-6: Clouded Lens ← Deep Eye) · Tattered hippogryph wing (Alkonost, H-6: Giant Bugard Tusk ← Ypotryll) · Cracked wivre horn (Keratyrannos, G-6: Armored Dragonhorn ← Mesa Wivre) |
| **Fistule** | (G-3), by Conflux #6 | No pop items. Bring the NM Guimauve (G-4, #6) next to it to make it pop |
| **Ulhuadshi** (Lv85) | ??? #3 J/K-7, Attohwa | Mucid worm segment (Pallid Percy, J-7: Blanched Silver ← Entozoon) · Shriveled hecteyes stalk (Amun, K-9, timed) |
| **Itzpapalotl** (Lv85) | ??? #7 K-10, Attohwa | Bulbous crawler cocoon (Blazing Eruca, J-10: Eruca Egg ← Ignis Eruca) · Venomous wamoura feeler (Granite Borer, K-10: Withered Cocoon ← Gullycampa) · Distended chigoe abdomen (Tunga, K-9/10, timed) |
| **Sobek** (Lv85) | ??? #7 J-11, Misareaux | Bloodstained bugard fang (Minax Bugard, K-10: Bewitching Tusk ← Abyssobugard) · Gnarled lizard nail (Sirrush, I-11: Molt Scraps ← Dusk Lizard) · Molted peiste skin (Gukumatz, J-11, timed) |
| **Cirein-croin** (Lv85) | ??? #3 J/K-7, Misareaux | Glistening orobon liver (Cep-Kamuy, F-5: Orobon Cheekmeat ← Ancient Orobon) · Doffed poroggo hat (Heqet, I-6, timed) |
| **Sedna** (Lv85) | ??? #3 K-6, Vunkerl | Glossy sea monk sucker (Iku-Turso, J-7: Moonbeam Clam ← Jasconius) · Shimmering pugil scale (Hrosshvalur, J/K-6, timed) |
| **Bukhis** (Lv85) | ??? #4 G-10, Vunkerl | Ingrown taurus nail (Khalkotaur, H-10: Gnarled Taurus Horn ← Aestutaur) · Ossified gargouille hand (Quasimodo, G-11: Gargouille Stone ← Gruesome Gargouille) · Imbrued vampyr fang (Lord Varney, G/H-10, timed) |
| **Dragua** (Lv90) | ??? #4 G-9, Altepa | Bloodied dragon ear (Hazhdiha, G/H-9/10, timed) |
| **Orthrus** (Lv90) | ??? #7 F-7, Altepa | Steaming cerberus tongue (Amarok, G-5: Sharabha Hide ← Sharabha ← Sand-caked Fang ← Dune Manticore; H.Q. Dhalmel Hide ← Camelopardalis; Tiger King Hide ← Ansherekh, timed) |
| **Apademak** (Lv90) | ??? #7 F-6, Uleguerand | Torn khimaira wing (Dhorme Khimaira, G-7: Snow God Core ← Upas-Kamuy ← Gelid Arm ← Snowflake; Sisyphus Fragment ← Sisyphus, free spawn among Verglas Golems; H.Q. Marid Hide ← Olyphant) |
| **Isgebind** (Lv90) | ??? #6 I-5, Uleguerand | Begrimed dragon hide (Kur, I/J-5, free spawn among Adasaurus) |
| **Alfard** (Lv90) | ??? #8 J-8, Grauberg | Venomous hydra fang (Ningishzida, I-7/8: Minaruja Skull ← Minaruja ← Pursuer's Wing ← Faunus Wyvern; Jaculus Wing ← Jaculus, timed; H.Q. Wivre Hide ← Glade Wivre) |
| **Azdaja** (Lv90) | ??? #7 C-8, Grauberg | Vacant bugard eye (Deelgeed, F-9, timed) |

## The window

```
EMPYBUILDER  Empyrean Lv80 NM items                              2 weapons  [-]
───────────────────────────────────────────────────────────────────────────────
You are nearest Conflux #2 (38 yalms)   steps by it are marked #2*

CHLORIS  Abyssea - Tahrongi  ??? #2* I-8   2Lf. Chloris Bud 13 / 50 (9 in inv)
  for Redemption, Rhongomiant
  Get the key items, then examine the ??? at (I-8)  1/4 KI
  [x] Torn bat wing  owned, ready for Chloris
  Gory scorpion claw  key item for Chloris   2/4 steps
    1 [x] Kill Pachypodium     #7 H/I-8     > Alkaline Humus             HAVE     -> Gancanagh
   >> [ ] Pop Gancanagh        #2* H-8      > Acidic Humus               POP IT   -> Hedetet
    3 [x] Kill Canyon Scorpion #4 F-7       > Venomous Scorpion Stinger  HAVE     -> Hedetet
    4 [ ] Pop Hedetet          #4 F-7       > Gory scorpion claw (KI)    NEED     -> Chloris   RED!!!
  Veinous hecteyes eyelid  key item for Chloris   0/6 steps
   >> [ ] Kill Gully Clionid   #1 I-12      > High-Quality Clionid Wing  FARM     -> Halimede
    2 [ ] Pop Halimede         #1 G-12      > Shriveled Wing             NEED     -> Ophanim
    3 [ ] Kill Gulch Limule    #1 H-11      > High-Quality Limule Pincer FARM     -> Vetehinen
    4 [ ] Pop Vetehinen        #1 H-10      > Tarnished Pincer           NEED     -> Ophanim
    5 [ ] Kill Beholder        #2* G-9      > Bloodshot Hecteye          FARM     -> Ophanim
    6 [ ] Pop Ophanim          #2* G-9      > Veinous hecteyes eyelid (KI) NEED   -> Chloris   RED!!!
  ...

FISTULE  Abyssea - Konschtat  spawn #6 G-3   Vial of Fistule Discharge 0 / 50
  for Gandiva
  Pops when you bring the NM Guimauve next to it, at (G-3) by Conflux #6.
  Find Guimauve (G-4, #6), claim it and pull it to Fistule at (G-3).

Searched bags + key items 17:52:10 (12s ago)  -  //empy refresh
```

## Tall layout

`//empy layout tall` switches to a narrow window (about 44 characters wide) that's built
around the **one thing to do next**. `//empy layout wide` switches back. The wide layout, with
every step for every key item, stays the default.

```
EMPYBUILDER                       #2* 38y  [-]
CHLORIS  Abyssea - Tahrongi
2Lf. Chloris Bud  9 in inv
13 / 50
[#######---------------------] 26%
for Redemption, Rhongomiant
+------------------------------------------+
| NEXT                         you're here |
| Pop Gancanagh         ??? #2* H-8        |
| trade Alkaline Humus          [x] have   |
| get   Acidic Humus                       |
| then  -> Hedetet -> Gory scorpion claw   |
+------------------------------------------+
KEY ITEMS                                1/4
[x] Torn bat wing                     done
>   Gory scorpion claw      [##--]    2/4 RED!!!
[ ] Veinous hecteyes eyelid [------]  0/6 RED!!!
[ ] Mossy adamantoise shell [-]       0/1 RED!!!

Gory scorpion claw                     steps
  [x] Pachypodium      #7 H/I-8  HAVE
  >>  Gancanagh        #2* H-8   POP IT
  [x] Canyon Scorpion  #4 F-7    HAVE
  [ ] Hedetet          #4 F-7    NEED     RED!!!

Click a key item to show its steps
Searched 14:05:12 (12s ago)
```

- **Count:** the Lv80 item count is shown large, with a progress bar under it.
- **NEXT box:** the single best step for that NM right now. Something you can pop or an item
  to move to your inventory comes first, and a step at the conflux you're standing at beats
  one that needs a warp. It says where to go (`you're here` or `warp to #4`), what to trade and
  whether you have it, what you get, and what that leads to. On a key item step it carries the
  `RED!!!` reminder.
- **Key items:** one line each, with a small progress bar over that key item's whole chain.
- **Steps:** the steps for one key item: the one the NEXT step belongs to. **Click a different
  key item** to see its steps instead; click it again to go back.
- **Header:** shows the conflux you're nearest (`#2* 38y`) in place of the weapon count.
- **Fistule:** its NEXT box says where it spawns and what to pull onto it to claim it.

Opacity, minimizing, dragging, compact and every other setting work the same in both layouts.

**Farming flow.** Each key item's chain is laid out as steps in the order you do them. Every
step reads *what to kill or pop* `>` *what it gives you* `->` *the NM that item pops*, so the
item from one step feeds straight into the next NM, ending with the key item `-> Chloris`.

- **Kill** a regular mob, **Pop** an NM with items you trade, **Camp** a timed NM.
- The deepest sub-chain comes first (Gully Clionid → Halimede → Ophanim), so each item sits
  right above the NM it's for.
- `>>` marks the step to do **next**: an NM you can pop right now, otherwise the first thing
  left to farm (or an item to move into your inventory).
- With **compact** on, a step you already have hides the steps under it, and an owned key
  item shrinks to one line.

`//empy list` prints the same steps in chat.

**Where to go.** Every step has a *where* column with the nearest Veridical Conflux and the
map square, e.g. `#4 F-7` (Conflux #4, square F-7). For an NM that's where its pop ??? is. Each
NM's header shows the same for the big NM's ??? (`??? #2 I-8`). Where no spot is known for a
regular mob (a few in Uleguerand), the column shows where the NM its item pops is, marked `~`
(`~#7 G-5`), since that's where you'll take the item.

**Where you are.** While you're in La Theine, Konschtat or Tahrongi, the top of the window
says which Veridical Conflux you're nearest and how far it is (`You are nearest Conflux #2
(38 yalms)`). Every step and NM by that conflux turns green and gets a `*` (`#2*`), so you can
see at a glance what to do from where you're standing. It's re-checked every **3 seconds**
(`//empy near <seconds>`, `//empy near off`); `//empy near` on its own says it in chat.
Conflux positions come from the [SuperWarp](https://github.com/AkadenTK/superwarp) addon by
Akaden (BSD licence).

| Zone | Conflux | What's near it |
| --- | --- | --- |
| Tahrongi | #1 | Halimede, Vetehinen |
| Tahrongi | #2 | Chloris, Treble Noctules, Blood Bat, Gancanagh, Ophanim, Beholder, Abas |
| Tahrongi | #4 | Cannered Noz, Hedetet, Canyon Scorpion, Alectryon, Cluckatrice |
| Tahrongi | #6 | Chukwa, Tefenet, Adze |
| Tahrongi | #7 | Muscaliet, Hieracosphinx, Minhocao |
| Tahrongi | #8 | Glavoid |
| La Theine | #1 | Adamastor, Bathyal Gigas |
| La Theine | #2 | Pantagruel, Hadal Gigas, Grandgousier, Demersal Gigas |
| La Theine | #4 | Briareus, Carabosse, La Theine Liege, Plateau Glider, Baba Yaga, Farfadet |
| Konschtat | #5 | Alkonost, Ypotryll, Keratyrannos, Mesa Wivre |
| Konschtat | #6 | Fistule, Guimauve |
| Konschtat | #7 | Arimaspi, Deep Eye |
| Konschtat | #8 | Kukulkan |

**Opacity.** The window starts at **75%** opacity so the game shows through. The panel, its
border and the text all fade together, and the weapon picker follows the same setting.
`//empy opacity 100` makes it solid; `//empy opacity 50` fades it further (10 is the lowest).
The setting is saved.

**Item count** (`13 / 50`): every bag is counted; `(9 in inv)` appears when some are elsewhere.
Yellow while you're collecting, green at 50. Chat says when the count goes up and when you
reach 50.

With no weapon picked, the window lists all 14 weapons with their Lv80 item and your count.

| Tag | Means |
| --- | --- |
| `OWNED` / `HAVE` (green) | You have it (items: in your inventory, ready to trade) |
| `IN SACK` etc. (yellow) | You have it, but in another bag; move it to your inventory to trade it |
| `POP IT` (blue) | You're missing this, but you hold everything to pop the NM that drops it |
| `NEED` | Missing; you need the steps above it first |
| `FARM` | Missing; kill the mob on that step (most also come from Gold Sturdy Pyxis) |
| `?name` | The addon couldn't find this name in the game's item list |

## Red proc alerts

In Abyssea, key items dropped by NMs aren't guaranteed. A **red proc** (an elemental weapon
skill that matches the NM's weakness) guarantees the pop key item to whoever claimed the NM.
Every key item in these chains comes from an NM, so each carries `RED!!!` until you own it.
When you **target** that NM, the tag flashes and reads `RED!!! proc it`. Ordinary pop items
(fangs, shields, scales...) need no red proc. `//empy red off` turns the alerts off.

## Respawn timers

Chukwa, Adze and Minhocao respawn **10-15 minutes** after they die, and Fistule **15-20
minutes**. EmpyBuilder watches the chat log for the kill (*... defeats Chukwa.* or *Chukwa
falls to the ground.*) and counts down:

- **Steps:** a timed NM's line shows `respawn 6-11m` while it can't be up yet, `may be up
  (<4m)` once its window opens, and `should be up` after. Before you've seen it die, the line
  shows `10-15m respawn` as a reminder.
- **NEXT box:** says `respawns in 6-11 min (died 00:31)`, `respawn window open` or `should be
  up now`.
- **Next step:** while a timed NM can't have respawned yet, the NEXT step moves on to
  something else you can do in the meantime, and comes back to it when nothing else is left.
- **Chat:** `Chukwa down: respawns in 10-15 min (about 00:41-00:46)`.

If someone else kills it out of your sight, start the timer yourself:
`//empy killed chukwa`, or `//empy killed chukwa 4` if it died 4 minutes ago.
`//empy killed clear` clears every timer. Timers are kept until you reload the addon.

## Red proc helper

A **RED PROC** section at the bottom of the window (both layouts) helps you land the red proc
that guarantees each key item. It shows while any NM you're working on still has a key item
left to get.

- **Your weapon skills:** it lists which red-proc weapon skills you can use with what you have
  equipped right now, e.g. `yours now: Shadow of Death (Dark)`.
- **Your target:** target a `RED!!!` NM and the section names it and its key item.
- **Reading the chat log:** with the **Abyssite of Discernment**, the game tells you the
  weakness when you use the wrong elemental weapon skill (*The fiend appears vulnerable to ice
  elemental weapon skills!*, with the element in place of "ice"). EmpyBuilder reads that line and shows the weapon skills for that
  element and which of them you can use now, or which weapon to swap to. A chat line says the
  same (`Hedetet is weak to Dark: use Shadow of Death`).
- **When it lands:** after *The fiend is frozen in its tracks.* it shows `Red proc landed:
  the key item will drop`.

The 13 weapon skills that can red proc in Abyssea:

| Element | Weapon skills |
| --- | --- |
| Fire | Red Lotus Blade (Sword) |
| Ice | Freezebite (Great Sword) |
| Wind | Cyclone (Dagger), Tachi: Jinpu (Great Katana) |
| Earth | Earth Crusher (Staff) |
| Lightning | Raiden Thrust (Polearm) |
| Light | Seraph Blade (Sword), Seraph Strike (Club), Tachi: Koki (Great Katana), Sunburst (Staff) |
| Dark | Shadow of Death (Scythe), Energy Drain (Dagger), Blade: Ei (Katana) |

No weapon skill red procs Water. What a fiend is weak to is remembered per mob until it dies,
you zone, or 10 minutes pass (weaknesses can change when an NM respawns). `//empy red off`
hides the section along with the `RED!!!` tags.

## Searching

Every bag (inventory, satchel, sack, case, wardrobes, safe, storage, locker) and your key items
are searched right away whenever an item or key item changes or you zone, plus a full search
every **60 seconds** (`//empy every <seconds>`, `0` = changes only), plus `//empy refresh`.

## Commands

`//empy` or `//empybuilder`

| Command | Does |
| --- | --- |
| `pick` | Open the weapon picker window |
| `stage [80\|85\|90\|done\|auto] [weapon]` | Show every stage of your weapons, or set one by hand (`auto`: from your bags) |
| `next [weapon]` | Move a weapon (or all of them) to its next stage |
| `full [on\|off]` | Also show the NMs for each weapon's later stages, marked `LATER` |
| `path <weapon>` | All three stages for one weapon in chat |
| `weapon <name or type>` | Add a weapon you're building: `weapon Rhongomiant`, `weapon polearm` |
| `add <name or type>` / `remove <name or type>` | Same as `weapon` / take one off the list |
| `<name or type>` | Shortcut for `add`: `//empy scythe` |
| `clear` | Remove all weapons |
| `weapons` (or `weapon` alone) | All 14 weapons in chat, with item, NM and your count |
| `show` / `hide` / `toggle` / `min` | Window visibility / minimize to the header |
| `compact [on\|off]` | Hide what's under a step you already have |
| `red [on\|off]` | `RED!!!` alerts |
| `where farm\|abyssea\|always` | Where the window appears: the three Lv80 zones (default), any Abyssea zone, or everywhere |
| `zone [on\|off]` | Inside those zones, only show NMs for the zone you're in |
| `announce [on\|off]` | Chat lines for new key items, count increases and reaching 50 |
| `every <seconds>` | Timed search (default 60; `0` = changes only) |
| `goal <n>` | Use this many items for every stage; `goal 0` goes back to 50 / 50 / 75 |
| `near [on\|off\|<seconds>]` | Nearest conflux: on / off / how often it's checked (default 3 s); alone, says it in chat |
| `killed <nm> [min ago]` | Start a respawn timer for a timed NM (Chukwa, Tunga, Hazhdiha...); `killed clear` clears them |
| `layout wide\|tall` | Wide window with every step (default), or the narrow next-step window |
| `opacity <10-100>` | How see-through the window is, panel and text together (default **75**) |
| `size <n>` / `pos <x> <y>` | Text size / window position |
| `list` | Your NMs' chains and status in chat |
| `refresh` | Search bags and key items now |

Display settings and window colours are in `addons/EmpyBuilder/data/settings.xml`; each
character's weapon list is in `addons/EmpyBuilder/data/<CharacterName>.xml`.

## Notes

- Every chain is checked against Arciel Spira's Abyssea zone maps (wilddragonchase.com) as well
  as BG Wiki. The maps also gave Uleguerand's conflux numbers, the spots of the Tahrongi
  regular mobs, Fistule's real trigger (Guimauve), and the NMs that spawn among regular mobs:
  Sisyphus (Verglas Golems), Kur (Adasaurus), Jaculus (Putrid Peapuk), Deelgeed (Deimobugard)
  and Ansherekh (Manigordo).
- Timed Lv85/Lv90 NMs (Tunga, Amun, Gukumatz, Heqet, Hrosshvalur, Lord Varney, Hazhdiha,
  Ansherekh, Jaculus, Deelgeed) get the same 10-15 minute respawn timers as Chukwa.

- Items and key items are matched by name against Windower's resources (short and long
  names), so no IDs are hard-coded. Any name that isn't found is listed in chat on load.
- The addon can't see an NM's weakness; use your Abyssite of Discernment for the element.
