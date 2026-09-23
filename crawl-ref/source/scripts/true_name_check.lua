-- Checks the scroll of true name: items become artefacts with only good new
-- properties, keeping their base type, enchantment and ego.
-- Run with: ./crawl.exe -script true_name_check

local eol = string.char(10)
local fails = 0
local function say(s) crawl.stderr(s .. eol) end
local function check(ok, what)
    if ok then say("  PASS  " .. what) else say("  FAIL  " .. what); fails = fails + 1 end
end

say("== Scroll exists ==")
you.init("HuFi", "long sword")
for dx = -2, 2 do for dy = -2, 2 do dgn.grid(20 + dx, 20 + dy, "floor") end end
you.moveto(20, 20)
local px, py = 21, 20
dgn.create_item(px, py, "scroll of true name pre_id")
local found = false
for _, it in ipairs(dgn.items_at(px, py)) do
    if string.find(it.name(), "true name", 1, true) then found = true end
end
check(found, "can create a scroll of true name")

-- Good-only check: no negative properties (e.g. Str-3, rF-).
local function pure(props)
    for k, v in pairs(props) do
        if k ~= "Brand" and v < 0 then return false, k end
    end
    return true
end

local function stats(it)
    return it.subtype(), it.plus, it.ego(), it.damage, it.ac, it.equipped
end

say("== Naming a Fighter's gear, 25 times ==")
local runs, named, impure = 0, 0, 0
local shown = 0
for trial = 1, 25 do
    you.init("HuFi", "long sword")
    for slot = 0, 51 do
        local it = items.inslot(slot)
        if it and it.class(true) ~= "missile" and (it.class(true) == "weapon"
                                                or it.class(true) == "armour") then
            local b, p, e, d, a, eq = stats(it)
            runs = runs + 1
            if debug.true_name(slot) then
                named = named + 1
                local n = items.inslot(slot)
                local b2, p2, e2, d2, a2, eq2 = stats(n)
                local ok, why = pure(n.artprops or {})
                if not ok then impure = impure + 1; say("    impure: " .. n.name() .. " (" .. why .. ")") end
                if not n.artefact or b2 ~= b or p2 ~= p or d2 ~= d or a2 ~= a or eq2 ~= eq
                   or (e and e ~= "" and e2 ~= e) then
                    fails = fails + 1
                    say(string.format("  FAIL  %s changed: base %s->%s plus %s->%s ego %s->%s",
                        n.name(), tostring(b), tostring(b2), tostring(p), tostring(p2),
                        tostring(e), tostring(e2)))
                end
                if shown < 6 then
                    shown = shown + 1
                    say("    " .. b .. " -> " .. n.name() .. (eq2 and " (still equipped)" or ""))
                end
                if debug.true_name(slot) then
                    fails = fails + 1
                    say("  FAIL  " .. n.name() .. " was named twice")
                end
            end
        end
    end
end
say(string.format("  %d items named out of %d tries", named, runs))
check(named == runs, "every weapon and armour piece could be named")
check(impure == 0, "no named item got a drawback")

say("== Egos and jewellery are kept ==")
local kept = { flaming = 0, ["fire resistance"] = 0, ring = 0 }
local tries = 0
local specs = { "long sword ego:flaming plus:4 pre_id",
                "ring mail ego:fire_resistance plus:2 pre_id",
                "ring of protection plus:3 pre_id" }
for trial = 1, 30 do
    you.init("HuFi", "long sword")
    for dx = -2, 2 do for dy = -2, 2 do dgn.grid(20 + dx, 20 + dy, "floor") end end
    you.moveto(20, 20)
    dgn.create_item(20, 20, specs[(trial - 1) % 3 + 1])
    for _, it in ipairs(dgn.items_at(20, 20)) do items.pickup(it) end
    for slot = 0, 51 do
        local it = items.inslot(slot)
        if it and not it.equipped and not it.artefact
           and (it.class(true) == "weapon" or it.class(true) == "armour"
                                       or it.class(true) == "jewellery") then
            local e, p, sub = it.ego(), it.plus, it.subtype()
            tries = tries + 1
            if debug.true_name(slot) then
                local n = items.inslot(slot)
                if trial <= 3 then
                    say(string.format("    -> %s (plus %s->%s, ego %s->%s)", n.name(),
                        tostring(p), tostring(n.plus), tostring(e), tostring(n.ego())))
                end
                if n.subtype() == sub and n.plus == p and (not e or n.ego() == e) then
                    if n.class(true) == "jewellery" then kept.ring = kept.ring + 1
                    else kept[e] = (kept[e] or 0) + 1 end
                else
                    say(string.format("    changed: %s (plus %s->%s, ego %s->%s)", n.name(),
                        tostring(p), tostring(n.plus), tostring(e), tostring(n.ego())))
                end
            else
                say("    could not be named: " .. it.name())
            end
        end
    end
end
say(string.format("  flaming kept %d/10, fire resistance kept %d/10, ring kept %d/10 (%d items)",
    kept.flaming, kept["fire resistance"], kept.ring, tries))
check(tries > 0, "could pick up test gear")
check(kept.flaming + kept["fire resistance"] + kept.ring == tries,
      "ego, enchantment and type are kept")

say(fails == 0 and "ALL CHECKS PASSED" or (fails .. " CHECK(S) FAILED"))
assert(fails == 0, fails .. " checks failed")
