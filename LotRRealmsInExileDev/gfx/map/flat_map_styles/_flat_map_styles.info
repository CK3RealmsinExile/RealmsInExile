##############################################################
# Overview
##############################################################
#
# A paper map style contains configuration for a paper map (aka flat map).
# Put your .dds files in gfx/map/terrain/flatmaps/ .
# Be sure to leave a default flatmap.dds file in the folder anyway, it will be used when loading the game.
#
##############################################################
# Structure
##############################################################

name_of_paper_map_style = {
	# If this table style is dynamically selected for the current character.
	# Auto-style selection will return the first style.
	# Scope: character (may be empty character when no character has been selected yet)
	is_shown = {}

	# If set require this DLC feature for the table style to be selected by a player via settings
	dlc_feature = feature_name

	# Priority for showing this style if multiple styles are all valid
	# Higher value = higher priority
	priority = int

	# Is this table the default one to show if no other is valid
	# Only one can be set
	default = yes/no

	# Name of the texture to use for the flat map, complete with dds extension. 
	texture = "flatmap.dds"
}
