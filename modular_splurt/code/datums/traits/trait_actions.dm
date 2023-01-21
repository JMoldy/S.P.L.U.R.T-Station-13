#define BLOOD_DRAIN_NUM 50

//
// Quirk: Hypnotic Gaze
//

/datum/action/innate/Hypnotize
	name = "Hypnotize"
	desc = "Stare deeply into someone's eyes, drawing them into a hypnotic slumber."
	button_icon_state = "Hypno_eye"
	icon_icon = 'modular_splurt/icons/mob/actions/lewd_actions/lewd_icons.dmi'
	background_icon_state = "bg_alien"
	var/mob/living/carbon/T //hypnosis target
	var/mob/living/carbon/human/H //Person with the quirk

/datum/action/innate/Hypnotize/Activate()
	var/mob/living/carbon/human/H = owner

	if(!H.pulling || !isliving(H.pulling) || H.grab_state < GRAB_AGGRESSIVE)
		to_chat(H, span_warning("You need to aggressively grab someone to hypnotize them!"))
		return

	var/mob/living/carbon/T = H.pulling

	if(T.IsSleeping())
		to_chat(H, "You can't hypnotize [T] whilst they're asleep!")
		return

	to_chat(H, span_notice("You stare deeply into [T]'s eyes..."))
	to_chat(T, span_warning("[H] stares intensely into your eyes..."))
	if(!do_mob(H, T, 12 SECONDS))
		return

	if(H.pulling !=T || H.grab_state < GRAB_AGGRESSIVE)
		return

	if(!(H in view(1, H.loc)))
		return

	if(!(T.client?.prefs.cit_toggles & HYPNO))
		return

	var/response = alert(T, "Do you wish to fall into a hypnotic sleep?(This will allow [H] to issue hypnotic suggestions)", "Hypnosis", "Yes", "No")

	if(response == "Yes")
		T.visible_message(span_warning("[T] falls into a deep slumber!"), "<span class = 'danger'>Your eyelids gently shut as you fall into a deep slumber. All you can hear is [H]'s voice as you commit to following all of their suggestions.</span>")

		T.SetSleeping(1200)
		T.drowsyness = max(T.drowsyness, 40)
		T = H.pulling
		var/response2 = alert(H, "Would you like to release your subject or give them a suggestion?", "Hypnosis", "Suggestion", "Release")

		if(response2 == "Suggestion")
			if(get_dist(H, T) > 1)
				to_chat(H, "You must stand in whisper range of [T].")
				return

			var/text = input("What would you like to suggest?", "Hypnotic suggestion", null, null)
			text = sanitize(text)
			if(!text)
				return

			to_chat(H, "You whisper your suggestion in a smooth calming voice to [T]")
			to_chat(T, span_hypnophrase("...[text]..."))

			T.visible_message(span_warning("[T] wakes up from their deep slumber!"), "<span class ='danger'>Your eyelids gently open as you see [H]'s face staring back at you.</span>")
			T.SetSleeping(0)
			T = null
			return

		if(response2 == "Release")
			T.SetSleeping(0)
			return
	else
		T.visible_message(span_warning("[T]'s attention breaks, despite the attempt to hypnotize them! They clearly don't want this!"), "<span class ='warning'>Your concentration breaks as you realise you have no interest in following [H]'s words!</span>")
		return

//
// Quirk: Hydra Heads
//

/datum/action/innate/hydra
	name = "Switch head"
	desc = "Switch between each of the heads on your body."
	icon_icon = 'icons/mob/actions/actions_minor_antag.dmi'
	button_icon_state = "art_summon"

/datum/action/innate/hydrareset
	name = "Reset speech"
	desc = "Go back to speaking as a whole."
	icon_icon = 'icons/mob/actions/actions_minor_antag.dmi'
	button_icon_state = "art_summon"

/datum/action/innate/hydrareset/Activate()
	var/mob/living/carbon/human/hydra = owner
	hydra.real_name = hydra.name_archive
	hydra.visible_message(span_notice("[hydra.name] pushes all three heads forwards; they seem to be talking as a collective."), \
							span_notice("You are now talking as [hydra.name_archive]!"), ignored_mobs=owner)

/datum/action/innate/hydra/Activate() //I hate this but its needed
	var/mob/living/carbon/human/hydra = owner
	var/list/names = splittext(hydra.name_archive,"-")
	var/selhead = input("Who would you like to speak as?","Heads:") in names
	hydra.real_name = selhead
	hydra.visible_message(span_notice("[hydra.name] pulls the rest of their heads back; and puts [selhead]'s forward."), \
							span_notice("You are now talking as [selhead]!"), ignored_mobs=owner)

//
// Quirk: Bloodsucker Fledgling / Vampire
//

/datum/action/vbite
	name = "Bite"
	button_icon_state = "power_feed"
	icon_icon = 'icons/mob/actions/bloodsucker.dmi'
	desc = "Sink your vampiric fangs into the person you are grabbing."
	var/drain_cooldown = 0

/datum/action/vbite/Trigger()
	. = ..()
	if(iscarbon(owner))
		var/mob/living/carbon/H = owner
		if(H.nutrition >= 500)
			to_chat(H, span_notice("You are too full to drain any more."))
			return
		if(drain_cooldown >= world.time)
			to_chat(H, span_notice("You just drained blood, wait a few seconds."))
			return
		if(!H.pulling || !iscarbon(H.pulling))
			if(H.getStaminaLoss() >= 80 && H.nutrition > 20)//prevents being stunlocked in the chapel
				to_chat(H,(span_notice("you use some of your power to energize")))
				H.adjustStaminaLoss(-20)
				H.adjust_nutrition(-20)
				H.resting = TRUE
		if(H.pulling && (iscarbon(H.pulling) || (istype(H.pulling,/obj/structure/arachnid/cocoon) && locate(/mob/living/carbon) in H.pulling.contents)))
			var/mob/living/carbon/victim
			if(iscarbon(H.pulling))
				victim = H.pulling
			else if(istype(H.pulling,/obj/structure/arachnid/cocoon))
				victim = locate(/mob/living/carbon) in H.pulling.contents
			drain_cooldown = world.time + 25
			if(victim.anti_magic_check(FALSE, TRUE, FALSE, 0))
				to_chat(victim, span_warning("[H] tries to bite you, but stops before touching you!"))
				to_chat(H, span_warning("[victim] is blessed! You stop just in time to avoid catching fire."))
				return
			//Here we check now for both the garlic cloves on the neck and for blood in the victims bloodstream.
			if(!blood_sucking_checks(victim, TRUE, TRUE))
				return
			H.visible_message(span_danger("[H] bites down on [victim]'s neck!"))
			victim.add_splatter_floor(get_turf(victim), TRUE)
			to_chat(victim, span_userdanger("[H] is draining your blood!"))
			if(!do_after(H, 30, target = victim))
				return
			var/blood_volume_difference = BLOOD_VOLUME_MAXIMUM - H.blood_volume //How much capacity we have left to absorb blood
			var/drained_blood = min(victim.blood_volume, BLOOD_DRAIN_NUM, blood_volume_difference)
			H.reagents.add_reagent(/datum/reagent/blood/, drained_blood)
			to_chat(victim, span_danger("[H] has taken some of your blood!"))
			to_chat(H, span_notice("You drain some blood!"))
			playsound(H, 'sound/items/drink.ogg', 30, 1, -2)
			victim.blood_volume = clamp(victim.blood_volume - drained_blood, 0, BLOOD_VOLUME_MAXIMUM)
			log_combat(H,victim,"vampire bit")//logs the biting action for admins
			if(!victim.blood_volume)
				to_chat(H, span_warning("You finish off [victim]'s blood supply!"))


/datum/action/vrevive
	name = "Resurrect"
	button_icon_state = "power_strength"
	icon_icon = 'icons/mob/actions/bloodsucker.dmi'
	desc = "Use all your energy to come back to life!"

/datum/action/vrevive/Trigger()
	. = ..()
	var/mob/living/carbon/C = owner
	var/mob/living/carbon/human/H = owner
	if(H.stat == DEAD && istype(C.loc, /obj/structure/closet/crate/coffin))
		H.revive(TRUE, FALSE)
		H.set_nutrition(0)
		H.Daze(20)
		H.drunkenness = 70
	else
		to_chat(H,span_warning("You need to be dead and in a coffin to revive!"))

//
// Quirk: Werewolf
//

/datum/action/werewolf
	name = "Werewolf Ability"
	desc = "Do something related to werewolves."
	icon_icon = 'modular_splurt/icons/mob/actions/misc_actions.dmi'
	button_icon_state = "Transform"

/datum/action/werewolf/transform
	name = "Toggle Werewolf Form"
	desc = "Transform in or out of your wolf form."
	var/transformed = FALSE
	var/list/old_features = list("species" = SPECIES_HUMAN, "legs" = "Plantigrade", "size" = 1, "bark")

/datum/action/werewolf/transform/Grant()
	. = ..()

	// Define action owner
	var/mob/living/carbon/human/action_owner = owner

	// Record features
	old_features = action_owner.dna.features.Copy()
	old_features["species"] = action_owner.dna.species.type
	old_features["size"] = get_size(action_owner)
	old_features["bark"] = action_owner.vocal_bark_id

/datum/action/werewolf/transform/Trigger()
	. = ..()

	// Define action owner
	var/mob/living/carbon/human/action_owner = owner

	// Check if owner is conscious
	if(action_owner.stat != CONSCIOUS)
		// Warn user and return
		to_chat(action_owner,span_warning("You cannot use this ability right now!"))
		return

	// Define citadel organs
	var/obj/item/organ/genital/penis/organ_penis = action_owner.getorganslot(ORGAN_SLOT_PENIS)
	var/obj/item/organ/genital/breasts/organ_breasts = action_owner.getorganslot(ORGAN_SLOT_BREASTS)
	var/obj/item/organ/genital/vagina/organ_vagina = action_owner.getorganslot(ORGAN_SLOT_VAGINA)

	// Play shake animation
	action_owner.shake_animation(2)

	// Transform into wolf form
	if(!transformed)
		// Change species
		action_owner.set_species(/datum/species/mammal, 1)

		// Set species features
		action_owner.dna.species.mutant_bodyparts["mam_tail"] = "Wolf"
		action_owner.dna.species.mutant_bodyparts["legs"] = "Digitigrade"
		action_owner.Digitigrade_Leg_Swap(FALSE)
		action_owner.dna.species.mutant_bodyparts["mam_snouts"] = "Mammal, Thick"
		action_owner.dna.features["mam_ears"] = "Wolf"
		action_owner.dna.features["mam_tail"] = "Wolf"
		action_owner.dna.features["mam_snouts"] = "Mammal, Thick"
		action_owner.dna.features["legs"] = "Digitigrade"
		action_owner.update_size(get_size(action_owner) + 0.5)
		action_owner.set_bark("bark")
		action_owner.custom_species = "Werewolf"
		if(!(action_owner.dna.species.species_traits.Find(DIGITIGRADE)))
			action_owner.dna.species.species_traits += DIGITIGRADE
		action_owner.update_body()
		action_owner.update_body_parts()

		// Update possible citadel organs
		if(organ_breasts)
			organ_breasts.color = "#[action_owner.dna.features["mcolor"]]"
			organ_breasts.update()
		if(organ_penis)
			organ_penis.shape = "Knotted"
			organ_penis.color = "#ff7c80"
			organ_penis.update()
			organ_penis.modify_size(6)
		if(organ_vagina)
			organ_vagina.shape = "Furred"
			organ_vagina.color = "#[action_owner.dna.features["mcolor"]]"
			organ_vagina.update()

	// Un-transform from wolf form
	else
		// Revert species
		action_owner.set_species(old_features["species"], TRUE)

		// Revert species trait
		action_owner.set_bark(old_features["bark"])
		action_owner.dna.features["mam_ears"] = old_features["mam_ears"]
		action_owner.dna.features["mam_snouts"] = old_features["mam_snouts"]
		action_owner.dna.features["mam_tail"] = old_features["mam_tail"]
		action_owner.dna.features["legs"] = old_features["legs"]
		if(old_features["legs"] == "Plantigrade")
			action_owner.dna.species.species_traits -= DIGITIGRADE
			action_owner.Digitigrade_Leg_Swap(TRUE)
			action_owner.dna.species.mutant_bodyparts["legs"] = old_features["legs"]
		action_owner.update_body()
		action_owner.update_body_parts()
		action_owner.update_size(get_size(action_owner) - 0.5)

		// Revert citadel organs
		if(organ_breasts)
			organ_breasts.color = "#[old_features["breasts_color"]]"
			organ_breasts.update()
		if(action_owner.has_penis())
			organ_penis.shape = old_features["cock_shape"]
			organ_penis.color = "#[old_features["cock_color"]]"
			organ_penis.update()
			organ_penis.modify_size(-6)
		if(action_owner.has_vagina())
			organ_vagina.shape = old_features["vag_shape"]
			organ_vagina.color = "#[old_features["vag_color"]]"
			organ_vagina.update()
			organ_vagina.update_size()

	// Set transformation message
	var/owner_p_their = action_owner.p_their()
	var/toggle_message = (!transformed ? "[action_owner] shivers, [owner_p_their] flesh bursting with a sudden growth of thick fur as [owner_p_their] features contort to that of a beast, fully transforming [action_owner.p_them()] into a werewolf!" : "[action_owner] shrinks, [owner_p_their] wolfish features quickly receding.")

	// Alert in local chat
	action_owner.visible_message(span_danger(toggle_message))

	// Toggle transformation state
	transformed = !transformed

//
// Quirk: Gargoyle
//

/datum/action/gargoyle/transform
	name = "Transform"
	desc = "Transform into a statue, regaining energy in the process. Additionally, you will slowly heal while in statue form."
	icon_icon = 'icons/mob/actions/actions_changeling.dmi'
	button_icon_state = "ling_camouflage"
	var/obj/structure/statue/gargoyle/current = null


/datum/action/gargoyle/transform/Trigger()
	.=..()
	var/mob/living/carbon/human/H = owner
	var/datum/quirk/gargoyle/T = locate() in H.roundstart_quirks
	if(!T.cooldown)
		if(!T.transformed)
			if(!isturf(H.loc))
				return 0
			var/obj/structure/statue/gargoyle/S = new(H.loc, H)
			S.name = "statue of [H.name]"
			H.bleedsuppress = 1
			S.copy_overlays(H)
			var/newcolor = list(rgb(77,77,77), rgb(150,150,150), rgb(28,28,28), rgb(0,0,0))
			S.add_atom_colour(newcolor, FIXED_COLOUR_PRIORITY)
			current = S
			T.transformed = 1
			T.cooldown = 30
			T.paused = 0
			S.dir = H.dir
			return 1
		else
			qdel(current)
			T.transformed = 0
			T.cooldown = 30
			T.paused = 0
			H.visible_message(span_warning("[H]'s skin rapidly softens, returning them to normal!"), span_userdanger("Your skin softens, freeing your movement once more!"))
	else
		to_chat(H, span_warning("You have transformed too recently; you cannot yet transform again!"))
		return 0

/datum/action/gargoyle/check
	name = "Check"
	desc = "Check your current energy levels."
	icon_icon = 'icons/mob/actions/actions_clockcult.dmi'
	button_icon_state = "Linked Vanguard"

/datum/action/gargoyle/check/Trigger()
	.=..()
	var/mob/living/carbon/human/H = owner
	var/datum/quirk/gargoyle/T = locate() in H.roundstart_quirks
	to_chat(H, span_warning("You have [T.energy]/100 energy remaining!"))

/datum/action/gargoyle/pause
	name = "Preserve"
	desc = "Become near-motionless, thusly conserving your energy until you move from your current tile. Note, you will lose a chunk of energy when you inevitably move from your current position, so you cannot abuse this!"
	icon_icon = 'icons/mob/actions/actions_flightsuit.dmi'
	button_icon_state = "flightsuit_lock"

/datum/action/gargoyle/pause/Trigger()
	.=..()
	var/mob/living/carbon/human/H = owner
	var/datum/quirk/gargoyle/T = locate() in H.roundstart_quirks

	if(!T.paused)
		T.paused = 1
		T.position = H.loc
		to_chat(H, span_warning("You are now conserving your energy; this effect will end the moment you move from your current position!"))
		return
	else
		to_chat(H, span_warning("You are already conserving your energy!"))
