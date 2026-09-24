-- Checks the Abandoned Battlefield branch, Veyrak, and god's eyes.
-- Run with: ./crawl.exe -script battlefield_check

local eol = string.char(10)
local fails = 0
local function say(s) crawl.stderr(s .. eol) end
local function check(ok, what)
    if ok then say("  PASS  " .. what) else say("  FAIL  " .. what); fails = fails + 1 end
end

say("== Entrance depth ==")
local seen = {}
for i = 1, 12 do
    you.init("HuFi", "long sword")
    local name = dgn.level_name(dgn.br_entrance("Field"))
    local d = string.match(name, "^D:(%d+)$")
    d = tonumber(d) or -1
    if i == 1 then say("  e.g. " .. name) end
    seen[#seen + 1] = d
end
local ok_depth = true
for _, d in ipairs(seen) do if d < 10 or d > 14 then ok_depth = false end end
say("  entrance depths over 12 games: " .. table.concat(seen, " "))
check(ok_depth, "entrance is always on D:10-14")

say("== The level ==")
you.init("HuFi", "long sword")
debug.goto_place("Field:1")
test.regenerate_level(nil, true)
say("  now in " .. you.branch() .. ":" .. you.depth())
check(you.branch() == "Field", "can generate the Battlefield")

local counts, total, veyrak = {}, 0, nil
for m in test.level_monster_iterator() do
    counts[m.name] = (counts[m.name] or 0) + 1
    total = total + 1
    if m.name == "Veyrak" then veyrak = m end
end
local names = {}
for n, c in pairs(counts) do names[#names + 1] = n .. " x" .. c end
table.sort(names)
say("  " .. total .. " monsters: " .. table.concat(names, ", "))
check(veyrak ~= nil, "Veyrak guards the level")
check(total >= 20 and total <= 45, "a field full of the dead (20-45 monsters)")

local exits, items, bones, good = 0, 0, 0, 0
for x = 1, 78 do
    for y = 1, 68 do
        local f = dgn.feature_name(dgn.grid(x, y))
        if f == "exit_battlefield" then exits = exits + 1 end
        for _, it in ipairs(dgn.items_at(x, y)) do
            items = items + 1
            local n = it.name()
            if string.find(n, "skeleton", 1, true) then bones = bones + 1
            elseif x >= 58 then
                -- The keep's hoard (the keep is the east end of the map,
                -- or the west end if the map was mirrored).
                good = good + 1
                say("    hoard: " .. n)
            elseif x <= 18 and it.class(true) ~= "weapon" and it.class(true) ~= "armour" then
                good = good + 1
                say("    hoard: " .. n)
            end
        end
    end
end
say(string.format("  %d exit(s), %d items (%d skeletons, %d artefacts/consumables)",
    exits, items, bones, good))
check(exits >= 1, "there is a way back to the Dungeon")
check(bones >= 2, "bones of the fallen litter the field")
check(good >= 2, "there is loot worth fighting for")

say("== God's eyes ==")
you.init("HuFi", "long sword")
for dx = -2, 2 do for dy = -2, 2 do dgn.grid(20 + dx, 20 + dy, "floor") end end
you.moveto(20, 20)
dgn.create_item(21, 20, "potion of god's eyes pre_id")
local found = false
for _, it in ipairs(dgn.items_at(21, 20)) do
    if string.find(it.name(), "god's eyes", 1, true) then found = true end
end
check(found, "can create a potion of god's eyes")

say(fails == 0 and "ALL CHECKS PASSED" or (fails .. " CHECK(S) FAILED"))
assert(fails == 0, fails .. " checks failed")
