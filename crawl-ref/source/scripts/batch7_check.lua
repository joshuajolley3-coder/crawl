-- Checks: sight range, draconians, fist weapons, the mask, weather, the
-- Ancient Temple and Tonalli, and that Vashtar can turn up at any altar.
-- Run with: ./crawl.exe -script batch7_check

local eol = string.char(10)
local fails = 0
local function say(s) crawl.stderr(s .. eol) end
local function check(ok, what)
    if ok then say("  PASS  " .. what) else say("  FAIL  " .. what); fails = fails + 1 end
end
local function arena()
    for dx = -5, 5 do for dy = -5, 5 do dgn.grid(20 + dx, 20 + dy, "floor") end end
    you.moveto(20, 20)
end
local function pick_up(spec, word)
    dgn.create_item(20, 20, spec)
    for _, it in ipairs(dgn.items_at(20, 20)) do items.pickup(it) end
    for slot = 0, 51 do
        local it = items.inslot(slot)
        if it and not it.equipped and string.find(it.name(), word, 1, true) then
            return slot, it
        end
    end
end

say("== Sight ==")
you.init("HuFi", "long sword")
say("  line of sight radius: " .. you.los())
check(you.los() == 8, "you see one tile further (8, was 7)")

say("== Draconians ==")
you.init("DrFi", "long sword")
say("  Draconian Fighter: Str " .. you.strength() .. " Dex " .. you.dexterity())
check(you.dexterity() >= 8, "draconians start with more Dexterity")

say("== Fist weapons ==")
you.init("HuBl", "long sword")
local r, sk = debug.melee_rating()
check(sk == "Unarmed Combat", "Brawlers wield brass knuckles, which use Unarmed Combat (" .. sk .. ")")
for _, spec in ipairs({ { "pair of brass knuckles", "brass knuckles" }, { "iron bagh nakh", "bagh nakh" } }) do
    you.init("HuFi", "long sword")
    arena()
    local fists = debug.melee_rating(true)
    local slot = pick_up(spec[1] .. " plus:0 ego:none", spec[2])
    check(slot ~= nil and debug.wear(slot), "can wield " .. spec[1])
    local r1, s1 = debug.melee_rating()
    check(s1 == "Unarmed Combat", spec[1] .. " uses Unarmed Combat")
    debug.set_skill("Unarmed Combat", 20)
    local r2 = debug.melee_rating()
    local fists2 = debug.melee_rating(true)
    say(string.format("  %s: fists %d -> %d, wielded %d -> %d (UC 0 -> 20)", spec[1], fists, fists2, r1, r2))
    check(r1 > fists, spec[1] .. " hits harder than bare fists")
    check(r2 >= r1 + 15, spec[1] .. " scales with Unarmed Combat like fists do")
    check(r2 > fists2, spec[1] .. " still beats bare fists at high skill")
end
say("== The mask ==")
you.init("HuFi", "long sword")
arena()
check(not debug.has_ability("Evoke Terrifying Visage"), "no mask ability without a mask")
slot = pick_up("mask", "mask")
check(slot ~= nil and debug.wear(slot), "can wear a mask")
check(debug.has_ability("Evoke Terrifying Visage"), "a worn mask grants Terrifying Visage")

say("== Altars ==")
local in_temple, ecu = debug.god_pools("Vashtar")
check(in_temple, "Vashtar can appear in the Temple and at random altars")
check(ecu, "Vashtar can be the unknown god of a faded altar")
in_temple, ecu = debug.god_pools("Tonalli")
check(not in_temple, "Tonalli never appears in the Temple or at random altars")
check(not ecu, "Tonalli is never an unknown god's faded altar")

say("== Tonalli ==")
you.init("HuFi", "long sword")
check(debug.join_god("Tonalli"), "can join Tonalli")
debug.set_piety(200)
for _, a in ipairs({ "Obsidian Edge", "Sun Lance", "Feathered Serpent", "Heart Offering" }) do
    check(debug.has_ability(a), "Tonalli grants " .. a)
end
check(you.res_fire() >= 1, "Tonalli's followers resist fire")

say("== The Ancient Temple ==")
local present = 0
for i = 1, 20 do
    you.init("HuFi", "long sword")
    local name = dgn.level_name(dgn.br_entrance("Ruin"))
    if string.match(name, "^Lair:[234]$") then present = present + 1 end
end
say("  temple present in " .. present .. " of 20 games")
check(present >= 3 and present <= 17, "the temple is in some games but not all")

you.init("HuFi", "long sword")
debug.goto_place("Ruin:1")
test.regenerate_level(nil, true)
check(you.branch() == "Ruin", "can generate the Ancient Temple")
local counts, total = {}, 0
for m in test.level_monster_iterator() do
    counts[m.name] = (counts[m.name] or 0) + 1
    total = total + 1
end
local names = {}
for n, c in pairs(counts) do names[#names + 1] = n .. " x" .. c end
table.sort(names)
say("  " .. total .. " monsters: " .. table.concat(names, ", "))
check((counts["jaguar warrior"] or 0) >= 3, "jaguar warriors guard the temple")
check((counts["sun priest"] or 0) >= 1, "sun priests keep the altar")
local altar, exit, trees, mask = 0, 0, 0, false
for x = 1, 78 do
    for y = 1, 68 do
        local f = dgn.feature_name(dgn.grid(x, y))
        if f == "altar_tonalli" then altar = altar + 1 end
        if f == "exit_ancient_temple" then exit = exit + 1 end
        if f == "tree" then trees = trees + 1 end
        for _, it in ipairs(dgn.items_at(x, y)) do
            if it.name() == "mask" or string.find(it.name(), " mask", 1, true) then mask = true end
        end
    end
end
say(string.format("  altar %d, exits %d, trees %d", altar, exit, trees))
check(altar == 1, "Tonalli's altar stands at the summit")
check(exit >= 1, "there is a way back to the Lair")
check(trees >= 100, "the jungle is thick")
check(mask, "a ritual mask lies in the temple")

say("== Weather ==")
you.init("HuFi", "long sword")
debug.goto_place("D:6")
test.regenerate_level(nil, true)
local function count_feature(name)
    local n = 0
    for x = 1, 78 do for y = 1, 68 do
        if dgn.feature_name(dgn.grid(x, y)) == name then n = n + 1 end
    end end
    return n
end
local w0 = count_feature("shallow_water")
debug.set_weather(1)
check(debug.weather() == "rain", "can set rain")
debug.shape_weather()
local w1 = count_feature("shallow_water")
say("  shallow water " .. w0 .. " -> " .. w1)
check(w1 > w0 + 20, "rain leaves puddles across the level")
-- Stand somewhere open (a regenerated level doesn't place the player).
local function stand_in_open()
    for x = 5, 74 do for y = 5, 64 do
        local open = true
        for dx = -2, 2 do for dy = -2, 2 do
            local f = dgn.feature_name(dgn.grid(x + dx, y + dy))
            if f ~= "floor" and f ~= "shallow_water" then open = false end
        end end
        if open then you.moveto(x, y); return true end
    end end
    return false
end
check(stand_in_open(), "found open ground to stand on")
local clouds = debug.weather_ticks(150)
say("  rain clouds in sight after 150 turns: " .. clouds)
check(clouds > 0, "rain showers fall near you")

-- Count the separate walkable regions of the level (deep water and lava
-- count as walls, as for a creature on foot).
local function regions()
    local seen, n = {}, 0
    local function walk(x, y)
        local f = dgn.feature_name(dgn.grid(x, y))
        return dgn.is_passable(x, y) and f ~= "deep_water" and f ~= "lava"
    end
    for x = 1, 78 do for y = 1, 68 do
        local k = x * 100 + y
        if not seen[k] and walk(x, y) then
            n = n + 1
            local stack = { { x, y } }
            seen[k] = true
            while #stack > 0 do
                local p = table.remove(stack)
                for dx = -1, 1 do for dy = -1, 1 do
                    local nx, ny = p[1] + dx, p[2] + dy
                    local nk = nx * 100 + ny
                    if nx >= 1 and ny >= 1 and nx <= 78 and ny <= 68
                       and not seen[nk] and walk(nx, ny) then
                        seen[nk] = true
                        stack[#stack + 1] = { nx, ny }
                    end
                end end
            end
        end
    end end
    return n
end
local grew, split = 0, false
for i = 1, 6 do
    test.regenerate_level(nil, true)
    local r0, t0 = regions(), count_feature("tree")
    debug.set_weather(4)
    debug.shape_weather()
    local r1, t1 = regions(), count_feature("tree")
    say(string.format("  level %d: trees %d -> %d, walkable regions %d -> %d", i, t0, t1, r0, r1))
    grew = grew + (t1 - t0)
    if r1 > r0 then split = true end
end
check(grew >= 30, "overgrowth sprouts trees")
check(not split, "overgrowth never cuts a level in two")

test.regenerate_level(nil, true)
debug.set_weather(2)
check(stand_in_open(), "found open ground for the fog test")
clouds = debug.weather_ticks(150)
say("  fog banks in sight after 150 turns: " .. clouds)
check(clouds > 0, "fog rolls in")

if fails == 0 then
    say("ALL CHECKS PASSED")
else
    say(fails .. " CHECK(S) FAILED")
    error(fails .. " checks failed")
end
