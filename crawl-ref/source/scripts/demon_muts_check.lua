-- Checks the custom Demonspawn changes: demonic wings, golden scales,
-- and removal of the magic facets. Run with: ./crawl.exe -script demon_muts_check

local eol = string.char(10)
local fails = 0
local function say(s) crawl.stderr(s .. eol) end
local function check(ok, what)
    if ok then say("  PASS  " .. what) else say("  FAIL  " .. what); fails = fails + 1 end
end

-- losing/gaining flight needs a real map position
local place = dgn.point(20, 20)
dgn.grid(place.x, place.y, "floor")
dgn.grid(place.x + 1, place.y, "floor")
you.moveto(place.x, place.y)

-- A Demonspawn's queued facets can block a second scale type, so test the
-- mutations' effects on a plain human.
local function fresh_demonspawn()
    you.delete_all_mutations("check")
    assert(you.set_xl(1, false))
    assert(you.change_species("human"))
    you.delete_all_mutations("check")
end

------------------------------------------------------------------
say("== Demonic wings ==")
fresh_demonspawn()
local ac0, dex0 = you.ac(), you.dexterity()
say(string.format("  base: AC %d, Dex %d, flying %s, cloak slot open %s",
    ac0, dex0, tostring(you.flying()), tostring(items.slot_is_available("cloak"))))
local want = { {2, 1}, {4, 2}, {6, 3} }
for lvl = 1, 3 do
    you.mutate("demonic wings", "check")
    local ac, dex = you.ac() - ac0, you.dexterity() - dex0
    say(string.format("  level %d: AC +%d, Dex +%d, flying %s, cloak slot open %s",
        you.get_base_mutation_level("demonic wings"), ac, dex,
        tostring(you.flying()), tostring(items.slot_is_available("cloak"))))
    check(you.get_base_mutation_level("demonic wings") == lvl, "wings at level " .. lvl)
    check(ac == want[lvl][1], "AC +" .. want[lvl][1] .. " at level " .. lvl)
    check(dex == want[lvl][2], "Dex +" .. want[lvl][2] .. " at level " .. lvl)
    check(you.flying() == (lvl == 3), "flying only at level 3")
    check(items.slot_is_available("cloak") == (lvl < 3), "cloak blocked only at level 3")
end
you.delete_mutation("demonic wings", "check")
check(not you.flying(), "lands again after losing level 3")

------------------------------------------------------------------
say("== Golden scales ==")
fresh_demonspawn()
ac0 = you.ac()
local rf0, rc0, rp0 = you.res_fire(), you.res_cold(), you.res_poison()
local want_ac = {3, 4, 6}
for lvl = 1, 3 do
    you.mutate("golden scales", "check")
    local ac = you.ac() - ac0
    local rf, rc, rp = you.res_fire() - rf0, you.res_cold() - rc0, you.res_poison() - rp0
    say(string.format("  level %d: AC +%d, rF +%d, rC +%d, rPois +%d",
        you.get_base_mutation_level("golden scales"), ac, rf, rc, rp))
    check(ac == want_ac[lvl], "AC +" .. want_ac[lvl] .. " at level " .. lvl)
    local res = (lvl == 3) and 1 or 0
    check(rf == res and rc == res and rp == res,
          "resistances " .. (res == 1 and "granted" or "absent") .. " at level " .. lvl)
end

------------------------------------------------------------------
say("== Facet rolls (300 random XL27 Demonspawn) ==")
local magic = {"big brain", "demonic magic", "magic regeneration", "magic shield",
               "magic link", "bedevilling", "black mark", "aura of silence"}
local seen = {}
local wings_seen, golden_seen = 0, 0
for i = 1, 300 do
    you.delete_all_mutations("check")
    assert(you.set_xl(1, false))
    assert(you.change_species("human"))
    assert(you.change_species("demonspawn"))
    assert(you.set_xl(27, false))
    for _, m in ipairs(magic) do
        if you.get_base_mutation_level(m) > 0 then seen[m] = (seen[m] or 0) + 1 end
    end
    if you.get_base_mutation_level("demonic wings") > 0 then wings_seen = wings_seen + 1 end
    if you.get_base_mutation_level("golden scales") > 0 then golden_seen = golden_seen + 1 end
end
for _, m in ipairs(magic) do
    check(not seen[m], m .. " never rolled" .. (seen[m] and (" (seen " .. seen[m] .. "x)") or ""))
end
say(string.format("  demonic wings rolled in %d/300, golden scales in %d/300", wings_seen, golden_seen))
check(wings_seen > 0, "demonic wings can roll")
check(golden_seen > 0, "golden scales can roll")
say("  sample final character: " .. you.mutation_overview())

------------------------------------------------------------------
-- skill_cost is relative to Human Fighting, which also got +1, so a
-- species' costs relative to each other are what we can see here.
you.delete_all_mutations("check")
assert(you.set_xl(1, false))
assert(you.change_species("human"))

------------------------------------------------------------------
say("== Vanara ==")
local ev_h = you.ev()
assert(you.change_species("vanara"))
say("  species: " .. you.species() .. ", genus: " .. you.genus())
check(you.species() == "Vanara", "can become a Vanara")
check(you.get_base_mutation_level("shaggy fur") == 1, "innate fur")
check(you.get_base_mutation_level("fangs") == 1, "innate fangs")
check(you.get_base_mutation_level("prehensile tail") == 1, "innate prehensile tail")
say(string.format("  EV %d (as human %d)", you.ev(), ev_h))
check(you.ev() >= ev_h + 3, "tail gives +3 EV")
local t, s, f = you.skill_cost("Throwing"), you.skill_cost("Spellcasting"), you.skill_cost("Alchemy")
say(string.format("  skill cost: throwing %s, spellcasting %s, alchemy %s",
    tostring(t), tostring(s), tostring(f)))
check(t ~= nil and t < 0.65,"throwing is cheap (3 better than human fighting)")
check(s ~= nil and s > 1.0, "spellcasting is expensive")
say("  mutations: " .. you.mutation_overview())

------------------------------------------------------------------
say("== Ruyi Jingu Bang ==")
check(not you.unrands("Ruyi Jingu Bang"), "not generated yet")
local ok, err = pcall(dgn.create_item, 21, 20, "Ruyi Jingu Bang")
if not ok then say("  create_item error: " .. tostring(err)) end
check(ok and you.unrands("Ruyi Jingu Bang"), "can be generated in the dungeon")

say(fails == 0 and "ALL CHECKS PASSED" or (fails .. " CHECK(S) FAILED"))
you.delete_all_mutations("check")
assert(fails == 0, fails .. " checks failed")
