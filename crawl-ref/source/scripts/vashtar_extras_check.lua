-- Checks: Vashtari champion, Excalibur, and abandoning Vashtar.
-- Run with: ./crawl.exe -script vashtar_extras_check

local eol = string.char(10)
local fails = 0
local function say(s) crawl.stderr(s .. eol) end
local function check(ok, what)
    if ok then say("  PASS  " .. what) else say("  FAIL  " .. what); fails = fails + 1 end
end
local function arena()
    for dx = -4, 4 do for dy = -4, 4 do dgn.grid(20 + dx, 20 + dy, "floor") end end
    you.moveto(20, 20)
end

say("== Vashtari champion ==")
you.init("HuFi", "long sword")
arena()
local m = dgn.create_monster(23, 23, "Vashtari champion")
check(m ~= nil and m.name == "Vashtari champion", "can place a Vashtari champion")
if m then
    local desc = m.name .. " HD " .. m.hd .. ", god " .. tostring(m.god)
    say("  " .. desc)
    local weapons = 0
    for _, it in ipairs(m.inventory and m.inventory() or {}) do
        if it.class(true) == "weapon" then weapons = weapons + 1 end
    end
    say("  weapons carried: " .. weapons)
    check(m.hd >= 17, "a high-level foe")
    m.dismiss()
end

say("== Excalibur ==")
dgn.create_item(21, 20, "Excalibur pre_id")
local ex = nil
for _, it in ipairs(dgn.items_at(21, 20)) do
    if string.find(it.name(), "Excalibur", 1, true) then ex = it end
end
check(ex ~= nil, "Excalibur exists")
if ex then
    say("  " .. ex.name() .. ": dmg " .. tostring(ex.damage) .. ", acc " .. tostring(ex.accuracy))
    check(ex.plus == 9 and ex.damage == 14, "+9 bastard sword")
    check(string.find(ex.name(), "holy", 1, true) ~= nil or ex.ego() == "holy wrath",
          "holy wrath brand")
end

say("== Abandoning Vashtar ==")
you.init("HuWM", "long sword")
arena()
say("  god: " .. you.god())
check(you.god() == "Vashtar", "Wrathful Monks start with Vashtar")
local s0, i0, d0 = you.strength(), you.intelligence(), you.dexterity()
debug.vashtar_tithe(0)   -- Str
debug.vashtar_tithe(2)   -- Dex
local s1, d1 = you.strength(), you.dexterity()
check(s1 == s0 + 2 and d1 == d0 + 2, "tithes raised Str and Dex")

-- Give a Vashtar gift weapon in the pack.
dgn.create_item(20, 20, "battleaxe pre_id")
for _, it in ipairs(dgn.items_at(20, 20)) do items.pickup(it) end
local gift_slot = nil
for slot = 0, 51 do
    local it = items.inslot(slot)
    if it and it.name("base") and string.find(it.name(), "battleaxe", 1, true) then gift_slot = slot end
end
if gift_slot then debug.mark_vashtar_gift(gift_slot) end
check(gift_slot ~= nil, "a gifted weapon is in the pack")

debug.abandon_god()
check(you.god() == "No God", "abandoned Vashtar")
-- Tithes now stay until a collector reclaims them (or the debt is broken).
check(you.strength() > s0 or you.dexterity() > d0,
      "the tithed blood is kept until a collector reclaims it")

local still_have = false
for slot = 0, 51 do
    local it = items.inslot(slot)
    if it and string.find(it.name(), "battleaxe", 1, true) then still_have = true end
end
check(not still_have, "the gifted weapon left the pack")
local dancer = false
for mm in test.level_monster_iterator() do
    if string.find(mm.name, "battleaxe", 1, true) then dancer = true; say("  rebel: " .. mm.name) end
end
check(dancer, "the gifted weapon rose up as a dancing weapon")

say(fails == 0 and "ALL CHECKS PASSED" or (fails .. " CHECK(S) FAILED"))
assert(fails == 0, fails .. " checks failed")
