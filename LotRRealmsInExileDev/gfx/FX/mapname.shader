Includes = {
	"jomini/countrynames.fxh"
	"jomini/jomini_fog.fxh"
	# MOD(godherja)
	#"jomini/jomini_fog_of_war.fxh"
	"gh_atmospheric.fxh"
	"gh_camera_utils.fxh"
	# END MOD
	# MOD(lotr)
	"jomini/jomini_province_overlays.fxh"
	# END MOD
	"standardfuncsgfx.fxh"
	"cw/lighting.fxh"
	"jomini/jomini_lighting.fxh"
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
	
	MainCode MapNamePixelShader
	{
		Input = "VS_OUTPUT_MAPNAME"
		Output = "PDX_COLOR"
		Code
		[[
			// MOD(lotr)
			float LOTR_GetOverlayAlphaMultiplierAtWorldSpacePosXZ(in float2 WorldSpacePosXZ)
			{
				float4 OverlayColor = BilinearColorSample(WorldSpacePosXZ * WorldSpaceToTerrain0To1, IndirectionMapSize, InvIndirectionMapSize, ProvinceColorIndirectionTexture, ProvinceColorTexture);

				return LOTR_GetOverlayAlphaMultiplier(OverlayColor.rgb);
			}
			// END MOD

			PDX_MAIN
			{
			// MOD(lotr)
			// float4 TextColor = float4( 0, 0, 0, 1 );
			// float4 OutlineColor = float4( 1, 1, 1, 1 );

			//float LOTR_OverlayAlphaMultiplier   = LOTR_GetOverlayAlphaMultiplierAtWorldSpacePosXZ(Input.WorldSpacePos.xz);
			float LOTR_OverlayAlphaMultiplier   = 1.0f; // Replace with the previous line to hide map names over black map overlay
			float GH_CameraPitchAlphaMultiplier = GH_GetDefaultCameraPitchAlphaMultiplier();

			float LOTR_Alpha = LOTR_OverlayAlphaMultiplier*GH_CameraPitchAlphaMultiplier;

			float4 TextColor = float4(0, 0, 0, LOTR_Alpha);
			float4 OutlineColor = float4(1, 1, 1, LOTR_Alpha);
			// END MOD

			float Sample = PdxTex2D( FontAtlas, Input.TexCoord ).r;
			
			float2 TextureCoordinate = Input.TexCoord * TextureSize;
			float Ratio = CalcTexelPixelRatio( TextureCoordinate );
			
			float Smoothing = 0.2f + Ratio * LodFactor;
			float Mid = 0.52f;

			float Factor = smoothstep( Mid - Smoothing, Mid, Sample );

			float4 MixedColor = lerp( OutlineColor, TextColor, Factor );

			// Set OutlineWidth to control outline width
			float OutlineWidth = 0.1;
			float OutlineSmoothing = OutlineWidth + Ratio * LodFactor * 0.4f;
			float OutlineFactor = smoothstep( Mid - OutlineSmoothing, Mid, Sample );
			MixedColor.a *= OutlineFactor;
			
			MixedColor.a *= Transparency;

			MixedColor.rgb = GH_ApplyAtmosphericEffects( MixedColor.rgb, Input.WorldSpacePos, FogOfWarAlpha );
			MixedColor.rgb = ApplyDistanceFog( MixedColor.rgb, Input.WorldSpacePos );
			
			// Apply lighting and shadows, only if we're fully in flat-map mode
			if ( HasFlatMapLightingEnabled == 1 && FlatMapLerp > 0.0 )
			{
				float ShadowTerm = CalculateShadow( Input.ShadowProj, ShadowMap );
				SMaterialProperties NamesMaterialProps = GetMaterialProperties( MixedColor.rgb, float3( 0.0, 1.0, 0.0 ), 1.0, 0.0, 0.0 );
				SLightingProperties NamesLightingProps = GetSunLightingProperties( Input.WorldSpacePos, ShadowTerm );
				MixedColor.rgb = CalculateSunLighting( NamesMaterialProps, NamesLightingProps, EnvironmentMap );
			}
			
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

# This makes the man names appear 'under' map objects, while actually being above them
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
