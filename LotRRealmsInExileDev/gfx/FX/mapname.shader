Includes = {
	# MOD(lotr)
	"cw/random.fxh"
	# END MOD
	"jomini/countrynames.fxh"
	"jomini/jomini_fog.fxh"
	"jomini/jomini_fog_of_war.fxh"
	"standardfuncsgfx.fxh"
	"cw/lighting.fxh"
	"jomini/jomini_lighting.fxh"
	"jomini/jomini_water.fxh"
	"clouds.fxh"
	# MOD (lotr)
	"jomini/jomini_province_overlays.fxh"
	"gh_atmospheric.fxh"
	"gh_camera_utils.fxh"
	# END MOD
}

VertexShader =
{
	MainCode MapNameVertexShader
	{
		Input = "VS_INPUT_MAPNAME"
		Output = "VS_OUTPUT_MAPNAME"
		Code
		[[
			PDX_MAIN
			{
				VS_OUTPUT_MAPNAME Out = MapNameVertexShader( Input, FlatMapHeight, FlatMapLerp );
				return Out;
			}
		]]
	}
}

PixelShader =
{
	TextureSampler FontAtlas
	{
		Ref = PdxTexture0
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Clamp"
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
	TextureSampler MapNameOverlayTexture
	{
		Index = 13
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear" 
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
		File = "gfx/map/textures/rough_texture_overlay.dds"
		sRGB = no
	}

	MainCode MapNamePixelShader
	{
		Input = "VS_OUTPUT_MAPNAME"
		Output = "PDX_COLOR"
		Code
		[[
			PDX_MAIN
			{
				#define TEXT_COLOR_FLATMAP float3( 0.006f, 0.005f, 0.005f )
				#define OUTLINE_COLOR_FLATMAP float3( 0.2f, 0.18f, 0.18f )

				#define TEXT_COLOR_CLEAR float3( 0.018f, 0.014f, 0.014f )
				#define TEXT_COLOR_FOW float3( 0.006f, 0.006f, 0.012f )
				#define TEXT_COLOR_CLOUD_SHADOW float3( 0.01f, 0.01f, 0.016f )

				#define OUTLINE_COLOR_CLEAR float3( 0.3f, 0.25f, 0.25f )
				#define OUTLINE_COLOR_FOW float3( 0.2f, 0.2f, 0.2f )
				#define OUTLINE_COLOR_CLOUD_SHADOW float3( 0.07f, 0.07f, 0.1f )

				#define OUTLINE_WIDTH 0.4f
				#define OUTLINE_SOFT_EDGE_SCALE 2.5f
				#define OUTLINE_ALPHA_SCALE 0.2f
				#define OUTLINE_NOISE_VARIATION_MIN 0.2f
				#define OUTLINE_NOISE_VARIATION_MAX 0.8f 

			// MOD(lotr)
			float LOTR_OverlayAlphaMultiplier = 1.0f;
			float GH_CameraPitchAlphaMultiplier = GH_GetDefaultCameraPitchAlphaMultiplier();
			float LOTR_AlphaMultiplier = LOTR_OverlayAlphaMultiplier*GH_CameraPitchAlphaMultiplier;
			// END MOD

			float Sample = PdxTex2D( FontAtlas, Input.TexCoord ).r;
			float2 TextureCoordinate = Input.TexCoord * TextureSize;
			float Ratio = CalcTexelPixelRatio( TextureCoordinate );
			
				#define TEXT_WIDTH 0.05f
				// Interior transition
				float InteriorMid = 0.50f;
				float InteriorSmoothing = TEXT_WIDTH;
				float InteriorFactor = smoothstep(
					InteriorMid - InteriorSmoothing,
					InteriorMid,
					Sample
				);

				// Define a scaling factor for the UV coordinates
				float2 InteriorUVScale = float2( 20.0f, 20.0f );
				float2 OutlineUVScale = float2( 50.0f, 30.0f );

				// Scale the texture coordinates 
				float2 InteriorScaledTexCoord = Input.TexCoord * InteriorUVScale;
				float2 OutlineScaledTexCoord = Input.TexCoord * OutlineUVScale;

				// Sample the overlay texture with scaled coordinates
				float4 InteriorOverlayColor = PdxTex2D( MapNameOverlayTexture, InteriorScaledTexCoord );
				float4 OutlineOverlayColor = PdxTex2D( MapNameOverlayTexture, OutlineScaledTexCoord );
				float NoiseVariation = lerp( OUTLINE_NOISE_VARIATION_MIN, OUTLINE_NOISE_VARIATION_MAX, OutlineOverlayColor.a );

				// Outline calculation
				float OutlineSmoothing = OUTLINE_WIDTH + Ratio * LodFactor * 0.4f;
				float OutlineFactor = pow( smoothstep(
					InteriorMid - OutlineSmoothing * NoiseVariation,
					InteriorMid - InteriorSmoothing,
					Sample
				), OUTLINE_SOFT_EDGE_SCALE );
				OutlineFactor *= OUTLINE_ALPHA_SCALE;

				float4 MixedColor;
				if ( FlatMapLerp != 1.0f )
				{
					float FogOfWarAlphaValue = PdxTex2D( FogOfWarAlpha, 
						Input.WorldSpacePos.xz * InverseWorldSize ).r;

					// Get cloud shadow mask
					float CloudMask = GetCloudShadowMask( Input.WorldSpacePos.xz, FogOfWarAlphaValue );
					
					// Interpolate colors based on FoW
					float3 TextColor = lerp( TEXT_COLOR_FOW, 
						TEXT_COLOR_CLEAR, FogOfWarAlphaValue );
					float3 OutlineColor = lerp( OUTLINE_COLOR_FOW, 
						OUTLINE_COLOR_CLEAR, FogOfWarAlphaValue );

					// Apply cloud shadow color modification
					TextColor = lerp( TextColor, TEXT_COLOR_CLOUD_SHADOW, CloudMask );
					OutlineColor = lerp( OutlineColor, OUTLINE_COLOR_CLOUD_SHADOW, CloudMask );

					// Combine colors
					MixedColor.rgb = lerp( OutlineColor, TextColor, InteriorFactor );
					MixedColor.a = max( OutlineFactor, InteriorFactor ) * Transparency;

					// Apply distance fog
					MixedColor.rgb = ApplyMapDistanceFogWithoutFoW( MixedColor.rgb, 
						Input.WorldSpacePos );
				}
				else
				{
					// Flat map mode - use clear colors
					MixedColor.rgb = lerp( OUTLINE_COLOR_FLATMAP, TEXT_COLOR_FLATMAP, InteriorFactor );
					MixedColor.a = max( OutlineFactor, InteriorFactor ) * Transparency;
				}

				// Apply overlay blend mode with blend factor
				float BlendFactor = 0.5f; // Can be adjusted as needed
				float3 OverlayedColor = Overlay( MixedColor.rgb, InteriorOverlayColor.rgb );
				MixedColor.rgb = lerp( MixedColor.rgb, OverlayedColor, BlendFactor );
				// MOD(lotr)
				MixedColor.a *= LOTR_AlphaMultiplier;
				// END MOD
				return MixedColor;
			}
		]]
	}
}


BlendState BlendState
{
	BlendEnable = yes
	SourceBlend = "src_alpha"
	DestBlend = "inv_src_alpha"
	WriteMask = "RED|GREEN|BLUE"
}

RasterizerState RasterizerState
{
	frontccw = yes
}

# This makes the map names appear 'under' map objects, while actually being above them
# Doesn't use the normal depthbuffer, but instead a specific stencil-buffer written into by other objects.
DepthStencilState DepthStencilStateFromStencil
{
	DepthEnable = no
	StencilEnable = yes
	FrontStencilFunc = not_equal
	StencilRef = 1
}

Effect mapname
{
	VertexShader = "MapNameVertexShader"
	PixelShader = "MapNamePixelShader"
	DepthStencilState = DepthStencilStateFromStencil

	Defines = { "PDX_NAMES_SHADOW_PROJ" }
}
