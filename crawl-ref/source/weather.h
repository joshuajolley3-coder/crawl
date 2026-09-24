/**
 * @file
 * @brief Weather: now and then a level has weather that reshapes it as it is
 *        built (puddles, undergrowth, frost or ash on the floor) and keeps
 *        acting while you are there (rain, fog banks, lightning...).
**/

#pragma once

enum weather_type
{
    WEATHER_NONE,
    WEATHER_RAIN,
    WEATHER_FOG,
    WEATHER_SNOW,
    WEATHER_OVERGROWTH,
    WEATHER_THUNDERSTORM,
    WEATHER_ASHFALL,
    NUM_WEATHERS
};

weather_type current_weather();
const char *weather_name(weather_type w);

// Level generation: maybe give the level being built some weather (call at
// the same time as roll_floor_theme), then reshape the level for it (call
// once monsters and items are placed).
void roll_weather();
void shape_level_for_weather();

// Arrival message.
void announce_weather(bool first_visit);
// Called every player turn: rain showers, fog banks, lightning...
void weather_tick();

// For tests.
void set_weather(weather_type w);
