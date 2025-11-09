You can define 

== Structure ==

# Tracks are split into 'in-game tracks' and 'main themes'. In-game tracks play
# during gameplay and main themes are played when the game is loaded and/or on
# the main menu.
# The in-game tracks should be specified in the game/music/music.txt file and the
# main themes should be specified in game/music/main_themes/music.txt file.

name_of_the_music_track = {
	
	# Path to the audio event for this track
	music = "event:/..."
	
	# Determines the value to add to the music system's pause factor counter. This determines how long the pause should be between tracks, default: 0
	# NOTE: This can only be applied to in-game tracks
	pause_factor = X
	
	# Is this track a mood track (i.e. a long track that the game can pick and doesn't need to be explicitly triggered)? default: no
	# NOTE: This can only be applied to in-game tracks
	mood = yes/no
	
	# Should this mood track get prioritized for a first time play over other tracks? (Useful for tracks with a narrow is_valid trigger) default: no
	# NOTE: This can only be applied to in-game tracks
	prioritized_mood = yes/no

	# Is this mood track valid to be played, only evaluated if playing or observing a specific character
	# NOTE: This can only be applied to in-game tracks
	is_valid = { <trigger> }
	
	# Can this track be interrupted by another track? Long mood track are good candidates for interrupting. default : no
	can_be_interrupted = yes/no
	
	# Cooldown in in-game time, the track will not be played for this amount of time after it has been started
	years/months/days = X
	
	# Cooldown in calls. After the track starts playing, it will not play again for X subsequent requests to play it. default : 0
	calls = X
	
	# Does this track's cooldown reset when starting/loading a game? default : no
	reset = yes/no

	# Only play this track if the user has the DLC specified here
	# NOTE: This can only be applied to main themes. To get similar behavior for in-game tracks the general-purpose is_valid can be used instead
	dlc = "NAME OF THE DLC"
}
