-- Checks the crown and the Hollowkin species.
-- Run with: ./crawl.exe -script crown_hollowkin_check

local eol = string.char(10)
local fails = 0
local function say(s) crawl.stderr(s .. eol) end
local function check(ok, what)
    if ok then say("  PASS  " .. what) else say("  FAIL  " .. what); fails = fails + 1 end
end

local function floor_around()
    for dx = -3, 3 do
        for dy = -3, 3 do dgn.grid(20 + dx, 20 + dy, "floor") end
    end
    you.moveto(20, 20)
end

say("== Hollowkin ==")
you.init("HkFi", "long sword")
floor_around()
local mp, max_mp = you.mp()
say(string.format("  %s %s: Str %d Int %d Dex %d, MP %d/%d",
    you.species(), you.class(), you.strength(), you.intelligence(),
    you.dexterity(), mp, max_mp))
check(you.species() == "Hollowkin", "can play a Hollowkin Fighter")
check(max_mp == 0, "has no MP")
check(you.get_base_mutation_level("no magic") == 1, "innate no magic")
check(you.get_base_mutation_level("devout") == 1, "innate devout")
check(not you.can_train_skill("Spellcasting"), "can't train Spellcasting")
check(not you.can_train_skill("Fire Magic"), "can't train magic schools")
check(you.can_train_skill("Fighting"), "can still train Fighting")

assert(you.set_xl(10, false))
local mp10, max_mp10 = you.mp()
check(max_mp10 == 0, "still no MP at XL 10")

-- Compare piety from ally kills: a devout Hollowkin vs a Vanara, both
-- Wrathful Monks of Vashtar.
local function ally_kill_piety(combo)
    you.init(combo, "quarterstaff")
    floor_around()
    you.piety(30)
    local start = you.piety()
    for i = 1, 100 do
        local ally = dgn.create_monster(21, 19, "orc warrior att:friendly")
        local foe = dgn.create_monster(21, 20, "goblin")
        if ally and foe then
            foe.set_hp(1)
            for t = 1, 6 do
                if not dgn.mons_at(21, 20) then break end
                ally.add_energy(200)
                ally.handle_behaviour()
                ally.run_ai()
            end
        end
        for _, y in ipairs({19, 20}) do
            local m = dgn.mons_at(21, y)
            if m then m.dismiss() end
        end
    end
    return you.piety() - start
end
local vanara = ally_kill_piety("VaWM")
local hollowkin = ally_kill_piety("HkWM")
say(string.format("  piety from 100 ally kills: Vanara +%d, Hollowkin +%d",
    vanara, hollowkin))
check(hollowkin > vanara * 1.2, "Hollowkin gain noticeably more piety")

say("== Crowns vs hats (300 of each) ==")
local function survey(name, y)
    for i = 1, 300 do dgn.create_item(22, y, name .. " pre_id") end
    local n, total_plus, egos, arts = 0, 0, 0, 0
    for _, it in ipairs(dgn.items_at(22, y)) do
        n = n + 1
        total_plus = total_plus + it.plus
        if it.artefact then arts = arts + 1
        elseif it.ego_type ~= "" and it.ego_type ~= "normal" then
            egos = egos + 1
        end
    end
    say(string.format("  %s: %d made, avg plus %.2f, %d egos, %d artefacts",
        name, n, total_plus / math.max(n, 1), egos, arts))
    return n, total_plus / math.max(n, 1), egos, arts
end
local cn, cplus, cegos, carts = survey("crown", 20)
local hn, hplus, hegos, harts = survey("hat", 21)
check(cn > 0, "crowns can be generated")
check(cplus > hplus + 0.5, "crowns are more enchanted than hats")
check(cegos > hegos, "crowns get egos more often than hats")

say("== Lightsaber \"Vaapad\" ==")
dgn.create_item(22, 22, 'lightsaber "Vaapad" pre_id')
local saber = nil
for _, it in ipairs(dgn.items_at(22, 22)) do
    if string.find(it.name(), "Vaapad", 1, true) then saber = it end
end
check(saber ~= nil, "Vaapad can be generated")
if saber then
    say(string.format("  %s: plus %s, ego %s, artefact %s",
        saber.name(), tostring(saber.plus), tostring(saber.ego_type),
        tostring(saber.artefact)))
    check(saber.plus == 12, "is +12")
    say("  base damage: " .. tostring(saber.damage))
    check(saber.damage == 10, "is a long sword (base damage 10)")
    check(saber.ego_type == "electrocution", "has the electrocution brand")
end

say(fails == 0 and "ALL CHECKS PASSED" or (fails .. " CHECK(S) FAILED"))
assert(fails == 0, fails .. " checks failed")
