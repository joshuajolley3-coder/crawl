/*** Debugging functions (dlua only).
 * @module debug
 */
#include "AppHdr.h"

#include "l-libs.h"

#include "act-iter.h"
#include "branch.h"
#include "chardump.h"
#include "cluautil.h"
#include "coordit.h"
#include "dbg-util.h"
#include "dungeon.h"
#include "files.h"
#include "god-wrath.h"
#include "blood-altar.h"
#include "floor-theme.h"
#include "god-abil.h"
#include "player-equip.h"
#include "suspicious-figure.h"
#include "player-stats.h"
#include "item-prop.h"
#include "item-use.h"
#include "items.h"
#include "ability.h"
#include "database.h"
#include "describe.h"
#include "skills.h"
#include "cloud.h"
#include "fight.h"
#include "weather.h"
#include "item-name.h"
#include "potion.h"
#include "mon-util.h"
#include "los.h"
#include "maps.h"
#include "message.h"
#include "mon-act.h"
#include "mon-cast.h"
#include "mon-death.h"
#include "mon-poly.h"
#include "ng-setup.h"
#include "religion.h"
#include "stairs.h"
#include "state.h"
#include "stringutil.h"
#include "tile-env.h"
#include "tileview.h"
#include "unique-creature-list-type.h"
#include "unwind.h"
#include "view.h"
#include "wiz-dgn.h"

// WARNING: This is a very low-level call.
//
// Usage: goto_place("placename", <bind_entrance>)
// "placename" is the name of the place as used in maps, such as "Lair:2",
// "Vaults:$", etc.
//
// If <bind_entrance> is specified, the entrance point of
// the branch specified in place_name is bound to the given level in the
// parent branch (the entrance level should be 1-based). This can be helpful
// when testing scenarios that depend on the absolute depth of the current
// place.
LUAFN(debug_goto_place)
{
    try
    {
        const level_id id = level_id::parse_level_id(luaL_checkstring(ls, 1));
        const int bind_entrance =
            lua_isnumber(ls, 2)? luaL_safe_checkint(ls, 2) : -1;

        if (is_connected_branch(id.branch))
            you.level_stack.clear();
        else
        {
            for (int i = you.level_stack.size() - 1; i >= 0; i--)
                if (you.level_stack[i].id == id)
                    you.level_stack.resize(i);
            if (!player_in_branch(id.branch))
                you.level_stack.push_back(level_pos::current());
        }

        you.goto_place(id);
        if (bind_entrance != -1)
            brentry[you.where_are_you].depth = bind_entrance;
    }
    catch (const bad_level_id &err)
    {
        luaL_error(ls, err.what());
    }
    return 0;
}

LUAWRAP(debug_dungeon_setup, initial_dungeon_setup())

LUAFN(debug_enter_dungeon)
{
    UNUSED(ls);

    init_level_connectivity();

    you.where_are_you = BRANCH_DUNGEON;
    you.depth = 1;

    load_level(DNGN_STONE_STAIRS_DOWN_I, LOAD_START_GAME, level_id());
    return 0;
}

LUAWRAP(debug_down_stairs, down_stairs(DNGN_STONE_STAIRS_DOWN_I))
LUAWRAP(debug_up_stairs, up_stairs(DNGN_STONE_STAIRS_UP_I))

LUAFN(debug_reset_player_data)
{
    UNUSED(ls);
    dgn_reset_player_data();
    init_level_connectivity();
    return 0;
}

LUAFN(debug_generate_level)
{
    msg::suppress mx;
    env.map_knowledge.init(map_cell());
    env.map_forgotten.reset();
    tile_env.remembered_flavour.reset();
    los_changed();
    tile_init_default_flavour();
    tile_clear_flavour();
    tile_new_level(true);
    builder(lua_isboolean(ls, 1)? lua_toboolean(ls, 1) : true);
    update_portal_entrances();
    return 0;
}

LUAFN(debug_reveal_mimics)
{
    UNUSED(ls);
    for (rectangle_iterator ri(1); ri; ++ri)
        if (mimic_at(*ri))
            discover_mimic(*ri);
    return 0;
}

LUAWRAP(debug_los_changed, los_changed())

LUAFN(debug_builder_ignore_depth)
{
    const bool b = lua_toboolean(ls, 1);
    dgn_ignore_depth(b);
    return 0;
}

LUAFN(debug_dump_map)
{
    const int pos = lua_isuserdata(ls, 1) ? 2 : 1;
    const bool builder_output = lua_toboolean(ls, pos + 1);
    if (lua_isstring(ls, pos))
        dump_map(lua_tostring(ls, pos), true, false, builder_output);
    return 0;
}

LUAFN(debug_vault_names)
{
    vector<string> vnames = level_vault_names(true);
    string r;
    r = comma_separated_line(vnames.begin(), vnames.end());
    lua_pushstring(ls, r.c_str());
    return 1;
}

LUAFN(_debug_test_explore)
{
    UNUSED(ls);
#ifdef WIZARD
    debug_test_explore();
#endif
    return 0;
}

LUAFN(debug_bouncy_beam)
{
    coord_def source;
    coord_def target;

    source.x = luaL_safe_checkint(ls, 1);
    source.y = luaL_safe_checkint(ls, 2);
    target.x = luaL_safe_checkint(ls, 3);
    target.y = luaL_safe_checkint(ls, 4);
    int range = luaL_safe_checkint(ls, 5);
    bool findray = false;
    if (lua_gettop(ls) > 5)
        findray = lua_toboolean(ls, 6);

    bolt beam;

    beam.range      = range;
    beam.glyph      = '*';
    beam.colour     = LIGHTCYAN;
    beam.flavour    = BEAM_ELECTRICITY;
    beam.source     = source;
    beam.target     = target;
    beam.pierce     = true;
    beam.draw_delay = 0;

    if (findray)
        beam.chose_ray = find_ray(source, target, beam.ray, opc_solid_see);

    beam.name       = "debug lightning beam";
    beam.short_name = "DEBUG";

    beam.fire();

    return 0;
}

// If env.mons[] is full, dismiss all monsters not near the player.
LUAFN(debug_cull_monsters)
{
    UNUSED(ls);

    // At least one empty space in env.mons
    for (const auto &mons : menv_real)
        if (mons.type == MONS_NO_MONSTER)
            return 0;

    mprf(MSGCH_DIAGNOSTICS, "env.mons[] is full, dismissing non-near monsters");

    // env.mons[] is full
    for (monster_iterator mi; mi; ++mi)
    {
        if (you.see_cell(mi->pos()))
            continue;

        monster_die(**mi, KILL_RESET, NON_MONSTER);
    }

    return 0;
}

LUAFN(debug_dismiss_adjacent)
{
    UNUSED(ls);

    for (adjacent_iterator ai(you.pos()); ai; ++ai)
    {
        monster* mon = monster_at(*ai);

        if (mon)
            monster_die(*mon, KILL_RESET, NON_MONSTER);
    }

    return 0;
}

LUAFN(debug_dismiss_monsters)
{
    UNUSED(ls);

    for (monster_iterator mi; mi; ++mi)
    {
        if (mi)
            monster_die(**mi, KILL_RESET, NON_MONSTER);
    }

    return 0;
}

// Usage: floor_theme() -- returns the current floor's theme name ("" if none),
// its monster names (a table), and whether the themed tiles were applied.
LUAFN(debug_floor_theme)
{
    const floor_theme_type theme = current_floor_theme();
    lua_pushstring(ls, floor_theme_name(theme));
    lua_newtable(ls);
    int i = 1;
    for (monster_type m : floor_theme_monster_list(theme))
    {
        lua_pushstring(ls, mons_type_name(m, DESC_PLAIN).c_str());
        lua_rawseti(ls, -2, i++);
    }
    lua_pushboolean(ls, floor_theme_tiles_applied());
    return 3;
}

// Usage: set_floor_theme(n) -- force theme n (0 = none) on the current level.
LUAFN(debug_set_floor_theme)
{
    const int t = luaL_safe_checkint(ls, 1);
    if (t <= 0 || t >= NUM_FLOOR_THEMES)
        env.properties.erase("floor_theme");
    else
        env.properties["floor_theme"].get_int() = t;
    return 0;
}

// Test hooks for Vashtar: abandon_god(), vashtar_tithe(stat 0-2: Str/Int/Dex),
// mark_vashtar_gift(slot).
LUAFN(debug_abandon_god)
{
    UNUSED(ls);
    excommunication(true);
    return 0;
}

LUAFN(debug_vashtar_tithe)
{
    const stat_type stat = static_cast<stat_type>(luaL_safe_checkint(ls, 1));
    modify_stat(stat, 2, false);
    you.props[VASHTAR_TITHES_KEY] = vashtar_tithes_taken() + 1;
    you.props[VASHTAR_TITHE_STATS_KEY].get_vector().push_back((int)stat);
    return 0;
}

LUAFN(debug_mark_vashtar_gift)
{
    const int slot = luaL_safe_checkint(ls, 1);
    if (slot >= 0 && slot < ENDOFPACK && you.inv[slot].defined())
        you.inv[slot].orig_monnum = -GOD_VASHTAR;
    return 0;
}

// Test hooks for this batch.
// blood_offer(0 gold / 1 mutation / 2 evil gift) -- offer at a blood altar.
LUAFN(debug_blood_offer)
{
    const int b = luaL_safe_checkint(ls, 1);
    PLUARET(boolean, blood_altar_offer(static_cast<blood_boon>(b)));
}

static monster *_nearest_figure()
{
    for (monster_iterator mi; mi; ++mi)
        if (mi->type == MONS_SUSPICIOUS_FIGURE)
            return *mi;
    return nullptr;
}

// figure_offers() -> swap offer name, blood item name, gold amount
LUAFN(debug_figure_offers)
{
    monster *fig = _nearest_figure();
    if (!fig)
        return 0;
    init_figure_offers(*fig);
    lua_pushstring(ls, fig->props["figure_offer_swap"].get_item().name(DESC_A).c_str());
    lua_pushstring(ls, fig->props["figure_offer_item"].get_item().name(DESC_A).c_str());
    lua_pushinteger(ls, fig->props["figure_offer_gold"].get_int());
    return 3;
}

// figure_deal(0 swap / 1 blood item / 2 blood gold, [slot for swap])
LUAFN(debug_figure_deal)
{
    monster *fig = _nearest_figure();
    if (!fig)
        PLUARET(boolean, false);
    const int deal = luaL_safe_checkint(ls, 1);
    const int slot = lua_isnumber(ls, 2) ? luaL_safe_checkint(ls, 2) : -1;
    PLUARET(boolean, take_figure_deal(*fig, static_cast<figure_deal>(deal), slot));
}

// can_equip(slot) -> bool, reason
LUAFN(debug_can_equip)
{
    const int slot = luaL_safe_checkint(ls, 1);
    string reason;
    const bool ok = slot >= 0 && slot < ENDOFPACK && you.inv[slot].defined()
                    && can_equip_item(you.inv[slot], true, &reason);
    lua_pushboolean(ls, ok);
    lua_pushstring(ls, reason.c_str());
    return 2;
}

// drink(slot) -> bool: quaff the potion in that inventory slot.
// drink("titan's blood") -> bool: quaff a potion of that type directly.
LUAFN(debug_drink)
{
    if (lua_type(ls, 1) == LUA_TSTRING)
    {
        const string want = lua_tostring(ls, 1);
        for (int i = 0; i < NUM_POTIONS; ++i)
        {
            const potion_type pot = static_cast<potion_type>(i);
            if (item_type_removed(OBJ_POTIONS, pot) || want != potion_type_name(pot))
                continue;
            const PotionEffect *effect = get_potion_effect(pot);
            PLUARET(boolean, you.can_drink(false)
                             && effect->can_quaff(nullptr, false)
                             && effect->quaff(true));
        }
        return luaL_error(ls, "no such potion: %s", want.c_str());
    }
    const int slot = luaL_safe_checkint(ls, 1);
    PLUARET(boolean, slot >= 0 && slot < ENDOFPACK
                     && you.inv[slot].defined()
                     && you.inv[slot].base_type == OBJ_POTIONS
                     && drink(&you.inv[slot]));
}

// join_god("Zin") -> bool, reason: join a god as if at its altar.
LUAFN(debug_join_god)
{
    const god_type god = str_to_god(luaL_checkstring(ls, 1));
    if (god == GOD_NO_GOD || god == NUM_GODS)
    {
        lua_pushboolean(ls, false);
        lua_pushstring(ls, "no such god");
        return 2;
    }
    const string reason = cannot_join_god_reason(god, true);
    if (!reason.empty())
    {
        lua_pushboolean(ls, false);
        lua_pushstring(ls, reason.c_str());
        return 2;
    }
    join_religion(god);
    lua_pushboolean(ls, you_worship(god));
    lua_pushstring(ls, "");
    return 2;
}

// god_pools("Vashtar") -> in the Temple / random altar pool, can be an
// unknown god's faded altar.
LUAFN(debug_god_pools)
{
    const god_type god = str_to_god(luaL_checkstring(ls, 1));
    const vector<god_type> temple = temple_god_list();
    lua_pushboolean(ls, find(temple.begin(), temple.end(), god) != temple.end());
    lua_pushboolean(ls, god_can_be_ecumenical(god));
    return 2;
}

// set_piety(n): set the current god's piety.
LUAFN(debug_set_piety)
{
    you.raw_piety = max(0, min(MAX_PIETY, luaL_safe_checkint(ls, 1)));
    you.piety_max[you.religion] = max<int>(you.piety_max[you.religion],
                                           you.raw_piety);
    set_god_ability_slots();
    return 0;
}

// has_ability("Sun Lance") -> bool: is it among your current abilities?
LUAFN(debug_has_ability)
{
    const string want = luaL_checkstring(ls, 1);
    for (const talent &tal : your_talents(false))
        if (ability_name(tal.which) == want)
            PLUARET(boolean, true);
    PLUARET(boolean, false);
}

// unarmed_bonus() -> the flat bonus added to your unarmed damage.
LUAFN(debug_unarmed_bonus)
{
    PLUARET(number, unarmed_base_damage_bonus(false));
}

// melee_rating() -> the damage rating of your wielded weapon (or fists), as
// shown on the item description screen; also its wielded weapon's skill.
LUAFN(debug_melee_rating)
{
    int rating = 0;
    // melee_rating(true): rate bare fists instead of the wielded weapon.
    const item_def *wpn = lua_toboolean(ls, 1) ? nullptr : you.weapon();
    damage_rating(wpn, &rating);
    lua_pushnumber(ls, rating);
    lua_pushstring(ls, skill_name(wpn ? item_attack_skill(*wpn)
                                      : SK_UNARMED_COMBAT));
    return 2;
}

// has_desc(key) -> bool: does the description database have this entry?
LUAFN(debug_has_desc)
{
    PLUARET(boolean, !trimmed_string(getLongDescription(luaL_checkstring(ls, 1))).empty());
}

// has_start_desc(key) -> bool: species/background description exists?
LUAFN(debug_has_start_desc)
{
    PLUARET(boolean, !trimmed_string(getGameStartDescription(luaL_checkstring(ls, 1))).empty());
}

// item_desc_keys(x, y) -> { {key, has_desc}, ... } for the items on a square,
// using the same lookup name the item description screen uses.
LUAFN(debug_item_desc_keys)
{
    const coord_def p(luaL_safe_checkint(ls, 1), luaL_safe_checkint(ls, 2));
    lua_newtable(ls);
    int i = 1;
    for (stack_iterator si(p); si; ++si)
    {
        // Named artefacts are described by their own unrand.txt entry.
        const string key = is_unrandom_artefact(*si)
            ? get_artefact_name(*si, true)
            : si->name(DESC_DBNAME, true, false, false);
        lua_newtable(ls);
        lua_pushstring(ls, key.c_str());
        lua_rawseti(ls, -2, 1);
        lua_pushboolean(ls, !trimmed_string(getLongDescription(key)).empty());
        lua_rawseti(ls, -2, 2);
        lua_rawseti(ls, -2, i++);
    }
    return 1;
}

// set_skill("Unarmed Combat", 20): set a skill level directly.
LUAFN(debug_set_skill)
{
    const skill_type sk = str_to_skill(luaL_checkstring(ls, 1));
    if (sk == SK_NONE)
        return luaL_error(ls, "no such skill");
    set_skill_level(sk, luaL_safe_checkint(ls, 2));
    return 0;
}

// weather() -> name; set_weather(n); shape_weather(); weather_ticks(n) ->
// clouds in sight afterward.
LUAFN(debug_weather)
{
    lua_pushstring(ls, weather_name(current_weather()));
    return 1;
}

LUAFN(debug_set_weather)
{
    set_weather(static_cast<weather_type>(luaL_safe_checkint(ls, 1)));
    return 0;
}

LUAWRAP(debug_shape_weather, shape_level_for_weather())

LUAFN(debug_weather_ticks)
{
    const int n = luaL_safe_checkint(ls, 1);
    for (int i = 0; i < n; ++i)
        weather_tick();
    int clouds = 0;
    for (rectangle_iterator ri(1); ri; ++ri)
        if (cloud_at(*ri))
            ++clouds;
    PLUARET(number, clouds);
}

// wear(slot) -> bool: put on the armour in that inventory slot, instantly.
LUAFN(debug_wear)
{
    const int slot = luaL_safe_checkint(ls, 1);
    if (slot < 0 || slot >= ENDOFPACK || !you.inv[slot].defined()
        || !can_equip_item(you.inv[slot], true))
    {
        PLUARET(boolean, false);
    }
    const equipment_slot eq = you.inv[slot].base_type == OBJ_WEAPONS
                              ? SLOT_WEAPON : get_armour_slot(you.inv[slot]);
    if (item_def *old = you.equipment.get_first_slot_item(eq))
        unequip_item(*old, false);
    equip_item(eq, slot, false);
    PLUARET(boolean, item_is_equipped(you.inv[slot]));
}

// kill_monster(name) -- kill the first monster with that name, as if slain.
LUAFN(debug_kill_monster)
{
    const string name = luaL_checkstring(ls, 1);
    for (monster_iterator mi; mi; ++mi)
        if (mi->name(DESC_PLAIN, true) == name)
        {
            monster_die(**mi, KILL_YOU, NON_MONSTER);
            PLUARET(boolean, true);
        }
    PLUARET(boolean, false);
}

// Usage: true_name(slot) -- speak the true name of the item in inventory
// slot `slot` (0-based), as a scroll of true name would. Returns success.
LUAFN(debug_true_name)
{
    const int slot = luaL_safe_checkint(ls, 1);
    if (slot < 0 || slot >= ENDOFPACK || !you.inv[slot].defined()
        || !can_true_name(you.inv[slot]))
    {
        PLUARET(boolean, false);
    }
    PLUARET(boolean, awaken_true_name(you.inv[slot]));
}

LUAFN(debug_god_wrath)
{
    const char *god_name = luaL_checkstring(ls, 1);
    if (!god_name)
    {
        string err = "god_wrath requires a god!";
        return luaL_argerror(ls, 1, err.c_str());
    }

    god_type god = strcmp(god_name, "random") ? str_to_god(god_name) : GOD_RANDOM;
    if (god == GOD_NO_GOD)
    {
        string err = make_stringf("'%s' matches no god.", god_name);
        return luaL_argerror(ls, 1, err.c_str());
    }

    bool no_bonus = lua_toboolean(ls, 2);

    divine_retribution(god, no_bonus);
    return 0;
}

LUAFN(debug_handle_monster_move)
{
    MonsterWrap *mw = clua_get_userdata< MonsterWrap >(ls, MONS_METATABLE);
    if (!mw || !mw->mons)
        return 0;

    handle_monster_move(mw->mons);
    return 0;
}

static unique_creature_list saved_uniques;

LUAFN(debug_save_uniques)
{
    UNUSED(ls);
    saved_uniques = you.unique_creatures;
    return 0;
}

LUAFN(debug_reset_uniques)
{
    UNUSED(ls);
    you.unique_creatures.reset();
    return 0;
}

LUAFN(debug_randomize_uniques)
{
    UNUSED(ls);
    you.unique_creatures.reset();
    for (monster_type mt = MONS_0; mt < NUM_MONSTERS; ++mt)
    {
        if (!mons_is_unique(mt))
            continue;
        you.unique_creatures.set(mt, coinflip());
    }
    return 0;
}

// Compare list of uniques on current level with
// you.unique_creatures.
static bool _check_uniques()
{
    bool ret = true;

    unique_creature_list uniques_on_level;
    for (monster_iterator mi; mi; ++mi)
        if (mons_is_unique(mi->type))
            uniques_on_level.set(mi->type);

    for (monster_type mt = MONS_0; mt < NUM_MONSTERS; ++mt)
    {
        if (!mons_is_unique(mt) || mons_species(mt) == MONS_SERPENT_OF_HELL)
            continue;
        bool was_set = saved_uniques[mt];
        bool is_set = you.unique_creatures[mt];
        bool placed = uniques_on_level[mt];
        if (placed && was_set
            || placed && !is_set
            || was_set && !is_set
            || !was_set && is_set && !placed)
        {
            mprf(MSGCH_ERROR,
                 "Bad unique tracking: %s placed=%d was_set=%d is_set=%d",
                 mons_type_name(mt, DESC_PLAIN).c_str(),
                 placed, was_set, is_set);
            ret = false;
        }
    }
    return ret;
}

LUAFN(debug_check_uniques)
{
    lua_pushboolean(ls, _check_uniques());
    return 1;
}

LUAFN(debug_viewwindow)
{
    viewwindow(lua_toboolean(ls, 1));
    update_screen();
    return 0;
}

LUAWRAP(debug_seen_monsters_react, seen_monsters_react())

static const char* disablements[] =
{
    "spawns",
    "mon_act",
    "mon_regen",
    "player_regen",
    "death",
    "delay",
    "confirmations",
    "afflictions",
    "mon_sight",
    "save_checkpoints",
};

LUAFN(debug_disable)
{
    COMPILE_CHECK(ARRAYSZ(disablements) == NUM_DISABLEMENTS);

    const char* what = luaL_checkstring(ls, 1);
    for (int dis = 0; dis < NUM_DISABLEMENTS; dis++)
        if (what && !strcmp(what, disablements[dis]))
        {
            bool onoff = true;
            if (lua_isboolean(ls, 2))
                onoff = lua_toboolean(ls, 2);
            crawl_state.disables.set(dis, onoff);
            return 0;
        }
    luaL_argerror(ls, 1,
                  make_stringf("unknown thing to disable: %s", what).c_str());

    return 0;
}

// call crawl's ASSERT with a boolean.
// swap out regular lua `assert` with this (debug.cpp_assert) to easily produce a crashlog from a lua test
// the optional 2nd argument will print a dprf to the log before crashing.
LUAFN(debug_cpp_assert)
{
    bool test = lua_toboolean(ls, 1);
    string reason = "";
    if (!lua_isnoneornil(ls, 2))
        reason = reason + ": (" + luaL_checkstring(ls, 2) + ")";
    if (!test)
        dprf("ASSERT from lua failed%s", reason.c_str());
    ASSERT(test);
    return 0;
}

LUAFN(debug_reset_rng)
{
    // call this with care...

    if (lua_type(ls, 1) == LUA_TSTRING)
    {
        const char *seed_string = lua_tostring(ls, 1);
        uint64_t tmp_seed = 0;
        if (!sscanf(seed_string, "%" SCNu64, &tmp_seed))
            tmp_seed = 0;
        Options.seed = tmp_seed;
    }
    else
    {
        // quick and dirty - use only 32 bit seeds
        unsigned int seed = (unsigned int) luaL_safe_checkint(ls, 1);
        Options.seed = (uint64_t) seed;
    }
    rng::reset();
    const string ret = make_stringf("%" PRIu64, Options.seed);
    lua_pushstring(ls, ret.c_str());
    return 1;
}

LUAFN(debug_get_rng_state)
{
    string r = make_stringf("seed: %" PRIu64 ", generator states: ",
        Options.seed);
    vector<uint64_t> states = rng::get_states();
    for (auto i : states)
        r += make_stringf("%" PRIu64 " ", i);
    lua_pushstring(ls, r.c_str());
    return 1;
}

LUAFN(debug_check_moncasts)
{
    COORDS(c1, 1, 2);
    COORDS(c2, 3, 4);

    monster *m1 = monster_at(c1);
    monster *m2 = monster_at(c2);
    ASSERT(m1);

    for (int s = SPELL_FIRST_SPELL; s < NUM_SPELLS; s++)
    {
        spell_type spell = static_cast<spell_type>(s);
        if (!is_valid_mon_spell(spell) || spell_removed(spell))
            continue;
        // we need to reset the foe each time: some spells (e.g. lesser
        // and greater healing) could change it.
        if (m2 && !mons_aligned(m1, m2))
            m1->foe = m2->mindex();
        else
            m1->foe = MHITNOT;
        const mon_spell_slot slot(spell, 255, MON_SPELL_NO_FLAGS);
        unwind_var<monster_spells> override(m1->spells, { slot });
        dprf("Forcing %s to cast %s", m1->name(DESC_THE, true).c_str(),
                                                spell_title(spell));
        handle_mon_spell(m1);

        // Heal 'target' after each spell, to make sure we don't kill it in the
        // process of testing.
        if (m2)
            m2->heal(10000);
    }
    return 1;
}

const struct luaL_Reg debug_dlib[] =
{
{ "goto_place", debug_goto_place },
{ "dungeon_setup", debug_dungeon_setup },
{ "enter_dungeon", debug_enter_dungeon },
{ "down_stairs", debug_down_stairs },
{ "up_stairs", debug_up_stairs },
{ "reset_player_data", debug_reset_player_data },
{ "builder_ignore_depth", debug_builder_ignore_depth },
{ "generate_level", debug_generate_level },
{ "reveal_mimics", debug_reveal_mimics },
{ "los_changed", debug_los_changed },
{ "dump_map", debug_dump_map },
{ "vault_names", debug_vault_names },
{ "test_explore", _debug_test_explore },
{ "bouncy_beam", debug_bouncy_beam },
{ "cull_monsters", debug_cull_monsters},
{ "dismiss_adjacent", debug_dismiss_adjacent},
{ "dismiss_monsters", debug_dismiss_monsters},
{ "god_wrath", debug_god_wrath},
{ "true_name", debug_true_name },
{ "floor_theme", debug_floor_theme },
{ "set_floor_theme", debug_set_floor_theme },
{ "abandon_god", debug_abandon_god },
{ "vashtar_tithe", debug_vashtar_tithe },
{ "mark_vashtar_gift", debug_mark_vashtar_gift },
{ "blood_offer", debug_blood_offer },
{ "figure_offers", debug_figure_offers },
{ "figure_deal", debug_figure_deal },
{ "can_equip", debug_can_equip },
{ "drink", debug_drink },
{ "wear", debug_wear },
{ "join_god", debug_join_god },
{ "god_pools", debug_god_pools },
{ "set_piety", debug_set_piety },
{ "has_ability", debug_has_ability },
{ "unarmed_bonus", debug_unarmed_bonus },
{ "melee_rating", debug_melee_rating },
{ "set_skill", debug_set_skill },
{ "has_desc", debug_has_desc },
{ "has_start_desc", debug_has_start_desc },
{ "item_desc_keys", debug_item_desc_keys },
{ "weather", debug_weather },
{ "set_weather", debug_set_weather },
{ "shape_weather", debug_shape_weather },
{ "weather_ticks", debug_weather_ticks },
{ "kill_monster", debug_kill_monster },
{ "handle_monster_move", debug_handle_monster_move },
{ "save_uniques", debug_save_uniques },
{ "randomize_uniques", debug_randomize_uniques },
{ "reset_uniques", debug_reset_uniques },
{ "check_uniques", debug_check_uniques },
{ "viewwindow", debug_viewwindow },
{ "seen_monsters_react", debug_seen_monsters_react },
{ "disable", debug_disable },
{ "cpp_assert", debug_cpp_assert },
{ "reset_rng", debug_reset_rng },
{ "get_rng_state", debug_get_rng_state },
{ "check_moncasts", debug_check_moncasts },
{ nullptr, nullptr }
};
