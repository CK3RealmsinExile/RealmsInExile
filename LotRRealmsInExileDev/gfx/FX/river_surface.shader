Includes = {
	"jomini/jomini_river_surface.fxh"
	# MOD(godherja)
	#"jomini/jomini_fog_of_war.fxh"
	"gh_atmospheric.fxh"
	# END MOD
	"standardfuncsgfx.fxh"
}

PixelShader =
{	
	TextureSampler FogOfWarAlpha
	{
		Ref = JominiFogOfWar
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
	}
	
	MainCode PS_surface
	{
		Input = "VS_OUTPUT_RIVER"
		Output = "PDX_COLOR"
		Code
		[[				
			PDX_MAIN
			{		
				float4 Color = CalcRiverSurface( Input );
				
				Color.rgb = GH_ApplyAtmosphericEffects( Color.rgb, Input.WorldSpacePos, FogOfWarAlpha );
				Color.rgb = ApplyDistanceFog( Color.rgb, Input.WorldSpacePos );
				
				Color.a *= 1.0f - FlatMapLerp;
				return Color;
			}
		]]
	}
}

Effect river_surface
{
	VertexShader = "VertexShader"
	PixelShader = "PS_surface"
	Defines = { "RIVER" }#"WATER_LOCAL_SPACE_NORMALS" }
}