-- Which monster/item spellings work, for the Battlefield map.
local eol = string.char(10)
local function say(s) crawl.stderr(s .. eol) end
you.init("HuFi", "long sword")
for dx = -4, 4 do for dy = -4, 4 do dgn.grid(20 + dx, 20 + dy, "floor") end end
you.moveto(20, 20)
for _, n in ipairs({ "human draugr", "orc draugr", "ogre draugr", "troll draugr",
                     "human zombie", "orc zombie",
                     "skeletal warrior", "wight", "phantom", "wraith", "bog body",
                     "dancing weapon", "Veyrak", "flayed ghost", "shadow wraith" }) do
    local m = dgn.create_monster(24, 24, n)
    say(string.format("  mons %-16s -> %s", n, m and m.name or "FAILED"))
    if m then m.dismiss() end
end
for _, n in ipairs({ "human skeleton", "orc skeleton", "human corpse", "any weapon mundane",
                     "long sword mundane", "chain mail mundane" }) do
    dgn.create_item(17, 17, n)
    local its = dgn.items_at(17, 17)
    local last = its[#its]
    say(string.format("  item %-20s -> %s", n, last and last.name() or "FAILED"))
end
