Includes = {
	# MOD(lotr)
	"cw/random.fxh"
	# END MOD
	"cw/camera.fxh"
	"cw/lighting.fxh"
	"jomini/jomini_flat_border.fxh"
	"jomini/jomini_fog.fxh"
	# MOD(godherja)
	#"jomini/jomini_fog_of_war.fxh"
	"gh_atmospheric.fxh"
	# END MOD
	"jomini/jomini_lighting.fxh"
	"standardfuncsgfx.fxh"
	"shadow_tint.fxh"
	"cw/pdxterrain.fxh"
	"clouds.fxh"
	"jomini/map_lighting.fxh"
}

VertexStruct VS_OUTPUT_PDX_BORDER
{
	float4 Position : PDX_POSITION;
	float3 WorldSpacePos : TEXCOORD0;
	float2 UV : TEXCOORD1;
    float4 ShadowProj		: TEXCOORD2;
};


VertexShader =
{
	MainCode VertexShader
	{
		Input = "VS_INPUT_PDX_BORDER"
		Output = "VS_OUTPUT_PDX_BORDER"
		Code
		[[			
			PDX_MAIN
			{
				VS_OUTPUT_PDX_BORDER Out;
				
				float3 position = Input.Position;
				position.y = lerp( position.y, FlatMapHeight, FlatMapLerp );
				position.y += _HeightOffset;
				
				Out.WorldSpacePos = position;
				Out.Position = FixProjectionAndMul( ViewProjectionMatrix, float4( position, 1.0 ) );
				Out.UV = Input.UV;

				Out.ShadowProj = mul( ShadowMapTextureMatrix, float4( Out.WorldSpacePos, 1.0 ) );

				return Out;
			}
		]]
	}
}


PixelShader =
{	
	TextureSampler BorderTexture
	{
		Index = 0
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Clamp"
	}
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
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
		CompareFunction = less_equal
		SamplerType = "Compare"
	}
	TextureSampler EnvironmentMap
	{
		Ref = JominiEnvironmentMap
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Clamp"
		SampleModeV = "Clamp"
		Type = "Cube"
	}
	TextureSampler SurroundFlatMapMask
	{
		Ref = SurroundFlatMapMask
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Border"
		SampleModeV = "Border"
		Border_Color = { 1 1 1 1 }
		File = "gfx/map/surround_map/surround_mask.dds"
	}

	MainCode PixelShader
	{
		Input = "VS_OUTPUT_PDX_BORDER"
		Output = "PDX_COLOR"
		Code
		[[			
			PDX_MAIN
			{	
				float2 MapCoords = Input.WorldSpacePos.xz * WorldSpaceToTerrain0To1;
				if ( FlatMapLerp > 0.001f )
				{
					float FlatMapMask = 1.0f - PdxTex2D( SurroundFlatMapMask, float2( MapCoords.x, 1.0f - MapCoords.y ) ).b;
					clip( FlatMapMask - 0.1f );
				}
				float4 Diffuse = PdxTex2D( BorderTexture, Input.UV );
				float3 BaseDiffuse = Diffuse.rgb;
				// Get FoW value and darken the border in FoW areas

				float FogOfWarAlphaValue = PdxTex2D( FogOfWarAlpha, MapCoords ).r;
				Diffuse.rgb *= ( 0.3f + 0.7f * FogOfWarAlphaValue ); // Darken to 30% in FoW
				Diffuse.rgb = lerp( BaseDiffuse, Diffuse.rgb, 0.03f );
				Diffuse.a *= _Alpha;
				#ifndef LOW_SPEC_SHADERS
					if ( _StartColorOverlayHeightBlend < 0.00001f )
					{
						float ShadowTerm = CalculateShadow( Input.ShadowProj, ShadowMap );
						// Apply shadow tint with cloud interaction for borders
						float CloudMask = GetCloudShadowMask( Input.WorldSpacePos.xz, FogOfWarAlphaValue );
						Diffuse.rgb = ApplyTerrainShadowTintWithClouds( Diffuse.rgb, Input.WorldSpacePos.xz, CloudMask, ShadowTerm );
						
						float3 CloudyColor = float3( 0.0f, 0.01f, 0.02f );
						Diffuse.rgb = lerp( Diffuse.rgb, CloudyColor, CloudMask * 0.6f );
					}
				#endif
				// MOD(godherja)
				//Diffuse.rgb = ApplyFogOfWar( Diffuse.rgb, Input.WorldSpacePos, FogOfWarAlpha );
				Diffuse.rgb = GH_ApplyAtmosphericEffects( Diffuse.rgb, Input.WorldSpacePos, FogOfWarAlpha );
				// END MOD
				Diffuse.rgb = ApplyMapDistanceFogWithoutFoW( Diffuse.rgb, Input.WorldSpacePos );

				return Diffuse;
			}
		]]
	}
	
	MainCode PixelShaderWar
	{
		Input = "VS_OUTPUT_PDX_BORDER"
		Output = "PDX_COLOR"
		Code
		[[			
			PDX_MAIN
			{
				float4 Diffuse = PdxTex2D( BorderTexture, Input.UV );
				
				// Tweakable values
				float BaseSpeed = 1.0f;
				float WaveLength = 4.0f;
				float MinAlpha = 0.1f;
				float PulseFrequency = 0.8f; // How fast the speed pulses
				float PulseAmplitude = 0.4f; // How much the speed varies (0-1)
				float SpeedBrightnessBoost = 1.0f; // How much brighter when fast
				float CometSharpness = 12.0f; // Leading edge sharpness
				float CometTailLength = 0.7f; // How long the tail extends (0-1) 
				float BrightnessPhaseLeadFactor = 0.3f; // How much brightness anticipates motion
				
				// Wave movement with variable speed
				float PulsePhase = PulseFrequency * GlobalTime * 6.28318f;
				
				// Position calculation using smooth sine integration
				float BaseOffset = BaseSpeed * GlobalTime;
				float PulseOffset = BaseSpeed * PulseAmplitude * 
					(1.0f - cos(PulsePhase)) / (PulseFrequency * 6.28318f);
				float Offset = BaseOffset + PulseOffset;
				
				// Brightness synchronized with movement speed
				// Apply slight phase lead so brightness anticipates motion
				float BrightnessPhase = PulsePhase + BrightnessPhaseLeadFactor;
				float BrightnessSpeed = BaseSpeed * 
					(1.0f + PulseAmplitude * sin(BrightnessPhase));
				
				float Wave = frac(Input.UV.x / WaveLength + Offset);
				
				// Create comet-like wave shape: sharp front, soft tail
				
				// Build asymmetric profile
				float WaveShape;
				if (Wave < 0.5f) {
					// Leading half - sharp rise to peak
					float t = Wave * 2.0f; // 0 to 1
					WaveShape = pow(t, CometSharpness);
				} else {
					// Trailing half - gradual falloff for comet tail
					float t = (1.0f - Wave) * 2.0f; // 1 to 0 as we go back
					// Exponential decay for natural comet tail
					float TailFalloff = 1.0f + CometTailLength * 3.0f;
					WaveShape = pow(t, 1.0f / TailFalloff);
				}
				
				// Add subtle glow at the very front for extra impact
				float FrontGlow = exp(-Wave * 20.0f) * 0.3f;
				WaveShape = saturate(WaveShape + FrontGlow);
				
				// Vary brightness based on visual movement speed
				float SpeedFactor = BrightnessSpeed / BaseSpeed;
				float BrightnessMultiplier = 1.0f + (SpeedFactor - 1.0f) * SpeedBrightnessBoost;
				float3 GlowColor = Diffuse.rgb * 2.5f * BrightnessMultiplier;
				Diffuse.rgb = lerp(Diffuse.rgb, GlowColor, WaveShape);
				float WaveAlpha = lerp(MinAlpha, 1.0f, WaveShape);
				Diffuse.a *= WaveAlpha;
				
				//Standard 
				// MOD(godherja)
				//Diffuse.rgb = ApplyFogOfWar( Diffuse.rgb, Input.WorldSpacePos, FogOfWarAlpha );
				Diffuse.rgb = GH_ApplyAtmosphericEffects( Diffuse.rgb, Input.WorldSpacePos, FogOfWarAlpha );
				// END MOD
				Diffuse.rgb = ApplyMapDistanceFogWithoutFoW( Diffuse.rgb, Input.WorldSpacePos );
				
				Diffuse.a *= _Alpha;

				#ifndef LOW_SPEC_SHADERS
					if ( _StartColorOverlayHeightBlend < 0.00001f )
					{
						float ShadowTerm = CalculateShadow( Input.ShadowProj, ShadowMap );
						// Apply shadow tint with cloud interaction for war borders
						float CloudMask = GetCloudShadowMask( Input.WorldSpacePos.xz );
						Diffuse.rgb = ApplyTerrainShadowTintWithClouds( Diffuse.rgb, Input.WorldSpacePos.xz, CloudMask, ShadowTerm );
					}
				#endif

				return Diffuse;
			}
		]]
	}


	MainCode PixelShaderWarOldAnimation
	{
		Input = "VS_OUTPUT_PDX_BORDER"
		Output = "PDX_COLOR"
		Code
		[[			
			PDX_MAIN
			{
				float4 Diffuse = PdxTex2D( BorderTexture, Input.UV );

				float vPulseFactor = saturate( smoothstep( 0.0f, 1.0f, 0.4f + sin( GlobalTime * 2.5f ) * 0.25f ) );
				Diffuse.rgb = saturate( Diffuse.rgb * vPulseFactor );
				
				// MOD(godherja)
				//Diffuse.rgb = ApplyFogOfWar( Diffuse.rgb, Input.WorldSpacePos, FogOfWarAlpha );
				Diffuse.rgb = GH_ApplyAtmosphericEffects( Diffuse.rgb, Input.WorldSpacePos, FogOfWarAlpha );
				// END MOD
				Diffuse.rgb = ApplyMapDistanceFogWithoutFoW( Diffuse.rgb, Input.WorldSpacePos );
				Diffuse.a *= _Alpha;

				#ifndef LOW_SPEC_SHADERS
					if ( _StartColorOverlayHeightBlend < 0.00001f )
					{
						float ShadowTerm = CalculateShadow( Input.ShadowProj, ShadowMap );
						// Apply shadow tint with cloud interaction for war borders
						float CloudMask = GetCloudShadowMask( Input.WorldSpacePos.xz );
						Diffuse.rgb = ApplyTerrainShadowTintWithClouds( Diffuse.rgb, Input.WorldSpacePos.xz, CloudMask, ShadowTerm );
					}
				#endif

				return Diffuse;
			}
		]]
	}

	MainCode PixelShaderStruggle
	{
		Input = "VS_OUTPUT_PDX_BORDER"
		Output = "PDX_COLOR"
		Code
		[[
			PDX_MAIN
			{
				float4 Diffuse = PdxTex2D( BorderTexture, Input.UV );

				float Highlight = float( _UserId );

				float LowColorMult = 0.3f;
				float ColorMult = LowColorMult + ( ( 1.0f - LowColorMult ) * Highlight );

				Diffuse.rgb = saturate( Diffuse.rgb * ColorMult );

				// MOD(godherja)
				//Diffuse.rgb = ApplyFogOfWar( Diffuse.rgb, Input.WorldSpacePos, FogOfWarAlpha );
				Diffuse.rgb = GH_ApplyAtmosphericEffects( Diffuse.rgb, Input.WorldSpacePos, FogOfWarAlpha );
				// END MOD
				Diffuse.rgb = ApplyMapDistanceFogWithoutFoW( Diffuse.rgb, Input.WorldSpacePos );
				
				Diffuse.a *= _Alpha;
				return Diffuse;
			}
		]]
	}
}

BlendState BlendState
{
	BlendEnable = yes
	SourceBlend = "SRC_ALPHA"
	DestBlend = "INV_SRC_ALPHA"
	WriteMask = "RED|GREEN|BLUE"
}

RasterizerState RasterizerState
{
	DepthBias = -30000
	SlopeScaleDepthBias = -2
}

DepthStencilState DepthStencilState
{
	DepthEnable = yes
	StencilEnable = yes
	FrontStencilFunc = not_equal
	StencilRef = 1
	DepthWriteEnable = no
}


Effect PdxBorder
{
	VertexShader = "VertexShader"
	PixelShader = "PixelShader"
}

Effect PdxBorderWar
{
	VertexShader = "VertexShader"
	PixelShader = "PixelShaderWarOldAnimation"
}

Effect PdxBorderStruggle
{
	VertexShader = "VertexShader"
	PixelShader = "PixelShaderStruggle"
}
