-- Checks the Angel species: starting god, traits, moving between the holy
-- trio, and the fall into a Fallen Angel.
-- Run with: ./crawl.exe -script angel_check

local eol = string.char(10)
local fails = 0
local function say(s) crawl.stderr(s .. eol) end
local function check(ok, what)
    if ok then say("  PASS  " .. what) else say("  FAIL  " .. what); fails = fails + 1 end
end
local good = { ["the Shining One"] = true, ["Zin"] = true, ["Elyvilon"] = true }

say("== A new Angel ==")
you.init("AnFi", "long sword")
say("  " .. you.race() .. " " .. you.class() .. ", god: " .. you.god() .. ", piety " .. you.piety())
check(you.race() == "Angel", "can play an Angel Fighter")
check(good[you.god()], "starts in the service of one of the holy trio")
check(you.piety() > 0, "starts with some piety")
check(you.see_invisible(), "sees invisible")
check(you.res_draining() >= 1, "resists negative energy")
check(not you.flying(), "can't fly yet at XL 1")
you.set_xl(7)
check(you.flying(), "flies from XL 7")

say("== Moving between the holy trio ==")
local target = you.god() == "Zin" and "Elyvilon" or "Zin"
local ok, why = debug.join_god(target)
check(ok, "can move to " .. target .. " " .. why)
check(you.race() == "Angel", "still an Angel after serving another good god")

say("== The fall ==")
local str0 = you.strength()
debug.abandon_god()
say("  now: " .. you.race() .. ", god: " .. you.god() .. ", Str " .. str0 .. " -> " .. you.strength())
check(you.race() == "Fallen Angel", "abandoning the holy trio makes you a Fallen Angel")
check(you.strength() == str0 + 2, "the fall grants +2 Str")
check(you.flying(), "a Fallen Angel keeps their wings")
check(you.see_invisible(), "a Fallen Angel keeps their sight")
check(you.res_draining() >= 2, "a Fallen Angel resists negative energy more strongly")
for _, g in ipairs({ "the Shining One", "Zin", "Elyvilon" }) do
    local joined, reason = debug.join_god(g)
    check(not joined, g .. " refuses a Fallen Angel (" .. reason .. ")")
end
local joined = debug.join_god("Makhleb")
check(joined, "a Fallen Angel can serve a darker god")

say("== Converting away also causes the fall ==")
you.init("AnGl", "long sword")
check(you.race() == "Angel", "fresh Angel Gladiator")
check(debug.join_god("Okawaru"), "an Angel can convert to Okawaru...")
check(you.race() == "Fallen Angel", "...and falls for it")

if fails == 0 then
    say("ALL CHECKS PASSED")
else
    say(fails .. " CHECK(S) FAILED")
    error(fails .. " checks failed")
end
