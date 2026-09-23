/**
 * @file
 * @brief Themed Dungeon floors.
**/

#include "AppHdr.h"

#include "floor-theme.h"

#include "branch.h"
#include "coordit.h"
#include "dgn-overview.h"
#include "dungeon.h"
#include "env.h"
#include "item-prop.h"
#include "items.h"
#include "mapdef.h"
#include "message.h"
#include "mon-place.h"
#include "player.h"
#include "random.h"
#include "rltiles/tiledef-dngn.h"
#include "state.h"
#include "stringutil.h"
#include "tile-env.h"

#define FLOOR_THEME_KEY "floor_theme"

/// One in this many eligible Dungeon floors gets a theme.
static const int FLOOR_THEME_CHANCE = 4;
/// Themes start here, so the first floors stay gentle.
static const int FLOOR_THEME_MIN_DEPTH = 3;

struct floor_theme_def
{
    const char *name;           // "Frost"
    const char *intro;          // first arrival: a short scene-setting paragraph
    vector<const char *> returns;   // later arrivals: one of these
    vector<const char *> ambience;  // now and then while exploring
    const char *floor_tile;     // existing dungeon tiles for the look
    const char *wall_tile;
    colour_t floor_colour;      // console colours
    colour_t rock_colour;
    vector<pop_entry> pop;      // depth-banded monster list (D:1-27 scale)
};

// Depth ranges follow the native Dungeon ranges of each monster where it has
// one, so a themed floor is about as dangerous as a normal floor of that depth.
static const floor_theme_def theme_defs[NUM_FLOOR_THEMES] =
{
    { "", "", {}, {}, "", "", BLACK, BLACK, {} },

    { "Frost",
      "Your breath fogs the moment you arrive. Frost furs every wall, the floor is slick with black ice, and somewhere in the stillness something is scraping its claws across the rime.",
      { "The cold bites again as you return.",
        "Ice has crept further across the floor since you left.",
        "Your breath hangs in the frozen air." },
      { "Frost crackles underfoot.", "A distant crack of shifting ice echoes through the halls.",
        "Snow drifts down from somewhere far above.", "Your fingers ache with the cold." },
      "floor_icy", "wall_icy_stone", LIGHTCYAN, WHITE,
      {
        {  3,  7,  350, PEAK, MONS_WHITE_IMP },
        {  3,  8,  450, PEAK, MONS_ICE_BEAST },
        {  5, 11,  250, PEAK, MONS_RIME_DRAKE },
        {  6, 12,  300, PEAK, MONS_POLAR_BEAR },
        {  7, 14,  180, PEAK, MONS_SHARD_SHRIKE },
        {  9, 17,  260, PEAK, MONS_FREEZING_WRAITH },
        { 10, 18,  150, PEAK, MONS_WENDIGO },
        { 11, 20,  200, PEAK, MONS_ICE_DEVIL },
        { 12, 22,  120, PEAK, MONS_AZURE_JELLY },
        { 12, 22,   60, PEAK, MONS_FROSTBOUND_TOME },
        { 13, 27,   80, SEMI, MONS_ICE_DRAGON },
        { 15, 27,   60, SEMI, MONS_FROST_GIANT },
      } },

    { "Fire",
      "A wall of heat meets you as you arrive. The stone glows a dull red, the air shimmers and tastes of ash, and cinders drift past on a wind that smells of burning.",
      { "The heat of the floor washes over you again.",
        "Ash is still falling here.",
        "The stones are still hot underfoot." },
      { "Embers swirl past on a hot draught.", "Somewhere, something roars like a furnace.",
        "Sweat stings your eyes.", "A wall hisses and pops as the heat splits the stone." },
      "floor_rough_red", "wall_volcanic", RED, LIGHTRED,
      {
        {  3,  7,  400, PEAK, MONS_FIRE_BAT },
        {  3,  9,  300, PEAK, MONS_HELL_HOUND },
        {  5, 11,  300, PEAK, MONS_FIRE_ELEMENTAL },
        {  6, 12,  150, PEAK, MONS_MOLTEN_GARGOYLE },
        {  8, 15,  150, PEAK, MONS_SALAMANDER_MYSTIC },
        {  9, 17,  250, PEAK, MONS_EFREET },
        { 10, 18,  120, PEAK, MONS_HELL_HOG },
        { 10, 19,  220, PEAK, MONS_DEEP_ELF_PYROMANCER },
        { 12, 22,   80, PEAK, MONS_FIRE_CRAB },
        { 12, 27,  120, SEMI, MONS_FIRE_DRAGON },
        { 15, 27,   60, SEMI, MONS_FIRE_GIANT },
      } },

    { "Death",
      "The air is cold and still and smells of the grave. Bones are set into the very walls, the dust is thick with old ashes, and in the silence you hear slow footsteps that do not tire.",
      { "The grave-stench closes around you again.",
        "The dead have not rested while you were gone.",
        "Something here remembers you." },
      { "You hear the dry rattle of bones in the dark.", "A cold breath touches the back of your neck.",
        "Somewhere, something shuffles closer.", "A faint moan drifts through the halls." },
      "floor_crypt", "wall_undead", DARKGREY, WHITE,
      {
        {  3,  6,  250, FLAT, MONS_BURIAL_ACOLYTE },
        {  3,  8,  300, PEAK, MONS_PHANTOM },
        {  3,  8,  250, PEAK, MONS_NECROPHAGE },
        {  5, 10,  350, PEAK, MONS_WIGHT },
        {  6, 12,  220, PEAK, MONS_BOG_BODY },
        {  8, 15,  350, PEAK, MONS_WRAITH },
        {  8, 15,  200, PEAK, MONS_VAMPIRE },
        {  9, 16,  150, PEAK, MONS_SHADOWGHAST },
        { 11, 21,  220, PEAK, MONS_SKELETAL_WARRIOR },
        { 12, 22,  120, PEAK, MONS_NECROMANCER },
        { 12, 22,  120, PEAK, MONS_FLAYED_GHOST },
        { 13, 25,  100, PEAK, MONS_GHOUL },
        { 14, 27,   60, SEMI, MONS_VAMPIRE_KNIGHT },
        { 15, 27,   60, SEMI, MONS_SHADOW_WRAITH },
      } },

    { "Arcane",
      "Raw magic hums in the air, making your hair stand on end. Shelves of dusty tomes and strange flasks line the walls, the floor is etched with glowing sigils, and from somewhere comes the murmur of incantations.",
      { "The hum of raw magic rises to greet you.",
        "The sigils underfoot flare as you return.",
        "Someone is still chanting here." },
      { "A stray spark of magic crackles past your ear.", "You hear the rustle of turning pages.",
        "The air tastes of ozone and old ink.", "A distant voice chants in a language you do not know." },
      "floor_crystal_squares", "wall_stone_magic_shelf", MAGENTA, LIGHTMAGENTA,
      {
        {  3,  8,  400, PEAK, MONS_ORC_WIZARD },
        {  3,  9,  250, PEAK, MONS_KOBOLD_GEOMANCER },
        {  4, 10,  200, PEAK, MONS_ORC_PRIEST },
        {  5, 12,  120, PEAK, MONS_GOLDEN_EYE },
        {  6, 13,  150, PEAK, MONS_KOBOLD_DEMONOLOGIST },
        {  9, 17,  200, PEAK, MONS_DEEP_ELF_ELEMENTALIST },
        { 10, 18,  200, PEAK, MONS_OGRE_MAGE },
        { 10, 18,  200, PEAK, MONS_ARCANIST },
        { 11, 20,   60, PEAK, MONS_EARTHEN_TOME },
        { 11, 20,   60, PEAK, MONS_CRYSTAL_TOME },
        { 12, 22,  150, PEAK, MONS_OCCULTIST },
        { 12, 22,  120, PEAK, MONS_DEEP_ELF_DEATH_MAGE },
        { 13, 24,  100, PEAK, MONS_GREAT_ORB_OF_EYES },
        { 14, 27,   80, SEMI, MONS_DEEP_ELF_SORCERER },
        { 15, 27,   50, SEMI, MONS_ORC_SORCERER },
      } },

    { "Venom",
      "The air is hot, wet and thick with rot. Moss carpets the stone, carved serpents coil across the walls, and every shadow seems to hiss.",
      { "The fetid air settles on you again.",
        "Something slithers away as you return.",
        "The hissing has not stopped." },
      { "Something hisses in the dark.", "A drop of something green falls from the ceiling.",
        "You hear the dry skitter of many legs.", "The air stings your throat." },
      "floor_moss", "wall_snake", GREEN, LIGHTGREEN,
      {
        {  3,  7,  400, PEAK, MONS_ADDER },
        {  3,  8,  300, PEAK, MONS_SCORPION },
        {  4, 10,  250, PEAK, MONS_JUMPING_SPIDER },
        {  5, 10,  300, PEAK, MONS_WATER_MOCCASIN },
        {  6, 12,  250, PEAK, MONS_KILLER_BEE },
        {  8, 14,  200, PEAK, MONS_NAGA },
        {  9, 15,  150, PEAK, MONS_SWAMP_DRAKE },
        { 10, 16,  150, PEAK, MONS_TARANTELLA },
        { 10, 18,  200, PEAK, MONS_VAMPIRE_MOSQUITO },
        { 11, 19,  150, PEAK, MONS_REDBACK },
        { 11, 20,  150, PEAK, MONS_NAGA_WARRIOR },
        { 12, 21,  150, PEAK, MONS_WOLF_SPIDER },
        { 12, 22,  120, PEAK, MONS_BLACK_MAMBA },
        { 13, 27,  100, SEMI, MONS_EMPEROR_SCORPION },
      } },

    { "Warband",
      "Drums are beating somewhere ahead. The floor is churned and bloodied, crude banners hang from the walls, and the air stinks of smoke, sweat and war.",
      { "The war drums pick up again as you return.",
        "The warband has not left.",
        "You hear rough laughter somewhere ahead." },
      { "War drums thunder in the distance.", "Somewhere, steel rings against steel.",
        "You hear rough voices arguing over spoils.", "A war horn sounds, far away." },
      "floor_cobble_blood", "wall_brick_brown", BROWN, RED,
      {
        {  3,  6,  300, FLAT, MONS_GOBLIN },
        {  3,  7,  350, PEAK, MONS_HOBGOBLIN },
        {  3,  8,  350, PEAK, MONS_GNOLL },
        {  3,  9,  500, PEAK, MONS_ORC },
        {  4, 10,  220, PEAK, MONS_OGRE },
        {  5, 12,  220, PEAK, MONS_GNOLL_SERGEANT },
        {  5, 12,  150, PEAK, MONS_ORC_PRIEST },
        {  6, 12,  200, PEAK, MONS_KOBOLD_BRIGAND },
        {  6, 13,  400, PEAK, MONS_ORC_WARRIOR },
        {  8, 15,  300, PEAK, MONS_TWO_HEADED_OGRE },
        {  9, 16,  300, PEAK, MONS_TROLL },
        { 10, 18,  200, PEAK, MONS_CENTAUR_WARRIOR },
        { 11, 19,  150, SEMI, MONS_VANARA_CHAMPION },
        { 12, 21,  150, SEMI, MONS_HOLLOWKIN_CHAMPION },
        { 12, 22,  200, PEAK, MONS_ORC_KNIGHT },
        { 13, 22,  150, PEAK, MONS_YAKTAUR },
        { 16, 27,   40, SEMI, MONS_ORC_WARLORD },
        { 16, 27,   50, SEMI, MONS_VASHTARI_CHAMPION },
      } },

    { "Storm",
      "A gust nearly knocks you from your feet. Thunder rolls through the halls, static crawls over your skin, and a howling wind drives flickers of lightning between the dark stones.",
      { "The storm howls around you again.",
        "Thunder greets your return.",
        "The wind has not dropped." },
      { "Thunder rumbles overhead.", "Static prickles across your skin.",
        "A gust of wind howls down the corridor.", "Lightning flickers somewhere nearby." },
      "floor_black_cobalt", "wall_cobalt_rock", BLUE, LIGHTBLUE,
      {
        {  3,  8,  350, PEAK, MONS_SKY_BEAST },
        {  3,  9,  250, PEAK, MONS_RAIJU },
        {  5, 11,  250, PEAK, MONS_WIND_DRAKE },
        {  5, 12,  250, PEAK, MONS_AIR_ELEMENTAL },
        {  9, 16,  150, PEAK, MONS_SPRIGGAN_AIR_MAGE },
        { 10, 18,  200, PEAK, MONS_SPARK_WASP },
        { 11, 20,  150, PEAK, MONS_HARPY },
        { 11, 20,  150, PEAK, MONS_TENGU_CONJURER },
        { 12, 22,  150, PEAK, MONS_SHOCK_SERPENT },
        { 12, 22,  150, PEAK, MONS_DEEP_ELF_ZEPHYRMANCER },
        { 13, 22,  100, PEAK, MONS_TENGU_WARRIOR },
        { 14, 27,   60, SEMI, MONS_STORM_DRAGON },
      } },
};

floor_theme_type current_floor_theme()
{
    if (!env.properties.exists(FLOOR_THEME_KEY))
        return FLOOR_THEME_NONE;
    const int t = env.properties[FLOOR_THEME_KEY].get_int();
    return t > FLOOR_THEME_NONE && t < NUM_FLOOR_THEMES
           ? static_cast<floor_theme_type>(t) : FLOOR_THEME_NONE;
}

const char *floor_theme_name(floor_theme_type theme)
{
    return theme_defs[theme].name;
}

vector<monster_type> floor_theme_monster_list(floor_theme_type theme)
{
    vector<monster_type> list;
    for (const pop_entry &e : theme_defs[theme].pop)
        list.push_back(e.value);
    return list;
}

bool floor_theme_tiles_applied()
{
    const floor_theme_type theme = current_floor_theme();
    tileidx_t tile;
    return theme != FLOOR_THEME_NONE
           && tile_dngn_index(theme_defs[theme].floor_tile, &tile)
           && tile_env.default_flavour.floor == tile;
}

const vector<pop_entry> *floor_theme_population()
{
    const floor_theme_type theme = current_floor_theme();
    if (theme == FLOOR_THEME_NONE || !player_in_branch(BRANCH_DUNGEON))
        return nullptr;
    return &theme_defs[theme].pop;
}

static void _set_theme_tiles(const floor_theme_def &def)
{
    // Respect a level layout that already chose its own look.
    if (tile_env.default_flavour.floor_idx || tile_env.default_flavour.wall_idx)
        return;

    tileidx_t tile;
    if (tile_dngn_index(def.floor_tile, &tile))
    {
        tile_env.default_flavour.floor = tile;
        tile_env.default_flavour.floor_idx = store_tilename_get_index(def.floor_tile);
    }
    if (tile_dngn_index(def.wall_tile, &tile))
    {
        tile_env.default_flavour.wall = tile;
        tile_env.default_flavour.wall_idx = store_tilename_get_index(def.wall_tile);
    }
}

void roll_floor_theme()
{
    env.properties.erase(FLOOR_THEME_KEY);

    if (!player_in_branch(BRANCH_DUNGEON)
        || you.depth < FLOOR_THEME_MIN_DEPTH
        || !crawl_state.game_has_random_floors()
        || crawl_state.game_is_tutorial()
        || !one_chance_in(FLOOR_THEME_CHANCE))
    {
        return;
    }

    const floor_theme_type theme = static_cast<floor_theme_type>(
        1 + random2(NUM_FLOOR_THEMES - 1));
    env.properties[FLOOR_THEME_KEY].get_int() = theme;

    const floor_theme_def &def = theme_defs[theme];
    env.floor_colour = def.floor_colour;
    env.rock_colour = def.rock_colour;
    _set_theme_tiles(def);
}

static void _place_item_randomly(int idx)
{
    if (idx == NON_ITEM)
        return;
    for (int tries = 0; tries < 500; ++tries)
    {
        const coord_def pos = random_in_bounds();
        const monster *mon = monster_at(pos);
        if (env.grid(pos) == DNGN_FLOOR && !map_masked(pos, MMT_NO_ITEM)
            && (!mon || !mon->is_firewood()))
        {
            move_item_to_grid(&idx, pos);
            return;
        }
    }
    destroy_item(idx);
}

void place_floor_theme_loot()
{
    const floor_theme_type theme = current_floor_theme();
    if (theme == FLOOR_THEME_NONE)
        return;

    const int level = env.absdepth0;
    int protection = NON_ITEM;
    switch (theme)
    {
    case FLOOR_THEME_FROST:
        protection = coinflip()
            ? items(false, OBJ_JEWELLERY, RING_PROTECTION_FROM_COLD, level)
            : items(false, OBJ_POTIONS, POT_RESISTANCE, level);
        break;
    case FLOOR_THEME_FIRE:
        protection = coinflip()
            ? items(false, OBJ_JEWELLERY, RING_PROTECTION_FROM_FIRE, level)
            : items(false, OBJ_POTIONS, POT_RESISTANCE, level);
        break;
    case FLOOR_THEME_DEATH:
        protection = items(false, OBJ_JEWELLERY, RING_POSITIVE_ENERGY, level);
        break;
    case FLOOR_THEME_ARCANE:
        protection = items(false, OBJ_JEWELLERY, RING_WILLPOWER, level);
        break;
    case FLOOR_THEME_VENOM:
        protection = items(false, OBJ_JEWELLERY, RING_POISON_RESISTANCE, level);
        break;
    case FLOOR_THEME_WARBAND:
        protection = items(false, OBJ_JEWELLERY, RING_PROTECTION, level);
        break;
    case FLOOR_THEME_STORM:
        // There's no ring of electricity resistance; a pair of potions.
        protection = items(false, OBJ_POTIONS, POT_RESISTANCE, level);
        if (protection != NON_ITEM)
            env.item[protection].quantity = 2;
        break;
    default:
        break;
    }
    _place_item_randomly(protection);

    // A little extra loot for braving a harder floor.
    _place_item_randomly(items(true, OBJ_RANDOM, OBJ_RANDOM, ISPEC_GOOD_ITEM));
}

void announce_floor_theme(bool first_visit)
{
    const floor_theme_type theme = current_floor_theme();
    if (theme == FLOOR_THEME_NONE)
        return;

    const floor_theme_def &def = theme_defs[theme];
    if (first_visit)
    {
        mprf(MSGCH_PLAIN, "%s", def.intro);
        mprf(MSGCH_WARN, "This is a %s floor: its creatures are all of one "
                         "kind. Something here may help you resist them.",
             def.name);
        mark_themed_level(level_id::current(),
                          make_stringf("%s floor", def.name));
    }
    else
        mprf(MSGCH_PLAIN, "%s", *random_iterator(def.returns));
}

void floor_theme_ambience()
{
    const floor_theme_type theme = current_floor_theme();
    if (theme == FLOOR_THEME_NONE || !player_in_branch(BRANCH_DUNGEON)
        || !one_chance_in(300))
    {
        return;
    }
    mprf(MSGCH_PLAIN, "%s", *random_iterator(theme_defs[theme].ambience));
}
