Includes = {
	"jomini/jomini_river_surface.fxh"
	# MOD(godherja)
	#"jomini/jomini_fog_of_war.fxh"
	"gh_atmospheric.fxh"
	# END MOD
	"standardfuncsgfx.fxh"
	"cw/pdxterrain.fxh"
	"shadow_tint.fxh"
	"clouds.fxh"
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
	
	TextureSampler ShadowMap
	{
		Ref = PdxShadowmap
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Clamp"
		SampleModeV = "Clamp"
		CompareFunction = less_equal
		SamplerType = "Compare"
	}
	
	MainCode PS_surface
	{
		Input = "VS_OUTPUT_RIVER"
		Output = "PDX_COLOR"
		Code
		[[
			static const float3 CloudyColor = float3( 0.0f, 0.01f, 0.02f );

			PDX_MAIN
			{
				const float ZoomBlendOut = clamp( ( 1.0f - _WaterZoomedInZoomedOutFactor ) * 2.0f, 0.0f, 1.0f );
				clip( ZoomBlendOut - 1e-5 );
				float4 Color = CalcRiverAdvanced( Input )._Color;
				Color.a *= 1.0f - FlatMapLerp;
				Color.a *= ZoomBlendOut;
				clip( Color.a - 1e-5 );

				#ifndef LOW_SPEC_SHADERS
					float4 ShadowProj = mul( ShadowMapTextureMatrix, float4( Input.WorldSpacePos, 1.0f ) );
					float ShadowTerm = CalculateShadow( ShadowProj, ShadowMap );

					// Apply shadow tint with cloud interaction for rivers
					float CloudMask = GetCloudShadowMask( Input.WorldSpacePos.xz );
					Color.rgb = ApplyTerrainShadowTintWithClouds( Color.rgb, Input.WorldSpacePos.xz, CloudMask, ShadowTerm );
					Color.rgb = lerp( Color.rgb, CloudyColor, CloudMask * 0.8f );
				#endif
				// MOD(godherja)
				//Color.rgb = ApplyFogOfWar( Color.rgb, Input.WorldSpacePos, FogOfWarAlpha );
				Color.rgb = GH_ApplyAtmosphericEffects( Color.rgb, Input.WorldSpacePos, FogOfWarAlpha );
				// END MOD
				Color.rgb = ApplyMapDistanceFogWithoutFoW( Color.rgb, Input.WorldSpacePos );

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
