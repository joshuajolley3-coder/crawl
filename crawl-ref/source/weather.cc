/**
 * @file
 * @brief Weather on dungeon levels.
**/

#include "AppHdr.h"

#include "weather.h"

#include "act-iter.h"
#include "branch.h"
#include "cloud.h"
#include "coordit.h"
#include "dungeon.h"
#include "env.h"
#include "fight.h"
#include "items.h"
#include "losglobal.h"
#include "mapdef.h"
#include "message.h"
#include "mon-util.h"
#include "monster.h"
#include "noise.h"
#include "player.h"
#include "random.h"
#include "rltiles/tiledef-dngn.h"
#include "shout.h"
#include "spl-clouds.h"
#include "state.h"
#include "stringutil.h"
#include "terrain.h"
#include "tile-env.h"

#define WEATHER_KEY "weather"

/// One in this many eligible levels has weather.
static const int WEATHER_CHANCE = 6;

struct weather_def
{
    const char *name;
    const char *intro;       // first arrival
    const char *returning;   // later arrivals
    vector<const char *> ambience;
    const char *floor_tile;  // "" to keep the level's own floor
};

static const weather_def weather_defs[NUM_WEATHERS] =
{
    { "", "", "", {}, "" },
    { "rain",
      "Water drips steadily from the ceiling here, pattering into puddles across the floor.",
      "Water is still dripping from above.",
      { "Water drips from the ceiling.",
        "A cold drop lands on the back of your neck.",
        "Somewhere, water trickles through the stone." },
      "" },
    { "fog",
      "A thick, cold mist hangs in the air here, and you cannot see far through it.",
      "The mist still hangs here.",
      { "The mist thickens for a moment.",
        "Shapes shift in the mist.",
        "Your footsteps sound muffled in the fog." },
      "" },
    { "snow",
      "A bitter draught blows through here, and flakes of snow drift down from cracks far above. Frost rimes the floor.",
      "Snow is still drifting down.",
      { "A few snowflakes settle on your shoulders.",
        "A cold draught stirs the snow.",
        "Frost crunches underfoot." },
      "floor_frozen" },
    { "overgrowth",
      "Roots have split the stone here, and grass and saplings have taken hold in the cracks.",
      "The growth here looks thicker than before.",
      { "Leaves rustle in a draught.",
        "Something small scurries through the grass.",
        "The air smells green and damp." },
      "floor_grass" },
    { "thunderstorm",
      "Wild magic has gathered here into a storm. Rain falls from nowhere, thunder rolls through the halls, and lightning crackles between the walls.",
      "The storm still rages.",
      { "Thunder rumbles through the stone.",
        "The rain drives down harder.",
        "Lightning flickers at the edge of sight." },
      "" },
    { "ashfall",
      "Hot vents in the floor breathe out smoke here, and grey ash drifts down like snow.",
      "Ash is still falling.",
      { "Ash settles on your shoulders.",
        "The air tastes of cinders.",
        "A vent nearby coughs out a plume of smoke." },
      "floor_grey_dirt" },
};

weather_type current_weather()
{
    if (!env.properties.exists(WEATHER_KEY))
        return WEATHER_NONE;
    const int w = env.properties[WEATHER_KEY].get_int();
    return w > WEATHER_NONE && w < NUM_WEATHERS ? static_cast<weather_type>(w)
                                                : WEATHER_NONE;
}

const char *weather_name(weather_type w)
{
    return weather_defs[w].name;
}

void set_weather(weather_type w)
{
    if (w <= WEATHER_NONE || w >= NUM_WEATHERS)
        env.properties.erase(WEATHER_KEY);
    else
        env.properties[WEATHER_KEY].get_int() = w;
}

/// The weathers that can happen in the current branch (empty if none).
static vector<weather_type> _possible_weathers()
{
    switch (you.where_are_you)
    {
    case BRANCH_DUNGEON:
        if (you.depth < 2)
            return {};
        // fallthrough
    case BRANCH_LAIR:
    case BRANCH_ORC:
    case BRANCH_SNAKE:
        return { WEATHER_RAIN, WEATHER_FOG, WEATHER_SNOW, WEATHER_OVERGROWTH,
                 WEATHER_THUNDERSTORM, WEATHER_ASHFALL };
    case BRANCH_SWAMP:
    case BRANCH_SHOALS:
        return { WEATHER_RAIN, WEATHER_FOG, WEATHER_THUNDERSTORM };
    case BRANCH_ANCIENT_TEMPLE:
        return { WEATHER_RAIN, WEATHER_FOG, WEATHER_THUNDERSTORM,
                 WEATHER_OVERGROWTH };
    default:
        return {};
    }
}

void roll_weather()
{
    env.properties.erase(WEATHER_KEY);

    if (!crawl_state.game_has_random_floors()
        || crawl_state.game_is_tutorial())
    {
        return;
    }
    const vector<weather_type> possible = _possible_weathers();
    // The jungle temple is wetter and wilder than most places.
    const int chance = player_in_branch(BRANCH_ANCIENT_TEMPLE)
                       ? 2 : WEATHER_CHANCE;
    if (possible.empty() || !one_chance_in(chance))
        return;

    const weather_type w = *random_iterator(possible);
    env.properties[WEATHER_KEY].get_int() = w;

    // Give the floor a look for it, unless the level already chose one.
    const char *floor = weather_defs[w].floor_tile;
    tileidx_t tile;
    if (*floor && !tile_env.default_flavour.floor_idx
        && tile_dngn_index(floor, &tile))
    {
        tile_env.default_flavour.floor = tile;
        tile_env.default_flavour.floor_idx = store_tilename_get_index(floor);
    }
}

/// Plain, unclaimed floor that weather may reshape.
static bool _open_floor(const coord_def &p)
{
    return in_bounds(p) && env.grid(p) == DNGN_FLOOR
           && !map_masked(p, MMT_VAULT)
           && !monster_at(p) && env.igrid(p) == NON_ITEM;
}

/// Puddles of shallow water: they never block the way.
static void _make_puddles(int one_in)
{
    vector<coord_def> made;
    for (rectangle_iterator ri(1); ri; ++ri)
        if (_open_floor(*ri) && one_chance_in(one_in))
        {
            env.grid(*ri) = DNGN_SHALLOW_WATER;
            made.push_back(*ri);
        }
    // Let each puddle spread a little.
    for (const coord_def &p : made)
        for (adjacent_iterator ai(p); ai; ++ai)
            if (_open_floor(*ai) && one_chance_in(3))
                env.grid(*ai) = DNGN_SHALLOW_WATER;
}

/// Can a creature walk here (for the purpose of keeping the level connected)?
static bool _walkable(const coord_def &p)
{
    if (!in_bounds(p) || cell_is_solid(p))
        return false;
    const dungeon_feature_type f = env.grid(p);
    return f != DNGN_DEEP_WATER && f != DNGN_LAVA;
}

/**
 * Would a tree here leave the level connected? True if the walkable squares
 * around it form a single unbroken arc of the ring of eight neighbours: they
 * are then all connected to each other without passing through this square.
 */
static bool _tree_keeps_connectivity(const coord_def &c)
{
    static const coord_def ring[8] =
    {
        { 0, -1 }, { 1, -1 }, { 1, 0 }, { 1, 1 },
        { 0, 1 }, { -1, 1 }, { -1, 0 }, { -1, -1 },
    };
    int walkable = 0, arcs = 0;
    for (int i = 0; i < 8; ++i)
    {
        const bool here = _walkable(c + ring[i]);
        const bool next = _walkable(c + ring[(i + 1) % 8]);
        walkable += here;
        if (here && !next)
            ++arcs;
    }
    // Keep a little room: don't plug the end of a corridor or a nook.
    return walkable == 8 || walkable >= 4 && arcs == 1;
}

/// Young trees sprouting through the floor, never where one would cut a path.
static void _grow_trees(int one_in)
{
    for (rectangle_iterator ri(2); ri; ++ri)
    {
        if (!_open_floor(*ri) || !one_chance_in(one_in))
            continue;
        bool vault_nearby = false;
        for (adjacent_iterator ai(*ri); ai; ++ai)
            if (map_masked(*ai, MMT_VAULT))
                vault_nearby = true;
        if (!vault_nearby && _tree_keeps_connectivity(*ri))
            env.grid(*ri) = DNGN_TREE;
    }
}

void shape_level_for_weather()
{
    switch (current_weather())
    {
    case WEATHER_RAIN:
        _make_puddles(22);
        break;
    case WEATHER_THUNDERSTORM:
        _make_puddles(30);
        break;
    case WEATHER_OVERGROWTH:
        _grow_trees(9);
        break;
    default:
        break;
    }
}

void announce_weather(bool first_visit)
{
    const weather_type w = current_weather();
    if (w == WEATHER_NONE)
        return;
    const weather_def &def = weather_defs[w];
    mprf(MSGCH_PLAIN, "%s", first_visit ? def.intro : def.returning);
}

/// A random open cell the player can see, near them (or origin if none).
static coord_def _visible_spot(int radius)
{
    for (int tries = 0; tries < 30; ++tries)
    {
        const coord_def p = you.pos() + coord_def(random_range(-radius, radius),
                                                  random_range(-radius, radius));
        if (in_bounds(p) && cell_see_cell(you.pos(), p, LOS_NO_TRANS)
            && !cell_is_solid(p)
            && p != you.pos())
        {
            return p;
        }
    }
    return coord_def();
}

/// Lightning strikes a random hostile creature in sight.
static void _lightning_strike()
{
    vector<monster *> targets;
    for (monster_near_iterator mi(you.pos(), LOS_NO_TRANS); mi; ++mi)
        if (!mi->wont_attack() && !mi->is_firewood() && you.can_see(**mi))
            targets.push_back(*mi);

    if (targets.empty())
    {
        if (one_chance_in(3))
        {
            mprf(MSGCH_PLAIN, "Lightning cracks down nearby, and thunder "
                              "shakes the walls!");
            noisy(15, you.pos());
        }
        return;
    }

    monster *mon = *random_iterator(targets);
    const coord_def where = mon->pos();
    int dam = resist_adjust_damage(mon, BEAM_ELECTRICITY, roll_dice(3, 10));
    mprf("Lightning lances down and strikes %s!", mon->name(DESC_THE).c_str());
    noisy(15, where);
    if (dam > 0)
        mon->hurt(nullptr, dam, BEAM_ELECTRICITY);
    if (mon->alive() && dam > 0)
        print_wounds(*mon);
}

/// Drift a cloud of this weather in somewhere near the player.
static void _weather_cloud(cloud_type cloud, int radius, int pow, int size)
{
    const coord_def p = _visible_spot(radius);
    if (!p.origin())
        big_cloud(cloud, nullptr, p, pow, size);
}

void weather_tick()
{
    const weather_type w = current_weather();
    if (w == WEATHER_NONE)
        return;

    switch (w)
    {
    case WEATHER_RAIN:
    case WEATHER_THUNDERSTORM:
        if (one_chance_in(w == WEATHER_RAIN ? 8 : 10))
            _weather_cloud(CLOUD_RAIN, 6, 20, 4 + random2(5));
        if (w == WEATHER_THUNDERSTORM && one_chance_in(30))
            _lightning_strike();
        break;
    case WEATHER_FOG:
        if (one_chance_in(12))
            _weather_cloud(CLOUD_GREY_SMOKE, 7, 15, 5 + random2(5));
        break;
    case WEATHER_SNOW:
        if (one_chance_in(10))
            _weather_cloud(CLOUD_MIST, 6, 12, 3 + random2(3));
        break;
    case WEATHER_ASHFALL:
        if (one_chance_in(16))
            _weather_cloud(CLOUD_BLACK_SMOKE, 7, 12, 3 + random2(4));
        break;
    default:
        break;
    }

    if (one_chance_in(300))
        mprf(MSGCH_PLAIN, "%s", *random_iterator(weather_defs[w].ambience));
}
