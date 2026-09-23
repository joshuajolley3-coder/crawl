-- Checks themed Dungeon floors: how often they happen, that their monsters
-- come from the theme, that the look and the resistance item are there.
-- Run with: ./crawl.exe -script floor_theme_check

local eol = string.char(10)
local fails = 0
local function say(s) crawl.stderr(s .. eol) end
local function check(ok, what)
    if ok then say("  PASS  " .. what) else say("  FAIL  " .. what); fails = fails + 1 end
end

-- Themes that always leave a ring somewhere on the floor.
local ring_themes = { Death = true, Arcane = true, Venom = true, Warband = true }

you.init("HuFi", "long sword")
local total, themed, early_themed = 0, 0, 0
local per_theme, in_theme, out_theme = {}, 0, 0
local tiles_ok, rings_ok, ring_floors = 0, 0, 0
local shown = {}
offnames = {}

for rep = 1, 7 do
    for depth = 1, 15 do
        debug.goto_place("D:" .. depth)
        test.regenerate_level(nil, true)
        total = total + 1
        local theme, list, tiles = debug.floor_theme()
        if theme ~= "" then
            themed = themed + 1
            if depth < 3 then early_themed = early_themed + 1 end
            per_theme[theme] = (per_theme[theme] or 0) + 1
            if tiles then tiles_ok = tiles_ok + 1
            else say("    no themed tiles on D:" .. depth .. " (" .. theme .. ")") end

            local allowed = {}
            for _, n in ipairs(list) do allowed[n] = true end
            local names = {}
            for m in test.level_monster_iterator() do
                -- Band members and vault monsters can be off-theme; count the rest.
                local base = m.name
                if allowed[base] then in_theme = in_theme + 1
                elseif not (string.find(base, "plant") or string.find(base, "fungus")
                            or string.find(base, "bush") or string.find(base, "toadstool")) then
                    out_theme = out_theme + 1
                    offnames[base] = (offnames[base] or 0) + 1
                end
                names[#names + 1] = base
            end
            if not shown[theme] then
                shown[theme] = true
                table.sort(names)
                say(string.format("  D:%d %s: %s", depth, theme, table.concat(names, ", ")))
            end

            if ring_themes[theme] then
                ring_floors = ring_floors + 1
                local found = false
                for x = 1, 78 do for y = 1, 68 do
                    for _, it in ipairs(dgn.items_at(x, y)) do
                        if it.class(true) == "jewellery" then found = true end
                    end
                end end
                if found then rings_ok = rings_ok + 1 end
            end
        end
    end
end

local parts = {}
for t, c in pairs(per_theme) do parts[#parts + 1] = t .. " " .. c end
table.sort(parts)
say(string.format("  %d of %d floors themed (%.0f%%): %s", themed, total,
    100 * themed / total, table.concat(parts, ", ")))
say(string.format("  monsters on themed floors: %d from the theme, %d others (vaults, bands)",
    in_theme, out_theme))
local offl = {}
for n, c in pairs(offnames) do offl[#offl + 1] = { n, c } end
table.sort(offl, function(a, b) return a[2] > b[2] end)
local top = {}
for i = 1, math.min(25, #offl) do top[#top + 1] = offl[i][1] .. " " .. offl[i][2] end
say("  most common others: " .. table.concat(top, ", "))
check(early_themed == 0, "D:1-2 are never themed")
local eligible = total * 13 / 15
check(themed >= eligible * 0.12 and themed <= eligible * 0.42, "about 1 in 4 eligible floors is themed")
check(in_theme > out_theme, "themed floors are mostly the theme's monsters "
      .. "(the rest come from hand-built vaults and bands)")

-- Every random spawn on a themed floor should come from the theme.
say("== Random spawns on each theme (D:5 and D:13) ==")
local all_ok = true
for t = 1, 7 do
    for _, depth in ipairs({ 5, 13 }) do
        debug.goto_place("D:" .. depth)
        test.regenerate_level(nil, true)
        debug.dismiss_monsters()
        debug.set_floor_theme(t)
        local theme, list = debug.floor_theme()
        local allowed = {}
        for _, n in ipairs(list) do allowed[n] = true end
        local counts, inn, n = {}, 0, 0
        for i = 1, 40 do
            for m in test.level_monster_iterator() do m.dismiss() end
            local placed = false
            for x = 10, 70 do
                for y = 10, 60 do
                    if not placed and dgn.grid(x, y) == dgn.fnum("floor") then
                        local m = dgn.create_monster(x, y, "random")
                        if m then
                            n = n + 1
                            counts[m.name] = (counts[m.name] or 0) + 1
                            if allowed[m.name] then inn = inn + 1 end
                        end
                        placed = true
                    end
                end
            end
        end
        local l = {}
        for k, c in pairs(counts) do l[#l + 1] = k .. " " .. c end
        table.sort(l)
        say(string.format("  %-7s D:%-2d %d/%d: %s", theme, depth, inn, n, table.concat(l, ", ")))
        if inn ~= n then all_ok = false end
    end
end
check(all_ok, "every random spawn on a themed floor is from its theme")
-- A few whole-level layouts pick their own tiles; those are left alone.
check(tiles_ok >= themed * 0.7, "themed floors get their themed tiles")
check(ring_floors == 0 or rings_ok == ring_floors, "ring themes always leave a ring")

say(fails == 0 and "ALL CHECKS PASSED" or (fails .. " CHECK(S) FAILED"))
assert(fails == 0, fails .. " checks failed")
