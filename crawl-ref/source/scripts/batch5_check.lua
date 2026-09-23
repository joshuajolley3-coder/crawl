-- Checks: Excalibur's requirements, the King's Regalia, the Brawler and bags
-- of sand, blood altars, the suspicious figure, and Vashtar's blood debt.
-- Run with: ./crawl.exe -script batch5_check

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
local function pick_up(spec)
    dgn.create_item(20, 20, spec)
    for _, it in ipairs(dgn.items_at(20, 20)) do items.pickup(it) end
    for slot = 0, 51 do
        local it = items.inslot(slot)
        if it and not it.equipped and string.find(it.name(), spec:match("^(%S+)"), 1, true) then
            return slot, it
        end
    end
end
local function max_hp() local _, m = you.hp(); return m end

say("== Excalibur ==")
you.init("HuFi", "long sword")
arena()
local slot = pick_up("Excalibur pre_id")
check(slot ~= nil, "picked up Excalibur")
if slot then
    local ok, why = debug.can_equip(slot)
    say("  Human fighter (Str " .. you.strength() .. "): " .. why)
    check(not ok, "too weak to wield it")
end
you.init("TrFi", "long sword")
arena()
debug.vashtar_tithe(0)                                        -- Str
for i = 1, 3 do debug.vashtar_tithe(2); debug.vashtar_tithe(1) end  -- Dex, Int
say(string.format("  Troll now Str %d Dex %d Int %d", you.strength(), you.dexterity(), you.intelligence()))
slot = pick_up("Excalibur pre_id")
if slot then
    local ok = debug.can_equip(slot)
    check(ok, "Str 25 / Dex 15 / Int 10 is worthy")
end

say("== King's Regalia ==")
dgn.create_item(21, 21, "the King's Regalia pre_id")
local reg = nil
for _, it in ipairs(dgn.items_at(21, 21)) do if string.find(it.name(), "Regalia", 1, true) then reg = it end end
check(reg ~= nil, "the King's Regalia exists")
if reg then say("  " .. reg.name()) end

say("== Brawler ==")
you.init("HuBl", "long sword")  -- (weaponless jobs ignore this)
say("  " .. you.class() .. ": Str " .. you.strength() .. ", UC " .. you.skill("Unarmed Combat")
    .. ", Dodging " .. you.skill("Dodging"))
check(you.class() == "Brawler", "can play a Brawler")
local sand = nil
for s = 0, 51 do
    local it = items.inslot(s)
    if it and string.find(it.name(), "sand", 1, true) then sand = it end
end
check(sand ~= nil, "starts with bags of sand")
if sand then say("  carries " .. sand.name()) end
check(you.skill("Unarmed Combat") >= 3, "trained in unarmed combat")

say("== Blood altar ==")
you.init("HuFi", "long sword")
arena()
dgn.grid(20, 20, "blood_altar")
local g0, h0 = you.gold(), max_hp()
check(debug.blood_offer(0), "offered blood for gold")
say(string.format("  gold %d -> %d, max HP %d -> %d", g0, you.gold(), h0, max_hp()))
check(you.gold() > g0 and max_hp() < h0, "paid in blood, got gold")
check(dgn.feature_name(dgn.grid(20, 20)) == "floor", "the altar crumbled")
dgn.grid(20, 20, "blood_altar")
debug.blood_offer(2)
local gift = nil
for _, it in ipairs(dgn.items_at(20, 20)) do gift = it end
check(gift ~= nil, "an evil gift appeared")
if gift then say("  gift: " .. gift.name()) end

say("== Suspicious figure ==")
you.init("HuFi", "long sword")
arena()
local fig = dgn.create_monster(21, 20, "suspicious figure att:neutral")
check(fig ~= nil, "a suspicious figure can appear")
local a, b, gold = debug.figure_offers()
say("  offers: swap for " .. tostring(a) .. "; blood for " .. tostring(b) .. "; blood for "
    .. tostring(gold) .. " gold")
local g1, h1 = you.gold(), max_hp()
check(debug.figure_deal(2), "took the blood-for-gold deal")
say(string.format("  gold %d -> %d, max HP %d -> %d", g1, you.gold(), h1, max_hp()))
check(you.gold() == g1 + gold, "got the promised gold")
local gone = true
for m in test.level_monster_iterator() do if m.name == "suspicious figure" then gone = false end end
check(gone, "the figure left after one deal")

say("== Vashtar's blood debt ==")
you.init("HuWM", "long sword")
arena()
debug.vashtar_tithe(0)
debug.vashtar_tithe(0)
local s0 = you.strength()
debug.abandon_god()
check(you.strength() == s0, "no stats lost on abandoning")
local collector = nil
for m in test.level_monster_iterator() do if m.name == "Vashtari champion" then collector = m end end
check(collector ~= nil, "a blood collector was sent")
if collector then say("  collector HD " .. collector.hd) end
check(debug.kill_monster("Vashtari champion"), "slew the collector")
check(you.strength() == s0, "the tithed Str is kept after winning")

-- And losing to one: let the collector hit us.
you.init("HuWM", "long sword")
arena()
debug.vashtar_tithe(0)
local s1 = you.strength()
debug.abandon_god()
local c2 = nil
for m in test.level_monster_iterator() do if m.name == "Vashtari champion" then c2 = m end end
if c2 then
    for t = 1, 60 do
        if you.strength() < s1 then break end
        c2.add_energy(200); c2.handle_behaviour(); c2.run_ai()
    end
end
say(string.format("  Str %d -> %d after the collector's blows", s1, you.strength()))
check(you.strength() == s1 - 2, "the collector tears the tithe back")

say(fails == 0 and "ALL CHECKS PASSED" or (fails .. " CHECK(S) FAILED"))
assert(fails == 0, fails .. " checks failed")
