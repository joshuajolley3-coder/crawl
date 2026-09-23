/**
 * @file
 * @brief The suspicious figure.
**/

#include "AppHdr.h"

#include "suspicious-figure.h"

#include "artefact.h"
#include "dungeon.h"
#include "env.h"
#include "invent.h"
#include "item-name.h"
#include "item-prop.h"
#include "item-status-flag-type.h"
#include "item-use.h"
#include "items.h"
#include "libutil.h"
#include "macro.h"
#include "makeitem.h"
#include "message.h"
#include "mon-death.h"
#include "monster.h"
#include "notes.h"
#include "player.h"
#include "prompt.h"
#include "state.h"
#include "stringutil.h"

#define FIGURE_SWAP_KEY "figure_offer_swap"
#define FIGURE_ITEM_KEY "figure_offer_item"
#define FIGURE_GOLD_KEY "figure_offer_gold"

int figure_blood_cost()
{
    return max(1, div_rand_round(get_real_hp(false, false)
                                     * FIGURE_BLOOD_PERCENT, 100));
}

/// A good item of the given class, identified, as a free-standing copy.
static item_def _make_offer(object_class_type cls, bool nicer)
{
    const int idx = items(false, cls, OBJ_RANDOM, ISPEC_GOOD_ITEM);
    item_def offer;
    if (idx == NON_ITEM)
        return offer;
    if (nicer && one_chance_in(3) && !is_artefact(env.item[idx]))
        make_item_randart(env.item[idx], true);
    offer = env.item[idx];
    offer.flags |= ISFLAG_IDENTIFIED;
    destroy_item(idx, true);
    return offer;
}

void init_figure_offers(monster &figure)
{
    if (figure.props.exists(FIGURE_ITEM_KEY))
        return;

    const object_class_type swap_cls =
        random_choose(OBJ_WEAPONS, OBJ_ARMOUR, OBJ_JEWELLERY);
    figure.props[FIGURE_SWAP_KEY].get_item() = _make_offer(swap_cls, true);

    const object_class_type item_cls =
        random_choose_weighted(3, OBJ_WEAPONS, 3, OBJ_ARMOUR,
                               2, OBJ_JEWELLERY, 1, OBJ_WANDS,
                               1, OBJ_STAVES);
    figure.props[FIGURE_ITEM_KEY].get_item() = _make_offer(item_cls, true);

    figure.props[FIGURE_GOLD_KEY].get_int() = 80 + 20 * env.absdepth0
                                              + random2(40);
}

static const char *_class_word(object_class_type cls)
{
    switch (cls)
    {
    case OBJ_WEAPONS:   return "weapon";
    case OBJ_ARMOUR:    return "piece of armour";
    case OBJ_JEWELLERY: return "ring or amulet";
    default:            return "item";
    }
}

/// Hand a stored offer to the player (dropped at their feet).
static void _give_offer(const item_def &offer)
{
    int idx = get_mitm_slot();
    if (idx == NON_ITEM)
        return;
    env.item[idx] = offer;
    env.item[idx].link = NON_ITEM;
    env.item[idx].pos.reset();
    env.item[idx].props.erase("held_by");
    if (move_item_to_grid(&idx, you.pos()))
    {
        mprf("The figure sets %s at your feet.",
             env.item[idx].name(DESC_A).c_str());
    }
}

static void _figure_departs(monster &figure)
{
    mpr("The figure tips its hood, and melts back into the shadows.");
    monster_die(figure, KILL_RESET, NON_MONSTER, true);
}

static void _pay_blood(int cost)
{
    mprf("You let the figure draw a little of your blood. (%d max HP)", -cost);
    you.hp_max_adj_perm -= cost;
    calc_hp();
    you.redraw_hit_points = true;
}

bool take_figure_deal(monster &figure, figure_deal deal, int give_slot)
{
    init_figure_offers(figure);
    switch (deal)
    {
    case figure_deal::swap:
    {
        const item_def &offer = figure.props[FIGURE_SWAP_KEY].get_item();
        if (give_slot < 0 || give_slot >= ENDOFPACK
            || !you.inv[give_slot].defined()
            || you.inv[give_slot].base_type != offer.base_type)
        {
            return false;
        }
        if (item_is_equipped(you.inv[give_slot]))
        {
            mpr("You'll have to take that off first.");
            return false;
        }
        mprf("You hand over %s.", you.inv[give_slot].name(DESC_YOUR).c_str());
        dec_inv_item_quantity(give_slot, you.inv[give_slot].quantity);
        _give_offer(offer);
        break;
    }
    case figure_deal::blood_item:
        _pay_blood(figure_blood_cost());
        _give_offer(figure.props[FIGURE_ITEM_KEY].get_item());
        break;
    case figure_deal::blood_gold:
    {
        _pay_blood(figure_blood_cost());
        const int gold = figure.props[FIGURE_GOLD_KEY].get_int();
        mprf("The figure counts %d gold coins into your hand.", gold);
        you.add_gold(gold);
        break;
    }
    }
    take_note(Note(NOTE_MESSAGE, 0, 0, "Made a deal with a suspicious figure."));
    _figure_departs(figure);
    return true;
}

void talk_to_suspicious_figure(monster &figure)
{
    init_figure_offers(figure);
    const item_def &swap = figure.props[FIGURE_SWAP_KEY].get_item();
    const item_def &offer = figure.props[FIGURE_ITEM_KEY].get_item();
    const int gold = figure.props[FIGURE_GOLD_KEY].get_int();
    const int cost = figure_blood_cost();

    mpr("The hooded figure murmurs: \"Psst. I have a few things you might want. "
        "One deal, and I'm gone.\"");
    mprf(MSGCH_PROMPT, "(a) Trade me any %s of yours for %s.",
         _class_word(swap.base_type), swap.name(DESC_A).c_str());
    mprf(MSGCH_PROMPT, "(b) A little of your blood (%d max HP) for %s.",
         cost, offer.name(DESC_A).c_str());
    mprf(MSGCH_PROMPT, "(c) A little of your blood (%d max HP) for %d gold.",
         cost, gold);
    mprf(MSGCH_PROMPT, "Which deal? (a/b/c, Esc to walk away)");

    while (true)
    {
        const int keyin = toupper_safe(getchm());
        if (key_is_escape(keyin) || crawl_state.seen_hups)
        {
            mpr("\"Suit yourself. I'll be here... for now.\"");
            return;
        }
        if (keyin == 'A')
        {
            item_def *given = nullptr;
            const string prompt = make_stringf("Trade which %s?",
                                               _class_word(swap.base_type));
            if (use_an_item_menu(given, OPER_ANY, swap.base_type,
                                 prompt.c_str()) != spret::success
                || !given)
            {
                canned_msg(MSG_OK);
                return;
            }
            take_figure_deal(figure, figure_deal::swap, given->link);
            return;
        }
        if (keyin == 'B')
        {
            take_figure_deal(figure, figure_deal::blood_item);
            return;
        }
        if (keyin == 'C')
        {
            take_figure_deal(figure, figure_deal::blood_gold);
            return;
        }
    }
}
