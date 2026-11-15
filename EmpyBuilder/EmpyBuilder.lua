--[[
EmpyBuilder: a display window for building the Empyrean weapons, Lv80 to Lv119.

Each Lv80 and Lv85 trial needs 50 of one Abyssea NM's drop, and Lv90 needs 75;
after that come Heavy Metal (Lv95), Riftcinder or Riftdross (Lv99) and Riftborn
Boulders (Lv119). Pick the weapon(s) you're building and the window shows how
many of the item you have (13 / 50) and the NM's whole pop chain, checked against
your bags and key items. Key items that only drop for sure on a red proc are
flagged RED!!!.

  //empy help    (or //empybuilder)

How the file is laid out, top to bottom:
  Settings             defaults for data/settings.xml
  Data                 every NM's pop chain, the materials, conflux spots, weapons
  Helpers              finding weapons by name or type, each character's file
  Stages               which stage each weapon is on
  Name -> ID lookup    item, key item and zone ids from Windower's resources
  The window           rectangles, text boxes, opacity, alerts, the tall layout
  Searching            reading bags and key items, working out each step's state
  Rendering            timers, chain steps, conflux, marks, red proc helper,
                       the NEXT box, kill log, other characters' counts,
                       Abyssea time, then the tall and wide layouts
  Refresh              search + announce + draw, and the frame loop
  Kills and chat       defeat messages, weakness and red proc lines
  Weapon picker        the clickable window for choosing weapons
  Lights window        lights this visit and what gold chests here can give
  Atma window          which Atmas in this zone you still need
  Commands             //empy help, status, and every command
  Load                 checks names and loads the character

Lua lets the main chunk have only 200 locals and a function only 60 outside
locals, so some sections sit inside do ... end blocks or their own function,
and the commands are split into three parts.
]]

-- Addon details Windower shows in //lua list, and the chat commands it answers to
_addon.name     = 'EmpyBuilder'
_addon.author   = 'Valdimar @ Phoenix'
_addon.version  = '3.1'
_addon.commands = {'empy', 'empybuilder'}

-- Says in chat when a newer version is on GitHub (once per load; see update_check.lua)
require('update_check').start({
    name    = 'EmpyBuilder',
    version = _addon.version,
    url     = 'https://raw.githubusercontent.com/Valdimar/EmpyBuilder/main/EmpyBuilder/EmpyBuilder.lua',
    page    = 'github.com/Valdimar/EmpyBuilder',
})

-- Windower libraries: logger (chat helpers), config (XML settings files),
-- texts (on-screen text boxes) and resources (the game's item, key item and zone lists)
require('logger')
local config = require('config')
local texts  = require('texts')
local res    = require('resources')

-------------------------------------------------------------------------------
-- Settings
-------------------------------------------------------------------------------
local defaults = {
    window = {
        pos     = {x = 400, y = 200},
        padding = 8,
        bg      = {alpha = 215, red = 14,  green = 18,  blue = 26},
        header  = {alpha = 235, red = 30,  green = 38,  blue = 56},
        border  = {alpha = 255, red = 90,  green = 110, blue = 150},
    },
    font         = 'Consolas',
    size         = 10,
    weapons      = '',      -- old shared list; weapons now live per character in data/<Name>.xml
    goal_override = 0,      -- 0: 50 for Lv80/85, 75 for Lv90; else this for every stage
    compact      = true,    -- hide what's under a step you already have
    only_in_zone = false,   -- only show NMs for the Abyssea zone you're in
    announce     = true,    -- chat line on new key items and on reaching the goal
    red_alerts   = true,    -- RED!!! tags on key items that need a red proc
    minimized    = false,   -- header strip only (click the header to toggle)
    rescan       = 60,      -- full bag + key item search every N seconds
    show_in      = 'farm',  -- where the window appears: farm | abyssea | always
    opacity      = 75,      -- whole window, panel and text (10-100%)
    near_rate    = 3,       -- seconds between "nearest conflux" checks (0 = off)
    layout       = 'wide',  -- wide (every step) | tall (narrow, next-step focus)
    sounds       = true,    -- play a sound with alerts
    flash        = true,    -- show alerts big on screen
    alerts = {              -- which events alert
        soon     = true,    -- a timed NM's window opens in about a minute
        respawn  = true,    -- a timed NM's respawn window opens
        up       = false,   -- a timed NM's window has passed: it should be up
        atma     = true,    -- you target an NM whose Atma you don't have
        weakness = true,    -- the log names your target's weakness
        redproc  = true,    -- a red proc lands
        goal     = true,    -- you reach 50 / 75 of an item
        time     = true,    -- 10 and 5 minutes of Abyssea time left
    },
    atma = {                -- the separate Atma window
        visible = false,
        pos     = {x = 60, y = 520},
    },
    procs = {               -- the separate red proc weapon skill window
        visible = false,
        pos     = {x = 60, y = 380},
    },
    lights = {              -- the separate lights window
        visible = false,
        pos     = {x = 60, y = 300},
    },
    visible      = true,
}
-- Load data/settings.xml, filling in anything missing from the defaults above
local settings = config.load(defaults)

-------------------------------------------------------------------------------
-- Data: every stage NM (Lv80, Lv85, Lv90) and its pop chain, then the materials
-- (Lv95, Lv99, Lv119). Each NM entry has its name, zone, the ??? spot, the item
-- it drops (with its short and long names) and the key items that pop it.
--   ki   = key item              item = accepted names (short / long)
--   from = what drops it         at   = map position
--   vc   = Veridical Conflux nearest `from` (from the BG Wiki farming flowcharts;
--          left out where the wiki gives none, and the NM it feeds is used with ~)
--   red  = needs a red proc      kids = what pops the NM in `from`
-------------------------------------------------------------------------------
local NMS = {
    -- Lv80: Verethragna, Redemption, Rhongomiant
    chloris = {
        name = 'Chloris', zone = 'Abyssea - Tahrongi', at = '(I-8)', vc = 2,
        drop = {'2Lf. Chloris Bud', 'Two-leaf Chloris Bud', '2Leaf Chloris Bud'},
        kids = {
            { ki = 'Torn bat wing', from = 'Treble Noctules', at = '(I-9)', vc = 2, red = true, kids = {
                { item = {'Bloody Fang'},     from = 'Blood Bat',    at = '(I-9)', vc = 2 },
                { item = {'Exorcised Skull'}, from = 'Cannered Noz', at = '(F-6)', vc = 4, kids = {
                    { item = {'Baleful Skull'}, from = 'Caoineag', at = '(F-6)', vc = 4 },
                }},
            }},
            { ki = 'Gory scorpion claw', from = 'Hedetet', at = '(F-7)', vc = 4, red = true, kids = {
                { item = {'Venomous Scorpion Stinger', 'Venom. Scorp. Stinger', 'Ven. Scorp. Stinger'},
                  from = 'Canyon Scorpion', at = '(F-7)', vc = 4 },
                { item = {'Acidic Humus'}, from = 'Gancanagh', at = '(H-8)', vc = 2, kids = {
                    { item = {'Alkaline Humus'}, from = 'Pachypodium', at = '(H/I-8)', vc = 7 },
                }},
            }},
            { ki = 'Veinous hecteyes eyelid', from = 'Ophanim', at = '(G-9)', vc = 2, red = true, kids = {
                { item = {'Bloodshot Hecteye', 'Bl. Hecteye'}, from = 'Beholder', at = '(G-9)', vc = 2 },
                { item = {'Shriveled Wing'}, from = 'Halimede', at = '(G-12)', vc = 1, kids = {
                    { item = {'High-Quality Clionid Wing', 'H.Q. Clionid Wing', 'HQ Clionid Wing'}, from = 'Gully Clionid', at = '(I-12)', vc = 1 },
                }},
                { item = {'Tarnished Pincer'}, from = 'Vetehinen', at = '(H-10)', vc = 1, kids = {
                    { item = {'High-Quality Limule Pincer', 'H.Q. Limule Pincer', 'HQ Limule Pincer'}, from = 'Gulch Limule', at = '(H-11)', vc = 1 },
                }},
            }},
            { ki = 'Mossy adamantoise shell', from = 'Chukwa', at = '(F-5)', vc = 6, red = true, note = 'timed', respawn = {10, 15} },
        },
    },

    -- Lv80: Twashtar, Ukonvasara
    glavoid = {
        name = 'Glavoid', zone = 'Abyssea - Tahrongi', at = '(I-5)', vc = 8,
        drop = {'Glavoid Shell'},
        kids = {
            { ki = 'Fat-lined cockatrice skin', from = 'Alectryon', at = '(H-8)', vc = 4, red = true, kids = {
                { item = {'Cockatrice Tailmeat', 'Ctrice. Tailmeat', 'Chunk of Cockatrice Tailmeat'},
                  from = 'Cluckatrice', at = '(H-8)', vc = 4 },
                { item = {'Quivering Eft Egg', 'Qvr. Eft Egg'}, from = 'Abas', at = '(K-10)', vc = 2, kids = {
                    { item = {'Eft Egg'}, from = 'Canyon Eft', at = '(J-10/11)', vc = 2 },
                }},
            }},
            { ki = 'Luxuriant manticore mane', from = 'Muscaliet', at = '(I-6)', vc = 7, red = true, kids = {
                { item = {'Resilient Mane'}, from = 'Hieracosphinx', at = '(J-6)', vc = 7 },
                { item = {'Smooth Whisker'}, from = 'Tefenet', at = '(G-6)', vc = 6, kids = {
                    { item = {'Shocking Whisker'}, from = 'Jaguarundi', at = '(H-6)', vc = 6 },
                }},
            }},
            { ki = 'Sticky gnat wing',     from = 'Adze',     at = '(G-5)', vc = 6, red = true, note = 'timed', respawn = {10, 15} },
            { ki = 'Sodden sandworm husk', from = 'Minhocao', at = '(I-6)', vc = 7, red = true, note = 'timed', respawn = {10, 15} },
        },
    },

    -- Lv80: Almace, Kannagi
    briareus = {
        name = 'Briareus', zone = 'Abyssea - La Theine', at = '(G-6)', vc = 4,
        drop = {'Helm of Briareus', 'Briareus\'s Helm', 'Briareus Helm'},
        kids = {
            { ki = 'Dented Gigas shield', from = 'Adamastor', at = '(C-4)', vc = 1, red = true, kids = {
                { item = {'Trophy Shield'}, from = 'Bathyal Gigas', at = '(C-4/5)', vc = 1 },
            }},
            { ki = 'Warped Gigas armband', from = 'Pantagruel', at = '(F-7)', vc = 2, red = true, kids = {
                { item = {'Oversized Sock'}, from = 'Hadal Gigas', at = '(F-6/7)', vc = 2 },
            }},
            { ki = 'Severed Gigas collar', from = 'Grandgousier', at = '(F-10)', vc = 2, red = true, kids = {
                { item = {'Massive Armband'}, from = 'Demersal Gigas', at = '(E/F-9)', vc = 2 },
            }},
        },
    },

    -- Lv80: Caladbolg, Masamune, Armageddon
    carabosse = {
        name = 'Carabosse', zone = 'Abyssea - La Theine', at = '(H-7)', vc = 4,
        drop = {"Carabosse's Gem", 'Carabosse Gem'},
        kids = {
            { ki = 'Pellucid fly eye', from = 'La Theine Liege', at = '(I-7)', vc = 4, red = true, kids = {
                { item = {'Transparent Insect Wing', 'Trans. Insect Wing', 'Transp. Insect Wing'},
                  from = 'Plateau Glider', at = '(H-7/8)', vc = 4 },
            }},
            { ki = 'Shimmering pixie pinion', from = 'Baba Yaga', at = '(H-7)', vc = 4, red = true, kids = {
                { item = {'Piceous Scale'}, from = 'Farfadet', at = '(G/H-7)', vc = 4 },
            }},
        },
    },

    -- Lv80: Hvergelmir
    kukulkan = {
        name = 'Kukulkan', zone = 'Abyssea - Konschtat', at = '(H-5)', vc = 8,
        drop = {"Kukulkan's Fang", 'Kukulkan Fang'},
        kids = {
            { ki = 'Mucid ahriman eyeball', from = 'Arimaspi', at = '(K-6)', vc = 7, red = true, kids = {
                { item = {'Clouded Lens'}, from = 'Deep Eye', at = '(J-6/7)', vc = 7 },
            }},
            { ki = 'Tattered hippogryph wing', from = 'Alkonost', at = '(H-6)', vc = 5, red = true, kids = {
                { item = {'Giant Bugard Tusk', 'Gnt. Bugard Tusk'}, from = 'Ypotryll', at = '(I-6)', vc = 5 },
            }},
            { ki = 'Cracked wivre horn', from = 'Keratyrannos', at = '(G-6)', vc = 5, red = true, kids = {
                { item = {'Armored Dragonhorn', 'Arm. Dragonhorn'}, from = 'Mesa Wivre', at = '(G/H-6)', vc = 5 },
            }},
        },
    },

    -- Lv80: Farsha, Gambanteinn, Gandiva
    fistule = {
        name = 'Fistule', zone = 'Abyssea - Konschtat', at = '(G-3)', vc = 6,
        drop = {'Vial of Fistule Discharge', 'Fistule Discharge', 'Fistule Dischrg.'},
        timed = 'Pops when you bring the NM Guimauve next to it, at (G-3) by Conflux #6.',
        respawn = {15, 20},
        info = 'Find Guimauve (G-4, #6), claim it and pull it to Fistule at (G-3).',
        kids = {},
    },

    ---------------------------------------------------------------------------
    -- Level 85 (50 each): Attohwa, Misareaux, Vunkerl
    ---------------------------------------------------------------------------
    -- Lv85: Verethragna, Redemption, Rhongomiant
    ulhuadshi = {
        name = 'Ulhuadshi', zone = 'Abyssea - Attohwa', at = '(J/K-7)', vc = 3, stage = 85,
        drop = {"Ulhuadshi's Fang", 'Ulhuadshi Fang', 'Ulhu. Fang'},
        kids = {
            { ki = 'Mucid worm segment', from = 'Pallid Percy', at = '(J-7)', vc = 3, red = true, kids = {
                { item = {'Blanched Silver'}, from = 'Entozoon', at = '(J-7)', vc = 3 },
            }},
            { ki = 'Shriveled hecteyes stalk', from = 'Amun', at = '(K-9)', vc = 8, red = true,
              note = 'timed', respawn = {10, 15} },
        },
    },

    -- Lv85: Twashtar, Ukonvasara
    itzpapalotl = {
        name = 'Itzpapalotl', zone = 'Abyssea - Attohwa', at = '(K-10)', vc = 7, stage = 85,
        drop = {"Itzpapalotl's Scale", 'Itzpapalotl Scale', 'Itzpa. Scale', 'Itzpapa. Scale'},
        kids = {
            { ki = 'Bulbous crawler cocoon', from = 'Blazing Eruca', at = '(J-10)', vc = 1, red = true, kids = {
                { item = {'Eruca Egg'}, from = 'Ignis Eruca', at = '(I-10)', vc = 1 },
            }},
            { ki = 'Venomous wamoura feeler', from = 'Granite Borer', at = '(K-10)', vc = 7, red = true, kids = {
                { item = {'Withered Cocoon'}, from = 'Gullycampa', at = '(K-10)', vc = 7 },
            }},
            { ki = 'Distended chigoe abdomen', from = 'Tunga', at = '(K-9/10)', vc = 7, red = true,
              note = 'timed', respawn = {10, 15} },
        },
    },

    -- Lv85: Almace, Kannagi
    sobek = {
        name = 'Sobek', zone = 'Abyssea - Misareaux', at = '(J-11)', vc = 7, stage = 85,
        drop = {"Sobek's Skin", 'Sobek Skin'},
        kids = {
            { ki = 'Bloodstained bugard fang', from = 'Minax Bugard', at = '(K-10)', vc = 7, red = true, kids = {
                { item = {'Bewitching Tusk'}, from = 'Abyssobugard', at = '(K-10/11)', vc = 7 },
            }},
            { ki = 'Gnarled lizard nail', from = 'Sirrush', at = '(I-11)', vc = 7, red = true, kids = {
                { item = {'Molt Scraps'}, from = 'Dusk Lizard', at = '(J-11)', vc = 7 },
            }},
            { ki = 'Molted peiste skin', from = 'Gukumatz', at = '(J-11)', vc = 7, red = true,
              note = 'timed', respawn = {10, 15} },
        },
    },

    -- Lv85: Caladbolg, Masamune, Armageddon
    cireincroin = {
        name = 'Cirein-croin', zone = 'Abyssea - Misareaux', at = '(J/K-7)', vc = 3, stage = 85,
        drop = {"Cirein-croin's Lantern", 'Cirein. Lantern', 'Cirein-croin Lantern'},
        kids = {
            { ki = 'Glistening orobon liver', from = 'Cep-Kamuy', at = '(F-5)', vc = 5, red = true, kids = {
                { item = {'Orobon Cheekmeat', 'Orbn. Cheekmeat', 'Orobon Chkmeat.'}, from = 'Ancient Orobon', at = '(F-5)', vc = 5 },
            }},
            { ki = 'Doffed poroggo hat', from = 'Heqet', at = '(I-6)', vc = 0, red = true,
              note = 'timed', respawn = {10, 15} },
        },
    },

    -- Lv85: Hvergelmir
    sedna = {
        name = 'Sedna', zone = 'Abyssea - Vunkerl', at = '(K-6)', vc = 3, stage = 85,
        drop = {"Sedna's Tusk", 'Sedna Tusk'},
        kids = {
            { ki = 'Glossy sea monk sucker', from = 'Iku-Turso', at = '(J-7)', vc = 3, red = true, kids = {
                { item = {'Moonbeam Clam'}, from = 'Jasconius', at = '(I/J-7)', vc = 3 },
            }},
            { ki = 'Shimmering pugil scale', from = 'Hrosshvalur', at = '(J/K-6)', vc = 3, red = true,
              note = 'timed', respawn = {10, 15} },
        },
    },

    -- Lv85: Farsha, Gambanteinn, Gandiva
    bukhis = {
        name = 'Bukhis', zone = 'Abyssea - Vunkerl', at = '(G-10)', vc = 4, stage = 85,
        drop = {"Bukhis's Wing", 'Bukhis Wing'},
        kids = {
            { ki = 'Ingrown taurus nail', from = 'Khalkotaur', at = '(H-10)', vc = 4, red = true, kids = {
                { item = {'Gnarled Taurus Horn', 'Gnrl. Taurus Horn'}, from = 'Aestutaur', at = '(G-9/10)', vc = 4 },
            }},
            { ki = 'Ossified gargouille hand', from = 'Quasimodo', at = '(G-11)', vc = 4, red = true, kids = {
                { item = {'Gargouille Stone'}, from = 'Gruesome Gargouille', at = '(F-10)', vc = 4 },
            }},
            { ki = 'Imbrued vampyr fang', from = 'Lord Varney', at = '(G/H-10)', vc = 5, red = true,
              note = 'timed', respawn = {10, 15} },
        },
    },

    ---------------------------------------------------------------------------
    -- Level 90 (75 each): Altepa, Uleguerand, Grauberg
    ---------------------------------------------------------------------------
    -- Lv90: Verethragna, Redemption, Rhongomiant
    dragua = {
        name = 'Dragua', zone = 'Abyssea - Altepa', at = '(G-9)', vc = 4, stage = 90,
        drop = {"Dragua's Scale", 'Dragua Scale'},
        kids = {
            { ki = 'Bloodied dragon ear', from = 'Hazhdiha', at = '(G/H-9/10)', vc = 4, red = true,
              note = 'timed', respawn = {10, 15} },
        },
    },

    -- Lv90: Twashtar, Ukonvasara
    orthrus = {
        name = 'Orthrus', zone = 'Abyssea - Altepa', at = '(F-7)', vc = 7, stage = 90,
        drop = {"Orthrus's Claw", 'Orthrus Claw'},
        kids = {
            -- Amarok's trade items follow BG Wiki's flowchart (Sharabha, Camelopardalis and Ansherekh feed it)
            { ki = 'Steaming cerberus tongue', from = 'Amarok', at = '(G-5)', vc = 3, red = true, kids = {
                { item = {'Sharabha Hide'}, from = 'Sharabha', at = '(G-5)', vc = 3, kids = {
                    { item = {'Sand-caked Fang', 'Sand-caked fang'}, from = 'Dune Manticore', at = '(F-5/6)', vc = 7 },
                }},
                { item = {'H.Q. Dhalmel Hide', 'High-Quality Dhalmel Hide'}, from = 'Camelopardalis', at = '(F-6/7)', vc = 7 },
                { item = {'Tiger King Hide'}, from = 'Ansherekh', at = '(F-7/8)', vc = 7, note = 'timed', respawn = {10, 15},
                  hint = 'spawns among Manigordo' },
            }},
        },
    },

    -- Lv90: Almace, Kannagi
    apademak = {
        name = 'Apademak', zone = 'Abyssea - Uleguerand', at = '(F-6)', vc = 7, stage = 90,
        drop = {"Apademak's Horn", 'Apademak Horn'},
        kids = {
            { ki = 'Torn khimaira wing', from = 'Dhorme Khimaira', at = '(G-7)', vc = 7, red = true, kids = {
                { item = {'Snow God Core'}, from = 'Upas-Kamuy', at = '(G-5)', vc = 7, kids = {
                    { item = {'Gelid Arm'}, from = 'Snowflake', vc = 7 },
                }},
                { item = {'Sisyphus Fragment'}, from = 'Sisyphus', at = '(G-6)', vc = 7,
                  note = 'lottery', hint = 'free spawn among Verglas Golems' },
                { item = {'H.Q. Marid Hide', 'High-Quality Marid Hide'}, from = 'Olyphant', vc = 7 },
            }},
        },
    },

    -- Lv90: Caladbolg, Masamune, Armageddon
    isgebind = {
        name = 'Isgebind', zone = 'Abyssea - Uleguerand', at = '(I-5)', vc = 6, stage = 90,
        drop = {"Isgebind's Heart", 'Isgebind Heart'},
        kids = {
            { ki = 'Begrimed dragon hide', from = 'Kur', at = '(I/J-5)', vc = 6, red = true,
              note = 'lottery', hint = 'free spawn among Adasaurus' },
        },
    },

    -- Lv90: Farsha, Gambanteinn, Gandiva
    alfard = {
        name = 'Alfard', zone = 'Abyssea - Grauberg', at = '(J-8)', vc = 8, stage = 90,
        drop = {"Alfard's Fang", 'Alfard Fang'},
        kids = {
            { ki = 'Venomous hydra fang', from = 'Ningishzida', at = '(I-7/8)', vc = 8, red = true, kids = {
                { item = {'Minaruja Skull'}, from = 'Minaruja', at = '(I-10)', vc = 3, kids = {
                    { item = {"Pursuer's Wing", 'Pursuer Wing'}, from = 'Faunus Wyvern', at = '(I-9/10)', vc = 3 },
                }},
                { item = {'Jaculus Wing'}, from = 'Jaculus', at = '(I-8/9)', vc = 3, note = 'timed', respawn = {10, 15},
                  hint = 'spawns among Putrid Peapuk' },
                { item = {'H.Q. Wivre Hide', 'High-Quality Wivre Hide'}, from = 'Glade Wivre', at = '(I-8)', vc = 8 },
            }},
        },
    },

    -- Lv90: Hvergelmir
    azdaja = {
        name = 'Azdaja', zone = 'Abyssea - Grauberg', at = '(C-8)', vc = 7, stage = 90,
        drop = {"Azdaja's Horn", 'Azdaja Horn'},
        kids = {
            { ki = 'Vacant bugard eye', from = 'Deelgeed', at = '(F-9)', vc = 7, red = true,
              note = 'timed', respawn = {10, 15}, hint = 'spawns among Deimobugard' },
        },
    },
}
-------------------------------------------------------------------------------
-- After Lv90 the trades are materials, not one NM's drop. Quantities from the
-- Trial of the Magians lists as posted on the official forums (Lv99, Lv119)
-- and BG Wiki (Lv95).
-------------------------------------------------------------------------------
-- Lv95: Heavy Metal plates (tradeable, so other characters' counts can be added in)
NMS.heavymetal = {
    name = 'Heavy Metal', material = true, stage = 95, goal = 1500, tradeable = true,
    drop = {'Heavy Metal'}, kids = {},
    info = {'From Ambuscade (Gorpa-Masorpa, Mhaura G-9) and Voidwatch', 'Riftworn Pyxis (Kaggen, Akvan, Pil, Botulus Rex...)',
            'Trade at a Trial of the Magians moogle'},
}
-- Lv99, half of the weapons: Riftcinder
NMS.riftcinder = {
    name = 'Riftcinder', material = true, stage = 99, goal = 60,
    drop = {'Riftcinder'}, kids = {},
    info = {'From Voidwatch Riftworn Pyxis', 'Trade at a Trial of the Magians moogle'},
}
-- Lv99, the other half: Riftdross
NMS.riftdross = {
    name = 'Riftdross', material = true, stage = 99, goal = 60,
    drop = {'Riftdross'}, kids = {},
    info = {'From Voidwatch Riftworn Pyxis', 'Trade at a Trial of the Magians moogle'},
}
-- Lv119: Riftborn Boulders
NMS.boulder = {
    name = 'Riftborn Boulder', material = true, stage = 119, goal = 300,
    drop = {'Riftborn Boulder', 'Riftborn Bldr.'}, kids = {},
    info = {'From Voidwatch Riftworn Pyxis', 'Upgrades the Lv99 weapon to Lv119'},
}

-- The order NMs are searched and listed in: Lv80, Lv85, Lv90, then the materials
local NM_ORDER = {'chloris', 'glavoid', 'briareus', 'carabosse', 'kukulkan', 'fistule',
                  'ulhuadshi', 'itzpapalotl', 'sobek', 'cireincroin', 'sedna', 'bukhis',
                  'dragua', 'orthrus', 'apademak', 'isgebind', 'alfard', 'azdaja',
                  'heavymetal', 'riftcinder', 'riftdross', 'boulder'}

-- Stage defaults: the six Lv80 NMs have no stage field, so they get 80 here, and
-- every NM gets the item count its trial needs.
local STAGES = {80, 85, 90, 95, 99, 119}
-- Items each NM trial needs, by stage (materials set their own goal)
local STAGE_GOAL = {[80] = 50, [85] = 50, [90] = 75}
-- The weapon level you hand in for each stage (a Lv80 trial takes the Lv75 weapon)
local STAGE_BEFORE = {[80] = 75, [85] = 80, [90] = 85, [95] = 90, [99] = 95, [119] = 99}
for _, nm in pairs(NMS) do
    nm.stage = nm.stage or 80
    nm.goal = nm.goal or STAGE_GOAL[nm.stage]
end

-- Where to get an NM's item, for chat lines
local function source_of(nm)
    if nm.material then return nm.info[1] end
    return ('%s (%s)'):format(nm.name, nm.zone)
end

-- Where each Veridical Conflux stands (x, y in game coordinates). Positions from
-- the SuperWarp addon by Akaden (BSD licence): https://github.com/AkadenTK/superwarp
local CONFLUX = {
    ['Abyssea - La Theine'] = {
        {1, -480.0, 764.0}, {2, -593.8, 30.2}, {3, -123.0, -39.0}, {4, -54.6, 175.3},
        {5, 201.7, -398.2}, {6, 595.4, -507.2}, {7, 494.2, 333.1}, {8, 215.1, -198.9},
    },
    ['Abyssea - Konschtat'] = {
        {1, 126.0, -834.0}, {2, -164.0, -276.0}, {3, -644.0, 124.0}, {4, 20.0, 45.0},
        {5, -125.0, 282.0}, {6, -316.0, 564.0}, {7, 476.0, 124.0}, {8, 244.0, 636.0},
    },
    ['Abyssea - Tahrongi'] = {
        {1, 7.8, -636.8}, {2, 24.0, -171.6}, {3, -290.8, -171.7}, {4, -239.9, 166.2},
        {5, -56.1, 547.4}, {6, -64.6, 331.8}, {7, 120.1, 155.1}, {8, 324.2, 433.3},
    },
    ['Abyssea - Attohwa'] = {
        {1, -140.0, -200.0}, {2, -485.5, -4.9}, {3, 258.9, -21.2}, {4, -603.9, 191.9},
        {5, 466.8, 78.0}, {6, -247.1, 283.6}, {7, 378.8, -141.9}, {8, 1.4, 150.8},
        {0, -280.0, 0.0},
    },
    ['Abyssea - Misareaux'] = {
        {1, 634.0, 286.0}, {2, 399.4, 33.2}, {3, -96.8, 254.3}, {4, 141.4, -222.4},
        {5, -40.9, 439.3}, {6, -231.3, 208.8}, {7, 289.0, -407.2}, {8, 648.3, -476.1},
        {0, 276.0, 236.0},
    },
    ['Abyssea - Vunkerl'] = {
        {1, -322.0, 676.0}, {2, -24.5, 370.2}, {3, 202.5, 312.1}, {4, -266.9, -111.4},
        {5, -118.7, -477.4}, {6, -100.0, -764.0}, {7, -675.1, -555.6}, {8, -291.0, 282.6},
        {0, 158.0, -158.0},
    },
    ['Abyssea - Altepa'] = {
        {1, 404.0, 288.0}, {2, 639.0, -126.0}, {3, -80.0, 437.0}, {4, -323.0, -263.0},
        {5, -477.0, -684.0}, {6, -640.0, -242.0}, {7, -604.0, -39.0}, {8, -826.0, -591.0},
    },
    ['Abyssea - Uleguerand'] = {
        {1, -202.0, -506.0}, {2, -381.1, -169.2}, {3, -300.8, -34.2}, {4, 137.4, -368.5},
        {5, 576.0, -8.4}, {6, 338.9, 500.1}, {7, -257.4, 236.8}, {8, -583.0, 45.5},
    },
    ['Abyssea - Grauberg'] = {
        {1, -514.0, -756.0}, {2, 321.8, -558.0}, {3, 424.0, -174.1}, {4, -26.5, -464.5},
        {5, -165.4, 405.6}, {6, 102.2, 497.3}, {7, -323.1, 113.7}, {8, 490.8, 340.6},
    },
}

-- Each weapon's NM or material at each stage: Lv80 (50), Lv85 (50), Lv90 (75),
-- then Heavy Metal for Lv95, a Rift item for Lv99 and Riftborn Boulders for Lv119
local WEAPONS = {
    {name = 'Verethragna', kind = 'H2H',          nm = {[80] = 'chloris',   [85] = 'ulhuadshi',   [90] = 'dragua', [95] = 'heavymetal', [99] = 'riftcinder', [119] = 'boulder'}},
    {name = 'Twashtar',    kind = 'Dagger',       nm = {[80] = 'glavoid',   [85] = 'itzpapalotl', [90] = 'orthrus', [95] = 'heavymetal', [99] = 'riftdross', [119] = 'boulder'}},
    {name = 'Almace',      kind = 'Sword',        nm = {[80] = 'briareus',  [85] = 'sobek',       [90] = 'apademak', [95] = 'heavymetal', [99] = 'riftcinder', [119] = 'boulder'}},
    {name = 'Caladbolg',   kind = 'Great Sword',  nm = {[80] = 'carabosse', [85] = 'cireincroin', [90] = 'isgebind', [95] = 'heavymetal', [99] = 'riftdross', [119] = 'boulder'}},
    {name = 'Farsha',      kind = 'Axe',          nm = {[80] = 'fistule',   [85] = 'bukhis',      [90] = 'alfard', [95] = 'heavymetal', [99] = 'riftcinder', [119] = 'boulder'}},
    {name = 'Ukonvasara',  kind = 'Great Axe',    nm = {[80] = 'glavoid',   [85] = 'itzpapalotl', [90] = 'orthrus', [95] = 'heavymetal', [99] = 'riftdross', [119] = 'boulder'}},
    {name = 'Redemption',  kind = 'Scythe',       nm = {[80] = 'chloris',   [85] = 'ulhuadshi',   [90] = 'dragua', [95] = 'heavymetal', [99] = 'riftcinder', [119] = 'boulder'}},
    {name = 'Rhongomiant', kind = 'Polearm',      nm = {[80] = 'chloris',   [85] = 'ulhuadshi',   [90] = 'dragua', [95] = 'heavymetal', [99] = 'riftcinder', [119] = 'boulder'}},
    {name = 'Kannagi',     kind = 'Katana',       nm = {[80] = 'briareus',  [85] = 'sobek',       [90] = 'apademak', [95] = 'heavymetal', [99] = 'riftdross', [119] = 'boulder'}},
    {name = 'Masamune',    kind = 'Great Katana', nm = {[80] = 'carabosse', [85] = 'cireincroin', [90] = 'isgebind', [95] = 'heavymetal', [99] = 'riftcinder', [119] = 'boulder'}},
    {name = 'Gambanteinn', kind = 'Club',         nm = {[80] = 'fistule',   [85] = 'bukhis',      [90] = 'alfard', [95] = 'heavymetal', [99] = 'riftdross', [119] = 'boulder'}},
    {name = 'Hvergelmir',  kind = 'Staff',        nm = {[80] = 'kukulkan',  [85] = 'sedna',       [90] = 'azdaja', [95] = 'heavymetal', [99] = 'riftdross', [119] = 'boulder'}},
    {name = 'Gandiva',     kind = 'Bow',          nm = {[80] = 'fistule',   [85] = 'bukhis',      [90] = 'alfard', [95] = 'heavymetal', [99] = 'riftcinder', [119] = 'boulder'}},
    {name = 'Armageddon',  kind = 'Gun',          nm = {[80] = 'carabosse', [85] = 'cireincroin', [90] = 'isgebind', [95] = 'heavymetal', [99] = 'riftdross', [119] = 'boulder'}},
}

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------
-- Lower-case a string (nil becomes ''), for matching names without caring about case
local function lc(s) return s and s:lower() or '' end
-- A chat line in the addon's colour (207) with the [EmpyBuilder] prefix
local function say(s) windower.add_to_chat(207, '[EmpyBuilder] ' .. s) end

-- Other names people use for the weapon types
local TYPE_ALIASES = {
    ['h2h'] = 'H2H', ['hand-to-hand'] = 'H2H', ['hand to hand'] = 'H2H', ['handtohand'] = 'H2H',
    ['knuckles'] = 'H2H', ['fists'] = 'H2H',
    ['gs'] = 'Great Sword', ['greatsword'] = 'Great Sword', ['2h sword'] = 'Great Sword',
    ['ga'] = 'Great Axe', ['greataxe'] = 'Great Axe', ['2h axe'] = 'Great Axe',
    ['gk'] = 'Great Katana', ['greatkatana'] = 'Great Katana', ['gkt'] = 'Great Katana',
    ['lance'] = 'Polearm', ['spear'] = 'Polearm', ['pole'] = 'Polearm',
    ['knife'] = 'Dagger', ['dag'] = 'Dagger',
    ['mace'] = 'Club', ['rod'] = 'Club',
    ['marksmanship'] = 'Gun', ['archery'] = 'Bow',
}

-- Letters you'd have to change to turn a into b (for typos like "Rhongomaint")
local function distance(a, b)
    if a == b then return 0 end
    local prev = {}
    for j = 0, #b do prev[j] = j end
    for i = 1, #a do
        local cur = {[0] = i}
        for j = 1, #b do
            local cost = (a:sub(i, i) == b:sub(j, j)) and 0 or 1
            cur[j] = math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
        end
        prev = cur
    end
    return prev[#b]
end

-- Weapons matching a name or a type. Returns a list (a type can match one weapon only,
-- but a typo can be close to two names) and how it matched.
local function find_weapons(q)
    -- Tidy the query: lower case, no spaces at the ends, single spaces inside
    q = lc(q):gsub('^%s+', ''):gsub('%s+$', ''):gsub('%s+', ' ')
    if q == '' then return {}, nil end
    -- Every weapon that passes test(w)
    local function where(test)
        local out = {}
        for _, w in ipairs(WEAPONS) do if test(w) then out[#out + 1] = w end end
        return out
    end
    local found
    -- 1. exact name, 2. exact type or alias
    found = where(function(w) return lc(w.name) == q end)
    if #found > 0 then return found, 'name' end
    local t = lc(TYPE_ALIASES[q] or q)
    found = where(function(w) return lc(w.kind) == t end)
    if #found > 0 then return found, 'type' end
    -- 3. start of a name, 4. start of a type ("great" matches all three great weapons)
    found = where(function(w) return lc(w.name):sub(1, #q) == q end)
    if #found > 0 then return found, 'name' end
    found = where(function(w) return lc(w.kind):sub(1, #q) == q end)
    if #found > 0 then return found, 'type' end
    -- 5. close spelling of a name or type (about one wrong letter in four)
    if #q >= 4 then
        local best, list = math.huge, {}
        for _, w in ipairs(WEAPONS) do
            local d = math.min(distance(q, lc(w.name)), distance(q, lc(w.kind)))
            if d < best then best, list = d, {w} elseif d == best then list[#list + 1] = w end
        end
        if best <= math.max(1, math.floor(#q / 4)) then return list, 'spelling' end
    end
    return {}, nil
end

-- One weapon, or nil (with the candidates when the query is ambiguous)
local function find_weapon(q)
    local list = find_weapons(q)
    if #list == 1 then return list[1] end
    return nil, list
end

-- Each character keeps its own weapon list in data/<CharacterName>.xml
local char = {name = nil, data = nil}

-- Load (or create) a character's file: weapons, stages, full mode, Atmas seen and
-- the kill log. Returns false when there's no name yet.
local function load_character(name)
    if not name or name == '' then return false end
    if char.name == name and char.data then return true end
    char.name = name
    -- stages: "Redemption=85,Twashtar=auto"; full: also show the later stages
    char.data = config.load('data/' .. name .. '.xml', {weapons = '', picked = false, stages = '', full = false,
        atmas = '', atmas_seeded = false, killlog = ''})
    -- One-time move from the old shared list (EmpyBuilder 2.0/2.1)
    if char.data.weapons == '' and (settings.weapons or '') ~= '' then
        char.data.weapons, char.data.picked = settings.weapons, true
        config.save(char.data, 'all')
    end
    return true
end

-- The weapons this character is building, as WEAPONS entries (from their saved names)
local function selected_weapons()
    local list = {}
    if not char.data then return list end
    for name in tostring(char.data.weapons or ''):gmatch('[^,]+') do
        local w = find_weapon(name:match('^%s*(.-)%s*$'))
        if w then list[#list + 1] = w end
    end
    return list
end

-- Save the list of weapons this character is building (and that they've picked)
local function save_weapons(list)
    if not char.data then return end
    local names = {}
    for _, w in ipairs(list) do names[#names + 1] = w.name end
    char.data.weapons = table.concat(names, ',')
    char.data.picked = true
    config.save(char.data, 'all')
end

-------------------------------------------------------------------------------
-- Stages. Each weapon is built Lv80 -> 85 -> 90 -> 95 -> 99 -> 119. The stage
-- you're on comes from the highest-level copy of the weapon in your bags (none:
-- Lv80, a Lv80 one: Lv85 ... a Lv99 one: Lv119, a Lv119 one: done), unless you
-- set it by hand with //empy stage.
-------------------------------------------------------------------------------
local detected = {}   -- weapon name -> stage worked out from your bags

-- Stages set by hand with //empy stage: weapon name -> 80 ... 119 or 'done'
local function stage_overrides()
    local map = {}
    if not char.data then return map end
    for name, v in tostring(char.data.stages or ''):gmatch('([^,=]+)=([^,]+)') do
        map[name] = tonumber(v) or v
    end
    return map
end

-- Set (or, with nil, clear) a weapon's stage by hand, and save it
local function set_stage(w, v)   -- v: 80 | 85 | 90 | 95 | 99 | 119 | 'done' | nil (auto)
    if not char.data then return end
    local map = stage_overrides()
    map[w.name] = v
    local parts = {}
    for name, val in pairs(map) do parts[#parts + 1] = name .. '=' .. tostring(val) end
    table.sort(parts)
    char.data.stages = table.concat(parts, ',')
    config.save(char.data, 'all')
end

-- The stage a weapon is on (80 ... 119 or 'done'), and whether it was set by hand
local function stage_of(w)
    local o = stage_overrides()[w.name]
    if o then return o, true end
    return detected[w.name] or 80, false
end

-- The stage that comes after each one; after 119 the weapon is done
local NEXT_STAGE = {[80] = 85, [85] = 90, [90] = 95, [95] = 99, [99] = 119}
local function stage_after(st)
    return NEXT_STAGE[st] or 'done'
end

-- Full build mode (//empy full): also show each weapon's later stages
local function full_mode() return char.data and char.data.full == true end

-------------------------------------------------------------------------------
-- Name -> ID lookup, done once
-------------------------------------------------------------------------------
-- Zone name -> zone id, filled in by resolve()
local zone_ids = {}

-- Look up the ids of every item, key item and weapon by name in Windower's
-- resources, so nothing is hard-coded. Each chain step gets n.ids (the ids that
-- count for it) and n.label (the name shown); each NM gets nm.drop_node for its item.
local function resolve()
    local want_items, want_kis = {}, {}
    -- Note that any of these item names counts for step n
    local function want(list, n)
        for _, nm in ipairs(list) do
            want_items[lc(nm)] = want_items[lc(nm)] or {}
            table.insert(want_items[lc(nm)], n)
        end
    end
    -- Go through a chain: items and key items get an empty id list to fill in
    local function walk(n)
        if n.item then
            n.ids, n.label = {}, n.item[1]
            want(n.item, n)
        elseif n.ki then
            n.ids, n.label = {}, n.ki
            want_kis[lc(n.ki)] = n
        end
        for _, k in ipairs(n.kids or {}) do walk(k) end
    end
    for key, nm in pairs(NMS) do
        nm.key = key
        nm.drop_node = {ids = {}, label = nm.drop[1]}
        want(nm.drop, nm.drop_node)
        walk(nm)
    end

    -- Every level of each Empyrean weapon (Lv80, 85, 90, 95, 99, 119 share a name)
    local weapon_by_name = {}
    for _, w in ipairs(WEAPONS) do
        w.ids = {}
        weapon_by_name[lc(w.name)] = w
    end

    -- One pass over every item in the game: match short (en) and long (enl) names
    for id, it in pairs(res.items) do
        for _, key in ipairs({lc(it.en), lc(it.enl)}) do
            for _, n in ipairs(want_items[key] or {}) do n.ids[id] = true end
        end
        local w = weapon_by_name[lc(it.en)]
        -- Lv119 copies report level 99 with an item level of 119
        if w and it.level then w.ids[id] = math.max(it.level, it.item_level or 0) end
    end
    -- Key items, by name
    for id, k in pairs(res.key_items) do
        local n = want_kis[lc(k.en)]
        if n then n.ids[id] = true end
    end
    -- Zones, by name
    for id, z in pairs(res.zones) do zone_ids[z.en] = id end
end
resolve()   -- once, when the addon loads

-------------------------------------------------------------------------------
-- The window: border, panel, header strip (prims), then two text objects
-------------------------------------------------------------------------------
-- The names of the window's rectangles (prims): outline, panel, header strip, header
-- underline, and the outline and fill of the Atma and Procs buttons
local P = {border = 'empybuilder_border', bg = 'empybuilder_bg', head = 'empybuilder_head', line = 'empybuilder_line',
           btnb = 'empybuilder_atma_btn_border', btn = 'empybuilder_atma_btn',
           pbtnb = 'empybuilder_procs_btn_border', pbtn = 'empybuilder_procs_btn'}

-- Every rectangle's full-strength colour, so opacity can be changed and changed back
local RECT_BASE = {}

-- The opacity setting as 0.1 to 1
local function opacity_factor()
    return math.max(0.1, math.min(1, (tonumber(settings.opacity) or 100) / 100))
end

-- Colour a rectangle at its full colour times the opacity
local function color_rect(name)
    local c = RECT_BASE[name]
    windower.prim.set_color(name, math.floor(c.alpha * opacity_factor() + 0.5), c.red, c.green, c.blue)
end

-- Create a rectangle (hidden) and remember its full colour
local function make_rect(name, c)
    windower.prim.create(name)
    RECT_BASE[name] = c
    color_rect(name)
    windower.prim.set_visibility(name, false)
end

-- Text boxes that fade with the window (text and its outline)
local FADE_TEXTS = {}
local function fade_text(t, stroke)
    FADE_TEXTS[#FADE_TEXTS + 1] = {t = t, stroke = stroke}
end

-- Re-apply the opacity to every rectangle and every text box that fades
local function apply_opacity()
    local f = opacity_factor()
    for name in pairs(RECT_BASE) do color_rect(name) end
    for _, e in ipairs(FADE_TEXTS) do
        e.t:alpha(math.floor(255 * f + 0.5))
        e.t:stroke_alpha(math.floor(e.stroke * f + 0.5))
    end
end
-- The main window's rectangles, using the colours in settings.xml
make_rect(P.border, settings.window.border)
make_rect(P.bg,     settings.window.bg)
make_rect(P.head,   settings.window.header)
make_rect(P.line,   settings.window.border)
make_rect(P.btnb,   settings.window.border)
make_rect(P.btn,    {alpha = 200, red = 45, green = 55, blue = 75})
make_rect(P.pbtnb,  settings.window.border)
make_rect(P.pbtn,   {alpha = 200, red = 45, green = 55, blue = 75})

-- Settings for a text box in the main window (draggable, no background of its own)
local function text_settings(bold)
    return {
        pos   = {x = settings.window.pos.x, y = settings.window.pos.y},
        bg    = {visible = false},
        text  = {font = settings.font, size = settings.size, alpha = 255, red = 230, green = 230, blue = 230,
                 stroke = {width = 1, alpha = 180, red = 0, green = 0, blue = 0}},
        flags = {draggable = true, bold = bold},
        padding = 0,
    }
end
-- The header text (bold) and the body text (the wide layout's whole content)
local title = texts.new('', text_settings(true))
local body  = texts.new('', text_settings(false))
fade_text(title, 180)
fade_text(body, 180)

-- The buttons at the top right of the header, right to left: "Atma" (the Atma
-- window) and "Procs" (the red proc weapon skill window). Each is green while its
-- window is on, grey-blue while it's off. Each button's box is where it is on
-- screen (for clicks), set by place().
local hdr_btns = {
    on  = {alpha = 230, red = 60, green = 130, blue = 85},
    off = {alpha = 200, red = 45, green = 55, blue = 75},
    list = {
        {label = 'Atma',  setting = 'atma',  cmd = 'empy atma',  fill = P.btn,  border = P.btnb},
        {label = 'Procs', setting = 'procs', cmd = 'empy procs', fill = P.pbtn, border = P.pbtnb},
    },
}
for _, b in ipairs(hdr_btns.list) do
    b.text = texts.new(b.label, {
        pos   = {x = settings.window.pos.x, y = settings.window.pos.y},
        bg    = {visible = false},
        text  = {font = settings.font, size = settings.size, alpha = 255, red = 235, green = 235, blue = 235,
                 stroke = {width = 1, alpha = 180, red = 0, green = 0, blue = 0}},
        flags = {draggable = false, bold = true},
        padding = 0,
    })
    b.box = {x = 0, y = 0, w = 0, h = 0}
    b.text:hide()
    fade_text(b.text, 180)
end
-- The button the mouse is over, or nil
function hdr_btns.hit(x, y)
    for _, b in ipairs(hdr_btns.list) do
        local r = b.box
        if r.w > 0 and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then return b end
    end
end
-- Show or hide every button's text, and change its text size
function hdr_btns.show(on) for _, b in ipairs(hdr_btns.list) do if on then b.text:show() else b.text:hide() end end end
function hdr_btns.size(n) for _, b in ipairs(hdr_btns.list) do b.text:size(n) end end
apply_opacity()

-------------------------------------------------------------------------------
-- Alerts: a sound (sounds/*.wav) and a big line of text at the top of the
-- screen for a few seconds. Each kind can be turned off with //empy alert.
-------------------------------------------------------------------------------
-- The sound and the colour of each kind of alert
local ALERT_SOUND = {soon = 'chime.wav', up = 'chime.wav', atma = 'chime.wav', respawn = 'chime.wav', weakness = 'chime.wav', redproc = 'success.wav',
                     goal = 'success.wav', time = 'alert.wav', test = 'chime.wav'}
local ALERT_COLOR = {soon = '\\cs(240,210,90)', up = '\\cs(110,220,110)', atma = '\\cs(200,170,255)', respawn = '\\cs(110,200,245)', weakness = '\\cs(255,205,110)', redproc = '\\cs(110,220,110)',
                     goal = '\\cs(110,220,110)', time = '\\cs(255,90,90)', test = '\\cs(255,205,110)'}

-- The big line of text an alert shows near the top of the screen
local flash_box = texts.new('', {
    pos   = {x = 0, y = 0},
    bg    = {visible = true, alpha = 170, red = 10, green = 12, blue = 18},
    text  = {font = settings.font, size = settings.size + 8, alpha = 255, red = 230, green = 230, blue = 230,
             stroke = {width = 2, alpha = 220, red = 0, green = 0, blue = 0}},
    flags = {draggable = false, bold = true},
    padding = 8,
})
flash_box:hide()
-- os.clock() time when the flash should go away (0 = not showing)
local flash_until = 0

-- Raise an alert: play its sound and flash its text, unless that kind is turned off
local function alert(kind, text)
    if kind ~= 'test' and settings.alerts[kind] == false then return end
    if settings.sounds then
        windower.play_sound(windower.addon_path .. 'sounds/' .. (ALERT_SOUND[kind] or 'chime.wav'))
    end
    if settings.flash then
        flash_box:text((ALERT_COLOR[kind] or '') .. text .. '\\cr')
        flash_box:show()
        flash_until = os.clock() + 3.5
    end
end

-- Keep the flash centred near the top, and hide it when its time is up
local function flash_tick()
    if flash_until == 0 then return end
    if os.clock() > flash_until then
        flash_box:hide()
        flash_until = 0
        return
    end
    local w = flash_box:extents() or 0
    local ws = windower.get_windower_settings()
    flash_box:pos(math.floor((ws.ui_x_res - w) / 2), math.floor(ws.ui_y_res * 0.18))
end

-- Tall layout: the body is a stack of text blocks instead of one text box,
-- so the item count can be big and the NEXT step can sit in a box
local tall = {texts = {}, boxes = {}, blocks = {}, used = 0, boxes_used = 0, pick = {}}

-- The i-th text block of the tall layout, made the first time it's needed
local function tall_text(i)
    local t = tall.texts[i]
    if not t then
        local s = text_settings(false)
        s.flags.draggable = false
        t = texts.new('', s)
        tall.texts[i] = t
        fade_text(t, 180)
        apply_opacity()
    end
    return t
end

-- The i-th boxed area of the tall layout (outline + fill), made the first time it's needed
local function tall_box(i)
    local b = tall.boxes[i]
    if not b then
        b = {border = 'empybuilder_tbox_b' .. i, fill = 'empybuilder_tbox_f' .. i}
        make_rect(b.border, {alpha = 255, red = 110, green = 200, blue = 245})
        make_rect(b.fill,   {alpha = 235, red = 22,  green = 34,  blue = 46})
        tall.boxes[i] = b
    end
    return b
end

-- Show the text blocks and boxes the tall layout is using, hide the rest
local function tall_show(on)
    for i, t in ipairs(tall.texts) do
        if on and i <= tall.used then t:show() else t:hide() end
    end
    for i, b in ipairs(tall.boxes) do
        local v = on and i <= tall.boxes_used
        windower.prim.set_visibility(b.border, v)
        windower.prim.set_visibility(b.fill, v)
    end
end

-- Whether the main window is on screen right now
local shown = false
-- Show or hide the whole main window (minimized: header only)
local function set_visible(on)
    shown = on
    for _, name in pairs(P) do windower.prim.set_visibility(name, on) end
    if on then title:show() else title:hide() end
    hdr_btns.show(on)
    local open = on and not settings.minimized
    if open and settings.layout ~= 'tall' then body:show() else body:hide() end
    tall_show(open and settings.layout == 'tall')
end

-- The header strip's height in pixels, worked out from the title text
local layout = {head_h = 22}
-- Where the title and body text should sit for the window's saved position
local function expected()
    local x, y, pad = settings.window.pos.x, settings.window.pos.y, settings.window.padding
    return x + pad, y + 4, x + pad, y + layout.head_h + 6
end

-- Size and place the rectangles around the text, and, in the tall layout, stack
-- the text blocks and their boxes one under another
local function place()
    local x, y, pad = settings.window.pos.x, settings.window.pos.y, settings.window.padding
    local tw, th = title:extents()
    local bw, bh = body:extents()
    tw, th, bw, bh = tw or 0, th or 0, bw or 0, bh or 0
    layout.head_h = math.max(th, 14) + 8

    local is_tall = settings.layout == 'tall'
    if is_tall then
        -- Measure the stack: boxed blocks get 8 px inside on the sides, 6 above and below
        bw, bh = 0, 0
        for i, b in ipairs(tall.blocks) do
            local ew, eh = tall.texts[i]:extents()
            b.w, b.h = ew or 0, eh or 0
            bw = math.max(bw, b.w + (b.box and 16 or 0))
            bh = bh + (b.gap or 0) + b.h + (b.box and 12 or 0)
        end
    end

    -- Room on the right of the header for the buttons (each is its text + 12 px, 4 px apart)
    local btns_w = 0
    for _, b in ipairs(hdr_btns.list) do
        local ew, eh = b.text:extents()
        b.tw, b.th = ew or 0, eh or 0
        btns_w = btns_w + b.tw + 12 + 4
    end

    local w = math.max(tw + btns_w + 12, settings.minimized and 0 or bw) + pad * 2
    local h = layout.head_h + (settings.minimized and 0 or (bh + 12))

    windower.prim.set_position(P.border, x - 1, y - 1); windower.prim.set_size(P.border, w + 2, h + 2)
    windower.prim.set_position(P.bg, x, y);             windower.prim.set_size(P.bg, w, h)
    windower.prim.set_position(P.head, x, y);           windower.prim.set_size(P.head, w, layout.head_h)
    windower.prim.set_position(P.line, x, y + layout.head_h); windower.prim.set_size(P.line, w, settings.minimized and 0 or 1)

    -- The buttons: from the top right corner of the header leftwards, each coloured
    -- by whether its window is on
    local bxr, by0, bh0 = x + w - 4, y + 3, layout.head_h - 6
    for _, b in ipairs(hdr_btns.list) do
        local bw0 = b.tw + 12
        local bx0 = bxr - bw0
        b.box = {x = bx0, y = by0, w = bw0, h = bh0}
        windower.prim.set_position(b.border, bx0 - 1, by0 - 1); windower.prim.set_size(b.border, bw0 + 2, bh0 + 2)
        windower.prim.set_position(b.fill, bx0, by0);           windower.prim.set_size(b.fill, bw0, bh0)
        local want = settings[b.setting].visible and hdr_btns.on or hdr_btns.off
        if RECT_BASE[b.fill] ~= want then RECT_BASE[b.fill] = want; color_rect(b.fill) end
        b.text:pos(bx0 + 6, by0 + math.floor((bh0 - b.th) / 2 + 0.5))
        bxr = bx0 - 4
    end

    local tx, ty, bx, by = expected()
    title:pos(tx, ty)
    body:pos(bx, by)

    if is_tall then
        local cy, nbox, inner = by, 0, w - pad * 2
        for i, b in ipairs(tall.blocks) do
            local t = tall.texts[i]
            cy = cy + (b.gap or 0)
            if b.box then
                nbox = nbox + 1
                local box = tall.boxes[nbox]
                windower.prim.set_position(box.border, bx - 1, cy - 1)
                windower.prim.set_size(box.border, inner + 2, b.h + 14)
                windower.prim.set_position(box.fill, bx, cy)
                windower.prim.set_size(box.fill, inner, b.h + 12)
                b.x, b.y = bx + 8, cy + 6
                cy = cy + b.h + 12
            else
                b.x, b.y = bx, cy
                cy = cy + b.h
            end
            b.inner = inner
            t:pos(b.x, b.y)
        end
    end
end

-- Which clickable row of the tall layout is under the mouse, if any
local function tall_hit(x, y)
    for _, b in ipairs(tall.blocks) do
        if b.rows and b.x and b.h and b.h > 0 and x >= b.x and x <= b.x + (b.inner or b.w)
            and y >= b.y and y <= b.y + b.h then
            local row = math.floor((y - b.y) / (b.h / #b.lines)) + 1
            return b.rows[row]
        end
    end
    return nil
end

-------------------------------------------------------------------------------
-- Searching bags and key items
-------------------------------------------------------------------------------
-- Every bag that's searched, with the short name shown when an item is in one
local BAGS = {
    {'inventory', 'INV'}, {'satchel', 'SATCH'}, {'sack', 'SACK'}, {'case', 'CASE'},
    {'safe', 'SAFE'}, {'safe2', 'SAFE2'}, {'storage', 'STOR'}, {'locker', 'LOCK'},
    {'wardrobe', 'WARD'}, {'wardrobe2', 'WARD2'}, {'wardrobe3', 'WARD3'}, {'wardrobe4', 'WARD4'},
    {'wardrobe5', 'WARD5'}, {'wardrobe6', 'WARD6'}, {'wardrobe7', 'WARD7'}, {'wardrobe8', 'WARD8'},
}

-- Read every bag and your key items. Returns have (item id -> {inv = in inventory,
-- total = everywhere, where = first other bag}) and kis (key item id -> true).
local function scan()
    local have = {}   -- id -> {inv = n, total = n, where = 'SACK'}
    local items = windower.ffxi.get_items()
    if items then
        for _, bag in ipairs(BAGS) do
            local b = items[bag[1]]
            if type(b) == 'table' and b.max then
                for i = 1, b.max do
                    local it = b[i]
                    if it and it.id and it.id ~= 0 then
                        local h = have[it.id] or {inv = 0, total = 0}
                        local n = it.count or 1
                        h.total = h.total + n
                        if bag[1] == 'inventory' then h.inv = h.inv + n
                        elseif not h.where then h.where = bag[2] end
                        have[it.id] = h
                    end
                end
            end
        end
    end
    local kis = {}
    for _, id in ipairs(windower.ffxi.get_key_items() or {}) do kis[id] = true end
    return have, kis
end

-- Fills n.state: 'have' | 'away' | 'ready' | 'need' | 'unknown'
local function evaluate(n, have, kis)
    for _, k in ipairs(n.kids or {}) do evaluate(k, have, kis) end
    if not n.ids then return end
    if next(n.ids) == nil then n.state = 'unknown' return end

    if n.ki then
        for id in pairs(n.ids) do if kis[id] then n.state = 'have' return end end
    else
        n.count, n.where = 0, nil
        for id in pairs(n.ids) do
            local h = have[id]
            if h then n.count = n.count + h.inv; n.where = n.where or h.where end
        end
        if n.count > 0 then n.state = 'have' return end
        if n.where then n.state = 'away' return end
    end

    if n.kids and #n.kids > 0 then
        local all = true
        for _, k in ipairs(n.kids) do if k.state ~= 'have' then all = false break end end
        if all then n.state = 'ready' return end
    end
    n.state = 'need'
end

-- How many of an NM's upgrade item you hold, across every bag
local function count_drop(nm, have)
    local total, inv = 0, 0
    for id in pairs(nm.drop_node.ids) do
        local h = have[id]
        if h then total, inv = total + h.total, inv + h.inv end
    end
    nm.count, nm.count_inv = total, inv
end

-- Work out each weapon's stage from the highest-level copy in your bags
local function detect_stages(have)
    for _, w in ipairs(WEAPONS) do
        local best = 0
        for id, level in pairs(w.ids or {}) do
            if have[id] and level > best then best = level end
        end
        if best >= 119 then detected[w.name] = 'done'
        elseif best >= 99 then detected[w.name] = 119
        elseif best >= 95 then detected[w.name] = 99
        elseif best >= 90 then detected[w.name] = 95
        elseif best >= 85 then detected[w.name] = 90
        elseif best >= 80 then detected[w.name] = 85
        else detected[w.name] = 80 end
        w.owned_level = best > 0 and best or nil
    end
end

-------------------------------------------------------------------------------
-- Rendering
-------------------------------------------------------------------------------
-- Text colours (Windower's \cs(r,g,b) codes)
local C = {
    head = '\\cs(255,205,110)', good = '\\cs(110,220,110)', warn = '\\cs(240,210,90)',
    bad  = '\\cs(235,95,95)',   pop  = '\\cs(110,200,245)', dim  = '\\cs(140,145,155)',
    text = '\\cs(230,230,230)', red  = '\\cs(255,60,60)',   redd = '\\cs(150,55,55)',
    nm   = '\\cs(200,170,255)',
}
-- Colour a piece of text, then reset the colour
local function col(c, s) return c .. s .. '\\cr' end

-- Column widths (in characters) for the wide layout
local NAME_W, SRC_W, TAG_W = 30, 24, 8

-- Pad (or cut, ending with .) a string to exactly w characters, for columns
local function pad(s, w)
    s = tostring(s)
    if #s > w then return s:sub(1, w - 1) .. '.' end
    return s .. string.rep(' ', w - #s)
end

-- The status column of a step: OWNED / HAVE x3 / IN SACK / POP IT / NEED / FARM
local function status_tag(n)
    local s, c
    if n.state == 'have' then
        c, s = C.good, n.ki and 'OWNED' or (n.count > 1 and ('HAVE x' .. n.count) or 'HAVE')
    elseif n.state == 'away' then c, s = C.warn, 'IN ' .. n.where
    elseif n.state == 'ready' then c, s = C.pop, 'POP IT'
    elseif n.state == 'unknown' then c, s = C.dim, '?name'
    else c, s = C.bad, (n.kids and #n.kids > 0) and 'NEED' or 'FARM' end
    return col(c, pad(s, TAG_W))
end

-- flash_on blinks the RED!!! tag of the NM you're targeting; target_name is that NM
local flash_on = false
local target_name

-- The RED!!! tag for a step that needs a red proc (blinking 'proc it' when targeted)
local function red_tag(n)
    if not (settings.red_alerts and n.red) or n.state == 'have' then return '' end
    if target_name == n.from then
        return ' ' .. col(flash_on and C.red or C.warn, 'RED!!! proc it')
    end
    return ' ' .. col(C.red, 'RED!!!')
end

-------------------------------------------------------------------------------
-- Timed NMs (Chukwa, Adze, Minhocao, Fistule and the Lv85/90 ones) take 10-15
-- or 15-20 minutes to respawn after they die. We note when one dies (from the
-- game's defeat message or the chat log) and count down to its window.
-------------------------------------------------------------------------------
local killed = {}   -- NM name -> os.time() it died

-- 'cooling' (can't be up yet), 'window' (may be up), 'up' (window over), or nil (no kill seen)
local function respawn_state(name, rng)
    local t = killed[name]
    if not t or not rng then return nil end
    local ago = os.time() - t
    local lo, hi = rng[1] * 60 - ago, rng[2] * 60 - ago
    if lo > 0 then return 'cooling', lo, hi end
    if hi > 0 then return 'window', lo, hi end
    return 'up', lo, hi
end

-- Seconds -> whole minutes, rounded up, never below 1
local function mins(sec) return math.max(1, math.ceil(sec / 60)) end

-- Short tag for a step line, e.g. " respawn 6-11m"
local function respawn_tag(name, rng)
    if not rng then return '' end
    local st, lo, hi = respawn_state(name, rng)
    if st == 'cooling' then return ' ' .. col(C.warn, ('respawn %d-%dm'):format(mins(lo), mins(hi))) end
    if st == 'window' then return ' ' .. col(C.pop, ('may be up (<%dm)'):format(mins(hi))) end
    if st == 'up' then return ' ' .. col(C.good, 'should be up') end
    return ' ' .. col(C.dim, ('%d-%dm respawn'):format(rng[1], rng[2]))
end

-- A full line for the NEXT box
local function respawn_line(name, rng)
    local st, lo, hi = respawn_state(name, rng)
    if st == 'cooling' then
        return col(C.warn, ('respawns in %d-%d min'):format(mins(lo), mins(hi)))
            .. col(C.dim, (' (died %s)'):format(os.date('%H:%M', killed[name])))
    elseif st == 'window' then
        return col(C.pop, 'respawn window open') .. col(C.dim, (': up within %d min'):format(mins(hi)))
    elseif st == 'up' then
        return col(C.good, 'should be up now') .. col(C.dim, (' (died %s)'):format(os.date('%H:%M', killed[name])))
    end
    return col(C.dim, ('timed: respawns %d-%d min after it dies'):format(rng[1], rng[2]))
end

-------------------------------------------------------------------------------
-- Farming flow: each key item's chain as steps in the order you do them.
-- A step is "kill/pop/camp <mob>  >  get <item>  ->  it pops <next NM>".
-------------------------------------------------------------------------------
-- How many steps deep a chain goes under n
local function chain_depth(n)
    local d = 0
    for _, k in ipairs(n.kids or {}) do d = math.max(d, chain_depth(k) + 1) end
    return d
end

-- Steps for a branch, deepest sub-chain first so each item lands right
-- before the NM it pops. `feeds` is what this step's item is used to pop.
local function flow_steps(n, feeds, out, feeds_vc, feeds_at)
    out = out or {}
    if not (settings.compact and n.state == 'have') then
        local kids = {}
        for i, k in ipairs(n.kids or {}) do kids[#kids + 1] = {k = k, i = i, d = chain_depth(k)} end
        table.sort(kids, function(a, b) if a.d ~= b.d then return a.d > b.d end return a.i < b.i end)
        for _, e in ipairs(kids) do flow_steps(e.k, n.from, out, n.vc, n.at) end
    end
    out[#out + 1] = {n = n, feeds = feeds, feeds_vc = feeds_vc, feeds_at = feeds_at}
    return out
end

-- A map square without its brackets: '(I-8)' -> 'I-8'
local function bare(at) return at and (at:gsub('[()]', '')) or nil end

-- Where to go for a step: nearest Veridical Conflux and map square.
-- For an NM that's its ???. When the wiki gives none for a regular mob, the
-- NM its item pops is used instead, marked ~ (you'll be heading there anyway).
-- Returns the text, the conflux number, and whether it was borrowed.
local function where(s)
    local n = s.n
    local vc, at, borrowed = n.vc, bare(n.at), false
    if not vc and not at then vc, at, borrowed = s.feeds_vc, bare(s.feeds_at), true end
    local parts = {}
    if vc then parts[#parts + 1] = '#' .. vc end
    if at then parts[#parts + 1] = at end
    local text = (borrowed and '~' or '') .. table.concat(parts, ' ')
    return text, vc, borrowed
end

-- An NM's own spot for headers: "#2 I-8", or just "F-6" where no conflux is known
local function nm_spot(nm, star)
    local parts = {}
    if nm.vc then parts[#parts + 1] = '#' .. nm.vc .. (star and '*' or '') end
    parts[#parts + 1] = bare(nm.at)
    return table.concat(parts, ' ')
end

-- Old name kept for chat output: the same as where(), without the borrowed flag
local function vc_text(s)
    local text, vc = where(s)
    return text, vc
end

-- Which conflux you're standing nearest, checked every few seconds
-- near: the nearest conflux number, its distance and zone; zone_names: zone id -> name
local near = {n = nil, dist = nil, zone = nil}
local zone_names
-- Work out the nearest conflux from where you stand. Returns true when it changed.
local function update_near()
    if not zone_names then
        zone_names = {}
        for name, id in pairs(zone_ids) do zone_names[id] = name end
    end
    local was = near.n
    near.n, near.dist, near.zone = nil, nil, nil
    local info = windower.ffxi.get_info()
    local zname = info and zone_names[info.zone]
    local list = zname and CONFLUX[zname]
    local me = list and windower.ffxi.get_mob_by_target('me')
    if me and me.x and me.y then
        local best, bd = nil, math.huge
        for _, c in ipairs(list) do
            local dx, dy = me.x - c[2], me.y - c[3]
            local d = math.sqrt(dx * dx + dy * dy)
            if d < bd then best, bd = c[1], d end
        end
        near.n, near.dist, near.zone = best, bd, zname
    end
    return near.n ~= was
end

-- Is this conflux number the one you're nearest, in this NM's zone?
local function is_near(nm, n)
    return n ~= nil and near.n == n and near.zone == nm.zone
end

-------------------------------------------------------------------------------
-- Marks. //empy mark saves where you're standing as the spot for an NM's ???
-- (or a mob's area); steps then show how far it is and which way. Marks are
-- shared by all your characters, in data/marks.xml.
-------------------------------------------------------------------------------
-- Saved as one line: 'Zone|Name|x|y;Zone|Name|x|y...'
local marks_file = config.load('data/marks.xml', {list = ''})
local marks = {}   -- 'Zone|Name' -> {x, y}
for zone, name, x, y in tostring(marks_file.list or ''):gmatch('([^|;]+)|([^|;]+)|([-%d%.]+)|([-%d%.]+)') do
    marks[zone .. '|' .. name] = {tonumber(x), tonumber(y)}
end

-- Write every mark back to data/marks.xml
local function save_marks()
    local parts = {}
    for key, p in pairs(marks) do parts[#parts + 1] = ('%s|%.1f|%.1f'):format(key, p[1], p[2]) end
    table.sort(parts)
    marks_file.list = table.concat(parts, ';')
    config.save(marks_file, 'all')
end

-- The name of the zone you're in, or nil
local function zone_name_now()
    local info = windower.ffxi.get_info()
    local z = info and res.zones[info.zone]
    return z and z.en or nil
end

-- mark_dir is set inside the block, so DIRS stays out of the main chunk's locals
local mark_dir
do
-- The eight compass points, clockwise from north
local DIRS = {'N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'}

-- "140y NE" from where you stand to a marked spot; nil if it isn't marked or
-- you're not in its zone. x runs west to east and y south to north.
function mark_dir(zone, name)
    if not zone or not name then return nil end
    local p = marks[zone .. '|' .. name]
    if not p or zone_name_now() ~= zone then return nil end
    local me = windower.ffxi.get_mob_by_target('me')
    if not me or not me.x then return nil end
    local dx, dy = p[1] - me.x, p[2] - me.y
    local d = math.sqrt(dx * dx + dy * dy)
    if d < 5 then return 'here' end
    local ang = (math.deg(math.atan2(dx, dy)) + 360) % 360
    return ('%dy %s'):format(math.floor(d + 0.5), DIRS[math.floor((ang + 22.5) / 45) % 8 + 1])
end
end

-- The same, coloured, with a leading space, for the end of a step line
local function mark_tag(zone, name)
    local d = mark_dir(zone, name)
    return d and (' ' .. col(C.good, d)) or ''
end


-- The verb for a step: Camp (timed NM), Hunt (lottery spawn), Pop (has pop items) or Kill
local function step_verb(n)
    if n.note == 'timed' then return 'Camp' end
    if n.note == 'lottery' then return 'Hunt' end
    if n.kids and #n.kids > 0 then return 'Pop' end
    return 'Kill'
end

-- The step to do next: an NM you can pop now, else the first thing left to farm.
-- A timed NM that can't have respawned yet waits until there's nothing else.
local function next_step(steps)
    for i, s in ipairs(steps) do if s.n.state == 'ready' then return i end end
    local waiting
    for i, s in ipairs(steps) do
        local n = s.n
        if n.state == 'away' then return i end
        if n.state == 'need' and not (n.kids and #n.kids > 0) then
            if respawn_state(n.from, n.respawn) == 'cooling' then
                waiting = waiting or i
            else
                return i
            end
        end
    end
    return waiting
end

-- Column widths for a step line: source, where, what you get, what it feeds
local SRC_COL, VC_COL, GET_COL, FEED_COL = 21, 13, 28, 20

-- The where column (conflux + map square): green with * when it's the conflux you're at
local function vc_cell(s, nm, done_c)
    local text, n = where(s)
    if is_near(nm, n) then
        text = text:gsub('#' .. n, '#' .. n .. '*', 1)
        return col(C.good, pad(text, VC_COL))
    end
    return col(done_c or C.head, pad(text, VC_COL))
end

-- Wide layout: one key item and every step of its chain, one line per step
local function render_branch(ki, nm, lines)
    -- Owned: one line and done
    if ki.state == 'have' and settings.compact then
        lines[#lines + 1] = '  ' .. col(C.good, '[x] ' .. ki.label) .. col(C.dim, '  owned, ready for ' .. nm.name)
        return
    end

    -- The steps, how many are done, and which one is next
    local steps = flow_steps(ki, nm.name, nil, nm.vc, nm.at)
    local done = 0
    for _, s in ipairs(steps) do if s.n.state == 'have' then done = done + 1 end end
    local nxt = next_step(steps)

    lines[#lines + 1] = '  ' .. col(C.pop, ki.label) .. col(C.dim, ('  key item for %s   %d/%d steps'):format(nm.name, done, #steps))

    -- One line per step: number (>> for next), [x], source, where, item, status, feeds, tags
    for i, s in ipairs(steps) do
        local n = s.n
        local num = (i == nxt) and col(C.pop, ' >>') or col(C.dim, ('%3d'):format(i))
        local mark = (n.state == 'have') and col(C.good, '[x]')
                  or (n.state == 'away') and col(C.warn, '[~]')
                  or col(C.dim, '[ ]')
        local src = step_verb(n) .. ' ' .. n.from
        local get = '> ' .. n.label .. (n.ki and ' (KI)' or '')
        local done_c = (n.state == 'have') and C.dim
        local feed_c = (s.n == ki) and C.nm or C.dim
        lines[#lines + 1] = '  ' .. num .. ' ' .. mark .. ' '
            .. col(done_c or C.dim, pad(src, SRC_COL))
            .. vc_cell(s, nm, done_c)
            .. col(done_c or (n.ki and C.pop or C.text), pad(get, GET_COL)) .. ' '
            .. status_tag(n) .. ' '
            .. col(feed_c, pad('-> ' .. s.feeds, FEED_COL))
            .. red_tag(n)
            .. (n.state ~= 'have' and respawn_tag(n.from, n.respawn) or '')
            .. ((n.state ~= 'have' and n.hint) and (' ' .. col(C.dim, '(' .. n.hint .. ')')) or '')
            .. (n.state ~= 'have' and mark_tag(nm.zone, n.from) or '')
    end
end

-- Items needed for this NM's trade: 50 for Lv80 and Lv85, 75 for Lv90, the
-- material's own amount after that, or //empy goal if one is set
local function goal_of(nm)
    local o = tonumber(settings.goal_override) or 0
    return o > 0 and o or nm.goal
end

-- '13 / 50', coloured by progress, plus '(9 in inv)' when some are in other bags
local function count_text(nm)
    local goal = goal_of(nm)
    local c = (nm.count or 0) >= goal and C.good or ((nm.count or 0) > 0 and C.warn or C.bad)
    local s = col(c, ('%d / %d'):format(nm.count or 0, goal))
    if (nm.count or 0) > (nm.count_inv or 0) then
        s = s .. col(C.dim, (' (%d in inv)'):format(nm.count_inv or 0))
    end
    return s
end

-- How many of an NM's pop key items you hold, and how many it needs
local function kis_got(nm)
    local got = 0
    for _, k in ipairs(nm.kids) do if k.state == 'have' then got = got + 1 end end
    return got, #nm.kids
end

-- The NM (or material) a weapon needs now, and its stage (nil NM when it's done)
local function current_nm(w)
    local st = stage_of(w)
    return (st ~= 'done') and NMS[w.nm[st]] or nil, st
end

-- The NMs to show. Each weapon contributes the NM for the stage it's on; in
-- full mode, also the NMs for its later stages (shown short, as "later").
-- Weapons sharing an NM share its section. Also returns the weapons that are done.
local function active_nms()
    local info = windower.ffxi.get_info() or {}
    local seen, list, done = {}, {}, {}
    -- Add a weapon's NM to the list (one section per NM, however many weapons share it)
    local function add(key, w, later)
        local nm = NMS[key]
        local g = seen[key]
        if not g then
            g = {nm = nm, weapons = {}, later = true}
            seen[key] = g
            if not settings.only_in_zone or not nm.zone or zone_ids[nm.zone] == info.zone then list[#list + 1] = g end
        end
        if not later then g.later = false end
        table.insert(g.weapons, w.name .. (later and (' (Lv' .. nm.stage .. ', later)') or ''))
    end
    -- Each weapon: its current stage, and in full mode the stages after it
    for _, w in ipairs(selected_weapons()) do
        local st = stage_of(w)
        if st == 'done' then
            done[#done + 1] = w.name
        else
            add(w.nm[st], w, false)
            if full_mode() then
                local s = stage_after(st)
                while s ~= 'done' do add(w.nm[s], w, true); s = stage_after(s) end
            end
        end
    end
    -- Current stages first, then later ones, each in stage order
    table.sort(list, function(a, b)
        if a.later ~= b.later then return not a.later end
        if a.nm.stage ~= b.nm.stage then return a.nm.stage < b.nm.stage end
        return a.nm.name < b.nm.name
    end)
    return list, done
end

-- Shown in the window when no weapon is picked yet: every weapon, its stage and item
local function render_picker(lines)
    lines[#lines + 1] = col(C.dim, 'No weapon picked. Choose with  //empy add <weapon>  (more than one is fine)')
    lines[#lines + 1] = ''
    lines[#lines + 1] = col(C.dim, pad('Weapon', 13) .. pad('Type', 14) .. pad('Stage', 7) .. pad('Item', 26) .. pad('NM', 13) .. 'Have')
    for _, w in ipairs(WEAPONS) do
        local nm, st = current_nm(w)
        if nm then
            lines[#lines + 1] = col(C.text, pad(w.name, 13)) .. col(C.dim, pad(w.kind, 14)) .. col(C.head, pad('Lv' .. st, 7))
                .. col(C.text, pad(nm.drop[1], 26)) .. col(C.nm, pad(nm.name, 13)) .. count_text(nm)
        else
            lines[#lines + 1] = col(C.text, pad(w.name, 13)) .. col(C.dim, pad(w.kind, 14)) .. col(C.good, 'Lv119 done')
        end
    end
end

-- When bags were last searched, the key items found then, and whether you're
-- targeting an NM that needs a red proc (for the blinking tag)
local last_scan = 0
local last_kis = {}   -- key item ids you hold, from the last search
local any_red_targeted = false

-------------------------------------------------------------------------------
-- Red proc helper: which weapon skills trigger a red proc, which of them you
-- can use right now, and what the chat log has said about your target
-------------------------------------------------------------------------------
-- The 13 weapon skills that can red proc in Abyssea, by element (none is Water)
local RED_WS = {
    {el = 'Fire',      ws = {{'Red Lotus Blade', 'Sword'}}},
    {el = 'Ice',       ws = {{'Freezebite', 'Great Sword'}}},
    {el = 'Wind',      ws = {{'Cyclone', 'Dagger'}, {'Tachi: Jinpu', 'Great Katana'}}},
    {el = 'Earth',     ws = {{'Earth Crusher', 'Staff'}}},
    {el = 'Lightning', ws = {{'Raiden Thrust', 'Polearm'}}},
    {el = 'Light',     ws = {{'Seraph Blade', 'Sword'}, {'Seraph Strike', 'Club'},
                             {'Tachi: Koki', 'Great Katana'}, {'Sunburst', 'Staff'}}},
    {el = 'Dark',      ws = {{'Shadow of Death', 'Scythe'}, {'Energy Drain', 'Dagger'}, {'Blade: Ei', 'Katana'}}},
}
-- Words the chat log uses for each element -> the element's name
local EL_WORDS = {fire = 'Fire', ice = 'Ice', wind = 'Wind', earth = 'Earth', lightning = 'Lightning',
                  thunder = 'Lightning', water = 'Water', light = 'Light', dark = 'Dark', darkness = 'Dark'}
-- Element -> its red proc weapon skills
local RED_BY_EL = {}
for _, e in ipairs(RED_WS) do RED_BY_EL[e.el] = e.ws end

-- What the log has told us, by mob id: weakness element, red proc landed
local fiend = {}   -- id -> {el = 'Ice', red = true, name = 'Hedetet', at = os.time()}

-- Red proc weapon skills you can use with what you have equipped now
-- my_red_ws is set inside the block; it's only re-checked every 2 seconds
local my_red_ws
do
-- The last result, and when it was worked out
local my_red_cache, my_red_at = {}, 0
function my_red_ws()
    if os.time() - my_red_at < 2 then return my_red_cache end
    my_red_at = os.time()
    local known = {}
    local ab = windower.ffxi.get_abilities()
    -- The weapon skills you know right now (they change with the weapon you hold)
    for _, id in ipairs(ab and ab.weapon_skills or {}) do
        local w = res.weapon_skills[id]
        if w then known[lc(w.en)] = true end
    end
    local out = {}
    -- Keep the red proc ones
    for _, e in ipairs(RED_WS) do
        for _, w in ipairs(e.ws) do
            if known[lc(w[1])] then out[#out + 1] = {name = w[1], el = e.el, kind = w[2]} end
        end
    end
    my_red_cache = out
    return out
end
end

-- Your target (or battle target), and what the log has said about it
local function current_fiend()
    local t = windower.ffxi.get_mob_by_target('t') or windower.ffxi.get_mob_by_target('bt')
    if not t then return nil end
    local f = fiend[t.id]
    -- forget a fiend that died, or one we heard about long ago (it may have respawned)
    if f and ((t.hpp or 100) == 0 or os.time() - f.at > 600 or f.name ~= t.name) then
        fiend[t.id], f = nil, nil
    end
    return t, f
end

-- Join items into lines no longer than `width`, the first one starting with `lead`
local function wrap_list(items, lead, width, color)
    local out, line, plain = {}, col(C.dim, lead), lead
    local indent = string.rep(' ', #lead)
    for i, it in ipairs(items) do
        local piece = it .. (i < #items and ', ' or '')
        if #plain + #piece > width and #plain > #lead then
            out[#out + 1] = line
            line, plain = col(C.dim, indent), indent
        end
        line, plain = line .. col(color or C.text, piece), plain .. piece
    end
    out[#out + 1] = line
    return out
end

-- The section at the bottom of the window. Shown while any NM you're working
-- on still has a key item that needs a red proc.
local function red_section(groups, width)
    if not settings.red_alerts then return nil end
    -- NMs you still need a red proc on: NM name -> the key item it gives
    local need = {}
    for _, g in ipairs(groups) do
        if not g.later then
            for _, ki in ipairs(g.nm.kids) do
                if ki.red and ki.state ~= 'have' then need[ki.from] = ki end
            end
        end
    end
    if next(need) == nil then return nil end

    local L = {}
    -- The heading: RED PROC, your target, and the key item it gives
    local t, f = current_fiend()
    local ki = t and need[t.name]
    local mine = my_red_ws()
    L[#L + 1] = col(C.red, 'RED PROC') .. (t and col(ki and C.text or C.dim, '  ' .. t.name) or '')
        .. (ki and col(C.dim, ' -> ' .. ki.label) or '')

    -- Then: proc landed / weakness known (which WS, which you have) / not known yet
    if t and f and f.red then
        L[#L + 1] = col(C.good, 'Red proc landed: the key item will drop')
    elseif t and f and f.el then
        local list = RED_BY_EL[f.el]
        if not list then
            L[#L + 1] = col(C.dim, 'weak to ') .. col(C.head, f.el) .. col(C.dim, ': no weapon skill red procs ' .. f.el)
        else
            local names = {}
            for _, w in ipairs(list) do names[#names + 1] = w[1] .. ' (' .. w[2] .. ')' end
            for _, l in ipairs(wrap_list(names, 'weak to ' .. f.el .. ': ', width, C.head)) do L[#L + 1] = l end
            local have = {}
            for _, m in ipairs(mine) do if m.el == f.el then have[#have + 1] = m.name end end
            if #have > 0 then
                for _, l in ipairs(wrap_list(have, 'use now: ', width, C.good)) do L[#L + 1] = l end
            else
                local kinds = {}
                for _, w in ipairs(list) do kinds[#kinds + 1] = w[2] end
                for _, l in ipairs(wrap_list(kinds, 'not on this weapon; swap to ', width, C.warn)) do L[#L + 1] = l end
            end
        end
    else
        if ki then
            L[#L + 1] = col(C.dim, 'weakness not known yet: try an elemental')
            L[#L + 1] = col(C.dim, 'WS; the chat log names the element')
            L[#L + 1] = col(C.dim, '(needs the Abyssite of Discernment)')
        end
        if #mine > 0 then
            local names = {}
            for _, m in ipairs(mine) do names[#names + 1] = m.name .. ' (' .. m.el .. ')' end
            for _, l in ipairs(wrap_list(names, 'yours now: ', width)) do L[#L + 1] = l end
        else
            L[#L + 1] = col(C.warn, 'no red proc weapon skill on this weapon')
        end
        if not ki then L[#L + 1] = col(C.dim, 'target a RED!!! NM to see its weakness') end
    end
    return L
end

-------------------------------------------------------------------------------
-- Tall layout (B): big count, a NEXT box with the one thing to do now, one
-- line per key item, and the steps for one key item (click another to switch)
-------------------------------------------------------------------------------
-- Steps done / total over a key item's whole chain (anything under an item
-- you hold counts as done)
local function progress(n, up)
    local covered = up or n.state == 'have'
    local d, t = covered and 1 or 0, 1
    for _, k in ipairs(n.kids or {}) do
        local a, b = progress(k, covered)
        d, t = d + a, t + b
    end
    return d, t
end

-- Each key item's steps, and the best next step for this NM: something you
-- can pop now beats farming, and the conflux you're at beats travelling
local function plan(nm)
    local list, best, bscore = {}, nil, -1
    for i, ki in ipairs(nm.kids) do
        local e = {ki = ki, i = i}
        e.done, e.total = progress(ki)
        if ki.state ~= 'have' then
            e.steps = flow_steps(ki, nm.name, nil, nm.vc, nm.at)
            e.nxt = next_step(e.steps)
            if e.nxt then
                local s = e.steps[e.nxt]
                local _, vc = where(s)
                local score = ((s.n.state == 'ready' or s.n.state == 'away') and 2 or 0) + (is_near(nm, vc) and 1 or 0)
                if score > bscore then best, bscore = e, score end
            end
        end
        list[#list + 1] = e
    end
    return list, best
end

-- Conflux + square for a step, with * on the conflux you're at
local function star_where(s, nm)
    local text, vc = where(s)
    if is_near(nm, vc) then text = text:gsub('#' .. vc, '#' .. vc .. '*', 1) end
    return text, is_near(nm, vc)
end

-- How wide the tall layout is
local TALL_W = 44   -- characters

-- The NEXT box of the tall layout: the one step to do now for this NM
local function next_box(nm, best)
    local L = {}
    -- The box's first line: NEXT, with a note on the right
    local function head(right, rc)
        L[#L + 1] = col(C.pop, pad('NEXT', TALL_W - 15)) .. (right and col(rc, right) or '')
    end

    -- An NM with no pop items (Fistule): camp its spawn point
    if nm.timed then
        head()
        L[#L + 1] = col(C.text, pad('Camp ' .. nm.name, 22)) .. col(is_near(nm, nm.vc) and C.good or C.head,
            'spawn ' .. nm_spot(nm, is_near(nm, nm.vc)))
        L[#L + 1] = respawn_line(nm.name, nm.respawn)
        local d = mark_dir(nm.zone, nm.name)
        if d then L[#L + 1] = col(C.dim, 'spawn point is ') .. col(C.good, d) end
        L[#L + 1] = col(C.dim, 'no pop items: pull the NM Guimauve')
        L[#L + 1] = col(C.dim, '(G-4, #6) next to it to make it pop')
        return L
    end

    -- Every key item in hand: pop the NM itself
    if not best then
        head("ready", C.good)
        L[#L + 1] = col(C.text, pad('Pop ' .. nm.name, 22)) .. col(is_near(nm, nm.vc) and C.good or C.head,
            '??? ' .. nm_spot(nm, is_near(nm, nm.vc)))
        L[#L + 1] = col(C.good, 'all key items in hand: examine the ???')
        local d = mark_dir(nm.zone, nm.name)
        if d then L[#L + 1] = col(C.dim, '??? is ') .. col(C.good, d) end
        return L
    end

    -- Otherwise the best next step: where to go (the heading says if you're there already)
    local s = best.steps[best.nxt]
    local n = s.n
    local wtext, here = star_where(s, nm)
    local _, vc = where(s)
    head(here and "you're here" or (vc and ('warp to #' .. vc) or nil), here and C.good or C.head)

    -- The item is in another bag: move it
    if n.state == 'away' then
        L[#L + 1] = col(C.text, 'Move ' .. n.label)
        L[#L + 1] = col(C.dim, 'from ' .. n.where .. ' to your inventory')
    else
        -- Pop an NM (with the items to trade and whether you have them) or kill/camp a mob
        local is_pop = n.kids and #n.kids > 0
        L[#L + 1] = col(C.text, pad(step_verb(n) .. ' ' .. n.from, 22))
            .. col(here and C.good or C.head, (is_pop and '??? ' or '') .. wtext)
        local d = mark_dir(nm.zone, n.from)
        if d then
            L[#L + 1] = col(C.dim, is_pop and '??? is ' or 'spot is ') .. col(C.good, d)
        elseif here and is_pop then
            L[#L + 1] = col(C.dim, 'stand at the ??? and //empy mark to save it')
        end
        if is_pop then
            for k, kid in ipairs(n.kids) do
                local tag
                if kid.state == 'have' then tag = col(C.good, '[x] have')
                elseif kid.state == 'away' then tag = col(C.warn, '[~] in ' .. kid.where)
                else tag = col(C.bad, '[ ] need') end
                L[#L + 1] = col(C.dim, k == 1 and 'trade ' or '      ') .. col(C.text, pad(kid.label, 22)) .. tag
            end
        elseif n.respawn then
            L[#L + 1] = respawn_line(n.from, n.respawn)
        elseif n.hint then
            L[#L + 1] = col(C.dim, n.hint .. ': kill them until it appears')
        end
        L[#L + 1] = col(C.dim, 'get   ') .. col(n.ki and C.pop or C.text, n.label .. (n.ki and ' (KI)' or ''))
    end

    -- What the item leads to: the NM itself, or the next NM up the chain
    if n == best.ki then
        L[#L + 1] = col(C.dim, 'then  -> ') .. col(C.nm, nm.name .. ' (??? ' .. bare(nm.at) .. ')')
    elseif s.feeds == best.ki.from then
        L[#L + 1] = col(C.dim, 'then  -> ' .. s.feeds .. ' -> ') .. col(C.pop, best.ki.label)
    else
        L[#L + 1] = col(C.dim, 'then  -> ' .. s.feeds .. ' -> ... -> ') .. col(C.pop, best.ki.label)
    end
    -- Remind you to red proc when the key item needs one
    if n.red and settings.red_alerts then
        L[#L + 1] = red_tag(n):gsub('^ ', '') .. col(C.dim, '  to be sure of the key item')
    end
    return L
end

-------------------------------------------------------------------------------
-- Kill log. Kills of each stage NM (Chloris, Glavoid...) and how many of its
-- upgrade item turned up within 3 minutes of a kill, per character. From that,
-- an estimate of the kills (and, from this session's pace, time) left.
-------------------------------------------------------------------------------
local STAGE_NM_NAMES = {}   -- 'Chloris' -> 'chloris'
for key, nm in pairs(NMS) do
    if not nm.material then STAGE_NM_NAMES[nm.name] = key end
end

local session_kills = {}    -- NM key -> {os.time() of each kill this session}
local last_kill_at = {}     -- NM key -> os.time() of the last kill

-- This character's kill log: NM key -> {kills, items}, from 'key|kills|items;...'
local function killlog()
    local map = {}
    if not char.data then return map end
    for key, k, it in tostring(char.data.killlog or ''):gmatch('([^|;]+)|(%d+)|(%d+)') do
        map[key] = {kills = tonumber(k), items = tonumber(it)}
    end
    return map
end

-- Write the kill log back to the character's file
local function save_killlog(map)
    local parts = {}
    for key, v in pairs(map) do parts[#parts + 1] = ('%s|%d|%d'):format(key, v.kills, v.items) end
    table.sort(parts)
    char.data.killlog = table.concat(parts, ';')
    config.save(char.data, 'all')
end

-- A stage NM died: count it
local function record_kill(name)
    local key = STAGE_NM_NAMES[name]
    if not key or not char.data then return end
    local map = killlog()
    local v = map[key] or {kills = 0, items = 0}
    v.kills = v.kills + 1
    map[key] = v
    save_killlog(map)
    last_kill_at[key] = os.time()
    session_kills[key] = session_kills[key] or {}
    table.insert(session_kills[key], os.time())
end

-- Your count of an NM's item went up: if it's soon after a kill, it's a drop
local function record_drop(nm, gained)
    local t = last_kill_at[nm.key]
    if not t or os.time() - t > 180 or not char.data then return end
    local map = killlog()
    local v = map[nm.key] or {kills = 0, items = 0}
    v.items = v.items + gained
    map[nm.key] = v
    save_killlog(map)
end

-- Seconds -> '1h50m' or '12m'
local function fmt_dur(sec)
    sec = math.floor(sec + 0.5)
    if sec >= 3600 then return ('%dh%02dm'):format(math.floor(sec / 3600), math.floor(sec % 3600 / 60)) end
    return ('%dm'):format(math.max(1, math.floor(sec / 60 + 0.5)))
end

-- "12 kills, 1.4 per kill: ~27 more kills, 37 at most (~1h50m at this pace)", or nil.
-- Every stage NM (Chloris, Ulhuadshi, Dragua...) drops at least 1 of its item per
-- kill, so the kills left are never more than the items left, and a logged rate
-- under 1 (a drop lotted after the 3 minutes, say) is treated as 1.
local function estimate_line(nm)
    if nm.material then return nil end
    local left = goal_of(nm) - (nm.count or 0)
    if left <= 0 then return nil end
    local v = killlog()[nm.key] or {kills = 0, items = 0}
    local s_ = left == 1 and '' or 's'

    -- No kills logged yet: only the guaranteed drop to go on
    if v.kills == 0 then
        return col(C.dim, 'at most ') .. col(C.text, ('%d more kill%s'):format(left, s_))
            .. col(C.dim, ' (1+ drop per kill)')
    end

    -- Drops per kill so far (never below the guaranteed 1), kills still needed,
    -- and the time from this session's pace
    local rate = math.max(1, v.items / v.kills)
    local kills_left = math.ceil(left / rate)
    local eta = ''
    local ts = session_kills[nm.key]
    if ts and #ts >= 2 then
        eta = ' (~' .. fmt_dur((ts[#ts] - ts[1]) / (#ts - 1) * kills_left) .. ' at this pace)'
    end
    local most = kills_left < left and col(C.dim, (', %d at most'):format(left)) or ''
    return col(C.dim, ('%d kill%s, %.1f per kill: '):format(v.kills, v.kills == 1 and '' or 's', rate))
        .. col(C.text, ('~%d more kill%s'):format(kills_left, kills_left == 1 and '' or 's')) .. most .. col(C.dim, eta)
end

-------------------------------------------------------------------------------
-- Counts on your other characters, for items you can trade between them
-- (Heavy Metal; anything not Rare/Ex). Each character's counts are kept in a
-- shared file, so they're as of that character's last login.
-------------------------------------------------------------------------------
-- Saved as 'Char|nmkey|count;...' and read into shared
local shared_file = config.load('data/shared_counts.xml', {list = ''})
local shared = {}   -- 'Char|nmkey' -> count
for who, key, n in tostring(shared_file.list or ''):gmatch('([^|;]+)|([^|;]+)|(%d+)') do
    shared[who .. '|' .. key] = tonumber(n)
end

-- Can this NM's item be traded between characters? Heavy Metal is marked so in
-- its data; otherwise the item must not be Ex (the game's 0x4000 flag).
local function nm_tradeable(nm)
    if nm.tradeable ~= nil then return nm.tradeable end
    local ok = false
    local band = bit and bit.band
    local any = false
    for id in pairs(nm.drop_node and nm.drop_node.ids or {}) do
        local it = res.items[id]
        any = true
        if band and it and type(it.flags) == 'number' and band(it.flags, 0x4000) == 0 then ok = true end
    end
    if any then nm.tradeable = ok end   -- decide once the item ids are known
    return ok
end

-- Store this character's counts of tradeable items (when they change)
local function share_counts()
    if not char.name then return end
    local changed = false
    for key, nm in pairs(NMS) do
        if nm_tradeable(nm) then
            local k = char.name .. '|' .. key
            local n = nm.count or 0
            if (shared[k] or 0) ~= n then
                shared[k] = n > 0 and n or nil
                changed = true
            end
        end
    end
    if changed then
        local parts = {}
        for k, n in pairs(shared) do parts[#parts + 1] = k .. '|' .. n end
        table.sort(parts)
        shared_file.list = table.concat(parts, ';')
        config.save(shared_file, 'all')
    end
end

-- "+300 on Valdmule = 1,420 / 1,500", or nil
local function others_line(nm)
    if not nm_tradeable(nm) or not char.name then return nil end
    local total, who = 0, {}
    for k, n in pairs(shared) do
        local name, key = k:match('^(.-)|(.*)$')
        if key == nm.key and name ~= char.name and n > 0 then
            total = total + n
            who[#who + 1] = name .. ' ' .. n
        end
    end
    if total == 0 then return nil end
    local all, goal = (nm.count or 0) + total, goal_of(nm)
    return col(C.dim, '+' .. total .. ' on ' .. table.concat(who, ', ') .. ' = ')
        .. col(all >= goal and C.good or C.warn, ('%d / %d'):format(all, goal))
end

-------------------------------------------------------------------------------
-- Abyssea time. The game says "Your visitant status will wear off in 25
-- minutes." now and then; each line sets the clock, and it counts down between.
-------------------------------------------------------------------------------
-- ends: os.time() your Abyssea time runs out; warned: which alerts have gone off
local visit = {ends = nil, warned = {}}

-- Seconds of Abyssea time left, or nil when it isn't known
local function visit_left()
    if not visit.ends then return nil end
    return math.max(0, visit.ends - os.time())
end

-- Header text: plain (for padding) and coloured. Empty when not known.
-- Leaving Abyssea with under 5 minutes left means an hour before you can go
-- back in, so between 10 and 5 minutes it also counts down to that point.
local function visit_tag()
    local left = visit_left()
    if not left then return '', '' end
    local text = 'time ' .. (left < 60 and (left .. 's') or (math.ceil(left / 60) .. 'm'))
    if left <= 600 and left > 300 then
        text = text .. ' (leave in ' .. math.ceil((left - 300) / 60) .. 'm)'
    elseif left <= 300 and left > 0 then
        text = text .. ' (1h lockout)'
    end
    local c = left <= 300 and C.bad or (left <= 600 and C.warn or C.good)
    return text, col(c, text)
end

-- Draw the tall layout. The body is built as a list of blocks (plain text, the big
-- count, or a boxed NEXT step), each shown in its own text box by place().
local function render_tall()
    local groups, done_w = active_nms()
    local wcount = #selected_weapons()

    -- Title strip: where you are when in a farm zone, else how many weapons
    local right, rc
    if near.n and settings.near_rate > 0 then
        right, rc = ('#%d* %dy'):format(near.n, math.floor(near.dist + 0.5)), C.good
    else
        right, rc = (wcount == 0 and 'pick a weapon' or (wcount .. (wcount == 1 and ' weapon' or ' weapons'))), C.warn
    end
    local tail = settings.minimized and '  [+]' or '  [-]'
    local tplain, tcol = visit_tag()
    if tplain ~= '' then tplain, tcol = tplain .. '  ', tcol .. '  ' end
    title:text(col(C.head, 'EMPYBUILDER') .. string.rep(' ', math.max(2, TALL_W - 11 - #tplain - #right - #tail))
        .. tcol .. col(rc, right) .. col(C.dim, tail))

    -- Helpers for building the blocks: add a line (optionally clickable) to the current
    -- block, start a new block after flush(), or add a special block (big or boxed)
    local blocks, cur = {}, nil
    local function flush() if cur and #cur.lines > 0 then blocks[#blocks + 1] = cur end; cur = nil end
    local function add(line, action, gap)
        if not cur then cur = {lines = {}, rows = nil, gap = gap} end
        cur.lines[#cur.lines + 1] = line
        if action then cur.rows = cur.rows or {}; cur.rows[#cur.lines] = action end
    end
    local function special(b) flush(); blocks[#blocks + 1] = b end

    -- Nothing to show yet: no weapon, or none of their NMs in this zone
    if wcount == 0 then
        add(col(C.dim, 'No weapon picked yet.'))
        add(col(C.text, '//empy pick') .. col(C.dim, ' or ') .. col(C.text, '//empy add <weapon>'))
    elseif #groups == 0 and #done_w == 0 then
        add(col(C.dim, 'None of your weapons\' NMs are in this zone.'))
        add(col(C.dim, '//empy zone off to show them all'))
    end
    if #done_w > 0 then
        add(col(C.good, 'Lv119 done: ' .. table.concat(done_w, ', ')))
    end

    local any_ki = false
    -- One section per NM you're working on
    for gi, g in ipairs(groups) do
        local nm = g.nm
        local goal, count = goal_of(nm), nm.count or 0

        -- A later stage (full mode): name, count and weapons only
        if g.later then
            add(col(C.dim, 'LATER  ') .. col(C.nm, nm.name:upper()) .. col(C.head, '  Lv' .. nm.stage)
                .. col(C.dim, '  ' .. (nm.zone and (nm.zone:gsub('^Abyssea %- ', '')) or 'Magian trial')), nil, gi > 1 and 14 or nil)
            add(col(C.text, pad(nm.drop[1], 26)) .. count_text(nm))
            add(col(C.dim, 'for ' .. table.concat(g.weapons, ', ')))
        else

        -- Name, stage, item, big count, bar, weapons
        add(col(C.nm, nm.name:upper()) .. col(C.head, '  Lv' .. nm.stage)
            .. col(C.dim, '  ' .. (nm.zone or 'Trial of the Magians')), nil, gi > 1 and 14 or nil)
        add(col(C.text, nm.drop[1]) .. (count > (nm.count_inv or 0) and col(C.dim, ('  %d in inv'):format(nm.count_inv or 0)) or ''))
        local cc = count >= goal and C.good or (count > 0 and C.warn or C.bad)
        special({lines = {col(cc, tostring(count)) .. col(C.dim, ' / ' .. goal)}, big = true})
        local width = 28
        local filled = math.min(width, math.floor(count / goal * width))
        add(col(C.dim, '[') .. col(cc, string.rep('#', filled)) .. col(C.dim, string.rep('-', width - filled) .. ']')
            .. col(cc, (' %d%%'):format(math.min(100, math.floor(count / goal * 100)))))
        local others = others_line(nm)
        if others then add(others) end
        local est = estimate_line(nm)
        if est then add(est) end
        add(col(C.dim, 'for ' .. table.concat(g.weapons, ', ')))

        if nm.material then
            -- A material stage: no NM to pop, just where the material comes from
            for _, l in ipairs(nm.info) do add(col(C.dim, l)) end
        else

        -- The NEXT box (timed NMs have no key items, so no plan)
        local list, best = {}, nil
        if not nm.timed then list, best = plan(nm) end
        special({lines = next_box(nm, best), box = true, gap = 8})

        if not nm.timed then
            any_ki = true
            -- Which key item's steps to show: your pick, else the one NEXT is in
            local show = tall.pick[nm.key]
            if not (show and list[show] and list[show].steps) then
                show = best and best.i
                if not show then
                    for _, e in ipairs(list) do if e.steps then show = e.i break end end
                end
            end

            -- One clickable line per key item: done, or a progress bar and steps done
            local got, total = kis_got(nm)
            add(col(C.head, pad('KEY ITEMS', TALL_W - 8)) .. col(got == total and C.good or C.warn, got .. '/' .. total), nil, 8)
            for _, e in ipairs(list) do
                if e.ki.state == 'have' then
                    add(col(C.good, '[x] ') .. col(C.dim, pad(e.ki.label, 24)) .. string.rep(' ', 10) .. col(C.good, 'done'))
                else
                    local len = math.min(e.total, 8)
                    local f = math.floor(e.done / e.total * len + 0.5)
                    local bar = '[' .. string.rep('#', f) .. string.rep('-', len - f) .. ']'
                    add(col(e.i == show and C.pop or C.dim, e.i == show and '>   ' or '[ ] ')
                        .. col(e.i == show and C.pop or C.text, pad(e.ki.label, 24))
                        .. col(e.done > 0 and C.warn or C.dim, pad(bar, 10))
                        .. col(C.text, e.done .. '/' .. e.total) .. red_tag(e.ki),
                        {nm = nm.key, i = e.i})
                end
            end

            -- The steps of the key item picked (or the one NEXT is in)
            local e = show and list[show]
            if e and e.steps then
                add('')
                add(col(C.pop, pad(e.ki.label, TALL_W - 8)) .. col(C.dim, 'steps'))
                for si, s in ipairs(e.steps) do
                    local n = s.n
                    local mark = (si == e.nxt) and col(C.pop, '>>  ')
                        or (n.state == 'have') and col(C.good, '[x] ')
                        or (n.state == 'away') and col(C.warn, '[~] ')
                        or col(C.dim, '[ ] ')
                    local wtext, here = star_where(s, nm)
                    add('  ' .. mark .. col(n.state == 'have' and C.dim or C.text, pad(n.from, 17))
                        .. col(here and C.good or (n.state == 'have' and C.dim or C.head), pad(wtext, 10))
                        .. status_tag(n) .. red_tag(n)
                        .. (n.state ~= 'have' and respawn_tag(n.from, n.respawn) or '')
                        .. (n.state ~= 'have' and mark_tag(nm.zone, n.from) or ''))
                end
            end
        end
        end   -- material / NM
        end   -- later / current
    end

    -- The footer: click hint, red proc helper, and when bags were last searched
    if any_ki then add(''); add(col(C.dim, 'Click a key item to show its steps')) end
    local red = red_section(groups, TALL_W)
    if red then
        flush()
        for i, l in ipairs(red) do add(l, nil, i == 1 and 10 or nil) end
        flush()
    end
    if last_scan > 0 then
        local ago = os.time() - last_scan
        if not any_ki and not red then add('') end
        add(col(C.dim, ('Searched %s (%s)'):format(os.date('%H:%M:%S', last_scan), ago < 5 and 'just now' or (ago .. 's ago'))))
    end
    flush()

    -- Fill the text pool
    local nbox = 0
    for i, b in ipairs(blocks) do
        local t = tall_text(i)
        t:size(b.big and (settings.size + 12) or settings.size)
        t:bold(b.big == true)
        t:text(table.concat(b.lines, '\n'))
        if b.box then nbox = nbox + 1; tall_box(nbox) end
    end
    tall.blocks, tall.used, tall.boxes_used = blocks, #blocks, nbox
    tall_show(shown and not settings.minimized)
end

-- Draw the window. The tall layout has its own function; this is the wide one:
-- one text box with every NM, every key item and every step.
local function render()
    if settings.layout == 'tall' then return render_tall() end
    local groups, done_w = active_nms()

    -- Title strip
    local wcount = #selected_weapons()
    local right = (wcount == 0 and 'pick a weapon' or (wcount .. (wcount == 1 and ' weapon' or ' weapons')))
    local tplain, tcol = visit_tag()
    if tplain ~= '' then tplain, tcol = tplain .. '   ', tcol .. '   ' end
    title:text(col(C.head, 'EMPYBUILDER') .. col(C.dim, '  Empyrean weapon builder')
        .. string.rep(' ', math.max(2, 50 - #tplain - #right)) .. tcol .. col(C.warn, right)
        .. col(C.dim, settings.minimized and '  [+]' or '  [-]'))

    -- The nearest conflux line, then the picker list or a note when there's nothing to show
    local lines = {}
    if near.n and settings.near_rate > 0 then
        lines[#lines + 1] = col(C.dim, 'You are nearest ') .. col(C.good, 'Conflux #' .. near.n)
            .. col(C.dim, (' (%d yalms)   steps by it are marked '):format(math.floor(near.dist + 0.5)))
            .. col(C.good, '#' .. near.n .. '*')
        lines[#lines + 1] = ''
    end
    if wcount == 0 then
        render_picker(lines)
    elseif #groups == 0 and #done_w == 0 then
        lines[#lines + 1] = col(C.dim, 'None of your weapons\' NMs are in this zone (//empy zone off to show all).')
    end
    if #done_w > 0 then
        lines[#lines + 1] = col(C.good, 'Lv119 done: ' .. table.concat(done_w, ', '))
    end

    -- One section per NM: heading, weapons, other characters' counts and the estimate,
    -- then its key items and their steps (or the material's info, or the camp note)
    for gi, g in ipairs(groups) do
        local nm = g.nm
        if gi > 1 then lines[#lines + 1] = '' end
        local place
        if nm.material then
            place = col(C.dim, '  Trial of the Magians')
        else
            place = col(C.dim, '  ' .. nm.zone .. (nm.timed and '  spawn ' or '  ??? '))
                .. col(is_near(nm, nm.vc) and C.good or C.head, nm_spot(nm, is_near(nm, nm.vc)))
        end
        lines[#lines + 1] = (g.later and col(C.dim, 'LATER  ') or '') .. col(C.nm, nm.name:upper())
            .. col(C.head, '  Lv' .. nm.stage) .. place
            .. '   ' .. col(C.text, nm.drop[1] .. ' ') .. count_text(nm)
        lines[#lines + 1] = col(C.dim, '  for ' .. table.concat(g.weapons, ', '))
        if not g.later then
            local others, est = others_line(nm), estimate_line(nm)
            if others then lines[#lines + 1] = '  ' .. others end
            if est then lines[#lines + 1] = '  ' .. est end
        end

        if g.later then
            lines[#lines + 1] = col(C.dim, ('  //empy stage %d <weapon> to work on it now'):format(nm.stage))
        elseif nm.material then
            for _, l in ipairs(nm.info) do lines[#lines + 1] = col(C.dim, '  ' .. l) end
        elseif nm.timed then
            lines[#lines + 1] = col(C.pop, '  ' .. nm.timed)
            lines[#lines + 1] = '  ' .. respawn_line(nm.name, nm.respawn)
            if nm.info then lines[#lines + 1] = col(C.dim, '  ' .. nm.info) end
        else
            local got, total = kis_got(nm)
            local kc = (got == total) and C.good or C.warn
            if got == total then
                lines[#lines + 1] = col(C.good, ('  Ready: examine the ??? at %s to pop %s'):format(nm.at, nm.name))
                    .. '  ' .. col(kc, ('%d/%d KI'):format(got, total))
            else
                lines[#lines + 1] = col(C.dim, ('  Get the key items, then examine the ??? at %s'):format(nm.at))
                    .. '  ' .. col(kc, ('%d/%d KI'):format(got, total))
            end
            for _, k in ipairs(nm.kids) do render_branch(k, nm, lines) end
        end
    end

    -- The red proc helper and when bags were last searched
    if last_scan > 0 then
        local ago = os.time() - last_scan
        local red = red_section(groups, 70)
        if red then
            lines[#lines + 1] = ''
            for _, l in ipairs(red) do lines[#lines + 1] = l end
        end
        lines[#lines + 1] = ''
        lines[#lines + 1] = col(C.dim, ('Searched bags + key items %s  (%s)  -  //empy refresh')
            :format(os.date('%H:%M:%S', last_scan), ago < 5 and 'just now' or (ago .. 's ago')))
    end
    body:text(table.concat(lines, '\n'))
end

-------------------------------------------------------------------------------
-- Refresh: search, evaluate, announce, draw
-------------------------------------------------------------------------------
local before   -- what the last search found {kis = owned key items, counts = item counts}, for announcements

-- The Abyssea zones the Empyrean NMs live in (Lv80, 85 and 90)
local FARM_ZONES = {}
for _, nm in pairs(NMS) do if nm.zone then FARM_ZONES[nm.zone] = true end end
-- Zone ids of the farm zones, and of every Abyssea zone
local farm_zone_ids, abyssea_zone_ids = {}, {}
for name, id in pairs(zone_ids) do
    if FARM_ZONES[name] then farm_zone_ids[id] = true end
    if name:sub(1, 10) == 'Abyssea - ' then abyssea_zone_ids[id] = true end
end

-- 'farm' = the nine Empyrean NM zones, 'abyssea' = any Abyssea zone, 'always' = everywhere
-- Material stages (Heavy Metal, Rift items) aren't farmed in Abyssea, so when
-- everything you're working on is a material, the window shows anywhere.
local function only_materials()
    local any = false
    for _, w in ipairs(selected_weapons()) do
        local st = stage_of(w)
        if st ~= 'done' then
            local nm = NMS[w.nm[st]]
            if not (nm and nm.material) then return false end
            any = true
        end
    end
    return any
end

-- Should the main window show in this zone (by the //empy where setting)?
local function window_zone_ok(zone)
    if settings.show_in == 'always' then return true end
    if only_materials() then return true end
    if settings.show_in == 'abyssea' then return abyssea_zone_ids[zone] == true end
    return farm_zone_ids[zone] == true
end

-- Search bags and key items, update every count and state, work out stages, say
-- what changed, and draw the window (or hide it outside the zones it shows in)
local function refresh()
    local info = windower.ffxi.get_info()
    if not info or not info.logged_in then
        if shown then set_visible(false) end
        return
    end

    -- Search, then update every NM: chain states, item counts, drops for the kill log
    local have, kis = scan()
    last_kis = kis
    last_scan = os.time()
    for _, key in ipairs(NM_ORDER) do
        local nm = NMS[key]
        local was = nm.count
        evaluate(nm, have, kis)
        count_drop(nm, have)
        if was and nm.count > was then record_drop(nm, nm.count - was) end
    end
    share_counts()

    -- Which stage each weapon is on, from the copy in your bags
    local stage_was = {}
    for _, w in ipairs(selected_weapons()) do stage_was[w.name] = stage_of(w) end
    detect_stages(have)
    -- A stage set by hand gives way once your bags show you're past it
    local rank = {[80] = 1, [85] = 2, [90] = 3, [95] = 4, [99] = 5, [119] = 6, done = 7}
    for _, w in ipairs(WEAPONS) do
        local o = stage_overrides()[w.name]
        if o and rank[o] and rank[detected[w.name]] and rank[detected[w.name]] > rank[o] then
            set_stage(w, nil)
            stage_was[w.name] = o
        end
    end

    -- Announcements for the NMs you're working on
    -- What you hold now, to compare with the last search
    local now = {kis = {}, counts = {}}
    for _, key in ipairs(NM_ORDER) do
        local nm = NMS[key]
        now.counts[key] = nm.count
        for _, k in ipairs(nm.kids) do if k.state == 'have' then now.kis[k.ki] = true end end
    end
    -- New key items, higher counts, goals reached
    if settings.announce and before then
        for _, g in ipairs(active_nms()) do
            local nm = g.nm
            for _, k in ipairs(nm.kids) do
                if now.kis[k.ki] and not before.kis[k.ki] then
                    local got, total = kis_got(nm)
                    say(('got %s (%s %d/%d)'):format(k.ki, nm.name, got, total))
                end
            end
            local was, goal = before.counts[nm.key] or 0, goal_of(nm)
            if nm.count > was and not g.later then
                say(('%s %d / %d'):format(nm.drop[1], nm.count, goal))
                if was < goal and nm.count >= goal then
                    say(('%d %s reached: ready for the Lv%d trade for %s'):format(goal, nm.drop[1], nm.stage,
                        table.concat(g.weapons, ', ')))
                    alert('goal', ('%d %s: ready for Lv%d'):format(goal, nm.drop[1], nm.stage))
                end
            end
        end
        -- A weapon moved up a stage (you traded and got the next level)
        for _, w in ipairs(selected_weapons()) do
            local st, manual = stage_of(w)
            if not manual and stage_was[w.name] and st ~= stage_was[w.name] then
                if st == 'done' then
                    say(('%s is Lv119: done'):format(w.name))
                else
                    local nm = NMS[w.nm[st]]
                    say(('%s is Lv%d now: next is %d %s from %s'):format(w.name, STAGE_BEFORE[st], goal_of(nm),
                        nm.drop[1], source_of(nm)))
                end
            end
        end
    end
    before = now

    -- Counts stay up to date everywhere; the window only appears where you farm
    if not settings.visible or not window_zone_ok(info.zone) then
        if shown then set_visible(false) end
        return
    end
    render()
    if not shown then set_visible(true) end
end

-------------------------------------------------------------------------------
-- Frame loop
-------------------------------------------------------------------------------
-- dirty: something changed, search again soon; last: when the last search ran
-- (os.clock); last_flash: the RED!!! blink; last_tick: the once-a-second redraw;
-- last_try: when the last timed search ran (os.time)
local dirty, last, last_flash, last_tick, last_try = true, 0, 0, 0, 0
-- Ask for a fresh search on the next frame (items or key items changed)
local function mark() dirty = true end

-- Note what you're targeting, and whether it's an NM you still need a red proc on
local function update_target()
    local t = windower.ffxi.get_mob_by_target('t')
    local name = t and t.name or nil
    local hit = false
    if name then
        for _, g in ipairs(active_nms()) do
            for _, k in ipairs(g.nm.kids) do
                if k.red and k.from == name and k.state ~= 'have' then hit = true end
            end
        end
    end
    if name ~= target_name then target_name = name; if shown then render() end end
    any_red_targeted = hit
end

-- When you drag the title or body text, move the whole window with it
local function follow_drag()
    local tx, ty, bx, by = expected()
    local ax, ay = title:pos()
    local cx, cy = body:pos()
    if ax ~= tx or ay ~= ty then
        settings.window.pos.x, settings.window.pos.y = settings.window.pos.x + ax - tx, settings.window.pos.y + ay - ty
    elseif shown and not settings.minimized and (cx ~= bx or cy ~= by) then
        settings.window.pos.x, settings.window.pos.y = settings.window.pos.x + cx - bx, settings.window.pos.y + cy - by
    end
end

do -- (in a do block to keep the main chunk under Lua's 200-local limit)
-- Every frame: target check (5x a second), nearest conflux, the RED!!! blink,
-- the search (after a change, or on the timer), a redraw once a second, and placing
-- the window
local target_clock, near_wall = 0, 0
windower.register_event('prerender', function()
    local now, wall = os.clock(), os.time()

    if now - target_clock > 0.2 then
        target_clock = now
        update_target()
    end
    -- Nearest conflux: re-checked every near_rate seconds
    if settings.near_rate > 0 and wall - near_wall >= settings.near_rate then
        near_wall = wall
        if update_near() and shown then render() end
    elseif settings.near_rate <= 0 and near.n then
        near.n = nil
        if shown then render() end
    end
    if any_red_targeted and now - last_flash > 0.5 then
        last_flash, flash_on = now, not flash_on
        if shown then render() end
    end

    if (dirty and now - last > 0.3) or (settings.rescan > 0 and wall - last_try >= settings.rescan) then
        dirty, last, last_try = false, now, wall
        refresh()
    elseif shown and wall ~= last_tick then
        last_tick = wall
        render()
    end

    if shown then
        follow_drag()
        place()
    end
end)
end

-- Items coming and going, and zoning, ask for a fresh search (zoning also
-- forgets what the log said about mobs)
windower.register_event('add item', mark)
windower.register_event('remove item', mark)
windower.register_event('zone change', function() fiend = {}; mark() end)

-- Timed NMs, by lower-case name -> {name, respawn}
local TIMED = {}
for _, key in ipairs(NM_ORDER) do
    local nm = NMS[key]
    if nm.respawn then TIMED[lc(nm.name)] = {name = nm.name, respawn = nm.respawn} end
    local function walk(n)
        if n.respawn then TIMED[lc(n.from)] = {name = n.from, respawn = n.respawn} end
        for _, k in ipairs(n.kids or {}) do walk(k) end
    end
    for _, k in ipairs(nm.kids) do walk(k) end
end

-- //empy debug: when on, every defeat the addon sees (and what it did with it) is
-- echoed in chat, to find out why a kill wasn't counted. Not saved.
local dbg = {on = false}
local function dbg_say(s) if dbg.on then windower.add_to_chat(8, '[EmpyBuilder debug] ' .. s) end end

-- Something died: start a timed NM's respawn timer, and count stage NM kills.
-- Both the game's defeat event and the chat line can report the same kill, so
-- a repeat within 30 seconds is ignored.
do -- (in a do block to keep the main chunk under Lua's 200-local limit)
-- Lower-case name -> proper name, for every NM a kill means something for
local DEFEAT_NAMES = {}
for low, t in pairs(TIMED) do DEFEAT_NAMES[low] = t.name end
for name in pairs(STAGE_NM_NAMES) do DEFEAT_NAMES[lc(name)] = name end

-- NM name -> os.time() its last kill was counted
local defeat_seen = {}

-- Count a kill: the kill log for stage NMs, the respawn timer for timed NMs.
-- Returns true when the name was one it tracks. how = where it was seen.
local function on_defeat(raw, how)
    if not raw or raw == '' then return false end
    -- Match without caring about case or a leading "the "
    local low = lc(raw):gsub('^the ', '')
    local name = DEFEAT_NAMES[low]
    if not name then return false end
    if defeat_seen[name] and os.time() - defeat_seen[name] <= 30 then
        dbg_say(name .. ' (' .. how .. '): already counted')
        return true
    end
    defeat_seen[name] = os.time()
    dbg_say(name .. ' defeated (' .. how .. ')')
    -- Each part is protected, so a problem in one can't stop the others
    if STAGE_NM_NAMES[name] then
        local ok, err = pcall(record_kill, name)
        if not ok then dbg_say('kill log error: ' .. tostring(err)) end
    end
    local t = TIMED[low]
    if t then
        killed[t.name] = os.time()
        if settings.announce then
            say(('%s down: respawns in %d-%d min (about %s-%s)'):format(t.name, t.respawn[1], t.respawn[2],
                os.date('%H:%M', os.time() + t.respawn[1] * 60), os.date('%H:%M', os.time() + t.respawn[2] * 60)))
        end
    end
    if shown then
        local ok, err = pcall(render)
        if not ok then dbg_say('redraw error: ' .. tostring(err)) end
    end
    return true
end

-- The game's defeat messages ("X defeats Y", "Y falls to the ground", ...). Some
-- name the one that died as the target and some as the actor, so try both.
local DEFEAT_MSG = {[6] = true, [20] = true, [113] = true, [406] = true, [605] = true, [646] = true}
local function mob_name(id, index)
    local m = (id and id > 0 and windower.ffxi.get_mob_by_id(id)) or (index and index > 0 and windower.ffxi.get_mob_by_index(index))
    return m and m.name or nil
end
windower.register_event('action message', function(actor_id, target_id, actor_index, target_index, message_id)
    if not DEFEAT_MSG[message_id] then return end
    local tname, aname = mob_name(target_id, target_index), mob_name(actor_id, actor_index)
    dbg_say(('defeat message %d: actor %s, target %s'):format(message_id, tostring(aname), tostring(tname)))
    if not on_defeat(tname, 'game message') then on_defeat(aname, 'game message') end
end)

-- Backup: the chat lines "<you> defeats (the) Chukwa." / "Chukwa falls to the ground."
windower.register_event('incoming text', function(original)
    if not original then return end
    local text = lc(original:gsub('[\30\31]%Z', ''):gsub('[\127\239].', ''))
    if not (text:find('defeat', 1, true) or text:find('falls to the ground', 1, true)) then return end
    dbg_say('chat: ' .. text)
    local hit = false
    for low in pairs(DEFEAT_NAMES) do
        if text:find('defeats ' .. low, 1, true) or text:find('defeats the ' .. low, 1, true)
            or text:find(low .. ' falls to the ground', 1, true) or text:find(low .. ' was defeated', 1, true) then
            hit = on_defeat(low, 'chat') or hit
        end
    end
    if not hit then dbg_say('chat line names no NM being tracked') end
end)
end

-- Read the chat log for what your target is weak to, and for a red proc landing:
--   "The fiend appears vulnerable to <element> elemental weapon skills!"  (Abyssite of Discernment)
--   "The fiend is frozen in its tracks."                                    (red proc)
windower.register_event('incoming text', function(original)
    if not original or not original:find('fiend', 1, true) then return end
    local text = lc(original:gsub('[\30\31]%Z', ''):gsub('[\127\239].', ''))
    -- The element word may come wrapped in colour or auto-translate marks: keep its letters
    local raw = text:match('vulnerable to (.-) elemental weapon skills')
    local el = raw and raw:match('(%a+)%A*$')
    if el and not EL_WORDS[el] then el = raw:match('%a+') end
    local red = text:find('frozen in its tracks', 1, true)
    if not el and not red then return end

    -- Note it against your target (or battle target), new fiend record if needed
    local t = windower.ffxi.get_mob_by_target('t') or windower.ffxi.get_mob_by_target('bt')
    if not t then return end
    local f = fiend[t.id]
    if not f or f.name ~= t.name then f = {name = t.name}; fiend[t.id] = f end
    f.at = os.time()
    -- A weakness: say which red proc weapon skills you have for it, and alert
    if el then
        f.el = EL_WORDS[el] or (el:sub(1, 1):upper() .. el:sub(2))
        if settings.announce and RED_BY_EL[f.el] then
            local have = {}
            for _, m in ipairs(my_red_ws()) do if m.el == f.el then have[#have + 1] = m.name end end
            say(('%s is weak to %s: %s'):format(t.name, f.el,
                #have > 0 and ('use ' .. table.concat(have, ' or ')) or 'none of its weapon skills is on this weapon'))
        end
        if RED_BY_EL[f.el] then
            local have = {}
            for _, m in ipairs(my_red_ws()) do if m.el == f.el then have[#have + 1] = m.name end end
            alert('weakness', ('%s: weak to %s%s'):format(t.name, f.el,
                #have > 0 and (', use ' .. table.concat(have, ' or ')) or ''))
        end
    end
    -- A red proc: alert once per fiend
    if red and not f.red then alert('redproc', 'Red proc on ' .. t.name .. '!') end
    if red then f.red = true end
    if shown then render() end
end)
-- Hide the window on logout; key item packets (0x055) and inventory packets
-- (0x01D, 0x020) ask for a fresh search
windower.register_event('logout', function() set_visible(false) end)
windower.register_event('incoming chunk', function(id)
    if id == 0x055 or id == 0x01D or id == 0x020 then mark() end
end)

-------------------------------------------------------------------------------
-- Weapon picker: a small clickable window, shown when a character hasn't
-- picked yet (and on //empy pick)
-------------------------------------------------------------------------------
-- The picker's rectangles: outline, panel, header strip, and the row under the mouse
local PP = {border = 'empybuilder_pick_border', bg = 'empybuilder_pick_bg',
            head = 'empybuilder_pick_head', hover = 'empybuilder_pick_hover'}

-- Its own function, so its locals don't count toward the main chunk's limit of 200
local picker_show, open_picker, picker_inside = (function()
-- open: showing; sel: weapons ticked; hover: row under the mouse; rows: what each
-- line does when clicked; box: where the picker is on screen
local picker = {open = false, sel = {}, hover = nil, rows = {}, box = {x = 0, y = 0, w = 0, h = 0}}

-- The picker's rectangles (hidden until it opens)
make_rect(PP.border, settings.window.border)
make_rect(PP.bg,     {alpha = 240, red = 14, green = 18, blue = 26})
make_rect(PP.head,   settings.window.header)
make_rect(PP.hover,  {alpha = 120, red = 70, green = 90, blue = 140})

-- The picker's text (one line per weapon, then Save and Not now)
local pick_text = texts.new('', {
    pos   = {x = 0, y = 0},
    bg    = {visible = false},
    text  = {font = settings.font, size = settings.size + 1, alpha = 255, red = 230, green = 230, blue = 230,
             stroke = {width = 1, alpha = 180, red = 0, green = 0, blue = 0}},
    flags = {draggable = false},
    padding = 0,
})
pick_text:hide()
fade_text(pick_text, 180)
apply_opacity()

-- Write the picker's lines, noting what clicking each one does
local function picker_render()
    local lines, rows = {}, {}
    local function add(s, action) lines[#lines + 1] = s; rows[#lines] = action end

    add(col(C.head, 'EMPYBUILDER') .. col(C.text, '   Which Empyrean weapon are you building?'))
    add(col(C.dim, 'Click to pick one or more, then Save' .. (char.name and (' (saved for ' .. char.name .. ')') or '') .. '.'))
    add('')
    add(col(C.dim, '     ' .. pad('Weapon', 13) .. pad('Type', 14) .. pad('Stage', 7) .. pad('Item', 27) .. 'Have'))
    for _, w in ipairs(WEAPONS) do
        local on = picker.sel[w.name]
        local nm, st = current_nm(w)
        add((on and col(C.good, ' [x] ') or col(C.dim, ' [ ] '))
            .. col(on and C.good or C.text, pad(w.name, 13)) .. col(C.dim, pad(w.kind, 14))
            .. (nm and (col(C.head, pad('Lv' .. st, 7)) .. col(C.nm, pad(nm.drop[1], 27)) .. count_text(nm))
                   or col(C.good, 'Lv119 done')),
            {weapon = w})
    end
    add('')
    local n = 0
    for _ in pairs(picker.sel) do n = n + 1 end
    add(col(C.pop, '   [ Save ]  ') .. col(C.dim, n == 0 and 'nothing picked yet' or (n .. ' picked')), {save = true})
    add(col(C.dim, '   [ Not now ]  ask again next time, or //empy pick'), {skip = true})

    picker.rows = rows
    pick_text:text(table.concat(lines, '\n'))
    picker.nlines = #lines
end

-- Centre the picker on screen and size its rectangles around the text
local function picker_place()
    local tw, th = pick_text:extents()
    tw, th = tw or 0, th or 0
    if tw == 0 then return end
    local pad_px = 12
    local ws = windower.get_windower_settings()
    local w, h = tw + pad_px * 2, th + pad_px * 2
    local x = math.floor((ws.ui_x_res - w) / 2)
    local y = math.floor((ws.ui_y_res - h) / 3)
    picker.box = {x = x, y = y, w = w, h = h, tx = x + pad_px, ty = y + pad_px, lh = th / math.max(picker.nlines or 1, 1)}

    pick_text:pos(x + pad_px, y + pad_px)
    windower.prim.set_position(PP.border, x - 1, y - 1); windower.prim.set_size(PP.border, w + 2, h + 2)
    windower.prim.set_position(PP.bg, x, y);             windower.prim.set_size(PP.bg, w, h)
    windower.prim.set_position(PP.head, x, y);           windower.prim.set_size(PP.head, w, math.floor(pad_px + picker.box.lh + 4))

    local r = picker.hover
    if r then
        windower.prim.set_position(PP.hover, x + 4, math.floor(picker.box.ty + (r - 1) * picker.box.lh))
        windower.prim.set_size(PP.hover, w - 8, math.ceil(picker.box.lh))
    end
    windower.prim.set_visibility(PP.hover, r ~= nil)
end

-- Show or hide the picker
local function picker_show(on)
    picker.open = on
    for key, name in pairs(PP) do
        if key ~= 'hover' then windower.prim.set_visibility(name, on) end
    end
    windower.prim.set_visibility(PP.hover, false)
    if on then pick_text:show() else pick_text:hide() end
end

-- Open the picker with this character's current weapons ticked
local function open_picker()
    if not char.data then say('log in first') return end
    picker.sel, picker.hover = {}, nil
    for _, w in ipairs(selected_weapons()) do picker.sel[w.name] = true end
    picker_render()
    picker_show(true)
end

-- Is the mouse over the picker?
local function picker_inside(x, y)
    local b = picker.box
    return picker.open and x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h
end

-- Which clickable line is at this height, if any
local function picker_row(y)
    local b = picker.box
    if not b.lh or b.lh <= 0 then return nil end
    local r = math.floor((y - b.ty) / b.lh) + 1
    if picker.rows[r] then return r end
    return nil
end

-- Clicking a line: tick/untick a weapon, Save the list, or Not now
local function picker_click(r)
    local action = picker.rows[r]
    if not action then return end
    if action.weapon then
        local name = action.weapon.name
        picker.sel[name] = (not picker.sel[name]) or nil
        picker_render()
    elseif action.save then
        local list = {}
        for _, w in ipairs(WEAPONS) do if picker.sel[w.name] then list[#list + 1] = w end end
        save_weapons(list)
        picker_show(false)
        if #list == 0 then
            say('no weapon picked; //empy pick to choose later')
        else
            local names = {}
            for _, w in ipairs(list) do names[#names + 1] = w.name end
            say('building ' .. table.concat(names, ', ') .. ' (saved for ' .. char.name .. ')')
            local info = windower.ffxi.get_info()
            if info and not window_zone_ok(info.zone) then
                say('the tracker window appears when you enter Abyssea; //empy weapons shows your counts anywhere')
            end
        end
        before = nil
        mark()
    elseif action.skip then
        picker_show(false)
        say('no problem; //empy pick when you are ready')
    end
end

-- While it's open: redraw once a second (so counts stay current) and keep it placed
local picker_tick = 0
windower.register_event('prerender', function()
    if not picker.open then return end
    local now = os.time()
    if now ~= picker_tick then      -- keep the "Have" counts current
        picker_tick = now
        picker_render()
    end
    picker_place()
end)

-- The picker takes clicks over it, so they don't reach the game or the window under it
windower.register_event('mouse', function(type, x, y)
    if not picker.open then return end
    local inside = picker_inside(x, y)
    -- type 0 = mouse move (highlight the row), 1 = button down, 2 = button up (click)
    if type == 0 then
        local r = inside and picker_row(y) or nil
        if r ~= picker.hover then picker.hover = r end
        return
    end
    if not inside then return end
    if type == 1 then return true end
    if type == 2 then
        local r = picker_row(y)
        if r then picker_click(r) end
        return true
    end
end)
    -- Hand back the three functions the rest of the addon uses
    return picker_show, open_picker, picker_inside
end)()

-- The loading echo, in the same style as the other addons:
--   [EmpyBuilder] Author: Valdimar @ Phoenix 3.0  -  //empy help for commands
--   [EmpyBuilder] Loaded profile for Valdimar: Redemption (Lv85), Rhongomiant (Lv85).
local function load_echo()
    say(('Author: %s %s  -  //empy help for commands'):format(_addon.author, _addon.version))
    if char.name then
        refresh()   -- read your bags first, so the stages are right
        local list = {}
        for _, w in ipairs(selected_weapons()) do
            local st = stage_of(w)
            list[#list + 1] = w.name .. (st == 'done' and ' (Lv119, done)' or (' (Lv' .. st .. ')'))
        end
        say(('Loaded profile for %s: %s.'):format(char.name,
            #list > 0 and table.concat(list, ', ') or 'no weapon picked yet'))
    end
end

-- On login (or when the addon loads while logged in): load that character's
-- list, ask which weapons if they haven't picked yet, and show the loading echo
local function on_character(name)
    if not load_character(name) then return end
    before = nil
    mark()
    if not char.data.picked then open_picker() end
    coroutine.schedule(load_echo, 2)
end

-- Login loads the character; logout closes the picker and forgets the character
windower.register_event('login', function(name) on_character(name) end)
windower.register_event('logout', function()
    picker_show(false)
    char.name, char.data = nil, nil
end)

do -- (in a do block to keep the main chunk under Lua's 200-local limit)
-- Clicks on the main window: the header toggles minimized, a key item line in the
-- tall layout shows its steps, and a drag saves the new position. press holds
-- where the window was when the button went down.
local press
windower.register_event('mouse', function(type, x, y)
    if not shown or picker_inside(x, y) then return end
    -- The Atma and Procs buttons: toggle that window on click (and keep the click from the game)
    local hb = (type == 1 or type == 2) and hdr_btns.hit(x, y) or nil
    if hb or ((type == 1 or type == 2) and press and press.btn) then
        if type == 1 then
            press = {btn = hb}
        elseif press and press.btn then
            if hb == press.btn then windower.send_command(hb.cmd) end
            press = nil
        end
        return true
    end
    if type == 1 then
        local act = settings.layout == 'tall' and not settings.minimized and tall_hit(x, y) or nil
        press = {x = settings.window.pos.x, y = settings.window.pos.y, on_title = title:hover(x, y), act = act}
        if act then return true end
    elseif type == 2 and press then
        local moved = press.x ~= settings.window.pos.x or press.y ~= settings.window.pos.y
        local act, on_title = press.act, press.on_title
        press = nil
        if moved then
            config.save(settings)
        elseif act then
            -- Click a key item: show its steps (click it again to go back to the NEXT one)
            tall.pick[act.nm] = (tall.pick[act.nm] ~= act.i) and act.i or nil
            render()
            return true
        elseif on_title then
            settings.minimized = not settings.minimized
            config.save(settings)
            set_visible(true)
            render()
        end
    end
end)
end

-- On unload: save the settings and remove every rectangle the addon made
windower.register_event('unload', function()
    config.save(settings)
    for _, name in pairs(P) do windower.prim.delete(name) end
    for _, name in pairs(PP) do windower.prim.delete(name) end
    for _, b in ipairs(tall.boxes) do windower.prim.delete(b.border); windower.prim.delete(b.fill) end
end)

-------------------------------------------------------------------------------
-- Lights window. A separate panel (//empy lights) that tallies the lights the
-- log says you gained in this Abyssea visit, shows exact values when a Conflux
-- Surveyor reports them, and lists which of your pop items gold chests here
-- can give.
-------------------------------------------------------------------------------
-- Its own function, so its locals don't count toward the main chunk's limit of 200
local lights_update, lights_is_shown = (function()
-- The seven lights, in the order shown, and what each one does
local LIGHTS = {
    {key = 'pearlescent', name = 'Pearlescent', what = 'more chests'},
    {key = 'azure',       name = 'Azure',       what = 'blue chests'},
    {key = 'ruby',        name = 'Ruby',        what = 'red chests'},
    {key = 'amber',       name = 'Amber'},
    {key = 'golden',      name = 'Golden',      what = 'gold chests: pop items'},
    {key = 'silvery',     name = 'Silvery'},
    {key = 'ebon',        name = 'Ebon'},
}
-- Each light's text colour
local LIGHT_COLOR = {pearlescent = '\\cs(235,235,245)', azure = '\\cs(110,160,255)', ruby = '\\cs(255,90,110)',
                     amber = '\\cs(255,180,70)', golden = '\\cs(255,215,80)', silvery = '\\cs(200,205,215)',
                     ebon = '\\cs(150,120,190)'}

-- In the newer zones the maps list which key items gold chests give; in the
-- first six zones any pop item or key item can come from one.
local GOLD_LIST = {
    ['Abyssea - Uleguerand'] = {['Begrimed dragon hide'] = true, ['Decaying diremite fang'] = true},
    ['Abyssea - Altepa']     = {['Bloodied dragon ear'] = true, ['Resplendent roc quill'] = true},
    ['Abyssea - Grauberg']   = {['Vacant bugard eye'] = true, ['Variegated uragnite shell'] = true},
}

local lights = {}   -- per visit: [key] = {exact = n or nil, faint = n, mild = n, strong = n}
local lights_checked   -- os.time() of the last Conflux Surveyor report
-- Start a fresh tally (on entering a zone)
local function lights_reset()
    lights, lights_checked = {}, nil
    for _, l in ipairs(LIGHTS) do lights[l.key] = {faint = 0, mild = 0, strong = 0} end
end
lights_reset()

-- The lights window: a draggable text box with its own background
local lights_box = texts.new('', {
    pos   = {x = settings.lights.pos.x, y = settings.lights.pos.y},
    bg    = {visible = true, alpha = 200, red = 14, green = 18, blue = 26},
    text  = {font = settings.font, size = settings.size, alpha = 255, red = 230, green = 230, blue = 230,
             stroke = {width = 1, alpha = 180, red = 0, green = 0, blue = 0}},
    flags = {draggable = true},
    padding = 8,
})
fade_text(lights_box, 180)
apply_opacity()
lights_box:hide()   -- off unless you turn it on with //empy lights
-- Whether the lights window is on screen
local lights_shown = false

-- Needed pop items / key items for your current NMs that a gold chest here can give
local function gold_items(zone)
    local out, seen = {}, {}
    local list = GOLD_LIST[zone]
    local groups = active_nms()
    for _, g in ipairs(groups) do
        if not g.later and g.nm.zone == zone then
            local function walk(n)
                if n.label and n.state ~= 'have' and not seen[n.label] and (not list or list[n.label]) then
                    seen[n.label] = true
                    out[#out + 1] = n.label
                end
                if n.state ~= 'have' then for _, k in ipairs(n.kids or {}) do walk(k) end end
            end
            for _, k in ipairs(g.nm.kids) do walk(k) end
        end
    end
    return out
end

-- Write the lights window: each light's exact value (from a Surveyor) plus the
-- gains the log has shown since, then the gold chest list
local function lights_render()
    local L = {}
    L[#L + 1] = col(C.head, 'LIGHTS') .. col(C.dim, '  this visit' .. (lights_checked
        and ('   exact at ' .. os.date('%H:%M', lights_checked)) or ''))
    for _, l in ipairs(LIGHTS) do
        local v = lights[l.key]
        local gains = {}
        if v.strong > 0 then gains[#gains + 1] = v.strong .. ' strong' end
        if v.mild > 0 then gains[#gains + 1] = v.mild .. ' mild' end
        if v.faint > 0 then gains[#gains + 1] = v.faint .. ' faint' end
        local val
        if v.exact then
            val = col(C.text, pad(tostring(v.exact), 5)) .. col(C.dim, #gains > 0 and ('+' .. table.concat(gains, ' +') .. ' since') or '')
        else
            val = col(C.text, #gains > 0 and table.concat(gains, ', ') or '-')
        end
        L[#L + 1] = (LIGHT_COLOR[l.key] or '') .. pad(l.name, 12) .. '\\cr' .. val
            .. (l.what and col(C.dim, '  ' .. l.what) or '')
    end
    if not lights_checked then
        L[#L + 1] = col(C.dim, 'Exact values: talk to a Conflux Surveyor')
    end

    local zone = zone_name_now()
    local gold = zone and gold_items(zone) or {}
    if #gold > 0 then
        L[#L + 1] = ''
        L[#L + 1] = col(C.head, 'GOLD CHESTS HERE CAN GIVE YOU')
        for _, l in ipairs(wrap_list(gold, '', 46, C.pop)) do L[#L + 1] = l end
    end
    L[#L + 1] = col(C.dim, '//empy lights to hide')
    lights_box:text(table.concat(L, '\n'))
end

-- Show the lights window when it's turned on and you're in Abyssea, else hide it
local function lights_update()
    local info = windower.ffxi.get_info()
    local want = settings.lights.visible and info and info.logged_in and abyssea_zone_ids[info.zone] == true
    if want then
        lights_render()
        if not lights_shown then lights_box:show(); lights_shown = true end
    elseif lights_shown then
        lights_box:hide(); lights_shown = false
    end
end

-- Lights reset when you leave Abyssea, and so does the Abyssea clock
windower.register_event('zone change', function(new_id)
    lights_reset()
    if not abyssea_zone_ids[new_id] then visit.ends, visit.warned = nil, {} end
    lights_update()
end)

-- Save the lights window's spot after you drag it
local lights_drag
windower.register_event('mouse', function(type)
    if not lights_shown then return end
    if type == 1 then
        lights_drag = {lights_box:pos()}
    elseif type == 2 and lights_drag then
        local x, y = lights_box:pos()
        if x ~= lights_drag[1] or y ~= lights_drag[2] then
            settings.lights.pos.x, settings.lights.pos.y = x, y
            config.save(settings)
        end
        lights_drag = nil
    end
end)

-- The chat log: lights you gain, Surveyor reports, and Abyssea time
--   "Valdimar's body emits a strong golden light!"
--   "Visitant Light Intensity Pearlescent: 120 / Ebon: 30 Golden: 75 / Silvery: 40"
--   "Azure: 90 / Ruby: 60 / Amber: 45"
--   "Your visitant status will wear off in 25 minutes."
windower.register_event('incoming text', function(original)
    if not original then return end
    local text = lc(original:gsub('[\30\31]%Z', ''):gsub('[\127\239].', ''))

    -- A light you gained (only your own name counts)
    local who, how, color = text:match("(%S+)'s body emits a (%a+) (%a+) light")
    if who then
        local me = windower.ffxi.get_player()
        if me and lc(me.name) == who and lights[color] and lights[color][how] then
            lights[color][how] = lights[color][how] + 1
            if lights_shown then lights_render() end
        end
        return
    end

    -- A Conflux Surveyor report (two lines): exact values replace the tally
    local p, e, g, s = text:match('pearlescent: (%d+) / ebon: (%d+) golden: (%d+) / silvery: (%d+)')
    if p then
        for key, v in pairs({pearlescent = p, ebon = e, golden = g, silvery = s}) do
            lights[key] = {exact = tonumber(v), faint = 0, mild = 0, strong = 0}
        end
        lights_checked = os.time()
        if lights_shown then lights_render() end
        return
    end
    local a, r, am = text:match('azure: (%d+) / ruby: (%d+) / amber: (%d+)')
    if a then
        for key, v in pairs({azure = a, ruby = r, amber = am}) do
            lights[key] = {exact = tonumber(v), faint = 0, mild = 0, strong = 0}
        end
        lights_checked = os.time()
        if lights_shown then lights_render() end
        return
    end

    -- Abyssea time: set the clock, add an extension, or end it when you're sent out
    local n, unit = text:match('visitant status will wear off in (%d+) (%a+)')
    if n then
        visit.ends = os.time() + tonumber(n) * (unit:find('second', 1, true) and 1 or 60)
        if shown then render() end
        return
    end
    local ext = text:match('visitant status has been extended by (%d+) minute')
    if ext and visit.ends then
        visit.ends = visit.ends + tonumber(ext) * 60
        if shown then render() end
        return
    end
    if text:find('returning to the searing ward', 1, true) then
        visit.ends = os.time()
    end
end)
    -- Hand back the update function, and a way to ask whether the window is showing
    return lights_update, function() return lights_shown end
end)()

-- Once a second: respawn windows opening, Abyssea time running low, and the
-- lights window; every frame: the flash
do -- (in a do block to keep the main chunk under Lua's 200-local limit)
-- respawn_seen: each timed NM's state last second; respawn_soon: the kill the
-- 1-minute warning was given for; tick_wall: the last second handled
local respawn_seen, respawn_soon, tick_wall = {}, {}, 0
windower.register_event('prerender', function()
    flash_tick()
    local wall = os.time()
    if wall == tick_wall then return end
    tick_wall = wall

    -- Respawn alerts: a minute before the window, when it opens, when it's passed
    for name, t in pairs(TIMED) do
        local st, lo = respawn_state(t.name, t.respawn)
        -- A minute's warning, once per kill
        if st == 'cooling' and lo <= 60 and respawn_soon[name] ~= killed[t.name] then
            respawn_soon[name] = killed[t.name]
            alert('soon', t.name .. ': window opens in 1 min')
        end
        if st == 'window' and respawn_seen[name] == 'cooling' then
            alert('respawn', t.name .. ' may be up now')
        end
        if st == 'up' and respawn_seen[name] == 'window' then
            alert('up', t.name .. ' should be up now')
        end
        respawn_seen[name] = st
    end

    local left = visit_left()
    if left then
        -- Under 10 minutes: leave (or extend) before it drops under 5, or you
        -- wait an hour to get back in
        local TIME_ALERTS = {
            {10, 'Under 10 min of Abyssea time: leave or extend in the next 5 min',
                 'Under 10 minutes of Abyssea time left. Leave (or extend your time) before it drops under 5 minutes: leaving with less than 5 left means waiting an hour to re-enter.'},
            {5,  'Under 5 min: leaving now means a 1-hour wait to re-enter',
                 'Under 5 minutes of Abyssea time left: if you leave now you\'ll have to wait an hour to enter again. Extend your time to avoid it.'},
        }
        for _, a in ipairs(TIME_ALERTS) do
            local m = a[1]
            if left <= m * 60 and left > 0 and not visit.warned[m] then
                visit.warned[m] = true
                alert('time', a[2])
                say(a[3])
            elseif left > m * 60 + 30 then
                visit.warned[m] = nil
            end
        end
    end

    lights_update()
end)
end

-------------------------------------------------------------------------------
-- Atma window. A separate panel (//empy atma) listing the NMs in this zone
-- that drop an Atma, and whether you have each one. Targeting an NM whose Atma
-- you don't have gives an alert.
-------------------------------------------------------------------------------
-- Its own function, so its locals don't count toward the main chunk's limit of 200
local atma_update, atma_is_shown, atma_unknown = (function()
-- NM Atmas by zone (BG Wiki, Category:Abyssea Atma): {NM name, Atma it drops}.
-- Synthetic Atmas from the Atma Fabricant aren't monster drops, so they're not here.
local ATMAS = {
    ['Abyssea - La Theine'] = {
        {'Hadhayosh', 'Atma of the Lion'},
        {'Briareus', 'Atma of the Stout Arm'},
        {'Karkinos', 'Atma of the Twin Claw'},
        {'Carabosse', 'Atma of Allure'},
        {'Ruminator', 'Atma of Eternity'},
        {'Ovni', 'Atma of the Heavens'},
        {'Lugarhoo', 'Atma of the Baying Moon'},
        {'Dozing Dorian', 'Atma of the Ebon Hoof'},
        {'Megamaw Mikey', 'Atma of Tremors'},
        {'Megantereon', 'Atma of the Savage Tiger'},
    },
    ['Abyssea - Konschtat'] = {
        {'Eccentric Eve', 'Atma of the Voracious Violet'},
        {'Bloodeye Vileberry', 'Atma of Cloak and Dagger'},
        {'Turul', 'Atma of the Stormbird'},
        {'Kukulkan', 'Atma of the Noxious Fang'},
        {'Fistule', 'Atma of Vicissitude'},
        {'Hadal Satiator', 'Atma of the Beyond'},
        {'Balaur', 'Atma of Stormbreath'},
        {'Alkonost', 'Atma of Gales'},
        {'Raskovnik', 'Atma of Thrashing Tendrils'},
        {'Khalamari', 'Atma of the Drifter'},
    },
    ['Abyssea - Tahrongi'] = {
        {'Lacovie', 'Atma of the Stronghold'},
        {'Chloris', 'Atma of the Harvester'},
        {'Glavoid', 'Atma of Dunes'},
        {'Iratham', 'Atma of the Cosmos'},
        {'Usurper', 'Atma of the Siren Shadow'},
        {'Myrmecoleon', 'Atma of the Impaler'},
        {'Chukwa', 'Atma of the Adamantine'},
        {'Adze', 'Atma of Calamity'},
        {'Cuelebre', 'Atma of the Claw'},
        {'Mictlantecuhtli', 'Atma of Baleful Bones'},
    },
    ['Abyssea - Attohwa'] = {
        {'Itzpapalotl', 'Atma of the Clawed Butterfly'},
        {'Ulhuadshi', 'Atma of the Desert Worm'},
        {'Titlacauan', 'Atma of the Undying'},
        {'Yaanei', 'Atma of the Impregnable Tower'},
        {'Smok', 'Atma of the Smoldering Sky'},
        {'Lusca', 'Atma of the Demonic Skewer'},
        {'Kampe', 'Atma of the Golden Claw'},
        {'Berstuk', 'Atma of the Glutinous Ooze'},
        {'Maahes', 'Atma of the Lightning Beast'},
        {'Nightshade', 'Atma of the Noxious Bloom'},
    },
    ['Abyssea - Misareaux'] = {
        {'Sobek', 'Atma of the Gnarled Horn'},
        {'Amhuluk', 'Atma of the Strangling Wind'},
        {'Cirein-croin', 'Atma of the Deep Devourer'},
        {'Kutharei', 'Atma of the Mounted Champion'},
        {'Ironclad Pulverizer', 'Atma of the Razed Ruins'},
        {'Tristitia', 'Atma of the Bludgeoning Brute'},
        {'Nehebkau', 'Atma of the Rapid Reptilian'},
        {'Avalerion', 'Atma of the Winged Enigma'},
        {'Karkatakam', 'Atma of the Cradle'},
        {'Nonno', 'Atma of the Untouched'},
    },
    ['Abyssea - Vunkerl'] = {
        {'Bukhis', 'Atma of the Sanguine Scythe'},
        {'Sedna', 'Atma of the Tusked Terror'},
        {'Durinn', 'Atma of the Minikin Monstrosity'},
        {'Sippoy', 'Atma of the Would-Be King'},
        {'Karkadann', 'Atma of the Blinding Horn'},
        {'Ketea', 'Atma of the Demonic Lash'},
        {'Seps', 'Atma of Apparitions'},
        {'Xan', 'Atma of the Shimmering Shell'},
        {'Chhir Batti', 'Atma of the Murky Miasma'},
        {'Hanuman', 'Atma of the Avaricious Ape'},
    },
    ['Abyssea - Altepa'] = {
        {'Rani', 'Atma of the Merciless Matriarch'},
        {'Orthrus', 'Atma of the Brother Wolf'},
        {'Dragua', 'Atma of the Earth Wyrm'},
        {'Bennu', 'Atma of the Ascending One'},
        {'Hedjedjet', 'Atma of the Scorpion Queen'},
        {'Cuijatender', 'Atma of a Thousand Needles'},
        {'Brulo', 'Atma of the Burning Effigy'},
        {'Ironclad Smiter', 'Atma of the Smiting Blow'},
        {'Amarok', 'Atma of the Lone Wolf'},
        {'Hazhdiha', 'Atma of the Crimson Scale'},
        {'Ouzelum', 'Atma of the Scarlet Wing'},
        {'Shaula', 'Atma of the Raised Tail'},
        {'Emperador de Altepa', 'Atma of the Sand Emperor'},
    },
    ['Abyssea - Uleguerand'] = {
        {'Pantokrator', 'Atma of the Omnipotent'},
        {'Apademak', 'Atma of the War Lion'},
        {'Isgebind', 'Atma of the Frozen Fetters'},
        {'Resheph', 'Atma of the Plaguebringer'},
        {'Empousa', 'Atma of the Shrieking One'},
        {'Indrik', 'Atma of the Holy Mountain'},
        {'Ogopogo', 'Atma of the Lake Lurker'},
        {'Ironclad Triturator', 'Atma of the Crushing Cudgel'},
        {'Dhorme Khimaira', 'Atma of Purgatory'},
        {'Kur', 'Atma of Blighted Breath'},
        {'Awahondo', 'Atma of the Persistent Predator'},
        {'Blanga', 'Atma of the Stone God'},
        {'Yaguarogui', 'Atma of the Sun Eater'},
    },
    ['Abyssea - Grauberg'] = {
        {'Raja', 'Atma of the Despot'},
        {'Alfard', 'Atma of the Solitary One'},
        {'Azdaja', 'Atma of the Winged Gloom'},
        {'Amphitrite', 'Atma of the Sea Daughter'},
        {'Fuath', 'Atma of the Hateful Stream'},
        {'Fleshflayer Killakriq', 'Atma of the Foe Flayer'},
        {'Maere', 'Atma of the Endless Nightmare'},
        {'Ironclad Sunderer', 'Atma of the Sundering Slash'},
        {'Ningishzida', 'Atma of Entwined Serpents'},
        {'Deelgeed', 'Atma of the Horned Beast'},
        {'Melo Melo', 'Atma of Aquatic Ardor'},
        {'Teugghia', 'Atma of the Fallen One'},
        {'Bomblix Flamefinger', 'Atma of Fires and Flares'},
    },
    ['Abyssea - Empyreal Paradox'] = {
        {'Shinryu', 'Atma of the Apocalypse'},
    },
}
local ATMA_BY_NM = {}   -- NM name -> {atma = name, zone = zone, ids = {key item ids}}
local atma_unknown = {} -- Atma names the game's key item list doesn't have
do
    -- Find each Atma's key item id by name, and list any the game's list doesn't know
    local want = {}
    for zone, list in pairs(ATMAS) do
        for _, e in ipairs(list) do
            local rec = {atma = e[2], zone = zone, ids = {}}
            ATMA_BY_NM[e[1]] = rec
            want[lc(e[2])] = rec
        end
    end
    for id, k in pairs(res.key_items) do
        local rec = want[lc(k.en)]
        if rec then rec.ids[id] = true end
    end
    for _, rec in pairs(ATMA_BY_NM) do
        if next(rec.ids) == nil then atma_unknown[#atma_unknown + 1] = rec.atma end
    end
end

-- true / false, or nil when the game's key item list doesn't know that Atma
local function has_atma(rec)
    if next(rec.ids) == nil then return nil end
    for id in pairs(rec.ids) do if last_kis[id] then return true end end
    return false
end

-- NM names that appear anywhere in the chains you're working on now
local function chain_names()
    local set = {}
    for _, g in ipairs(active_nms()) do
        if not g.later and not g.nm.material then
            set[g.nm.name] = true
            local function walk(n)
                if n.from then set[n.from] = true end
                for _, k in ipairs(n.kids or {}) do walk(k) end
            end
            for _, k in ipairs(g.nm.kids) do walk(k) end
        end
    end
    return set
end

-- The Atma window: a draggable text box with its own background
local atma_box = texts.new('', {
    pos   = {x = settings.atma.pos.x, y = settings.atma.pos.y},
    bg    = {visible = true, alpha = 200, red = 14, green = 18, blue = 26},
    text  = {font = settings.font, size = settings.size, alpha = 255, red = 230, green = 230, blue = 230,
             stroke = {width = 1, alpha = 180, red = 0, green = 0, blue = 0}},
    flags = {draggable = true},
    padding = 8,
})
fade_text(atma_box, 180)
apply_opacity()
atma_box:hide()   -- off unless you turn it on with //empy atma
-- Whether the Atma window is on screen
local atma_shown = false

-- Write the Atma window: how many of this zone's Atmas you own, your target's
-- Atma, then every Atma NM here (missing ones first, those in your chains on top)
local function atma_render()
    local zone = zone_name_now()
    local list = zone and ATMAS[zone] or {}
    local inchain = chain_names()
    local got, known = 0, 0
    for _, e in ipairs(list) do
        local h = has_atma(ATMA_BY_NM[e[1]])
        if h ~= nil then known = known + 1 end
        if h then got = got + 1 end
    end

    local L = {}
    L[#L + 1] = col(C.head, 'ATMA') .. col(C.dim, '  ' .. (zone and (zone:gsub('^Abyssea %- ', '')) or ''))
        .. '   ' .. col(got == known and C.good or C.warn, ('%d/%d owned'):format(got, known))

    -- What you're targeting, if it drops an Atma
    local t = windower.ffxi.get_mob_by_target('t')
    local tr = t and ATMA_BY_NM[t.name]
    if tr then
        local h = has_atma(tr)
        L[#L + 1] = col(C.dim, 'target: ') .. col(C.text, t.name .. '  ')
            .. (h == false and col(C.bad, 'MISSING ' .. tr.atma) or col(C.good, 'Atma owned'))
    end
    L[#L + 1] = ''

    -- Missing first (NMs in your chains at the top), then owned
    local rows = {}
    for _, e in ipairs(list) do
        local h = has_atma(ATMA_BY_NM[e[1]])
        rows[#rows + 1] = {nm = e[1], atma = (e[2]:gsub('^Atma of ', '')), have = h, chain = inchain[e[1]]}
    end
    table.sort(rows, function(a, b)
        if (a.have == true) ~= (b.have == true) then return a.have ~= true end
        if (a.chain == true) ~= (b.chain == true) then return a.chain == true end
        return a.nm < b.nm
    end)
    for _, r in ipairs(rows) do
        local mark = r.have == true and col(C.good, '[x] ') or (r.have == nil and col(C.dim, '[?] ') or col(C.bad, '[ ] '))
        L[#L + 1] = mark .. col(r.have and C.dim or C.text, pad(r.nm, 22))
            .. col(r.have and C.dim or C.nm, pad(r.atma, 24))
            .. ((r.chain and not r.have) and col(C.pop, 'your chain') or '')
    end
    if #list == 0 then L[#L + 1] = col(C.dim, 'No Atma NMs in this zone') end
    L[#L + 1] = col(C.dim, '//empy atma to hide')
    atma_box:text(table.concat(L, '\n'))
end

-- Show the Atma window when it's turned on and this zone has Atma NMs, else hide it
local function atma_update()
    local info = windower.ffxi.get_info()
    local zone = zone_name_now()
    local want = settings.atma.visible and info and info.logged_in and zone and ATMAS[zone] ~= nil
    if want then
        atma_render()
        if not atma_shown then atma_box:show(); atma_shown = true end
    elseif atma_shown then
        atma_box:hide(); atma_shown = false
    end
end

-- Save the Atma window's spot after you drag it
local atma_drag
windower.register_event('mouse', function(type)
    if not atma_shown then return end
    if type == 1 then
        atma_drag = {atma_box:pos()}
    elseif type == 2 and atma_drag then
        local x, y = atma_box:pos()
        if x ~= atma_drag[1] or y ~= atma_drag[2] then
            settings.atma.pos.x, settings.atma.pos.y = x, y
            config.save(settings)
        end
        atma_drag = nil
    end
end)

-- Say so when you get an Atma this character has never had before. Each
-- character's Atmas are remembered in its save file, so reloading or logging
-- in (when the game sends key items a few at a time) doesn't list them again.
-- The first time, they're saved quietly.
local function atma_check_new()
    if next(last_kis) == nil or not char.data then return end
    local saved = {}
    for a in tostring(char.data.atmas or ''):gmatch('[^;]+') do saved[a] = true end
    local added = {}
    for _, rec in pairs(ATMA_BY_NM) do
        if has_atma(rec) and not saved[rec.atma] then
            saved[rec.atma] = true
            added[#added + 1] = rec.atma
        end
    end
    if #added == 0 then return end
    if char.data.atmas_seeded and settings.announce then
        for _, a in ipairs(added) do say('new Atma: ' .. a) end
    end
    local list = {}
    for a in pairs(saved) do list[#list + 1] = a end
    table.sort(list)
    char.data.atmas = table.concat(list, ';')
    char.data.atmas_seeded = true
    config.save(char.data, 'all')
end

-- Every frame: has the target changed? Alert for an NM whose Atma you don't
-- have (once per NM every 5 minutes). Once a second: the window and new Atmas.
local atma_target, atma_alerted, atma_wall = nil, {}, 0
windower.register_event('prerender', function()
    local t = windower.ffxi.get_mob_by_target('t')
    local name = t and t.name or nil
    if name ~= atma_target then
        atma_target = name
        local rec = name and ATMA_BY_NM[name]
        if rec and next(last_kis) ~= nil and has_atma(rec) == false and (os.time() - (atma_alerted[name] or 0)) > 300 then
            atma_alerted[name] = os.time()
            alert('atma', ('%s drops %s: you don\'t have it'):format(name, rec.atma))
            say(('%s drops %s, which you don\'t have'):format(name, rec.atma))
        end
        if atma_shown then atma_render() end
    end
    local wall = os.time()
    if wall ~= atma_wall then
        atma_wall = wall
        atma_update()
        atma_check_new()
    end
end)
    -- Hand back the update function, a way to ask whether it's showing, and the
    -- Atmas the key item list doesn't know (listed by //empy atma)
    return atma_update, function() return atma_shown end, atma_unknown
end)()

-------------------------------------------------------------------------------
-- Procs window. A separate panel (//empy procs, or the Procs button in the
-- header) listing the weapon skills that red proc in Abyssea, by element: the
-- ones you can use with your weapon now are ticked, and when the log has said
-- what your target is weak to, that element is marked.
-------------------------------------------------------------------------------
-- Its own function, so its locals don't count toward the main chunk's limit of 200
local procs_update, procs_is_shown = (function()
-- Each element's text colour
local EL_COLOR = {
    Fire = '\\cs(255,110,80)', Ice = '\\cs(140,210,255)', Wind = '\\cs(110,220,140)', Earth = '\\cs(210,170,100)',
    Lightning = '\\cs(220,140,255)', Light = '\\cs(255,245,180)', Dark = '\\cs(170,150,200)',
}

-- The Procs window: a draggable text box with its own background
local procs_box = texts.new('', {
    pos   = {x = settings.procs.pos.x, y = settings.procs.pos.y},
    bg    = {visible = true, alpha = 200, red = 14, green = 18, blue = 26},
    text  = {font = settings.font, size = settings.size, alpha = 255, red = 230, green = 230, blue = 230,
             stroke = {width = 1, alpha = 180, red = 0, green = 0, blue = 0}},
    flags = {draggable = true},
    padding = 8,
})
fade_text(procs_box, 180)
apply_opacity()
procs_box:hide()   -- off unless you turn it on
-- Whether the Procs window is on screen
local procs_shown = false

-- Write the window: your target's weakness (if known), then each element and
-- its weapon skills, ticking the ones you have now
local function procs_render()
    local mine = {}
    for _, m in ipairs(my_red_ws()) do mine[m.name] = true end
    local t, f = current_fiend()
    local weak = f and f.el or nil

    local L = {}
    L[#L + 1] = col(C.head, 'RED PROC WEAPON SKILLS')
    if t and weak then
        L[#L + 1] = col(C.dim, 'target: ') .. col(C.text, t.name) .. col(C.dim, '  weak to ')
            .. (EL_COLOR[weak] or C.text) .. weak .. '\\cr'
            .. (f.red and col(C.good, '  proc landed') or '')
    elseif t then
        L[#L + 1] = col(C.dim, 'target: ') .. col(C.text, t.name) .. col(C.dim, '  weakness not known yet')
    end
    L[#L + 1] = ''
    for _, e in ipairs(RED_WS) do
        local here = (weak == e.el)
        L[#L + 1] = (here and col(C.pop, '> ') or '  ') .. (EL_COLOR[e.el] or C.text) .. e.el .. '\\cr'
            .. (here and col(C.pop, '  <- your target') or '')
        for _, w in ipairs(e.ws) do
            local have = mine[w[1]]
            L[#L + 1] = '    ' .. (have and col(C.good, '[x] ') or col(C.dim, '[ ] '))
                .. col(have and C.good or C.text, pad(w[1], 18)) .. col(C.dim, w[2])
        end
    end
    L[#L + 1] = ''
    L[#L + 1] = col(C.dim, '[x] = usable with your weapon now')
    procs_box:text(table.concat(L, '\n'))
end

-- Show the window when it's turned on (and you're logged in), else hide it
local function procs_update()
    local info = windower.ffxi.get_info()
    local want = settings.procs.visible and info and info.logged_in
    if want then
        procs_render()
        if not procs_shown then procs_box:show(); procs_shown = true end
    elseif procs_shown then
        procs_box:hide(); procs_shown = false
    end
end

-- Save the window's spot after you drag it
local procs_drag
windower.register_event('mouse', function(type)
    if not procs_shown then return end
    if type == 1 then
        procs_drag = {procs_box:pos()}
    elseif type == 2 and procs_drag then
        local x, y = procs_box:pos()
        if x ~= procs_drag[1] or y ~= procs_drag[2] then
            settings.procs.pos.x, settings.procs.pos.y = x, y
            config.save(settings)
        end
        procs_drag = nil
    end
end)

-- Once a second: show/hide and redraw (your weapon and target change as you play)
local procs_wall = 0
windower.register_event('prerender', function()
    local wall = os.time()
    if wall ~= procs_wall then
        procs_wall = wall
        procs_update()
    end
end)

-- Hand back the update function, and a way to ask whether it's showing
return procs_update, function() return procs_shown end
end)()

-- Names you can //empy mark here: the NMs and mobs in your current chains in this zone
local function mark_names(zone)
    local out = {}
    for _, g in ipairs(active_nms()) do
        if g.nm.zone == zone then
            out[#out + 1] = g.nm.name
            local function walk(n)
                if n.from then out[#out + 1] = n.from end
                for _, k in ipairs(n.kids or {}) do walk(k) end
            end
            for _, k in ipairs(g.nm.kids) do walk(k) end
        end
    end
    return out
end

-- What //empy mark with no name means: the NEXT step's NM (or the big NM's ??? when you have every key item)
local function mark_default(zone)
    for _, g in ipairs(active_nms()) do
        if not g.later and g.nm.zone == zone and not g.nm.material then
            if g.nm.timed then return g.nm.name end
            local _, best = plan(g.nm)
            if not best then return g.nm.name end
            local s = best.steps[best.nxt]
            if s.n.state ~= 'away' then return s.n.from end
        end
    end
    return nil
end

-- Read 'on' / 'off' from a command; anything else flips the current value
local function onoff(arg, current)
    arg = lc(arg)
    if arg == 'on' then return true elseif arg == 'off' then return false end
    return not current
end

-- //empy weapons: every weapon in chat with its stage, item, NM and your count
local function print_weapons()
    say('Empyrean trials: Lv80 and Lv85 need 50 items, Lv90 needs 75')
    local picked = {}
    for _, w in ipairs(selected_weapons()) do picked[w.name] = true end
    for _, w in ipairs(WEAPONS) do
        local nm, st = current_nm(w)
        local _, manual = stage_of(w)
        if nm then
            windower.add_to_chat(207, ('  %s%-12s %-13s Lv%d%s %-26s %-12s %d/%d'):format(
                picked[w.name] and '* ' or '  ', w.name, w.kind, st, manual and '!' or ' ',
                nm.drop[1], nm.name, nm.count or 0, goal_of(nm)))
        else
            windower.add_to_chat(207, ('  %s%-12s %-13s Lv119 done'):format(picked[w.name] and '* ' or '  ', w.name, w.kind))
        end
    end
    windower.add_to_chat(207, '  (* = building, ! = stage set by hand)  //empy stage <80..119|auto> <weapon>')
end

-- Every stage of one weapon, in chat
local function print_path(w)
    local st = stage_of(w)
    say(('%s (%s): on %s'):format(w.name, w.kind, st == 'done' and 'Lv119, done' or ('the Lv' .. st .. ' stage')))
    for _, s in ipairs(STAGES) do
        local nm = NMS[w.nm[s]]
        local mark = (st == s) and '>>' or ((st == 'done' or s < st) and 'ok' or '  ')
        windower.add_to_chat(207, ('  %s Lv%d  %d %-26s %-12s %-20s %d/%d'):format(mark, s, goal_of(nm), nm.drop[1],
            nm.name, nm.zone and (nm.zone:gsub('^Abyssea %- ', '')) or 'Magian trial', nm.count or 0, goal_of(nm)))
    end
end

-- //empy chain: one NM's key items and the steps still to do, in chat
local function print_chain(nm)
    if nm.material then
        windower.add_to_chat(207, ('%s Lv%d: %d/%d  (%s)'):format(nm.name, nm.stage, nm.count or 0, goal_of(nm), nm.info[1]))
        return
    end
    windower.add_to_chat(207, ('%s Lv%d  %s ??? %s: %s %d/%d'):format(nm.name, nm.stage, nm.zone, nm_spot(nm),
        nm.drop[1], nm.count or 0, goal_of(nm)))
    if nm.timed then windower.add_to_chat(207, '  ' .. nm.timed) end
    for _, ki in ipairs(nm.kids) do
        windower.add_to_chat(207, '  ' .. ki.label .. ' (KI)' .. (ki.state == 'have' and '  owned' or ''))
        if ki.state ~= 'have' then
            local steps = flow_steps(ki, nm.name, nil, nm.vc, nm.at)
            local nxt = next_step(steps)
            for i, s in ipairs(steps) do
                local n = s.n
                local vc = vc_text(s)
                windower.add_to_chat(207, ('    %s %s %s%s > %s -> %s%s  (%s)'):format(
                    i == nxt and '>>' or ('%2d'):format(i), step_verb(n), n.from,
                    vc ~= '' and (' at ' .. vc) or '',
                    n.label, s.feeds, n.red and '  RED!!!' or '', n.state or '?'))
            end
        end
    end
end

-- //empy help [topic]. Each topic is {name, title, {{command, what it does}...}}.
-- help holds everything to do with help and command names, in one table (to keep
-- the main chunk under Lua's 200-local limit)
local help = {}
help.TOPICS = {
    {'weapons', 'Weapons and stages', {
        {'pick', 'choose your weapons in a window'},
        {'add <name|type>', 'add a weapon: add Rhongomiant, add polearm (or just //empy polearm)'},
        {'remove <name|type|all>', 'take one weapon off, or all of them'},
        {'weapons', 'all 14 weapons with stage, item, NM and your count'},
        {'stage [80..119|done|auto] [weapon]', 'show every stage, or set one by hand (auto = from your bags)'},
        {'next [weapon]', 'move a weapon (or all) to its next stage'},
        {'full [on|off]', 'also show the later stages, marked LATER'},
        {'chain', 'your NMs\' pop chains and status in chat'},
    }},
    {'window', 'The window', {
        {'show | hide | toggle', 'turn the window on or off'},
        {'min', 'minimize to the header (or click [-])'},
        {'layout [wide|tall]', 'every step, or the narrow NEXT-step window'},
        {'where [farm|abyssea|always]', 'Empyrean NM zones (default), any Abyssea zone, or everywhere'},
        {'zone [on|off]', 'only the NMs for the zone you are in'},
        {'compact [on|off]', 'hide what is under a step you already have'},
        {'red [on|off]', 'RED!!! tags on key items that need a red proc'},
        {'opacity <10-100>', 'how see-through it is (default 75)'},
        {'size <n> | pos <x> <y>', 'text size / window position'},
        {'lights [on|off]', 'the Abyssea lights window (off by default)'},
        {'atma [on|off]', 'the Atma window (off by default; or click Atma in the header)'},
        {'procs [on|off]', 'red proc weapon skills by element (or click Procs in the header)'},
    }},
    {'tracking', 'Timers and tracking', {
        {'timer', 'running respawn timers'},
        {'timer <nm> [min ago] | timer clear', 'start a timer for a kill you missed / clear them'},
        {'kills | kills reset [nm]', 'kills and drops per NM (for the estimate) / clear the log'},
        {'time [minutes|clear]', 'Abyssea time: say it, set it, or clear it'},
        {'mark [nm] | mark list | mark clear <nm>', 'save a ??? spot for distance and direction'},
        {'near [on|off|<seconds>]', 'nearest conflux (alone: say it now)'},
    }},
    {'alerts', 'Alerts', {
        {'alert', 'list the alerts and whether each is on'},
        {'alert <kind> [on|off] | alert test', 'turn one on or off / try one'},
        {'sound [on|off] | flash [on|off]', 'alert sounds / big on-screen text'},
        {'announce [on|off]', 'chat lines for new key items and counts'},
    }},
    {'general', 'General', {
        {'status', 'every setting at a glance'},
        {'refresh', 'search bags and key items now'},
        {'every <seconds>', 'how often to search (default 60, 0 = only on changes)'},
        {'goal <n>', 'items needed for every stage (0 = the real amounts)'},
        {'about | reload', 'the loading lines again / reload the addon'},
        {'debug [on|off]', 'show every defeat seen in chat (to check kills are caught)'},
    }},
}

-- Old names and short forms, so nothing you're used to stops working
help.ALIAS = {
    weapon = 'add', w = 'add', choose = 'pick', rm = 'remove', del = 'remove', clear = 'remove',
    list = 'chain', chains = 'chain', path = 'stage',
    killed = 'timer', died = 'timer', timers = 'timer', killlog = 'kills',
    minimize = 'min', tall = 'layout', wide = 'layout', alpha = 'opacity', fade = 'opacity',
    sounds = 'sound', alerts = 'alert', atmas = 'atma', proc = 'procs', redproc = 'procs', ws = 'procs', conflux = 'near', vc = 'near',
    interval = 'every', version = 'about', settings = 'status', ['?'] = 'help',
}

-- //empy help: no topic = one line per topic; a topic (or its first letters) = that
-- topic in full; 'all' = everything
function help.print(topic)
    topic = lc(topic)
    local function section(h)
        say(h[2] .. '  (//empy help ' .. h[1] .. ')')
        for _, c in ipairs(h[3]) do
            windower.add_to_chat(207, ('  %-36s %s'):format(c[1], c[2]))
        end
    end
    if topic == 'all' then
        for _, h in ipairs(help.TOPICS) do section(h) end
        return
    end
    for _, h in ipairs(help.TOPICS) do
        if topic ~= '' and h[1]:sub(1, #topic) == topic then section(h); return end
    end
    say('commands: //empy <command>   (//empy help <topic> for more)')
    for _, h in ipairs(help.TOPICS) do
        local names = {}
        for _, c in ipairs(h[3]) do names[#names + 1] = (c[1]:match('^(%S+)')) end
        windower.add_to_chat(207, ('  %-9s %s'):format(h[1], table.concat(names, ', ')))
    end
    windower.add_to_chat(207, '  help all  every command at once')
end

-- //empy status: every setting on a few lines
function help.status()
    local function o(v) return v and 'on' or 'off' end
    say(('status  (%s %s)'):format(_addon.name, _addon.version))
    windower.add_to_chat(207, ('  window %s%s, layout %s, where %s, zone only %s, opacity %d%%, size %d'):format(
        o(settings.visible), settings.minimized and ' (minimized)' or '', settings.layout, settings.show_in,
        o(settings.only_in_zone), settings.opacity, settings.size))
    windower.add_to_chat(207, ('  compact %s, red tags %s, announce %s, search every %s, goal %s'):format(
        o(settings.compact), o(settings.red_alerts), o(settings.announce),
        settings.rescan > 0 and (settings.rescan .. 's') or 'change only',
        (settings.goal_override or 0) > 0 and tostring(settings.goal_override) or 'normal'))
    windower.add_to_chat(207, ('  lights window %s, Atma window %s, Procs window %s, nearest conflux %s, sound %s, flash %s'):format(
        o(settings.lights.visible), o(settings.atma.visible), o(settings.procs.visible),
        settings.near_rate > 0 and ('every ' .. settings.near_rate .. 's') or 'off', o(settings.sounds), o(settings.flash)))
    local parts = {}
    for _, k in ipairs({'soon', 'respawn', 'up', 'atma', 'weakness', 'redproc', 'goal', 'time'}) do
        parts[#parts + 1] = k .. ' ' .. o(settings.alerts[k])
    end
    windower.add_to_chat(207, '  alerts: ' .. table.concat(parts, ', '))
    if char.data then
        windower.add_to_chat(207, ('  %s: full build %s, %d weapon%s'):format(char.name, o(char.data.full),
            #selected_weapons(), #selected_weapons() == 1 and '' or 's'))
    end
end

-- Commands that need a character loaded (they read or write its file)
help.NEEDS_LOGIN = {add = true, remove = true, stage = true, next = true, full = true, kills = true}

-- The commands, in three parts (a Lua function can only reach 60 outside
-- locals). Each returns false when the command isn't one of its own, nil when
-- it's done, or 'save' to save the settings afterwards.
local cmd_parts = {}
-- Part 1: help, weapons, the window, searching
cmd_parts[1] = function(cmd, args, rest)
    if false then
    -- //empy help [topic] and //empy status
    elseif cmd == '' or cmd == 'help' then
        help.print(args[1])
        return
    elseif cmd == 'status' then
        help.status()
        return

    -- //empy pick: the weapon picker window
    elseif cmd == 'pick' then
        refresh(); open_picker(); return
    -- //empy remove all (and the old //empy clear)
    elseif cmd == 'remove' and lc(rest) == 'all' then
        save_weapons({}); say('weapon list cleared')
        before = nil
    -- //empy add / remove <name or type>: find the one weapon meant, then add or remove it
    elseif cmd == 'add' or cmd == 'remove' then
        if rest == '' then say('//empy ' .. cmd .. ' <weapon name or type>' .. (cmd == 'remove' and ' | all' or '')
            .. ', e.g. Rhongomiant or polearm') return end
        -- No match, or more than one: say so and stop
        local matches, how = find_weapons(rest)
        if #matches == 0 then
            say('no weapon matches "' .. rest .. '"; try a name (Redemption) or a type (scythe). //empy weapons lists them')
            return
        elseif #matches > 1 then
            local names = {}
            for _, x in ipairs(matches) do names[#names + 1] = x.name .. ' (' .. x.kind .. ')' end
            say('"' .. rest .. '" could be ' .. table.concat(names, ', ') .. '; be more specific')
            return
        end
        -- Say how a type or a typo was read
        local w = matches[1]
        if how == 'spelling' then say('taking "' .. rest .. '" as ' .. w.name) end
        if how == 'type' then say(w.kind .. ' is ' .. w.name) end
        -- Is it on the list already?
        local list, found = selected_weapons(), nil
        for i, x in ipairs(list) do if x.name == w.name then found = i end end
        -- Add it (and say what its current stage needs), or remove it
        if cmd == 'add' then
            if found then say(w.name .. ' is already on the list') return end
            list[#list + 1] = w
            local nm, st = current_nm(w)
            if nm then
                say(('added %s (Lv%d stage): %d %s from %s'):format(w.name, st, goal_of(nm), nm.drop[1], source_of(nm)))
            else
                say(('added %s: it is already Lv119, done'):format(w.name))
            end
            local info = windower.ffxi.get_info()
            if info and not window_zone_ok(info.zone) then
                say('the window appears when you enter Abyssea; //empy weapons shows your counts anywhere')
            end
        else
            if not found then say(w.name .. ' is not on the list') return end
            table.remove(list, found)
            say('removed ' .. w.name)
        end
        -- Save, and don't announce what was already there as new
        save_weapons(list)
        before = nil

    -- //empy weapons: list all 14
    elseif cmd == 'weapons' then refresh(); print_weapons(); return
    -- //empy where farm | abyssea | always
    elseif cmd == 'where' then
        local v = lc(args[1])
        if v == 'farm' or v == 'abyssea' or v == 'always' then
            settings.show_in = v
            say(({farm = 'window shows only in the nine Abyssea zones with Empyrean NMs',
                  abyssea = 'window shows in any Abyssea zone',
                  always = 'window shows everywhere'})[v])
        else
            say('where farm | abyssea | always  (now: ' .. settings.show_in .. ')')
            return
        end
    -- //empy show / hide / toggle
    elseif cmd == 'show' or cmd == 'hide' or cmd == 'toggle' then
        if cmd == 'toggle' then settings.visible = not settings.visible else settings.visible = (cmd == 'show') end
        say('window ' .. (settings.visible and 'on' or 'off'))
        local info = windower.ffxi.get_info()
        if settings.visible and info and not window_zone_ok(info.zone) then
            say('it appears when you enter Abyssea (//empy where always to show it everywhere)')
        end
    -- //empy min: minimize to the header, or restore
    elseif cmd == 'min' then
        settings.minimized = onoff(args[1], settings.minimized); set_visible(shown)
        say(settings.minimized and 'window minimized' or 'window restored')
    -- On/off settings: compact steps, RED!!! tags, this zone's NMs only, chat announcements
    elseif cmd == 'compact' then settings.compact = onoff(args[1], settings.compact); say('compact ' .. (settings.compact and 'on' or 'off'))
    elseif cmd == 'red' then settings.red_alerts = onoff(args[1], settings.red_alerts); say('red proc alerts ' .. (settings.red_alerts and 'on' or 'off'))
    elseif cmd == 'zone' then settings.only_in_zone = onoff(args[1], settings.only_in_zone); say('only this zone\'s NMs ' .. (settings.only_in_zone and 'on' or 'off'))
    elseif cmd == 'announce' then settings.announce = onoff(args[1], settings.announce); say('announce ' .. (settings.announce and 'on' or 'off'))
    -- //empy every <seconds>: how often bags are searched
    elseif cmd == 'every' then
        if not tonumber(args[1]) then say('every <seconds>  (now: ' .. settings.rescan .. ', 0 = only on changes)') return end
        settings.rescan = math.max(0, math.floor(tonumber(args[1])))
        say(settings.rescan > 0 and ('searching every ' .. settings.rescan .. 's (and on every change)')
            or 'timed search off (still searches on every change)')
    -- //empy goal <n>: one goal for every stage (0 = the real amounts)
    elseif cmd == 'goal' then
        if not tonumber(args[1]) then
            say('goal <n>  (now: ' .. (((settings.goal_override or 0) > 0) and settings.goal_override or 'the real amounts') .. ', 0 = the real amounts)')
            return
        end
        settings.goal_override = math.max(0, math.floor(tonumber(args[1])))
        say(settings.goal_override > 0 and ('goal ' .. settings.goal_override .. ' for every stage')
            or 'goal back to the real amount for each stage')
    else return false end
    return 'save'
end

-- Part 2: kill log, timers, stages, about and reload
cmd_parts[2] = function(cmd, args, rest)
    if false then
    -- //empy kills [reset [nm]]
    elseif cmd == 'kills' then
        -- //empy kills: kills and drops per NM;  //empy kills reset [nm]
        -- Reset all of it, or one NM (by its name or the start of it)
        if lc(args[1]) == 'reset' or lc(args[1]) == 'clear' then
            local which = lc(table.concat(args, ' ', 2))
            if which == '' then
                char.data.killlog = ''
                config.save(char.data, 'all')
                session_kills, last_kill_at = {}, {}
                say('kill log cleared')
            else
                local map, hit = killlog(), nil
                for key in pairs(map) do
                    if lc(NMS[key] and NMS[key].name or key):sub(1, #which) == which then hit = key end
                end
                if not hit then say('no kills logged for ' .. which); return end
                map[hit] = nil
                save_killlog(map)
                session_kills[hit], last_kill_at[hit] = nil, nil
                say('kill log cleared for ' .. NMS[hit].name)
            end
            render()
            return
        end
        -- List each NM's kills, drops, drops per kill and this session's kills
        local map, any = killlog(), false
        for _, key in ipairs(NM_ORDER) do
            local v = map[key]
            if v then
                any = true
                local rate = v.kills > 0 and v.items / v.kills or 0
                local ses = session_kills[key] and #session_kills[key] or 0
                windower.add_to_chat(207, ('  %-12s %4d kills  %4d %s  %.2f per kill%s'):format(NMS[key].name, v.kills,
                    v.items, NMS[key].drop[1], rate, ses > 0 and ('  (' .. ses .. ' this session)') or ''))
            end
        end
        if not any then say('no kills logged yet: kill a stage NM (Chloris, Glavoid...) and it counts here') end
    -- //empy timer [<nm> [minutes ago] | clear]
    elseif cmd == 'timer' then
        -- //empy timer: running timers;  //empy timer chukwa [minutes ago];  //empy timer clear
        if lc(args[1]) == 'clear' then killed = {}; say('respawn timers cleared'); render(); return end
        -- No arguments: list the timers running
        if rest == '' then
            local any = false
            for _, t in pairs(TIMED) do
                local st, lo, hi = respawn_state(t.name, t.respawn)
                if st then
                    any = true
                    windower.add_to_chat(207, ('  %-14s %s'):format(t.name,
                        st == 'cooling' and ('respawns in %d-%d min'):format(mins(lo), mins(hi))
                        or st == 'window' and ('window open (closes in %d min)'):format(mins(hi)) or 'should be up'))
                end
            end
            if not any then say('no respawn timers running') end
            windower.add_to_chat(207, '  //empy timer <nm> [min ago]  start one   //empy timer clear  clear them')
            return
        end
        -- A number at the end is how long ago it died; the rest is the NM's name (or its start)
        local ago = tonumber(args[#args])
        local name = lc(table.concat(args, ' ', 1, ago and (#args - 1) or #args))
        local hit
        for low, t in pairs(TIMED) do
            if name ~= '' and low:sub(1, #name) == name then hit = t end
        end
        -- Not a timed NM: list the ones there are
        if not hit then
            local names = {}
            for _, t in pairs(TIMED) do names[#names + 1] = t.name end
            table.sort(names)
            say('timer <nm> [minutes ago], nm = ' .. table.concat(names, ', '))
            return
        end
        -- Start the timer from the time it died
        killed[hit.name] = os.time() - math.floor((ago or 0) * 60)
        local st, lo, hi = respawn_state(hit.name, hit.respawn)
        say(('%s respawn timer started: %s'):format(hit.name,
            st == 'cooling' and ('respawns in %d-%d min'):format(mins(lo), mins(hi))
            or st == 'window' and 'window open now' or 'should be up'))
        render()
        return
    -- //empy stage [level] [weapon] and //empy next [weapon]
    elseif cmd == 'stage' or cmd == 'next' then
        -- Which weapons: one named at the end, or "all" / nothing = every weapon you're building
        local a = {}
        for _, v in ipairs(args) do a[#a + 1] = v end
        local value
        -- //empy stage takes a level (80 ... 119, done or auto) as its first word
        if cmd == 'stage' and a[1] then
            local v = lc(a[1])
            if NEXT_STAGE[tonumber(v) or 0] or v == '119' then value = tonumber(v)
            elseif v == 'done' or v == 'auto' then value = v end
            if value then table.remove(a, 1) end
        end
        -- What's left names the weapon; nothing (or 'all') means every weapon you're building
        local q = table.concat(a, ' ')
        local targets = {}
        if q == '' or lc(q) == 'all' then
            targets = selected_weapons()
        else
            local m = find_weapons(q)
            if #m ~= 1 then
                say(#m == 0 and ('no weapon matches "' .. q .. '"') or ('"' .. q .. '" could be more than one weapon; be more specific'))
                return
            end
            targets = m
        end
        if #targets == 0 then say('no weapons picked; //empy add <weapon>') return end

        -- No level: print each weapon's path through the stages
        if cmd == 'stage' and not value then
            refresh()
            for _, w in ipairs(targets) do print_path(w) end
            windower.add_to_chat(207, '  //empy stage <80|85|90|95|99|119|done|auto> [weapon]   //empy next [weapon]   //empy full')
            return
        end

        -- Set the stage (next: the one after its current stage) and say what it needs now
        for _, w in ipairs(targets) do
            local v = value
            if cmd == 'next' then v = stage_after((stage_of(w))) end
            set_stage(w, (v ~= 'auto') and v or nil)
            local st, manual = stage_of(w)
            if st == 'done' then
                say(w.name .. ': Lv119, done')
            else
                local nm = NMS[w.nm[st]]
                say(('%s: Lv%d stage%s, %d %s from %s'):format(w.name, st, manual and '' or ' (from your bags)',
                    goal_of(nm), nm.drop[1], source_of(nm)))
            end
        end
        before = nil
    -- //empy full: also show each weapon's later stages
    elseif cmd == 'full' then
        char.data.full = onoff(args[1], char.data.full == true)
        config.save(char.data, 'all')
        say(char.data.full and 'full build: also showing the Lv85 and Lv90 NMs still ahead (short, marked LATER)'
            or 'showing only the stage each weapon is on')
    -- //empy about: the loading lines again
    elseif cmd == 'about' then
        load_echo()
        return
    -- //empy debug [on|off]: echo every defeat seen, to check kills are being caught
    elseif cmd == 'debug' then
        dbg.on = onoff(args[1], dbg.on)
        say('debug ' .. (dbg.on and 'on: defeats seen will show in chat (//empy debug off to stop)' or 'off'))
        return
    -- //empy reload: reload the addon
    elseif cmd == 'reload' then
        -- Reload the addon itself (picks up a new version you copied in)
        say('reloading...')
        config.save(settings)
        windower.send_command('lua reload ' .. _addon.name)
        return
    else return false end
    return 'save'
end

-- Part 3: the extra windows, Abyssea time, marks, alerts, layout and display
cmd_parts[3] = function(cmd, args, rest)
    if false then
    -- //empy atma [on|off]: the Atma window
    elseif cmd == 'atma' then
        settings.atma.visible = onoff(args[1], settings.atma.visible)
        config.save(settings)
        say(settings.atma.visible and 'Atma window on (it shows in the Abyssea zones)' or 'Atma window off')
        atma_update()
        if settings.atma.visible and not atma_is_shown() then say('you are not in an Abyssea zone right now; it will appear when you are') end
        if #atma_unknown > 0 then
            windower.add_to_chat(167, '[EmpyBuilder] Atma names not found in the key item list: ' .. table.concat(atma_unknown, ', '))
        end
        return
    -- //empy procs [on|off]: the red proc weapon skill window
    elseif cmd == 'procs' then
        settings.procs.visible = onoff(args[1], settings.procs.visible)
        config.save(settings)
        say(settings.procs.visible and 'Procs window on' or 'Procs window off')
        procs_update()
        return
    -- //empy lights [on|off]: the lights window
    elseif cmd == 'lights' then
        settings.lights.visible = onoff(args[1], settings.lights.visible)
        config.save(settings)
        say(settings.lights.visible and 'lights window on (it shows while you are in Abyssea)' or 'lights window off')
        lights_update()
        if settings.lights.visible and not lights_is_shown() then say('you are not in Abyssea right now; it will appear when you are') end
        return
    -- //empy time [minutes | clear]: Abyssea time
    elseif cmd == 'time' then
        -- //empy time 45: set the Abyssea clock by hand; //empy time clear
        local a = lc(args[1])
        if a == 'clear' or a == 'off' then
            visit.ends, visit.warned = nil, {}
            say('Abyssea time cleared')
        elseif tonumber(a) then
            visit.ends, visit.warned = os.time() + math.floor(tonumber(a) * 60), {}
            say(('Abyssea time set: %d minutes left'):format(tonumber(a)))
        else
            local left = visit_left()
            say(left and ('Abyssea time left: about %d min (from the last "visitant status" line)'):format(math.ceil(left / 60))
                or 'Abyssea time not known yet: it shows after the game\'s next "visitant status" line, or //empy time <minutes>')
            return
        end
        render()
        return
    -- //empy mark [nm] | mark list | mark clear <nm>
    elseif cmd == 'mark' then
        -- //empy mark [name] | mark list | mark clear <name>
        local zone = zone_name_now()
        local me = windower.ffxi.get_mob_by_target('me')
        local sub = lc(args[1])
        -- mark list: every mark, with how far and which way for this zone's
        if sub == 'list' then
            local n = 0
            for key, p in pairs(marks) do
                local z, name = key:match('^(.-)|(.*)$')
                windower.add_to_chat(207, ('  %s  %s  (%.0f, %.0f)%s'):format(name, z, p[1], p[2],
                    z == zone and ('  ' .. (mark_dir(z, name) or '')) or ''))
                n = n + 1
            end
            if n == 0 then say('no marks yet: stand at a ??? and //empy mark') end
            return
        end
        if not zone or not abyssea_zone_ids[(windower.ffxi.get_info() or {}).zone] then say('marks are for the Abyssea zones') return end
        -- Which NM or mob: the name given (or its start), or the NEXT step's when none is
        local clear = (sub == 'clear' or sub == 'delete')
        local q = lc(table.concat(args, ' ', clear and 2 or 1))
        local name
        if q == '' then
            name = mark_default(zone)
            if not name then say('nothing to mark here: //empy mark <NM name>') return end
        else
            local hits, seen = {}, {}
            for _, nmn in ipairs(mark_names(zone)) do
                if lc(nmn):sub(1, #q) == q and not seen[nmn] then seen[nmn] = true; hits[#hits + 1] = nmn end
            end
            if #hits ~= 1 then
                say(#hits == 0 and ('"' .. q .. '" is not in your chains in this zone') or ('"' .. q .. '" could be ' .. table.concat(hits, ', ')))
                return
            end
            name = hits[1]
        end
        -- Save the spot where you stand (or clear it)
        if clear then
            marks[zone .. '|' .. name] = nil
            say('mark cleared: ' .. name)
        else
            if not me or not me.x then return end
            marks[zone .. '|' .. name] = {me.x, me.y}
            say(('marked %s here (%.0f, %.0f); its steps now show how far and which way'):format(name, me.x, me.y))
        end
        save_marks()
        render()
        return
    -- //empy sound / flash [on|off]: alert sounds and on-screen text
    elseif cmd == 'sound' then
        settings.sounds = onoff(args[1], settings.sounds)
        say('alert sounds ' .. (settings.sounds and 'on' or 'off'))
    elseif cmd == 'flash' then
        settings.flash = onoff(args[1], settings.flash)
        say('on-screen alerts ' .. (settings.flash and 'on' or 'off'))
    -- //empy alert [<kind> [on|off] | test]
    elseif cmd == 'alert' then
        -- //empy alert: list | alert <kind> on|off | alert test
        local kind = lc(args[1])
        -- alert test plays one; an unknown kind (or none) lists them; else turn that kind on/off
        if kind == 'test' then alert('test', 'EmpyBuilder alert test'); return end
        if settings.alerts[kind] == nil then
            local parts = {}
            for _, k in ipairs({'soon', 'respawn', 'up', 'atma', 'weakness', 'redproc', 'goal', 'time'}) do
                parts[#parts + 1] = k .. (settings.alerts[k] and ' on' or ' off')
            end
            say('alerts: ' .. table.concat(parts, ', ') .. '  (sound ' .. (settings.sounds and 'on' or 'off')
                .. ', flash ' .. (settings.flash and 'on' or 'off') .. ')')
            windower.add_to_chat(207, '  //empy alert <kind> [on|off]   //empy alert test   //empy sound [on|off]   //empy flash [on|off]')
            return
        end
        settings.alerts[kind] = onoff(args[2], settings.alerts[kind])
        say(kind .. ' alert ' .. (settings.alerts[kind] and 'on' or 'off'))
    -- //empy layout [wide|tall] (also //empy wide, //empy tall)
    elseif cmd == 'layout' then
        local v = lc(args[1])
        if v == '' or v == 'toggle' then v = (settings.layout == 'tall') and 'wide' or 'tall' end
        if v ~= 'tall' and v ~= 'wide' then say('layout wide | tall  (now: ' .. settings.layout .. ')') return end
        settings.layout = v
        say(v == 'tall' and 'tall layout: the NEXT step, one line per key item, click one for its steps'
            or 'wide layout: every step for every key item')
        set_visible(shown)
        render()
    -- //empy near [on|off|<seconds>]: the nearest conflux
    elseif cmd == 'near' then
        local a = lc(args[1])
        -- off / on / a number of seconds; nothing says the nearest conflux now
        if a == 'off' then
            settings.near_rate = 0; say('nearest conflux off')
        elseif a == 'on' then
            settings.near_rate = (settings.near_rate > 0) and settings.near_rate or 3
            say('nearest conflux on, checked every ' .. settings.near_rate .. 's')
        elseif tonumber(a) then
            settings.near_rate = math.max(0, math.floor(tonumber(a)))
            say(settings.near_rate > 0 and ('nearest conflux checked every ' .. settings.near_rate .. 's') or 'nearest conflux off')
        else
            update_near()
            if near.n then
                say(('nearest Veridical Conflux: #%d, %d yalms away (%s)'):format(near.n, math.floor(near.dist + 0.5), near.zone))
            else
                say('not in an Abyssea zone with Empyrean NMs')
            end
            if shown then render() end
            return
        end
    -- //empy opacity <10-100>
    elseif cmd == 'opacity' then
        local v = tonumber((args[1] or ''):match('^(%d+)'))
        if not v then say('opacity ' .. settings.opacity .. '%  (//empy opacity <10-100>)') return end
        settings.opacity = math.max(10, math.min(100, math.floor(v)))
        apply_opacity()
        say('opacity ' .. settings.opacity .. '%')
    -- //empy size <n> and //empy pos <x> <y>
    elseif cmd == 'size' then
        if not tonumber(args[1]) then say('size <n>  (now: ' .. settings.size .. ')') return end
        settings.size = tonumber(args[1]); title:size(settings.size); body:size(settings.size); hdr_btns.size(settings.size)
        say('text size ' .. settings.size)
    elseif cmd == 'pos' then
        if not (tonumber(args[1]) and tonumber(args[2])) then
            say(('pos <x> <y>  (now: %d %d; you can also drag the window)'):format(settings.window.pos.x, settings.window.pos.y))
            return
        end
        settings.window.pos.x, settings.window.pos.y = tonumber(args[1]), tonumber(args[2])
        say(('window moved to %d, %d'):format(settings.window.pos.x, settings.window.pos.y))
    -- //empy chain: your NMs' chains in chat
    elseif cmd == 'chain' then
        refresh()
        local groups = active_nms()
        if #groups == 0 then say('no weapons picked; //empy add <weapon>') end
        for _, g in ipairs(groups) do print_chain(g.nm) end
        return
    -- //empy refresh: search bags and key items now
    elseif cmd == 'refresh' then
        refresh(); say('searched bags and key items'); return
    else return false end
    return 'save'
end

-- //empy <command> [args]: turn old names and short forms into the current command,
-- check it needs no login it doesn't have, then try each part in turn
windower.register_event('addon command', function(cmd, ...)
    -- args: the words after the command; rest: them joined; typed: the command as typed
    local args = {...}
    local rest = table.concat(args, ' ')
    cmd = lc(cmd)
    local typed = cmd

    -- //empy weapon <name or type> adds it; //empy weapon on its own lists them
    if (cmd == 'weapon' or cmd == 'w') and rest == '' then cmd = 'weapons' end
    if cmd == 'weapons' and rest ~= '' then cmd = 'add' end
    -- //empy clear (old) = remove all
    if cmd == 'clear' then rest = 'all' end
    -- //empy tall / //empy wide
    if cmd == 'tall' or cmd == 'wide' then args = {cmd} end
    cmd = help.ALIAS[cmd] or cmd

    if help.NEEDS_LOGIN[cmd] and not char.data then say('log in first'); return end

    -- Each part returns false if the command isn't its own, so try the next
    local r = false
    for _, f in ipairs(cmd_parts) do
        r = f(cmd, args, rest)
        if r ~= false then break end
    end
    -- nil: done (nothing to save); false: no part knew it; 'save': save the settings
    if r == nil then return end
    if r == false then
        -- //empy <weapon name or type> as a shortcut for add
        local q = typed .. (rest ~= '' and (' ' .. rest) or '')
        local w = find_weapon(q)
        if w then
            windower.send_command('empy add ' .. q)
            return
        end
        -- Suggest commands that start the same way
        local hits, seen = {}, {}
        for _, h in ipairs(help.TOPICS) do
            for _, c in ipairs(h[3]) do
                -- the command names: the first word, and the first word after each " | "
                for part in (c[1] .. ' | '):gmatch('(.-) | ') do
                    local name = part:match('^(%a+)')
                    if name and not seen[name] and #typed >= 2 and name:sub(1, #typed) == typed then
                        seen[name] = true; hits[#hits + 1] = name
                    end
                end
            end
        end
        say('unknown command "' .. typed .. '"' .. (#hits > 0 and ('; did you mean ' .. table.concat(hits, ', ') .. '?') or '')
            .. '  //empy help lists them')
        return
    end
    -- A setting changed: save it, keep the window hidden if it was turned off, and redraw
    config.save(settings)
    if not settings.visible then set_visible(false) end
    mark()
end)

-- When the addon loads: list any item or key item name the game's lists don't have
-- (a spelling to fix), then load the character if you're already logged in
windower.register_event('load', function()
    local missing = {}
    local function walk(n)
        if n.ids and next(n.ids) == nil then missing[#missing + 1] = n.label end
        for _, k in ipairs(n.kids or {}) do walk(k) end
    end
    for _, key in ipairs(NM_ORDER) do
        local nm = NMS[key]
        if next(nm.drop_node.ids) == nil then missing[#missing + 1] = nm.drop[1] end
        walk(nm)
    end
    if #missing > 0 then
        windower.add_to_chat(167, '[EmpyBuilder] Not found in the item list (check spelling): ' .. table.concat(missing, ', '))
    end
    local player = windower.ffxi.get_player()
    if player and player.name then
        on_character(player.name)
    else
        load_echo()   -- not logged in yet: just the author line
    end
    mark()
end)
