/**
 * @file
 * @brief Blood altars.
**/

#include "AppHdr.h"

#include "blood-altar.h"

#include "artefact.h"
#include "dungeon.h"
#include "env.h"
#include "item-name.h"
#include "item-prop.h"
#include "item-status-flag-type.h"
#include "items.h"
#include "makeitem.h"
#include "libutil.h"
#include "macro.h"
#include "message.h"
#include "mutation.h"
#include "notes.h"
#include "player.h"
#include "prompt.h"
#include "religion.h"
#include "state.h"
#include "stringutil.h"
#include "terrain.h"

int blood_altar_cost()
{
    return max(1, div_rand_round(get_real_hp(false, false)
                                     * BLOOD_ALTAR_COST_PERMILLE, 1000));
}

static int _gold_offered()
{
    // Grows with depth: roughly what a few floors of gold would give.
    return 60 + 25 * env.absdepth0;
}

/// An evil-branded weapon (sometimes an artefact), identified.
static int _make_evil_gift()
{
    const int wpn = random_choose(WPN_LONG_SWORD, WPN_SCIMITAR, WPN_WAR_AXE,
                                  WPN_BROAD_AXE, WPN_MORNINGSTAR, WPN_SPEAR,
                                  WPN_TRIDENT, WPN_SHORT_SWORD, WPN_RAPIER,
                                  WPN_FLAIL, WPN_BASTARD_SWORD);
    const int brand = random_choose(SPWPN_VAMPIRISM, SPWPN_DRAINING,
                                    SPWPN_PAIN, SPWPN_REAPING);
    const int idx = items(false, OBJ_WEAPONS, wpn, ISPEC_GOOD_ITEM, brand);
    if (idx == NON_ITEM)
        return NON_ITEM;
    item_def &item = env.item[idx];
    if (one_chance_in(3) && !is_artefact(item))
    {
        make_item_randart(item, true);
        artefact_set_property(item, ARTP_BRAND, brand);
    }
    item.flags |= ISFLAG_IDENTIFIED;
    return idx;
}

bool blood_altar_offer(blood_boon boon)
{
    if (boon == blood_boon::mutation && !you.can_safely_mutate())
    {
        mpr("Your body cannot change, so the altar has no gift of flesh for "
            "you.");
        return false;
    }

    const int cost = blood_altar_cost();
    mprf("You open a vein over the altar. (%d max HP)", -cost);
    you.hp_max_adj_perm -= cost;
    calc_hp();
    you.redraw_hit_points = true;

    switch (boon)
    {
    case blood_boon::gold:
    {
        const int gold = _gold_offered();
        mprf("The blood hisses away, and %d gold coins well up in its place.",
             gold);
        you.add_gold(gold);
        break;
    }
    case blood_boon::mutation:
        mpr("The altar's hunger answers with a gift of flesh.");
        if (!mutate(RANDOM_GOOD_MUTATION, "a blood altar", false, false,
                    false, true))
        {
            mpr("...but nothing changes, and your blood is gone.");
        }
        break;
    case blood_boon::evil_gift:
    {
        int idx = _make_evil_gift();
        if (idx != NON_ITEM && move_item_to_grid(&idx, you.pos()))
        {
            mprf("A %s rises, dripping, from the altar.",
                 env.item[idx].name(DESC_PLAIN).c_str());
        }
        break;
    }
    }

    take_note(Note(NOTE_MESSAGE, 0, 0, "Made a blood offering."));

    // The good gods are appalled.
    if (is_good_god(you.religion))
    {
        simple_god_message(" is appalled by your blood offering!");
        dock_piety(30, 15, true);
    }

    // Sated, the altar crumbles.
    mpr("Sated, the altar cracks and crumbles into dust.");
    dungeon_terrain_changed(you.pos(), DNGN_FLOOR);
    return true;
}

void use_blood_altar()
{
    const int cost = blood_altar_cost();
    if (is_good_god(you.religion)
        && !yesno(make_stringf("%s would be appalled by a blood offering. "
                               "Make one anyway?",
                               god_name(you.religion).c_str()).c_str(),
                  false, 'n'))
    {
        canned_msg(MSG_OK);
        return;
    }

    const bool can_mutate = you.can_safely_mutate();
    mprf(MSGCH_PROMPT, "The altar thirsts. Offer your blood (%d max HP, "
                       "forever) for (g)old [%d], %s(a)n evil gift? "
                       "(Esc to leave)",
         cost, _gold_offered(),
         can_mutate ? "a gift of (f)lesh, or " : "");

    while (true)
    {
        const int keyin = toupper_safe(getchm());
        if (key_is_escape(keyin) || crawl_state.seen_hups)
        {
            canned_msg(MSG_OK);
            return;
        }
        if (keyin == 'G')
        {
            blood_altar_offer(blood_boon::gold);
            return;
        }
        if (keyin == 'F' && can_mutate)
        {
            blood_altar_offer(blood_boon::mutation);
            return;
        }
        if (keyin == 'A' || keyin == 'E')
        {
            blood_altar_offer(blood_boon::evil_gift);
            return;
        }
    }
}
