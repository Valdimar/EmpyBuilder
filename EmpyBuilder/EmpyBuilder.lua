--[[
EmpyBuilder: a display window for building the Empyrean weapons, Lv80 to Lv119.

Each Lv80 trial needs 50 of one Abyssea NM's drop. Pick the weapon(s) you're
building and the window shows how many of that item you have (13 / 50) and the
NM's whole pop chain, checked against your bags and key items. Key items that
only drop for sure on a red proc are flagged RED!!!.

  //empy help    (or //empybuilder)
]]

_addon.name     = 'EmpyBuilder'
_addon.author   = 'Valdimar @ Phoenix'
_addon.version  = '1.9'
_addon.commands = {'empy', 'empybuilder'}

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
        respawn  = true,    -- a timed NM's respawn window opens
        weakness = true,    -- the log names your target's weakness
        redproc  = true,    -- a red proc lands
        goal     = true,    -- you reach 50 / 75 of an item
        time     = true,    -- 10 and 5 minutes of Abyssea time left
    },
    lights = {              -- the separate lights window
        visible = false,
        pos     = {x = 60, y = 300},
    },
    visible      = true,
}
local settings = config.load(defaults)

-------------------------------------------------------------------------------
-- Data: the six Lv80 NMs and their pop chains
--   ki   = key item              item = accepted names (short / long)
--   from = what drops it         at   = map position
--   vc   = Veridical Conflux nearest `from` (from the BG Wiki farming flowcharts;
--          left out where the wiki gives none, and the NM it feeds is used with ~)
--   red  = needs a red proc      kids = what pops the NM in `from`
-------------------------------------------------------------------------------
local NMS = {
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
    dragua = {
        name = 'Dragua', zone = 'Abyssea - Altepa', at = '(G-9)', vc = 4, stage = 90,
        drop = {"Dragua's Scale", 'Dragua Scale'},
        kids = {
            { ki = 'Bloodied dragon ear', from = 'Hazhdiha', at = '(G/H-9/10)', vc = 4, red = true,
              note = 'timed', respawn = {10, 15} },
        },
    },

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

    isgebind = {
        name = 'Isgebind', zone = 'Abyssea - Uleguerand', at = '(I-5)', vc = 6, stage = 90,
        drop = {"Isgebind's Heart", 'Isgebind Heart'},
        kids = {
            { ki = 'Begrimed dragon hide', from = 'Kur', at = '(I/J-5)', vc = 6, red = true,
              note = 'lottery', hint = 'free spawn among Adasaurus' },
        },
    },

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
NMS.heavymetal = {
    name = 'Heavy Metal', material = true, stage = 95, goal = 1500,
    drop = {'Heavy Metal'}, kids = {},
    info = {'From Ambuscade (Gorpa-Masorpa, Mhaura G-9) and Voidwatch', 'Riftworn Pyxis (Kaggen, Akvan, Pil, Botulus Rex...)',
            'Trade at a Trial of the Magians moogle'},
}
NMS.riftcinder = {
    name = 'Riftcinder', material = true, stage = 99, goal = 60,
    drop = {'Riftcinder'}, kids = {},
    info = {'From Voidwatch Riftworn Pyxis', 'Trade at a Trial of the Magians moogle'},
}
NMS.riftdross = {
    name = 'Riftdross', material = true, stage = 99, goal = 60,
    drop = {'Riftdross'}, kids = {},
    info = {'From Voidwatch Riftworn Pyxis', 'Trade at a Trial of the Magians moogle'},
}
NMS.boulder = {
    name = 'Riftborn Boulder', material = true, stage = 119, goal = 300,
    drop = {'Riftborn Boulder', 'Riftborn Bldr.'}, kids = {},
    info = {'From Voidwatch Riftworn Pyxis', 'Upgrades the Lv99 weapon to Lv119'},
}

local NM_ORDER = {'chloris', 'glavoid', 'briareus', 'carabosse', 'kukulkan', 'fistule',
                  'ulhuadshi', 'itzpapalotl', 'sobek', 'cireincroin', 'sedna', 'bukhis',
                  'dragua', 'orthrus', 'apademak', 'isgebind', 'alfard', 'azdaja',
                  'heavymetal', 'riftcinder', 'riftdross', 'boulder'}

-- Stage defaults: the six Lv80 NMs have no stage field
local STAGES = {80, 85, 90, 95, 99, 119}
local STAGE_GOAL = {[80] = 50, [85] = 50, [90] = 75}
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

-- Each weapon's NM at each stage: Lv80 (50), Lv85 (50), Lv90 (75)
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
local function lc(s) return s and s:lower() or '' end
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
    q = lc(q):gsub('^%s+', ''):gsub('%s+$', ''):gsub('%s+', ' ')
    if q == '' then return {}, nil end
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

local function load_character(name)
    if not name or name == '' then return false end
    if char.name == name and char.data then return true end
    char.name = name
    -- stages: "Redemption=85,Twashtar=auto"; full: also show the later stages
    char.data = config.load('data/' .. name .. '.xml', {weapons = '', picked = false, stages = '', full = false})
    -- One-time move from the old shared list (EmpyBuilder 2.0/2.1)
    if char.data.weapons == '' and (settings.weapons or '') ~= '' then
        char.data.weapons, char.data.picked = settings.weapons, true
        config.save(char.data, 'all')
    end
    return true
end

local function selected_weapons()
    local list = {}
    if not char.data then return list end
    for name in tostring(char.data.weapons or ''):gmatch('[^,]+') do
        local w = find_weapon(name:match('^%s*(.-)%s*$'))
        if w then list[#list + 1] = w end
    end
    return list
end

local function save_weapons(list)
    if not char.data then return end
    local names = {}
    for _, w in ipairs(list) do names[#names + 1] = w.name end
    char.data.weapons = table.concat(names, ',')
    char.data.picked = true
    config.save(char.data, 'all')
end

-------------------------------------------------------------------------------
-- Stages. Each weapon is built Lv80 -> 85 -> 90. The stage you're on comes
-- from the highest-level copy of the weapon in your bags (none: Lv80, a Lv80
-- one: Lv85, a Lv85 one: Lv90, Lv90 or above: done), unless you set it with
-- //empy stage.
-------------------------------------------------------------------------------
local detected = {}   -- weapon name -> stage worked out from your bags

local function stage_overrides()
    local map = {}
    if not char.data then return map end
    for name, v in tostring(char.data.stages or ''):gmatch('([^,=]+)=([^,]+)') do
        map[name] = tonumber(v) or v
    end
    return map
end

local function set_stage(w, v)   -- v: 80 | 85 | 90 | 'done' | nil (auto)
    if not char.data then return end
    local map = stage_overrides()
    map[w.name] = v
    local parts = {}
    for name, val in pairs(map) do parts[#parts + 1] = name .. '=' .. tostring(val) end
    table.sort(parts)
    char.data.stages = table.concat(parts, ',')
    config.save(char.data, 'all')
end

-- 80 | 85 | 90 | 'done', and whether it was set by hand
local function stage_of(w)
    local o = stage_overrides()[w.name]
    if o then return o, true end
    return detected[w.name] or 80, false
end

local NEXT_STAGE = {[80] = 85, [85] = 90, [90] = 95, [95] = 99, [99] = 119}
local function stage_after(st)
    return NEXT_STAGE[st] or 'done'
end

local function full_mode() return char.data and char.data.full == true end

-------------------------------------------------------------------------------
-- Name -> ID lookup, done once
-------------------------------------------------------------------------------
local zone_ids = {}

local function resolve()
    local want_items, want_kis = {}, {}
    local function want(list, n)
        for _, nm in ipairs(list) do
            want_items[lc(nm)] = want_items[lc(nm)] or {}
            table.insert(want_items[lc(nm)], n)
        end
    end
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

    for id, it in pairs(res.items) do
        for _, key in ipairs({lc(it.en), lc(it.enl)}) do
            for _, n in ipairs(want_items[key] or {}) do n.ids[id] = true end
        end
        local w = weapon_by_name[lc(it.en)]
        -- Lv119 copies report level 99 with an item level of 119
        if w and it.level then w.ids[id] = math.max(it.level, it.item_level or 0) end
    end
    for id, k in pairs(res.key_items) do
        local n = want_kis[lc(k.en)]
        if n then n.ids[id] = true end
    end
    for id, z in pairs(res.zones) do zone_ids[z.en] = id end
end
resolve()

-------------------------------------------------------------------------------
-- The window: border, panel, header strip (prims), then two text objects
-------------------------------------------------------------------------------
local P = {border = 'empybuilder_border', bg = 'empybuilder_bg', head = 'empybuilder_head', line = 'empybuilder_line'}

-- Every rectangle's full-strength colour, so opacity can be changed and changed back
local RECT_BASE = {}

local function opacity_factor()
    return math.max(0.1, math.min(1, (tonumber(settings.opacity) or 100) / 100))
end

local function color_rect(name)
    local c = RECT_BASE[name]
    windower.prim.set_color(name, math.floor(c.alpha * opacity_factor() + 0.5), c.red, c.green, c.blue)
end

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

local function apply_opacity()
    local f = opacity_factor()
    for name in pairs(RECT_BASE) do color_rect(name) end
    for _, e in ipairs(FADE_TEXTS) do
        e.t:alpha(math.floor(255 * f + 0.5))
        e.t:stroke_alpha(math.floor(e.stroke * f + 0.5))
    end
end
make_rect(P.border, settings.window.border)
make_rect(P.bg,     settings.window.bg)
make_rect(P.head,   settings.window.header)
make_rect(P.line,   settings.window.border)

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
local title = texts.new('', text_settings(true))
local body  = texts.new('', text_settings(false))
fade_text(title, 180)
fade_text(body, 180)
apply_opacity()

-------------------------------------------------------------------------------
-- Alerts: a sound (sounds/*.wav) and a big line of text at the top of the
-- screen for a few seconds. Each kind can be turned off with //empy alert.
-------------------------------------------------------------------------------
local ALERT_SOUND = {respawn = 'chime.wav', weakness = 'chime.wav', redproc = 'success.wav',
                     goal = 'success.wav', time = 'alert.wav', test = 'chime.wav'}
local ALERT_COLOR = {respawn = '\\cs(110,200,245)', weakness = '\\cs(255,205,110)', redproc = '\\cs(110,220,110)',
                     goal = '\\cs(110,220,110)', time = '\\cs(255,90,90)', test = '\\cs(255,205,110)'}

local flash_box = texts.new('', {
    pos   = {x = 0, y = 0},
    bg    = {visible = true, alpha = 170, red = 10, green = 12, blue = 18},
    text  = {font = settings.font, size = settings.size + 8, alpha = 255, red = 230, green = 230, blue = 230,
             stroke = {width = 2, alpha = 220, red = 0, green = 0, blue = 0}},
    flags = {draggable = false, bold = true},
    padding = 8,
})
flash_box:hide()
local flash_until = 0

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

local shown = false
local function set_visible(on)
    shown = on
    for _, name in pairs(P) do windower.prim.set_visibility(name, on) end
    if on then title:show() else title:hide() end
    local open = on and not settings.minimized
    if open and settings.layout ~= 'tall' then body:show() else body:hide() end
    tall_show(open and settings.layout == 'tall')
end

local layout = {head_h = 22}
local function expected()
    local x, y, pad = settings.window.pos.x, settings.window.pos.y, settings.window.padding
    return x + pad, y + 4, x + pad, y + layout.head_h + 6
end

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

    local w = math.max(tw, settings.minimized and 0 or bw) + pad * 2
    local h = layout.head_h + (settings.minimized and 0 or (bh + 12))

    windower.prim.set_position(P.border, x - 1, y - 1); windower.prim.set_size(P.border, w + 2, h + 2)
    windower.prim.set_position(P.bg, x, y);             windower.prim.set_size(P.bg, w, h)
    windower.prim.set_position(P.head, x, y);           windower.prim.set_size(P.head, w, layout.head_h)
    windower.prim.set_position(P.line, x, y + layout.head_h); windower.prim.set_size(P.line, w, settings.minimized and 0 or 1)

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
local BAGS = {
    {'inventory', 'INV'}, {'satchel', 'SATCH'}, {'sack', 'SACK'}, {'case', 'CASE'},
    {'safe', 'SAFE'}, {'safe2', 'SAFE2'}, {'storage', 'STOR'}, {'locker', 'LOCK'},
    {'wardrobe', 'WARD'}, {'wardrobe2', 'WARD2'}, {'wardrobe3', 'WARD3'}, {'wardrobe4', 'WARD4'},
    {'wardrobe5', 'WARD5'}, {'wardrobe6', 'WARD6'}, {'wardrobe7', 'WARD7'}, {'wardrobe8', 'WARD8'},
}

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
local C = {
    head = '\\cs(255,205,110)', good = '\\cs(110,220,110)', warn = '\\cs(240,210,90)',
    bad  = '\\cs(235,95,95)',   pop  = '\\cs(110,200,245)', dim  = '\\cs(140,145,155)',
    text = '\\cs(230,230,230)', red  = '\\cs(255,60,60)',   redd = '\\cs(150,55,55)',
    nm   = '\\cs(200,170,255)',
}
local function col(c, s) return c .. s .. '\\cr' end

local NAME_W, SRC_W, TAG_W = 30, 24, 8

local function pad(s, w)
    s = tostring(s)
    if #s > w then return s:sub(1, w - 1) .. '.' end
    return s .. string.rep(' ', w - #s)
end

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

local flash_on = false
local target_name

local function red_tag(n)
    if not (settings.red_alerts and n.red) or n.state == 'have' then return '' end
    if target_name == n.from then
        return ' ' .. col(flash_on and C.red or C.warn, 'RED!!! proc it')
    end
    return ' ' .. col(C.red, 'RED!!!')
end

-------------------------------------------------------------------------------
-- Timed NMs (Chukwa, Adze, Minhocao, Fistule) take 10-15 or 15-20 minutes to
-- respawn after they die. We note when one dies (from the chat log) and count
-- down to its window.
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

-- Old name kept for chat output
local function vc_text(s)
    local text, vc = where(s)
    return text, vc
end

-- Which conflux you're standing nearest, checked every few seconds
local near = {n = nil, dist = nil, zone = nil}
local zone_names
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
local marks_file = config.load('data/marks.xml', {list = ''})
local marks = {}   -- 'Zone|Name' -> {x, y}
for zone, name, x, y in tostring(marks_file.list or ''):gmatch('([^|;]+)|([^|;]+)|([-%d%.]+)|([-%d%.]+)') do
    marks[zone .. '|' .. name] = {tonumber(x), tonumber(y)}
end

local function save_marks()
    local parts = {}
    for key, p in pairs(marks) do parts[#parts + 1] = ('%s|%.1f|%.1f'):format(key, p[1], p[2]) end
    table.sort(parts)
    marks_file.list = table.concat(parts, ';')
    config.save(marks_file, 'all')
end

local function zone_name_now()
    local info = windower.ffxi.get_info()
    local z = info and res.zones[info.zone]
    return z and z.en or nil
end

local DIRS = {'N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'}

-- "140y NE" from where you stand to a marked spot; nil if it isn't marked or
-- you're not in its zone. x runs west to east and y south to north.
local function mark_dir(zone, name)
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

-- The same, coloured, with a leading space, for the end of a step line
local function mark_tag(zone, name)
    local d = mark_dir(zone, name)
    return d and (' ' .. col(C.good, d)) or ''
end


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

local function render_branch(ki, nm, lines)
    -- Owned: one line and done
    if ki.state == 'have' and settings.compact then
        lines[#lines + 1] = '  ' .. col(C.good, '[x] ' .. ki.label) .. col(C.dim, '  owned, ready for ' .. nm.name)
        return
    end

    local steps = flow_steps(ki, nm.name, nil, nm.vc, nm.at)
    local done = 0
    for _, s in ipairs(steps) do if s.n.state == 'have' then done = done + 1 end end
    local nxt = next_step(steps)

    lines[#lines + 1] = '  ' .. col(C.pop, ki.label) .. col(C.dim, ('  key item for %s   %d/%d steps'):format(nm.name, done, #steps))

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

-- Items needed for this NM's trade: 50 for Lv80 and Lv85, 75 for Lv90
local function goal_of(nm)
    local o = tonumber(settings.goal_override) or 0
    return o > 0 and o or nm.goal
end

local function count_text(nm)
    local goal = goal_of(nm)
    local c = (nm.count or 0) >= goal and C.good or ((nm.count or 0) > 0 and C.warn or C.bad)
    local s = col(c, ('%d / %d'):format(nm.count or 0, goal))
    if (nm.count or 0) > (nm.count_inv or 0) then
        s = s .. col(C.dim, (' (%d in inv)'):format(nm.count_inv or 0))
    end
    return s
end

local function kis_got(nm)
    local got = 0
    for _, k in ipairs(nm.kids) do if k.state == 'have' then got = got + 1 end end
    return got, #nm.kids
end

-- The NM a weapon needs now (nil when it's past Lv90)
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

local last_scan = 0
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
local EL_WORDS = {fire = 'Fire', ice = 'Ice', wind = 'Wind', earth = 'Earth', lightning = 'Lightning',
                  thunder = 'Lightning', water = 'Water', light = 'Light', dark = 'Dark', darkness = 'Dark'}
local RED_BY_EL = {}
for _, e in ipairs(RED_WS) do RED_BY_EL[e.el] = e.ws end

-- What the log has told us, by mob id: weakness element, red proc landed
local fiend = {}   -- id -> {el = 'Ice', red = true, name = 'Hedetet', at = os.time()}

-- Red proc weapon skills you can use with what you have equipped now
local my_red_cache, my_red_at = {}, 0
local function my_red_ws()
    if os.time() - my_red_at < 2 then return my_red_cache end
    my_red_at = os.time()
    local known = {}
    local ab = windower.ffxi.get_abilities()
    for _, id in ipairs(ab and ab.weapon_skills or {}) do
        local w = res.weapon_skills[id]
        if w then known[lc(w.en)] = true end
    end
    local out = {}
    for _, e in ipairs(RED_WS) do
        for _, w in ipairs(e.ws) do
            if known[lc(w[1])] then out[#out + 1] = {name = w[1], el = e.el, kind = w[2]} end
        end
    end
    my_red_cache = out
    return out
end

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
    local t, f = current_fiend()
    local ki = t and need[t.name]
    local mine = my_red_ws()
    L[#L + 1] = col(C.red, 'RED PROC') .. (t and col(ki and C.text or C.dim, '  ' .. t.name) or '')
        .. (ki and col(C.dim, ' -> ' .. ki.label) or '')

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

local TALL_W = 44   -- characters

local function next_box(nm, best)
    local L = {}
    local function head(right, rc)
        L[#L + 1] = col(C.pop, pad('NEXT', TALL_W - 15)) .. (right and col(rc, right) or '')
    end

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

    if not best then
        head("ready", C.good)
        L[#L + 1] = col(C.text, pad('Pop ' .. nm.name, 22)) .. col(is_near(nm, nm.vc) and C.good or C.head,
            '??? ' .. nm_spot(nm, is_near(nm, nm.vc)))
        L[#L + 1] = col(C.good, 'all key items in hand: examine the ???')
        local d = mark_dir(nm.zone, nm.name)
        if d then L[#L + 1] = col(C.dim, '??? is ') .. col(C.good, d) end
        return L
    end

    local s = best.steps[best.nxt]
    local n = s.n
    local wtext, here = star_where(s, nm)
    local _, vc = where(s)
    head(here and "you're here" or (vc and ('warp to #' .. vc) or nil), here and C.good or C.head)

    if n.state == 'away' then
        L[#L + 1] = col(C.text, 'Move ' .. n.label)
        L[#L + 1] = col(C.dim, 'from ' .. n.where .. ' to your inventory')
    else
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

    if n == best.ki then
        L[#L + 1] = col(C.dim, 'then  -> ') .. col(C.nm, nm.name .. ' (??? ' .. bare(nm.at) .. ')')
    elseif s.feeds == best.ki.from then
        L[#L + 1] = col(C.dim, 'then  -> ' .. s.feeds .. ' -> ') .. col(C.pop, best.ki.label)
    else
        L[#L + 1] = col(C.dim, 'then  -> ' .. s.feeds .. ' -> ... -> ') .. col(C.pop, best.ki.label)
    end
    if n.red and settings.red_alerts then
        L[#L + 1] = red_tag(n):gsub('^ ', '') .. col(C.dim, '  to be sure of the key item')
    end
    return L
end

-------------------------------------------------------------------------------
-- Abyssea time. The game says "Your visitant status will wear off in 25
-- minutes." now and then; each line sets the clock, and it counts down between.
-------------------------------------------------------------------------------
local visit = {ends = nil, warned = {}}

local function visit_left()
    if not visit.ends then return nil end
    return math.max(0, visit.ends - os.time())
end

-- Header text: plain (for padding) and coloured. Empty when not known.
local function visit_tag()
    local left = visit_left()
    if not left then return '', '' end
    local text = 'time ' .. (left < 60 and (left .. 's') or (math.ceil(left / 60) .. 'm'))
    local c = left <= 300 and C.bad or (left <= 600 and C.warn or C.good)
    return text, col(c, text)
end

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

    local blocks, cur = {}, nil
    local function flush() if cur and #cur.lines > 0 then blocks[#blocks + 1] = cur end; cur = nil end
    local function add(line, action, gap)
        if not cur then cur = {lines = {}, rows = nil, gap = gap} end
        cur.lines[#cur.lines + 1] = line
        if action then cur.rows = cur.rows or {}; cur.rows[#cur.lines] = action end
    end
    local function special(b) flush(); blocks[#blocks + 1] = b end

    if wcount == 0 then
        add(col(C.dim, 'No weapon picked yet.'))
        add(col(C.text, '//empy pick') .. col(C.dim, ' or ') .. col(C.text, '//empy weapon <name>'))
    elseif #groups == 0 and #done_w == 0 then
        add(col(C.dim, 'None of your weapons\' NMs are in this zone.'))
        add(col(C.dim, '//empy zone off to show them all'))
    end
    if #done_w > 0 then
        add(col(C.good, 'Lv119 done: ' .. table.concat(done_w, ', ')))
    end

    local any_ki = false
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
        add(col(C.dim, 'for ' .. table.concat(g.weapons, ', ')))

        if nm.material then
            -- A material stage: no NM to pop, just where the material comes from
            for _, l in ipairs(nm.info) do add(col(C.dim, l)) end
        else

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
local before   -- {ki owned set, counts} for announcements

-- The Abyssea zones the Empyrean NMs live in (Lv80, 85 and 90)
local FARM_ZONES = {}
for _, nm in pairs(NMS) do if nm.zone then FARM_ZONES[nm.zone] = true end end
local farm_zone_ids, abyssea_zone_ids = {}, {}
for name, id in pairs(zone_ids) do
    if FARM_ZONES[name] then farm_zone_ids[id] = true end
    if name:sub(1, 10) == 'Abyssea - ' then abyssea_zone_ids[id] = true end
end

-- 'farm' = the nine Empyrean NM zones, 'abyssea' = any Abyssea zone, 'always' = everywhere
local function window_zone_ok(zone)
    if settings.show_in == 'always' then return true end
    if settings.show_in == 'abyssea' then return abyssea_zone_ids[zone] == true end
    return farm_zone_ids[zone] == true
end

local function refresh()
    local info = windower.ffxi.get_info()
    if not info or not info.logged_in then
        if shown then set_visible(false) end
        return
    end

    local have, kis = scan()
    last_scan = os.time()
    for _, key in ipairs(NM_ORDER) do
        local nm = NMS[key]
        evaluate(nm, have, kis)
        count_drop(nm, have)
    end

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
    local now = {kis = {}, counts = {}}
    for _, key in ipairs(NM_ORDER) do
        local nm = NMS[key]
        now.counts[key] = nm.count
        for _, k in ipairs(nm.kids) do if k.state == 'have' then now.kis[k.ki] = true end end
    end
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
local dirty, last, last_flash, last_tick, last_try = true, 0, 0, 0, 0
local function mark() dirty = true end

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

-- "<you> defeats Chukwa." / "Chukwa falls to the ground." start its respawn timer
windower.register_event('incoming text', function(original)
    if not original then return end
    local text = lc(original:gsub('[\30\31]%Z', ''):gsub('[\127\239].', ''))
    if not (text:find('defeats', 1, true) or text:find('falls to the ground', 1, true)) then return end
    for low, t in pairs(TIMED) do
        if text:find('defeats ' .. low, 1, true) or text:find(low .. ' falls to the ground', 1, true) then
            if not killed[t.name] or os.time() - killed[t.name] > 30 then
                killed[t.name] = os.time()
                if settings.announce then
                    say(('%s down: respawns in %d-%d min (about %s-%s)'):format(t.name, t.respawn[1], t.respawn[2],
                        os.date('%H:%M', os.time() + t.respawn[1] * 60), os.date('%H:%M', os.time() + t.respawn[2] * 60)))
                end
                if shown then render() end
            end
        end
    end
end)

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

    local t = windower.ffxi.get_mob_by_target('t') or windower.ffxi.get_mob_by_target('bt')
    if not t then return end
    local f = fiend[t.id]
    if not f or f.name ~= t.name then f = {name = t.name}; fiend[t.id] = f end
    f.at = os.time()
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
    if red and not f.red then alert('redproc', 'Red proc on ' .. t.name .. '!') end
    if red then f.red = true end
    if shown then render() end
end)
windower.register_event('logout', function() set_visible(false) end)
windower.register_event('incoming chunk', function(id)
    if id == 0x055 or id == 0x01D or id == 0x020 then mark() end
end)

-------------------------------------------------------------------------------
-- Weapon picker: a small clickable window, shown when a character hasn't
-- picked yet (and on //empy pick)
-------------------------------------------------------------------------------
local picker = {open = false, sel = {}, hover = nil, rows = {}, box = {x = 0, y = 0, w = 0, h = 0}}
local PP = {border = 'empybuilder_pick_border', bg = 'empybuilder_pick_bg',
            head = 'empybuilder_pick_head', hover = 'empybuilder_pick_hover'}

make_rect(PP.border, settings.window.border)
make_rect(PP.bg,     {alpha = 240, red = 14, green = 18, blue = 26})
make_rect(PP.head,   settings.window.header)
make_rect(PP.hover,  {alpha = 120, red = 70, green = 90, blue = 140})

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

local function picker_show(on)
    picker.open = on
    for key, name in pairs(PP) do
        if key ~= 'hover' then windower.prim.set_visibility(name, on) end
    end
    windower.prim.set_visibility(PP.hover, false)
    if on then pick_text:show() else pick_text:hide() end
end

local function open_picker()
    if not char.data then say('log in first') return end
    picker.sel, picker.hover = {}, nil
    for _, w in ipairs(selected_weapons()) do picker.sel[w.name] = true end
    picker_render()
    picker_show(true)
end

local function picker_inside(x, y)
    local b = picker.box
    return picker.open and x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h
end

local function picker_row(y)
    local b = picker.box
    if not b.lh or b.lh <= 0 then return nil end
    local r = math.floor((y - b.ty) / b.lh) + 1
    if picker.rows[r] then return r end
    return nil
end

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

-- On login (or when the addon loads while logged in): load that character's
-- list, and ask if they haven't picked yet
-- The loading echo, in the same style as the other addons:
--   [EmpyBuilder] Author: Valdimar @ Phoenix 1.8  -  //empy help for commands
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

local function on_character(name)
    if not load_character(name) then return end
    before = nil
    mark()
    if not char.data.picked then open_picker() end
    coroutine.schedule(load_echo, 2)
end

windower.register_event('login', function(name) on_character(name) end)
windower.register_event('logout', function()
    picker_show(false)
    char.name, char.data = nil, nil
end)

local press
windower.register_event('mouse', function(type, x, y)
    if not shown or picker_inside(x, y) then return end
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

windower.register_event('unload', function()
    config.save(settings)
    for _, name in pairs(P) do windower.prim.delete(name) end
    for _, name in pairs(PP) do windower.prim.delete(name) end
    for _, b in ipairs(tall.boxes) do windower.prim.delete(b.border); windower.prim.delete(b.fill) end
end)

-------------------------------------------------------------------------------
-- Commands
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Lights window. A separate panel (//empy lights) that tallies the lights the
-- log says you gained in this Abyssea visit, shows exact values when a Conflux
-- Surveyor reports them, and lists which of your pop items gold chests here
-- can give.
-------------------------------------------------------------------------------
local LIGHTS = {
    {key = 'pearlescent', name = 'Pearlescent', what = 'more chests'},
    {key = 'azure',       name = 'Azure',       what = 'blue chests'},
    {key = 'ruby',        name = 'Ruby',        what = 'red chests'},
    {key = 'amber',       name = 'Amber'},
    {key = 'golden',      name = 'Golden',      what = 'gold chests: pop items'},
    {key = 'silvery',     name = 'Silvery'},
    {key = 'ebon',        name = 'Ebon'},
}
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
local function lights_reset()
    lights, lights_checked = {}, nil
    for _, l in ipairs(LIGHTS) do lights[l.key] = {faint = 0, mild = 0, strong = 0} end
end
lights_reset()

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

    local who, how, color = text:match("(%S+)'s body emits a (%a+) (%a+) light")
    if who then
        local me = windower.ffxi.get_player()
        if me and lc(me.name) == who and lights[color] and lights[color][how] then
            lights[color][how] = lights[color][how] + 1
            if lights_shown then lights_render() end
        end
        return
    end

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

-- Once a second: respawn windows opening, Abyssea time running low, and the
-- lights window; every frame: the flash
local respawn_seen, tick_wall = {}, 0
windower.register_event('prerender', function()
    flash_tick()
    local wall = os.time()
    if wall == tick_wall then return end
    tick_wall = wall

    for name, t in pairs(TIMED) do
        local st = respawn_state(t.name, t.respawn)
        if st == 'window' and respawn_seen[name] == 'cooling' then
            alert('respawn', t.name .. ' may be up now')
        end
        respawn_seen[name] = st
    end

    local left = visit_left()
    if left then
        for _, m in ipairs({10, 5}) do
            if left <= m * 60 and left > 0 and not visit.warned[m] then
                visit.warned[m] = true
                alert('time', ('%d minutes of Abyssea time left'):format(m))
                say(('%d minutes of Abyssea time left'):format(m))
            elseif left > m * 60 + 30 then
                visit.warned[m] = nil
            end
        end
    end

    lights_update()
end)

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

local function onoff(arg, current)
    arg = lc(arg)
    if arg == 'on' then return true elseif arg == 'off' then return false end
    return not current
end

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

windower.register_event('addon command', function(cmd, ...)
    local args = {...}
    local rest = table.concat(args, ' ')
    cmd = lc(cmd)

    -- //empy weapon <name or type> adds it; //empy weapon on its own lists them
    if cmd == 'weapon' or cmd == 'weapons' or cmd == 'w' then
        cmd = (rest ~= '') and 'add' or 'weapons'
    end

    if cmd == '' or cmd == 'help' then
        say('//empy pick  (choose your weapons in a window)')
        windower.add_to_chat(207, '  weapon <name or type>   e.g. weapon Rhongomiant, weapon polearm')
        windower.add_to_chat(207, '  remove <name or type> | clear | weapons (list all)')
        windower.add_to_chat(207, '  show | hide | toggle | min | list | refresh | reload | about')
        windower.add_to_chat(207, '  compact [on|off]  hide what is under a step you already have')
        windower.add_to_chat(207, '  red [on|off]      RED!!! alerts on key items that need a red proc')
        windower.add_to_chat(207, '  where farm|abyssea|always  where the window appears (default: farm =')
        windower.add_to_chat(207, '                    the nine Abyssea zones with Empyrean NMs)')
        windower.add_to_chat(207, '  zone [on|off]     only show NMs for the Abyssea zone you are in')
        windower.add_to_chat(207, '  announce [on|off] chat lines for new key items and item counts')
        windower.add_to_chat(207, '  every <seconds>   timed search of bags + key items (0 = only on changes)')
        windower.add_to_chat(207, '  layout wide|tall  every step / narrow window with the NEXT step')
        windower.add_to_chat(207, '  lights [on|off]   the lights window   |  time [minutes|clear]  Abyssea clock')
        windower.add_to_chat(207, '  mark [name] | mark list | mark clear <name>   save a ??? spot for distance/direction')
        windower.add_to_chat(207, '  alert [kind on|off|test] | sound on|off | flash on|off')
        windower.add_to_chat(207, '  stage [80..119|done|auto] [weapon] show / set the stage (auto: from your bags)')
        windower.add_to_chat(207, '  next [weapon]     move a weapon to its next stage after you trade')
        windower.add_to_chat(207, '  full [on|off]     also show the later stages\' NMs   |  path <weapon>')
        windower.add_to_chat(207, '  killed <nm> [min ago] | killed clear   start / clear a respawn timer')
        windower.add_to_chat(207, '  near [on|off|<seconds>]  nearest conflux (alone: say it now)')
        windower.add_to_chat(207, '  opacity <10-100>  whole window, panel and text (default 75)')
        windower.add_to_chat(207, '  goal <n> | size <n> | pos <x> <y>')
        return

    elseif cmd == 'pick' or cmd == 'choose' then
        refresh(); open_picker(); return
    elseif (cmd == 'add' or cmd == 'remove' or cmd == 'rm' or cmd == 'clear') and not char.data then
        say('log in first'); return
    elseif cmd == 'add' or cmd == 'remove' or cmd == 'rm' then
        if rest == '' then say('//empy ' .. cmd .. ' <weapon name or type>, e.g. Rhongomiant or polearm') return end
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
        local w = matches[1]
        if how == 'spelling' then say('taking "' .. rest .. '" as ' .. w.name) end
        if how == 'type' then say(w.kind .. ' is ' .. w.name) end
        local list, found = selected_weapons(), nil
        for i, x in ipairs(list) do if x.name == w.name then found = i end end
        if cmd == 'add' then
            if found then say(w.name .. ' is already on the list') return end
            list[#list + 1] = w
            local nm, st = current_nm(w)
            if nm then
                say(('added %s (Lv%d stage): %d %s from %s'):format(w.name, st, goal_of(nm), nm.drop[1], source_of(nm)))
            else
                say(('added %s: it is already Lv90'):format(w.name))
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
        save_weapons(list)
        before = nil

    elseif cmd == 'clear' then save_weapons({}); say('weapon list cleared')
    elseif cmd == 'weapons' then refresh(); print_weapons(); return
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
    elseif cmd == 'show' then
        settings.visible = true
        local info = windower.ffxi.get_info()
        if info and not window_zone_ok(info.zone) then
            say('the window will appear when you enter Abyssea (//empy where always to show it everywhere)')
        end
    elseif cmd == 'hide' then settings.visible = false
    elseif cmd == 'toggle' then settings.visible = not settings.visible
    elseif cmd == 'min' or cmd == 'minimize' then settings.minimized = not settings.minimized; set_visible(shown)
    elseif cmd == 'compact' then settings.compact = onoff(args[1], settings.compact); say('compact ' .. (settings.compact and 'on' or 'off'))
    elseif cmd == 'red' then settings.red_alerts = onoff(args[1], settings.red_alerts); say('red proc alerts ' .. (settings.red_alerts and 'on' or 'off'))
    elseif cmd == 'zone' then settings.only_in_zone = onoff(args[1], settings.only_in_zone); say('only this zone\'s NMs ' .. (settings.only_in_zone and 'on' or 'off'))
    elseif cmd == 'announce' then settings.announce = onoff(args[1], settings.announce); say('announce ' .. (settings.announce and 'on' or 'off'))
    elseif (cmd == 'every' or cmd == 'interval') and tonumber(args[1]) then
        settings.rescan = math.max(0, math.floor(tonumber(args[1])))
        say(settings.rescan > 0 and ('searching every ' .. settings.rescan .. 's (and on every change)')
            or 'timed search off (still searches on every change)')
    elseif cmd == 'goal' and tonumber(args[1]) then
        settings.goal_override = math.max(0, math.floor(tonumber(args[1])))
        say(settings.goal_override > 0 and ('goal ' .. settings.goal_override .. ' for every stage')
            or 'goal back to 50 for Lv80/85 and 75 for Lv90')
    elseif cmd == 'killed' or cmd == 'timer' or cmd == 'died' then
        -- //empy killed chukwa [minutes ago]: for a kill the log didn't show you
        if lc(args[1]) == 'clear' then killed = {}; say('respawn timers cleared'); render(); return end
        local ago = tonumber(args[#args])
        local name = lc(table.concat(args, ' ', 1, ago and (#args - 1) or #args))
        local hit
        for low, t in pairs(TIMED) do
            if name ~= '' and low:sub(1, #name) == name then hit = t end
        end
        if not hit then
            local names = {}
            for _, t in pairs(TIMED) do names[#names + 1] = t.name end
            table.sort(names)
            say('killed <' .. table.concat(names, '|') .. '> [minutes ago]')
            return
        end
        killed[hit.name] = os.time() - math.floor((ago or 0) * 60)
        local st, lo, hi = respawn_state(hit.name, hit.respawn)
        say(('%s respawn timer started: %s'):format(hit.name,
            st == 'cooling' and ('respawns in %d-%d min'):format(mins(lo), mins(hi))
            or st == 'window' and 'window open now' or 'should be up'))
        render()
        return
    elseif (cmd == 'stage' or cmd == 'next' or cmd == 'path') and not char.data then
        say('log in first'); return
    elseif cmd == 'stage' or cmd == 'next' or cmd == 'path' then
        -- Which weapons: one named at the end, or "all" / nothing = every weapon you're building
        local a = {}
        for _, v in ipairs(args) do a[#a + 1] = v end
        local value
        if cmd == 'stage' and a[1] then
            local v = lc(a[1])
            if NEXT_STAGE[tonumber(v) or 0] or v == '119' then value = tonumber(v)
            elseif v == 'done' or v == 'auto' then value = v end
            if value then table.remove(a, 1) end
        end
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
        if #targets == 0 then say('no weapons picked; //empy weapon <name>') return end

        if cmd == 'path' or (cmd == 'stage' and not value) then
            refresh()
            for _, w in ipairs(targets) do print_path(w) end
            if cmd == 'stage' then
                windower.add_to_chat(207, '  //empy stage <80|85|90|95|99|119|done|auto> [weapon]   //empy next [weapon]   //empy full')
            end
            return
        end

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
    elseif cmd == 'full' then
        if not char.data then say('log in first') return end
        char.data.full = onoff(args[1], char.data.full == true)
        config.save(char.data, 'all')
        say(char.data.full and 'full build: also showing the Lv85 and Lv90 NMs still ahead (short, marked LATER)'
            or 'showing only the stage each weapon is on')
    elseif cmd == 'about' or cmd == 'version' then
        load_echo()
        return
    elseif cmd == 'reload' then
        -- Reload the addon itself (picks up a new version you copied in)
        say('reloading...')
        config.save(settings)
        windower.send_command('lua reload ' .. _addon.name)
        return
    elseif cmd == 'lights' then
        settings.lights.visible = onoff(args[1], settings.lights.visible)
        config.save(settings)
        say(settings.lights.visible and 'lights window on (it shows while you are in Abyssea)' or 'lights window off')
        lights_update()
        if settings.lights.visible and not lights_shown then say('you are not in Abyssea right now; it will appear when you are') end
        return
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
    elseif cmd == 'mark' then
        -- //empy mark [name] | mark list | mark clear <name>
        local zone = zone_name_now()
        local me = windower.ffxi.get_mob_by_target('me')
        local sub = lc(args[1])
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
    elseif cmd == 'sound' or cmd == 'sounds' then
        settings.sounds = onoff(args[1], settings.sounds)
        say('alert sounds ' .. (settings.sounds and 'on' or 'off'))
    elseif cmd == 'flash' then
        settings.flash = onoff(args[1], settings.flash)
        say('on-screen alerts ' .. (settings.flash and 'on' or 'off'))
    elseif cmd == 'alert' or cmd == 'alerts' then
        -- //empy alert: list | alert <kind> on|off | alert test
        local kind = lc(args[1])
        if kind == 'test' then alert('test', 'EmpyBuilder alert test'); return end
        if settings.alerts[kind] == nil then
            local parts = {}
            for _, k in ipairs({'respawn', 'weakness', 'redproc', 'goal', 'time'}) do
                parts[#parts + 1] = k .. (settings.alerts[k] and ' on' or ' off')
            end
            say('alerts: ' .. table.concat(parts, ', ') .. '  (sound ' .. (settings.sounds and 'on' or 'off')
                .. ', flash ' .. (settings.flash and 'on' or 'off') .. ')')
            windower.add_to_chat(207, '  //empy alert <kind> on|off   //empy alert test   //empy sound on|off   //empy flash on|off')
            return
        end
        settings.alerts[kind] = onoff(args[2], settings.alerts[kind])
        say(kind .. ' alert ' .. (settings.alerts[kind] and 'on' or 'off'))
    elseif cmd == 'layout' or cmd == 'tall' or cmd == 'wide' then
        local v = (cmd ~= 'layout') and cmd or lc(args[1])
        if v == '' or v == 'toggle' then v = (settings.layout == 'tall') and 'wide' or 'tall' end
        if v ~= 'tall' and v ~= 'wide' then say('layout wide | tall  (now: ' .. settings.layout .. ')') return end
        settings.layout = v
        say(v == 'tall' and 'tall layout: the NEXT step, one line per key item, click one for its steps'
            or 'wide layout: every step for every key item')
        set_visible(shown)
        render()
    elseif cmd == 'near' or cmd == 'conflux' or cmd == 'vc' then
        local a = lc(args[1])
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
    elseif cmd == 'opacity' or cmd == 'alpha' or cmd == 'fade' then
        local v = tonumber((args[1] or ''):match('^(%d+)'))
        if not v then say('opacity ' .. settings.opacity .. '%  (//empy opacity <10-100>)') return end
        settings.opacity = math.max(10, math.min(100, math.floor(v)))
        apply_opacity()
        say('opacity ' .. settings.opacity .. '%')
    elseif cmd == 'size' and tonumber(args[1]) then
        settings.size = tonumber(args[1]); title:size(settings.size); body:size(settings.size)
    elseif cmd == 'pos' and tonumber(args[1]) and tonumber(args[2]) then
        settings.window.pos.x, settings.window.pos.y = tonumber(args[1]), tonumber(args[2])
    elseif cmd == 'list' then
        refresh()
        local groups = active_nms()
        if #groups == 0 then say('no weapons picked; //empy add <weapon>') end
        for _, g in ipairs(groups) do print_chain(g.nm) end
        return
    elseif cmd == 'refresh' then
        refresh(); say('searched bags and key items'); return
    else
        -- //empy <weapon name or type> as a shortcut for add
        local w = find_weapon(cmd .. (rest ~= '' and (' ' .. rest) or ''))
        if w then
            windower.send_command('empy add ' .. cmd .. (rest ~= '' and (' ' .. rest) or ''))
            return
        end
        say('unknown command, try //empy help')
        return
    end
    config.save(settings)
    if not settings.visible then set_visible(false) end
    mark()
end)

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
