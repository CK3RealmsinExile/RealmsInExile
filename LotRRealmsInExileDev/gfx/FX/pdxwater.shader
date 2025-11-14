Includes = {
	"cw/heightmap.fxh"
	"bordercolor.fxh"
	"jomini/jomini_water_default.fxh"
	"jomini/jomini_water_pdxmesh.fxh"
	"jomini/jomini_water.fxh"
	# MOD(godherja)
	#"jomini/jomini_fog_of_war.fxh"
	"gh_atmospheric.fxh"
	# END MOD
	"jomini/jomini_mapobject.fxh"
	"standardfuncsgfx.fxh"
	"paper_transition.fxh"
	"clouds.fxh"
	"utility_game.fxh"
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
	TextureSampler FlatMapTexture
	{
		Ref = TerrainFlatMap
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Clamp"
		SampleModeV = "Clamp"
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
	
	Code
	[[
		float CalcSingleWave( float3 WorldSpacePos, float Depth, float TimeOffset, float2 UVOffset )
		{
			// Scale wave frequency to keep consistent width
			float WaveFrequency = 0.4f; // Wider waves in shallow water
			
			float WaveLines = ( 1.0f - Depth ) * 1.0f - GlobalTime * 0.15f + TimeOffset;
			WaveLines = frac( WaveLines * WaveFrequency );
			
			// return WaveLines;
			// Only create waves in a portion of the cycle (0.5 to 1.0), leaving gaps (0.0 to 0.5)

			// Remap to 0-1 range for the wave portion
			float WavePortion = (WaveLines - 0.5f) * 2.0f;
			
			// Sharp leading edge (front of wave toward shore) - at END of wave portion
			float SharpEdge = smoothstep( 0.8f, 1.0f, WavePortion );
			
			// Soft trailing edge - strongest near sharp edge, fades toward ocean
			float TrailingFade = (smoothstep( 0.1, 0.8f, WavePortion )) * 0.4f;
			
			// Combine for asymmetric wave shape
			float WaveShape = max( SharpEdge, TrailingFade );
			
			WaveLines = WaveShape;
			
			// Add depth-based fade: opaque near shore, fade toward ocean
			float DepthFade = smoothstep( 3.0f, 1.0f, Depth );
			WaveLines *= DepthFade;
			
			return WaveLines;
		}
		
		float CalcApproachingWaves( float2 WorldUV, float3 WorldSpacePos, float Depth )
		{
			// Sample flow map including alpha channel
			float4 FlowData = PdxTex2D( FlowMapTexture, WorldUV );
			float ShoreWaveMask = FlowData.a; // Alpha channel controls where waves appear
			// Early out if no shore waves should appear 
			if (ShoreWaveMask <= 0.0f)
			{
				return 0.0f;
			}
			
			// Create 3 wave layers with basic wave patterns
			float Wave1 = CalcSingleWave( WorldSpacePos, Depth, 0.0f, float2( 0.0f, GlobalTime ) );
			float Wave2 = CalcSingleWave( WorldSpacePos, Depth, 0.0f, float2( 0.3f, GlobalTime ) );
			float Wave3 = CalcSingleWave( WorldSpacePos, Depth, 1.0f, float2( 0.6f, GlobalTime ) );
			
			// Combine all wave layers
			float ApproachingWaves = saturate( Wave1 + Wave2 + Wave3 );
			
			// Large scale mask UV transforms - red channel (different for each wave)
			float2 BaseUV = WorldSpacePos.xz * 0.001f; // Large scale
			float2 LargeScaleMaskUV1A = BaseUV + GlobalTime * 0.1f * float2( 0.02f, 0.01f );
			float2 LargeScaleMaskUV2A = BaseUV * 1.3f + GlobalTime * 0.1f * float2( -0.015f, 0.025f );
			float2 LargeScaleMaskUV3A = BaseUV * 0.8f + GlobalTime * 0.1f * float2( 0.018f, -0.02f );
			
			// Large scale mask UV transforms - blue channel (different scale and motion for variety)
			float2 BlueBaseUV = WorldSpacePos.xz * 0.001f; // Different base scale
			float2 LargeScaleMaskUV1B = BlueBaseUV * 0.7f + GlobalTime * 0.05f * float2( 0.03f, -0.02f );
			float2 LargeScaleMaskUV2B = BlueBaseUV * 1.8f + GlobalTime * 0.08f * float2( -0.01f, 0.04f );
			float2 LargeScaleMaskUV3B = BlueBaseUV * 1.1f + GlobalTime * 0.06f * float2( 0.025f, 0.015f );
			
			// Sample large scale masks for each wave
			float LargeScaleMask1A = PdxTex2DUpscaleNative( FoamTexture, LargeScaleMaskUV1A ).g;
			float LargeScaleMask1B = PdxTex2DUpscaleNative( FoamTexture, LargeScaleMaskUV1B ).g;
			float LargeScaleMask2A = PdxTex2DUpscaleNative( FoamTexture, LargeScaleMaskUV2A ).g;
			float LargeScaleMask2B = PdxTex2DUpscaleNative( FoamTexture, LargeScaleMaskUV2B ).g;
			float LargeScaleMask3A = PdxTex2DUpscaleNative( FoamTexture, LargeScaleMaskUV3A ).g;
			float LargeScaleMask3B = PdxTex2DUpscaleNative( FoamTexture, LargeScaleMaskUV3B ).g;
			
			// Combine red and blue channels for each wave
			float LargeScaleMask1 = LargeScaleMask1A * LargeScaleMask1B;
			float LargeScaleMask2 = LargeScaleMask2A * LargeScaleMask2B;
			float LargeScaleMask3 = LargeScaleMask3A * LargeScaleMask3B;
			
			// Apply large scale masks to individual waves
			Wave1 *= LargeScaleMask1;
			Wave2 *= LargeScaleMask2;
			Wave3 *= LargeScaleMask3;
			
			// Recombine masked waves
			ApproachingWaves = saturate( Wave1 + Wave2 + Wave3 );
			
			// Small-scale mask that affects all waves, with more opacity where waves are translucent 
			float2 SmallScaleMaskUV1 = WorldSpacePos.xz * 0.06f + GlobalTime * 0.2f * float2( 0.1f, 0.05f );
			float2 SmallScaleMaskUV2 = WorldSpacePos.xz * 0.5f + GlobalTime * float2( -0.08f, -0.06f );
			float SmallScaleMask1 = PdxTex2DUpscaleNative( FoamTexture, SmallScaleMaskUV1 ).b;
			float SmallScaleMask2 = PdxTex2DUpscaleNative( FoamNoiseTexture, SmallScaleMaskUV2 ).g;
			
			// Combine the two small scale masks with max for more complex patterns
			float SmallScaleMask = min(SmallScaleMask1, SmallScaleMask2);
			
			// Apply small scale mask with inverse relationship to wave opacity
			// Where waves are more translucent (lower ApproachingWaves), mask has more effect
			float MaskStrength = lerp( 0.3f, 1.0f, 1.0f - ApproachingWaves );
			SmallScaleMask = lerp( 1.0f, SmallScaleMask, MaskStrength );
			
			ApproachingWaves *= SmallScaleMask;
			
			// Apply foam map texture as a mask
			float FoamMap = PdxTex2D( FoamMapTexture, WorldUV ).g;
			ApproachingWaves *= FoamMap;
						

			// Wave1 *= LargeScaleMask1;
			// return LargeScaleMask1;
			return ApproachingWaves;
		}
	]]
	
	MainCode PixelShader
	{
		Input = "VS_OUTPUT_WATER"
		Output = "PDX_COLOR"
		Code
		[[
			PDX_MAIN
			{
				float4 ShadowProj = mul( ShadowMapTextureMatrix, float4( Input.WorldSpacePos, 1.0f ) );
				float ShadowTerm = CalculateShadow( ShadowProj, ShadowMap );
				float4 Water = CalcWater( Input, ShadowTerm )._Color;
				
				// Calculate enhanced approaching waves effects
				float Height = GetHeightMultisample( Input.WorldSpacePos.xz, 0.65 );
				float Depth = Input.WorldSpacePos.y - Height;
				
				// Calculate approaching waves
				float ApproachingWaves = CalcApproachingWaves( Input.UV01, Input.WorldSpacePos, Depth );
				
				// Blend approaching waves with water color
				Water.rgb = lerp( Water.rgb, float3( 1.0f, 1.0f, 1.0f ), ApproachingWaves );

				#ifdef WATER_COLOR_OVERLAY
					// Not enough texture slots, so use only secondary colors on water.
					#if defined( PDX_OSX ) && defined( PDX_OPENGL )
						ApplySecondaryColorGame( Water.rgb, float2( Input.UV01.x, 1.0f - Input.UV01.y ) );
					#else
						float3 BorderColor;
						float BorderPreLightingBlend;
						float BorderPostLightingBlend;
						GetProvinceOverlayAndBlend( Input.WorldSpacePos.xz, BorderColor, BorderPreLightingBlend, BorderPostLightingBlend );
						GetBorderColorAndBlendGame( Input.WorldSpacePos.xz, Water.rgb, BorderColor, BorderPreLightingBlend, BorderPostLightingBlend );

						// Don't draw too close to the shore to not duplicate the colors with stripes over the land.
						float AccurateHeight = GetHeight( Input.WorldSpacePos.xz );
						BorderPreLightingBlend *= 1.0f - Levels( max( AccurateHeight - ( _WaterHeight - 0.05f ), 0.0f ), 0.0f, 0.05f );

						Water.rgb = lerp( Water.rgb, BorderColor, BorderPreLightingBlend );
					#endif
				#endif
				
				// MOD(godherja)
				//Water.rgb = ApplyFogOfWarMultiSampled( Water.rgb, Input.WorldSpacePos, FogOfWarAlpha );
				Water.rgb = GH_ApplyAtmosphericEffects( Water.rgb, Input.WorldSpacePos, FogOfWarAlpha, 0.4f );
				// END MOD
				Water.rgb = ApplyMapDistanceFogWithoutFoW( Water.rgb, Input.WorldSpacePos );

				float3 FlatMap = PdxTex2D( FlatMapTexture, Input.UV01 ).rgb;
				FlatMap = ApplyFlatMapBrightnessAdjustment( FlatMap );

				float Blend = CalculatePaperTransitionBlend( Input.UV01, FlatMapLerp );
				Water.rgb = FlatMapLerp > 0 ? lerp( Water.rgb, FlatMap, Blend )
											: Water.rgb;
				return Water;
			}
		]]
	}

	MainCode PixelShaderLowSpec
	{
		Input = "VS_OUTPUT_WATER"
		Output = "PDX_COLOR"
		Code
		[[			
			// low spec version of CalcWater
			float4 CalcWaterLowSpec( VS_OUTPUT_WATER Input, out float Depth )
			{
				float Height = GetHeightMultisample( Input.WorldSpacePos.xz, 0.65 );
				Depth = Input.WorldSpacePos.y - Height;
				
				float WaterFade = 1.0 - saturate( (_WaterFadeShoreMaskDepth - Depth) * _WaterFadeShoreMaskSharpness );
				float4 WaterColorAndSpec = PdxTex2D( WaterColorTexture, Input.UV01 );
				
				return float4(WaterColorAndSpec.xyz, WaterFade);
			}

			PDX_MAIN
			{
				float Depth;
				float4 Water = CalcWaterLowSpec( Input, Depth );

				#ifdef WATER_COLOR_OVERLAY
						ApplySecondaryColorGame( Water.rgb, float2( Input.UV01.x, 1.0f - Input.UV01.y ) );
				#endif
				
				// MOD(godherja)
				//Water.rgb = ApplyFogOfWarMultiSampled( Water.rgb, Input.WorldSpacePos, FogOfWarAlpha );
				Water.rgb = GH_ApplyAtmosphericEffects( Water.rgb, Input.WorldSpacePos, FogOfWarAlpha, 0.4f );
				// END MOD
				Water.rgb = ApplyMapDistanceFogWithoutFoW( Water.rgb, Input.WorldSpacePos );

				Water.rgb = FlatMapLerp > 0.0f ? lerp( Water.rgb, PdxTex2D( FlatMapTexture, Input.UV01 ).rgb, FlatMapLerp ) : Water.rgb;

				// MOD(map-skybox)
				 if (Input.WorldSpacePos.x < 0.0 || Input.WorldSpacePos.x >= WorldExtents.x ||
					 Input.WorldSpacePos.z < 0.0 || Input.WorldSpacePos.z >= WorldExtents.y)
				{
					Water.a = 1.0f;
				}
				// END MOD

				return Water;
			}
		]]
	}
}


Effect water
{
	VertexShader = "JominiWaterVertexShader"
	PixelShader = "PixelShader"
}

Effect waterLowSpec
{
	VertexShader = "JominiWaterVertexShader"
	PixelShader = "PixelShaderLowSpec"
}

Effect lake
{
	VertexShader = "VS_jomini_water_mesh"
	PixelShader = "PixelShader"
}
Effect lake_mapobject
{
	VertexShader = "VS_jomini_water_mapobject"
	PixelShader = "PixelShader"
}
