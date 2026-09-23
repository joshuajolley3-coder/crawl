-- Checks Vashtar and the Wrathful Monk background.
-- Run with: ./crawl.exe -script vashtar_check

local eol = string.char(10)
local fails = 0
local function say(s) crawl.stderr(s .. eol) end
local function check(ok, what)
    if ok then say("  PASS  " .. what) else say("  FAIL  " .. what); fails = fails + 1 end
end

say("== Wrathful Monk start ==")
you.init("VaWM", "quarterstaff")
debug.goto_place("D:1")
test.regenerate_level(nil, true)
debug.dismiss_monsters()
say("  " .. you.species() .. " " .. you.class() .. " of " .. you.god()
    .. ", piety " .. you.piety() .. ", rank " .. you.piety_rank())
check(you.species() == "Vanara", "Vanara can be a Wrathful Monk")
check(you.class() == "Wrathful Monk", "background is Wrathful Monk")
check(you.god() == "Vashtar", "starts worshipping Vashtar")
check(you.piety_rank() >= 2, "starts at 2 stars or more")
check(you.base_skill("Invocations") > 0, "starts with Invocations skill")

for dx = -3, 3 do
    for dy = -3, 3 do dgn.grid(20 + dx, 20 + dy, "floor") end
end
you.moveto(20, 20)
-- Scripts don't refresh line of sight on their own.
debug.los_changed()
crawl.redraw_view()

local function clear(x, y)
    local m = dgn.mons_at(x, y)
    if m then m.dismiss() end
end

say("== Piety from deaths you only witness ==")
say("  can see (22,20): " .. tostring(you.see_cell(22, 20))
    .. ", own square: " .. tostring(you.see_cell(you.pos())))
you.piety(60)
local p0 = you.piety()
local burned = 0
for i = 1, 80 do
    local m = dgn.create_monster(22, 20, "goblin")
    if m then
        m.set_hp(1)
        dgn.place_cloud(22, 20, "flame", 10, "other")
        for t = 1, 3 do
            if not dgn.mons_at(22, 20) then break end
            m.add_energy(200)
            m.run_ai()
        end
        if dgn.mons_at(22, 20) then clear(22, 20) else burned = burned + 1 end
    end
end
say(string.format("  %d goblins burned to death, piety %d -> %d",
    burned, p0, you.piety()))
check(burned > 0, "monsters died to something other than you")
if you.see_cell(you.pos()) then
    check(you.piety() > p0, "deaths in sight give piety")
else
    -- Script mode leaves the player "off-level", so nothing is ever in sight.
    say("  SKIP  deaths in sight give piety (no line of sight in script mode)")
end

-- Dismissing monsters isn't a death, so it must not give piety.
you.piety(60)
for i = 1, 60 do
    local m = dgn.create_monster(22, 20, "goblin")
    if m then m.dismiss() end
end
check(you.piety() == 60, "removed (not killed) monsters give no piety")

say("== Kills by your allies ==")
you.piety(60)
p0 = you.piety()
local kills = 0
for i = 1, 40 do
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
        if dgn.mons_at(21, 20) then clear(21, 20) else kills = kills + 1 end
    end
    clear(21, 19)
    clear(21, 20)
end
say(string.format("  allies killed %d goblins, piety %d -> %d",
    kills, p0, you.piety()))
check(kills > 0, "allies can kill")
check(you.piety() > p0, "ally kills give piety")

say("== Wrath ==")
local weak = false
for i = 1, 8 do
    debug.god_wrath("Vashtar", true)
    if you.status("weakened") then weak = true end
end
local demons = 0
for x = 1, 78 do
    for y = 1, 68 do
        local m = dgn.mons_at(x, y)
        if m and m.has_prop("dummy_never_set") == false
           and string.find("hellwing orange demon ynoxinul smoke demon "
                           .. "executioner balrug reaper", m.name, 1, true) then
            demons = demons + 1
        end
    end
end
say(string.format("  after 8 wraths: %d war demons on the level, weakened: %s",
    demons, tostring(weak)))
check(demons > 0 or weak, "Vashtar's wrath does something")

say(fails == 0 and "ALL CHECKS PASSED" or (fails .. " CHECK(S) FAILED"))
assert(fails == 0, fails .. " checks failed")
