-- Checks: bastard sword, beast hide robe, and how Beastkin compare with
-- other species. Run with: ./crawl.exe -script gear_balance_check

local eol = string.char(10)
local fails = 0
local function say(s) crawl.stderr(s .. eol) end
local function check(ok, what)
    if ok then say("  PASS  " .. what) else say("  FAIL  " .. what); fails = fails + 1 end
end
local function arena()
    for dx = -3, 3 do
        for dy = -3, 3 do dgn.grid(20 + dx, 20 + dy, "floor") end
    end
    you.moveto(20, 20)
end
local function make(spec, x, y, want)
    dgn.create_item(x, y, spec)
    for _, it in ipairs(dgn.items_at(x, y)) do
        if string.find(it.name(), want, 1, true) then return it end
    end
end

say("== New gear ==")
you.init("HuFi", "long sword")
arena()
local bs = make("bastard sword plus:0 pre_id", 18, 18, "bastard sword")
local ls = make("long sword plus:0 pre_id", 19, 18, "long sword")
local gs = make("great sword plus:0 pre_id", 20, 18, "great sword")
check(bs ~= nil, "can create a bastard sword")
if bs and ls and gs then
    say(string.format("  bastard sword: dmg %d, acc %d, delay %d, hands %d",
        bs.damage, bs.accuracy, bs.delay, bs.hands))
    say(string.format("  long sword:    dmg %d, acc %d, delay %d, hands %d",
        ls.damage, ls.accuracy, ls.delay, ls.hands))
    say(string.format("  great sword:   dmg %d, acc %d, delay %d, hands %d",
        gs.damage, gs.accuracy, gs.delay, gs.hands))
    check(bs.hands == 1, "bastard sword is one-handed for a human")
    check(bs.damage > ls.damage and bs.damage < gs.damage,
          "bastard sword hits harder than a long sword, less than a great sword")
    check(bs.accuracy < ls.accuracy, "bastard sword is less accurate")
end

local hr = make("beast hide robe plus:0 pre_id", 18, 19, "beast hide robe")
local rb = make("robe plus:0 pre_id", 19, 19, "robe")
local la = make("leather armour plus:0 pre_id", 20, 19, "leather armour")
check(hr ~= nil, "can create a beast hide robe")
if hr and rb and la then
    say(string.format("  beast hide robe: AC %d, encumbrance %d", hr.ac, hr.encumbrance))
    say(string.format("  robe:            AC %d, encumbrance %d", rb.ac, rb.encumbrance))
    say(string.format("  leather armour:  AC %d, encumbrance %d", la.ac, la.encumbrance))
    check(hr.ac > rb.ac and hr.ac > la.ac, "beast hide robe has more AC than robe and leather")
    check(hr.encumbrance == 0, "beast hide robe has no encumbrance")
end

say("== Species comparison (Fighter) ==")
local function profile(sp, xl)
    you.init(sp .. "Fi", "long sword")
    arena()
    if xl > 1 then assert(you.set_xl(xl, false)) end
    local _, mhp = you.hp()
    return mhp, you.strength(), you.intelligence(), you.dexterity()
end
local rows = {}
for _, sp in ipairs({ "Hu", "Dg", "Mi", "Tr", "Gr", "Bk" }) do
    local h1, s1, i1, d1 = profile(sp, 1)
    local h27, s27, i27, d27 = profile(sp, 27)
    rows[sp] = { h27, s27 + i27 + d27 }
    say(string.format("  %s  XL1: HP %3d  Str %2d Int %2d Dex %2d | XL27: HP %3d  Str %2d Int %2d Dex %2d  (stat total %d)",
        sp, h1, s1, i1, d1, h27, s27, i27, d27, s27 + i27 + d27))
end
check(rows.Bk[2] >= rows.Dg[2] - 3, "Beastkin stat total keeps up with Demigods")
check(rows.Bk[1] >= rows.Hu[1], "Beastkin have at least human HP")
you.init("BkFi", "long sword")
check(you.get_base_mutation_level("regeneration") == 1, "Beastkin heal quickly")

say(fails == 0 and "ALL CHECKS PASSED" or (fails .. " CHECK(S) FAILED"))
assert(fails == 0, fails .. " checks failed")
