/**
 * @file
 * @brief Themed Dungeon floors: a floor may be taken over by one family of
 *        monsters (frost, fire, death...), with a matching look, a warning on
 *        arrival, a resistance item and a little bonus loot.
**/

#pragma once

#include <vector>

#include "mon-pick.h"

using std::vector;

enum floor_theme_type
{
    FLOOR_THEME_NONE,
    FLOOR_THEME_FROST,
    FLOOR_THEME_FIRE,
    FLOOR_THEME_DEATH,
    FLOOR_THEME_ARCANE,
    FLOOR_THEME_VENOM,
    FLOOR_THEME_WARBAND,
    FLOOR_THEME_STORM,
    NUM_FLOOR_THEMES
};

floor_theme_type current_floor_theme();
const char *floor_theme_name(floor_theme_type theme);

// Level generation: maybe give the level being built a theme (call before
// random monsters are placed), then add the theme's items (after items).
void roll_floor_theme();
void place_floor_theme_loot();

// The themed monster list for the current level, or nullptr.
const vector<pop_entry> *floor_theme_population();

// Arrival message (and overview label, on the first visit).
void announce_floor_theme(bool first_visit);
// Now and then, a line of atmosphere while exploring a themed floor.
void floor_theme_ambience();

// For tests.
vector<monster_type> floor_theme_monster_list(floor_theme_type theme);
bool floor_theme_tiles_applied();
