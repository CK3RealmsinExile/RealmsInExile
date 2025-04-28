##############################################################
# Overview
##############################################################
#
# Configuration for per-province shader effects.
# Each entry represents an effect that can be active on a map province.
# If multiple province_effect entries apply to the same province, the entry with the higher effect_index is applied.
#
# See 'gfx/FX/province_effects.fxh' for the shader implementation.
#
# At this point in time, Situations are the only objects that can set province effects. See `_situations.info`
#
# Snow province data has been added to WinterTexture. If the effect displays snow, please set is_winter_effect = yes.
#
##############################################################
# Structure
##############################################################

province_effect_key = {
	# The number passed into the effect texture data, for the shader to identify this effect by
	effect_index = int
	is_winter_effect = bool
}
