-- Checks: rock plate armour, and the five elixirs (titan's blood,
-- quicksilver, sagacity, vitality, arcana).
-- Run with: ./crawl.exe -script batch6_check

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
local function max_hp() local _, m = you.hp(); return m end
local function max_mp() local _, m = you.mp(); return m end

say("== Rock plate armour ==")
you.init("MiFi", "long sword")
arena()
local slot, arm = pick_up("rock plate armour pre_id", "rock plate")
check(slot ~= nil, "can create rock plate armour")
if arm then
    say("  " .. arm.name() .. ": base AC " .. arm.ac .. ", encumbrance " .. arm.encumbrance)
    check(arm.ac == 16, "base AC 16 (crystal plate is 14)")
    check(arm.encumbrance == 28, "encumbrance 28, heavier than crystal plate (23)")
    local rf0, rc0 = you.res_fire(), you.res_cold()
    -- Take off the starting armour first.
    check(debug.wear(slot), "a minotaur can wear it")
    say(string.format("  rF %d -> %d, rC %d -> %d, AC now %d", rf0, you.res_fire(), rc0, you.res_cold(), you.ac()))
    check(you.res_fire() == rf0 + 1, "grants rF+")
    check(you.res_cold() == rc0 + 1, "grants rC+")
end

say("== Elixirs ==")
you.init("HuCj", "long sword")
arena()
local function drink(spec, word)
    local name = spec:gsub("^potion of ", "")
    return debug.drink(name)
end

local str0, dex0, int0 = you.strength(), you.dexterity(), you.intelligence()
check(drink("potion of titan's blood", "titan"), "drank titan's blood")
check(you.strength() == str0 + 3, "titan's blood: Str " .. str0 .. " -> " .. you.strength())
check(drink("potion of quicksilver", "quicksilver"), "drank quicksilver")
check(you.dexterity() == dex0 + 3, "quicksilver: Dex " .. dex0 .. " -> " .. you.dexterity())
check(drink("potion of sagacity", "sagacity"), "drank sagacity")
check(you.intelligence() == int0 + 3, "sagacity: Int " .. int0 .. " -> " .. you.intelligence())

local hp0 = max_hp()
check(drink("potion of vitality", "vitality"), "drank vitality")
check(max_hp() == hp0 + 10, "vitality: max HP " .. hp0 .. " -> " .. max_hp())
local mp0 = max_mp()
check(drink("potion of arcana", "arcana"), "drank arcana")
check(max_mp() >= mp0 + 4, "arcana: max MP " .. mp0 .. " -> " .. max_mp())

-- The gains are permanent: they survive a level-up.
you.set_xl(you.xl() + 3)
check(max_hp() >= hp0 + 10, "vitality bonus survives levelling (max HP " .. max_hp() .. ")")

say("== Djinni can't use arcana ==")
you.init("DjCj", "long sword")
arena()
check(not debug.drink("arcana"), "a Djinni is refused the potion of arcana")
check(debug.drink("vitality"), "...but can drink vitality")

if fails == 0 then
    say("ALL CHECKS PASSED")
else
    say(fails .. " CHECK(S) FAILED")
    error(fails .. " checks failed")
end
