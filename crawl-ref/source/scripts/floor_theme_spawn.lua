-- Spawn many random monsters on a forced-theme floor and tally them.
local eol = string.char(10)
local function say(s) crawl.stderr(s .. eol) end
you.init("HuFi", "long sword")
debug.goto_place("D:6")
test.regenerate_level(nil, true)
debug.dismiss_monsters()
debug.set_floor_theme(7) -- Storm
local theme, list = debug.floor_theme()
local allowed = {}
for _, n in ipairs(list) do allowed[n] = true end
local counts, inn, out = {}, 0, 0
for i = 1, 200 do
    for m in test.level_monster_iterator() do m.dismiss() end
    for x = 10, 70 do
        for y = 10, 60 do
            if dgn.grid(x, y) == dgn.fnum("floor") and not dgn.mons_at(x, y) then
                local m = dgn.create_monster(x, y, "random")
                if m then
                    counts[m.name] = (counts[m.name] or 0) + 1
                    if allowed[m.name] then inn = inn + 1 else out = out + 1 end
                end
                goto next
            end
        end
    end
    ::next::
end
local l = {}
for n, c in pairs(counts) do l[#l + 1] = n .. " " .. c end
table.sort(l)
say(theme .. ": " .. inn .. " themed, " .. out .. " other")
say(table.concat(l, ", "))
