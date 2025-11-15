role_name = {	
	# scope:ruler = character who owns the royal court
	# use add_to_list = characters to save all characters who are valid for this role
	effect = {
		# eg:
		scope:ruler = {
			every_knight = {
				add_to_list = characters
			}
		}
	}

	# scripted animation block for animation selection based on triggers
	# scope:ruler = character who owns the royal court
	# scope:character = the character who is going to receive triggered animation
	scripted_animation = {
		triggered_animation = {
			trigger = {
				scope:ruler = {
					is_female = no
				}
			}

			# both syntaxes are supported
			animation = { one_handed_1_aggressive one_handed_2_aggressive }
			animation = one_handed_1_aggressive
			# Instead of 'animation' you can also define a 'scripted_animation'
			scripted_animation = key_of_scripted_animation

			### brief: camera ( database key, optional )
			# A camera type defined for a triggered animation will override the
			# default camera defined for the scripted animation if this triggered
			# animation is chosen
			#
			camera = camera_name
		}
		triggered_animation = {
			trigger = {
				scope:character = {
					is_female = yes
				}
			}

			animation = throne_room_conversation_1
			camera = camera_name
		}

		# 1 default animation if all triggers fail. Convention is to always have some always-valid trigger and not use this field
		animation = throne_room_conversation_3
		# Instead of 'animation' you can also define a 'scripted_animation'
		scripted_animation = key_of_scripted_animation

		### brief: camera ( database key, optional )
		# A default camera type to display when none of the triggered animations
		# have triggered. This camera will override the default camera defined for
		# a portrait in events or elsewhere.
		#
		camera = camera_name
	}
}

Court events can override what roles are given to who in the court scene, the events override the default role. The court events can override the animation as well for the role.
