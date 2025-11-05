### Defines a bookmark

bookmark_01 = {
	### Brief: start_data (date)
	# Which date this bookmark starts at
	start_date = 867.1.1
	
	### Brief: is_playable (yes/no)
	# Sets if this bookmark is playable or not
	# defaults to: yes
	is_playable = yes

	### Brief: weight (scriptable value)
	# Sets the weight for this bookmark to be the default bookmark
	# Bookmark with the highest value will be the default
	# Note that this is calculated before a gamestate exists and thus cannot use gamestate related triggers
	# defaults value: -1
	weight = {
		value = 0
		if = {
			limit = { has_dlc = "The Fate of Iberia" }
			add = 20
		}
	}

	### Brief: recommended (yes/no)
	# If bookmark should show as recommended or not
	# defaults to: no
	recommended = yes

	### Brief: group (bookmark_group key)
	# Set what group this bookmark is part of
	# left empty bookmark will be ungrouped
	group = bm_group_867

	### Brief: requires_dlc_flag (dlc feature flag)
	# Sets a DLC flag the must be active for this bookmark to show.
	# Not adding this will make the bookmark show regardless of active DLCs.
	requires_dlc_flag = legends_of_the_dead

	character = {
		### Brief: name (key)
		# Localization key for this bookmark
		name = bookmark_test_1066_person_name

		### Brief: history_id (key)
		# Which historical character ID this bookmark corresponds to
		history_id = test_12345

		### Brief: bookmark_type (existing_ruler, new_landless_adventurer, new_noble_family)
		# What type of bookmark this character represents.
		# For 'new_landless_adventurer' and 'new_noble_family', the starting location 'title' needs to configured
		# defaults to: existing_ruler
		bookmark_type = existing_ruler
	}
}
