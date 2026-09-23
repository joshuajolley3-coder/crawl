/**
 * @file
 * @brief The suspicious figure: a rare, honest (if shady) trader who offers
 *        three deals and vanishes after you take one.
**/

#pragma once

class monster;

/// Permanent max HP a blood-price deal costs, in percent.
const int FIGURE_BLOOD_PERCENT = 5;

enum class figure_deal
{
    swap,       // one of your items for a better one of the same kind
    blood_item, // a little blood for a good item
    blood_gold, // a little blood for gold
};

// Called when the player walks into a (non-hostile) suspicious figure.
void talk_to_suspicious_figure(monster &figure);

// Make sure the figure's three offers exist (generated on first contact).
void init_figure_offers(monster &figure);

// Take a deal. For a swap, give_slot is the inventory slot handed over.
bool take_figure_deal(monster &figure, figure_deal deal, int give_slot = -1);

int figure_blood_cost();
