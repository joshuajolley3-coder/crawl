/**
 * @file
 * @brief Blood altars: offer a piece of your life for gold, a mutation or an
 *        evil gift. The good gods take a very dim view of it.
**/

#pragma once

/// How much permanent max HP an offering costs, in tenths of a percent.
const int BLOOD_ALTAR_COST_PERMILLE = 75;

enum class blood_boon
{
    gold,
    mutation,
    evil_gift,
};

// Interactive: called when the player uses a blood altar (> or <).
void use_blood_altar();

// Make the offering and grant the chosen boon. Returns whether it happened.
bool blood_altar_offer(blood_boon boon);

// Max HP an offering would cost right now.
int blood_altar_cost();
