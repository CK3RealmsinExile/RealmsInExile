#######################################################################
# Structure 
#######################################################################

### brief: any_database_key
# Defines the focus types available. 
#
focus_type = {

	### brief: type ( enum )
	# What type of focus is this? 
	#
	# Valid values: 
	#	education
	#	lifestyle
	#
	type = lifestyle
	
	### brief: is_shown ( trigger )
	# Is the focus visible to the scoped character?
	# 
	# Supported scopes: 
	# 	root: ( Character )
	#		Character being evaluated for focus type
	#
	is_shown = { }

	### brief: is_valid ( trigger )
	# Can the scoped character choose this focus? 
	# 
	# Supported scopes: 
	# 	root: ( Character )
	#		Character being evaluated for focus type
	#
	is_valid = { }

	### brief: is_valid_showing_failures_only ( trigger )
	# Can the scoped character choose this focus? 
	# These will be shown only if they fail. 
	# 
	# Supported scopes: 
	# 	root: ( Character )
	#		Character being evaluated for focus type
	#
	is_valid_showing_failures_only = { }

	### brief: is_good_for ( trigger )
	# Is this a good education focus for the scoped child?
	#
	# This is used by education focuses.
	# 
	# Supported scopes: 
	# 	root: ( Character )
	#		Character being evaluated for focus type
	#
	is_good_for = { }

	### brief: is_bad_for ( trigger )
	# Is this a bad education focus for the scoped child?
	#
	# This is used by education focuses.
	# 
	# Supported scopes: 
	# 	root: ( Character )
	#		Character being evaluated for focus type
	#
	is_bad_for = { }

	### brief: is_default ( trigger )
	# Is this the default education focus for the scoped child?
	#
	# This is used by education focuses.
	# 
	# Supported scopes: 
	# 	root: ( Character )
	#		Character being evaluated for focus type.
	#
	is_default = { }

	### brief: on_change_to ( effect )
	# Effect to execute on the character changing to this type.
	# 
	# Supported scopes: 
	# 	root: ( Character )
	#		Character changing to this focus type.
	#
	on_change_to = { }

	### brief: on_change_from ( effect )
	# Effect to execute on the character changing away from this type.
	# 
	# Supported scopes: 
	# 	root: ( Character )
	#		Character changing away from this focus type.
	#
	on_change_from = { }

	### brief: on_birthday ( effect )
	# Effect to execute on the character's birthday if they are above 
	# NCharacter::FOCUS_CHILD_MIN_AGE. 
	# 
	# Supported scopes: 
	# 	root: ( Character )
	#		Character that has birthday.
	#
	on_birthday = { }

	### brief: modifier ( modifiers )
	# Modifiers to apply to the character that has this focus
	#
	modifier = { }

	### brief: skill ( enum )
	# Which skill is this focus related to? 
	#
	# This is used by education focuses.
	#
	skill = count

	### brief: lifestyle ( database key )
	# What lifestyle the focus belongs to. Adding this will make it a
	# lifestyle focus. 
	#
	# If the type is lifestyle this is required.
	#
	# Key is mapped to the lifestyle database: common/lifestyles/
	# 
	lifestyle = lifestyle_key

	### brief: icon ( string )
	# Override for what key to use for the icon. 
	#
	# Defaults to the key of the focus.
	#
	icon = focus_type
	
	### brief: auto_selection_weight ( scripted value )
	# Script value for selection weight. Primarily used by the AI, but 
	# also when a character is promoted to having focus for any reason
	# to select initial focus. 
	#
	# Supported scopes: 
	# 	root: ( Character )
	#		Character being evaluated for focus type
	#
	auto_selection_weight = { value = 1000 }		

	### brief: desc ( dynamic description )
	# Descriptions used to describe the focus in the interface. 
	#
	desc = {
		desc = loc_key
		desc = loc_key_2
	}
}
