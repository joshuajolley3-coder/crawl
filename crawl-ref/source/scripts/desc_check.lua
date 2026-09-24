-- Checks that everything added in this fork has an in-game description:
-- items, artefacts, monsters, features, abilities, gods, species,
-- backgrounds, branches, statuses and mutations.
-- Run with: ./crawl.exe -script desc_check

local eol = string.char(10)
local fails = 0
local function say(s) crawl.stderr(s .. eol) end
local function check(ok, what)
    if not ok then say("  MISSING  " .. what); fails = fails + 1 end
end

local function keys(list, suffix, lookup)
    local n = 0
    for _, k in ipairs(list) do
        n = n + 1
        check((lookup or debug.has_desc)(k .. (suffix or "")), k .. (suffix or ""))
    end
    return n
end

you.init("HuFi", "long sword")
for dx = -3, 30 do for dy = -3, 3 do dgn.grid(20 + dx, 20 + dy, "floor") end end
you.moveto(20, 20)

say("== Items ==")
local items_to_check = {
    "bastard sword", "pair of brass knuckles", "iron bagh nakh",
    "beast hide robe", "rock plate armour", "crown", "mask",
    "bag of sand", "throwing knife",
    "potion of positive mutation", "potion of empowerment", "potion of god's eyes",
    "potion of titan's blood", "potion of quicksilver", "potion of sagacity",
    "potion of vitality", "potion of arcana",
    "scroll of enslavement", "scroll of true name",
    "Excalibur", "the King's Regalia", "Ruyi Jingu Bang",
    'lightsaber "Vaapad"', "Xom's Treads", "alien zapper",
}
local n_items = 0
for i, spec in ipairs(items_to_check) do
    local x = 20 + i
    local ok, err = pcall(function() dgn.create_item(x, 21, spec .. " pre_id") end)
    if not ok then
        check(false, "can't create '" .. spec .. "': " .. tostring(err))
    else
        for _, e in ipairs(debug.item_desc_keys(x, 21)) do
            n_items = n_items + 1
            check(e[2], "item: " .. e[1])
        end
    end
end
say("  " .. n_items .. " items checked")

say("== Monsters ==")
say("  " .. keys({ "vanara champion", "hollowkin champion", "Veyrak",
                   "Vashtari champion", "suspicious figure", "jaguar warrior",
                   "sun priest", "feathered serpent" }) .. " monsters checked")

say("== Features ==")
-- The game looks features up by their name with an article.
say("  " .. keys({ "a blood-soaked altar", "a skull-heaped altar of Vashtar",
                   "a sun-stone altar of Tonalli",
                   "a passage to the Abandoned Battlefield",
                   "a passage back to the Dungeon",
                   "an overgrown stair to the Ancient Temple",
                   "an overgrown stair back to the Lair" }) .. " features checked")

say("== Abilities ==")
say("  " .. keys({ "Evoke Terrifying Visage", "War Paint", "Vashtar's Fury",
                   "Blood Tithe", "Spoils of War", "Thousand Arms",
                   "Obsidian Edge", "Sun Lance", "Feathered Serpent",
                   "Heart Offering", "Hollow Silence", "Call the Pack",
                   "Wind Strike", "Gale Vortex" }, " ability") .. " abilities checked")

say("== Gods ==")
for _, g in ipairs({ "Vashtar", "Tonalli" }) do
    check(debug.has_desc(g), g)
    check(debug.has_desc(g .. " powers"), g .. " powers")
    check(debug.has_desc(g .. " wrath"), g .. " wrath")
end

say("== Species and backgrounds ==")
keys({ "Vanara", "Hollowkin", "Beastkin", "Angel", "Fallen Angel",
       "Wrathful Monk", "Brawler" }, nil, debug.has_start_desc)

say("== Branches ==")
keys({ "Battlefield", "Ancient Temple" })

say("== Statuses ==")
keys({ "WarPaint", "Obsidian" }, " status")

say("== Mutations ==")
keys({ "demonic wings", "golden scales", "prehensile tail", "golden fur",
       "no magic", "devout", "hollow silence", "shunned", "wolf blood",
       "cat blood", "bird blood" }, " mutation")

if fails == 0 then
    say("ALL CHECKS PASSED")
else
    say(fails .. " MISSING DESCRIPTION(S)")
    error(fails .. " missing descriptions")
end
