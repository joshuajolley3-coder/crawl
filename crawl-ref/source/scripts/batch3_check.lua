-- Checks: new potions, throwing knives, scroll of enslavement, Xom's Treads,
-- alien zapper, Hollowkin silence, champions, Vashtar in temples, Beastkin.
-- Run with: ./crawl.exe -script batch3_check

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

say("== New items ==")
you.init("HuFi", "long sword")
arena()
local specs = {
    { "potion of empowerment pre_id", "empowerment" },
    { "potion of positive mutation pre_id", "positive mutation" },
    { "throwing knife pre_id", "throwing kni" },
    { "scroll of enslavement pre_id", "enslavement" },
    { "Xom's Treads pre_id", "Xom's Treads" },
    { "alien zapper pre_id", "alien zapper" },
}
for i, s in ipairs(specs) do
    local x, y = 17 + i, 17
    dgn.create_item(x, y, s[1])
    local found = nil
    for _, it in ipairs(dgn.items_at(x, y)) do
        if string.find(it.name(), s[2], 1, true) then found = it end
    end
    check(found ~= nil, "can create " .. s[2]
          .. (found and (" -> " .. found.name()) or ""))
end

say("== Champions ==")
for _, name in ipairs({ "vanara champion", "hollowkin champion" }) do
    local m = dgn.create_monster(22, 22, name)
    check(m ~= nil and m.name == name, name .. " can be placed")
    if m then m.dismiss() end
end

say("== Hollowkin silence ==")
you.init("HkFi", "long sword")
check(you.get_base_mutation_level("hollow silence") == 0, "no silence at XL 1")
assert(you.set_xl(12, false))
check(you.get_base_mutation_level("hollow silence") == 1, "hollow silence at XL 12")

-- (Temples can't be checked here: script mode doesn't build them the way a
-- real new game does. Vashtar is a normal temple god; check the Temple in game.)

say("== Beastkin ==")
you.init("BkFi", "long sword")
say(string.format("  XL1: claws %d, fangs %d, forlorn %d, shunned %d",
    you.get_base_mutation_level("claws"), you.get_base_mutation_level("fangs"),
    you.get_base_mutation_level("forlorn"), you.get_base_mutation_level("shunned")))
check(you.species() == "Beastkin", "can play a Beastkin")
check(you.get_base_mutation_level("forlorn") == 1, "cannot worship gods")
check(you.get_base_mutation_level("shunned") == 1, "shunned by shops")
check(you.get_base_mutation_level("claws") == 1 and you.get_base_mutation_level("fangs") == 1,
      "starts with weak claws and a bite")

local seen = {}
local function path()
    for _, p in ipairs({ "wolf blood", "cat blood", "bird blood" }) do
        local lvl = you.get_base_mutation_level(p)
        if lvl > 0 then return p, lvl end
    end
    return nil, 0
end
-- Evolve a fresh Beastkin to the given XL and report what it became.
local function evolve_to(xl)
    you.init("BkFi", "long sword")
    arena()
    local s0, d0, i0 = you.strength(), you.dexterity(), you.intelligence()
    assert(you.set_xl(xl, false))
    local p, lvl = path()
    return p, lvl, you.strength() - s0, you.dexterity() - d0, you.intelligence() - i0
end
for i = 1, 30 do
    local p = evolve_to(6)
    if p then seen[p] = (seen[p] or 0) + 1 end
end
say(string.format("  paths at XL 6 over 30 characters: wolf %d, cat %d, bird %d",
    seen["wolf blood"] or 0, seen["cat blood"] or 0, seen["bird blood"] or 0))
check(seen["wolf blood"] and seen["cat blood"] and seen["bird blood"],
      "all three paths can happen")

local tested = {}
for i = 1, 40 do
    local p, lvl, ds, dd, di = evolve_to(24)
    if p and not tested[p] then
        tested[p] = true
        say(string.format("  XL 24 %s: stage %d, Str +%d, Dex +%d, Int +%d, flying %s, "
                          .. "fur %d, fangs %d, claws %d, SInv %s",
            p, lvl, ds, dd, di, tostring(you.flying()),
            you.get_base_mutation_level("shaggy fur"),
            you.get_base_mutation_level("fangs"),
            you.get_base_mutation_level("claws"), tostring(you.see_invisible())))
        check(lvl == 3, p .. " reaches stage 3 (plus the XL 24 evolution)")
        if p == "wolf blood" then
            check(ds >= 9, "wolfman gains Strength each stage")
            check(you.get_base_mutation_level("shaggy fur") == 3
                  and you.get_base_mutation_level("fangs") == 3, "wolfman fur and bite grow")
        elseif p == "cat blood" then
            check(dd >= 9, "catman gains Dexterity each stage")
            check(you.get_base_mutation_level("claws") == 3, "catman claws grow sharp")
            check(you.see_invisible(), "catman sees invisible")
        else
            check(di >= 9, "birdman gains Intelligence each stage")
            check(you.flying(), "birdman can fly")
        end
    end
    if tested["wolf blood"] and tested["cat blood"] and tested["bird blood"] then break end
end

say(fails == 0 and "ALL CHECKS PASSED" or (fails .. " CHECK(S) FAILED"))
assert(fails == 0, fails .. " checks failed")
