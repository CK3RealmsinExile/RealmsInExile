Includes = {
	"cw/pdxterrain.fxh"
	"cw/pdxmesh.fxh"

	"jomini/map_lighting.fxh"
	"jomini/jomini_fog.fxh"
	# MOD(godherja)
	#"jomini/jomini_fog_of_war.fxh"
	"gh_atmospheric.fxh"
	# END MOD
	"jomini/jomini_mapobject.fxh"
	"bordercolor.fxh"
	"dynamic_masks.fxh"
	"legend.fxh"
	"disease.fxh"
	"shadow_tint.fxh"
	"clouds.fxh"
	"province_effects.fxh"
	"standardfuncsgfx.fxh"
}

PixelShader =
{
	TextureSampler DiffuseMap
	{
		Index = 0
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
	}
	TextureSampler PropertiesMap
	{
		Index = 1
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
	}
	TextureSampler NormalMap
	{
		Index = 2
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
	}
	TextureSampler TintMap
	{
		Index = 3
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
	}
	TextureSampler ShadowTexture
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
	TextureSampler FogOfWarAlpha
	{
		Ref = JominiFogOfWar
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
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
	#TextureSampler TerrainColorMapTexture
	#{
	#	Ref = PdxTerrainColorMap
	#	MagFilter = "Linear"
	#	MinFilter = "Linear"
	#	MipFilter = "Linear"
	#	SampleModeU = "Clamp"
	#	SampleModeV = "Clamp"
	#}
}

VertexStruct VS_OUTPUT_TREE
{
	float4 	Position 		: PDX_POSITION;
	float3 	Normal			: TEXCOORD0;
	float3 	Tangent			: TEXCOORD1;
	float3 	Bitangent		: TEXCOORD2;
	float2 	UV0				: TEXCOORD3;
	float3 	WorldSpacePos	: TEXCOORD5;
	uint	InstanceIndex	: TEXCOORD6;
	float3	Scale_Seed_Yaw	: TEXCOORD7;
}

VertexShader =
{
	Code
	[[
		VS_OUTPUT_TREE ConvertOutput( VS_OUTPUT_PDXMESH In )
		{
			VS_OUTPUT_TREE Out;
			Out.Position = In.Position;
			Out.Normal = In.Normal;
			Out.Tangent = In.Tangent;
			Out.Bitangent = In.Bitangent;
			Out.UV0 = In.UV0;
			Out.WorldSpacePos = In.WorldSpacePos;
			return Out;
		}

		void FinalizeOutput( inout VS_OUTPUT_TREE Out, in uint InstanceIndex, in float4x4 WorldMatrix )
		{
			Out.InstanceIndex = InstanceIndex;
			Out.Scale_Seed_Yaw.x = 1.0f;
			Out.Scale_Seed_Yaw.y = CalcRandom( float2( GetMatrixData( WorldMatrix, 0, 2 ), GetMatrixData( WorldMatrix, 2, 2 ) ) );
			Out.Scale_Seed_Yaw.z = frac(Out.Scale_Seed_Yaw.y) * TWO_PI; //We could calculate a correct Yaw from the WorldMatrix, we could also just fake it!
		}
	]]
	MainCode VS_standard
	{
		Input = "VS_INPUT_PDXMESHSTANDARD"
		Output = "VS_OUTPUT_TREE"
		Code
		[[
			PDX_MAIN
			{
				VS_OUTPUT_TREE Out = ConvertOutput( PdxMeshVertexShaderStandard( Input ) );
				FinalizeOutput( Out, Input.InstanceIndices.y, PdxMeshGetWorldMatrix( Input.InstanceIndices.y ) );
				return Out;
			}
		]]
	}
	MainCode VS_mapobject
	{
		Input = "VS_INPUT_PDXMESH_MAPOBJECT"
		Output = "VS_OUTPUT_TREE"
		Code
		[[
			PDX_MAIN
			{
				float4x4 WorldMatrix = UnpackAndGetMapObjectWorldMatrix( Input.InstanceIndex24_Opacity8 );
				VS_OUTPUT_TREE Out = ConvertOutput( PdxMeshVertexShader( PdxMeshConvertInput( Input ), Input.InstanceIndex24_Opacity8, WorldMatrix ) );
				FinalizeOutput( Out, Input.InstanceIndex24_Opacity8, WorldMatrix );
				return Out;
			}
		]]
	}
}

PixelShader =
{

	Code
	[[
		float ApplyOpacity( in float Alpha, in float2 NoiseCoordinate, in uint InstanceIndex )
		{
			#ifdef JOMINI_MAP_OBJECT
				float Opacity = UnpackAndGetMapObjectOpacity( InstanceIndex );
			#else
				float Opacity = PdxMeshGetOpacity( InstanceIndex );
			#endif
			return PdxMeshApplyOpacity( Alpha, NoiseCoordinate, Opacity );
		}

		float DitherThreshold( in float2 ScreenPosition )
		{
			// 4x4 Bayer dither matrix
			//float4x4 DitherMatrix = float4x4(
			//	0.0f / 16.0f,  8.0f / 16.0f,  2.0f / 16.0f, 10.0f / 16.0f,
			//	12.0f / 16.0f, 4.0f / 16.0f, 14.0f / 16.0f,  6.0f / 16.0f,
			//	3.0f / 16.0f, 11.0f / 16.0f,  1.0f / 16.0f,  9.0f / 16.0f,
			//	15.0f / 16.0f, 7.0f / 16.0f, 13.0f / 16.0f,  5.0f / 16.0f
			//);

			// Remove the computation version
			float4x4 DitherMatrix = float4x4(
				0.0f,      0.5f,      0.125f,    0.625f,
				0.75f,     0.25f,     0.875f,    0.375f,
				0.1875f,   0.6875f,   0.0625f,   0.5625f,
				0.9375f,   0.4375f,   0.8125f,   0.3125f
			);
			uint2 PixelPos = uint2( ScreenPosition.xy ) % 4;
			return DitherMatrix[ PixelPos.y ][ PixelPos.x ];
		}

		void DitheredAlpha( in float Alpha, in float2 ScreenPosition, in float BaseThreshold )
		{
			float DitherValue = DitherThreshold( ScreenPosition );
			float AdjustedThreshold = BaseThreshold + (DitherValue - 0.5f) * 0.6f;
			clip( Alpha - AdjustedThreshold );
		}

		float3 CalculateLighting( in VS_OUTPUT_TREE Input, in float4 Diffuse, in float3 Normal, in float4 Properties, in float SnowHighlight )
		{
			float3 WorldSpacePos = Input.WorldSpacePos;
			float2 MapCoords = WorldSpacePos.xz * WorldSpaceToTerrain0To1;
			float3 BorderColor;
			float BorderPreLightingBlend;
			float BorderPostLightingBlend;
			GetBorderColorAndBlendGame( WorldSpacePos.xz , Diffuse.rgb, BorderColor, BorderPreLightingBlend, BorderPostLightingBlend );

			LerpBorderColorWithFogOfWar( Diffuse.rgb, WorldSpacePos.xz, BorderColor, BorderPreLightingBlend );
			ApplyHighlightColor( Diffuse.rgb, MapCoords );
			CompensateWhiteHighlightColor( Diffuse.rgb, MapCoords, SnowHighlight );
			
			SMaterialProperties MaterialProps = GetMaterialProperties( Diffuse.rgb, Normal, Properties.a, Properties.g, Properties.b );

			// Calculate combined shadow mask from clouds and shadow tint
			float CloudMask = GetCloudShadowMask( WorldSpacePos.xz );
			const float3 TerrainNormal = CalculateNormal( WorldSpacePos.xz );
			
			// Get shadow term for shadow tint calculation
			SLightingProperties LightingProps = GetMapLightingProperties( WorldSpacePos, ShadowTexture );

			// Use terrain dual scenario lighting for trees (sunny outside clouds, shadow inside clouds)
			LightingProps._ToLightDir = ToTerrainSunnySunDir;
			float TerrainShadowTerm = GetTerrainShadowTintMask( MapCoords, LightingProps._ToLightDir, LightingProps._ShadowTerm, TerrainNormal );
			LightingProps._ShadowTerm = LightingProps._ShadowTerm * ( 1.0f - TerrainShadowTerm );

			float3 Color = CalculateTerrainDualScenarioLighting( LightingProps, MaterialProps, CloudMask, EnvironmentMap );
			Color = ApplyTreeShadowTintWithClouds( Color, WorldSpacePos.xz, CloudMask, LightingProps._ShadowTerm, Normal, TerrainNormal);

			ApplyLegendDiffuse( Color, MapCoords );
			ApplyDiseaseDiffuse( Color, MapCoords );

			// MOD(godherja)
			//Color = ApplyFogOfWar( Color, WorldSpacePos, FogOfWarAlpha );
			Color = GH_ApplyAtmosphericEffects( Color, WorldSpacePos, FogOfWarAlpha );
			// END MOD
			Color = ApplyMapDistanceFogWithoutFoW( Color, WorldSpacePos );

			BorderColor = lerp( BorderColor, BorderColor * 0.1f, CloudMask ); // Don't have darkening effect visible when zoomed out

			Color.rgb = lerp( Color.rgb, BorderColor, BorderPostLightingBlend );

			// DebugReturn( Color, MaterialProps, LightingProps, EnvironmentMap );
			return Color;
		}
	]]

	MainCode PS_leaf
	{
		Input = "VS_OUTPUT_TREE"
		Output = "PDX_COLOR"
		Code
		[[
			PDX_MAIN
			{
				float2 ColorMapCoords = Input.WorldSpacePos.xz * WorldSpaceToTerrain0To1;
				float4 Diffuse = PdxTex2D( DiffuseMap, Input.UV0 );

				//Opacity
				Diffuse.a = ApplyOpacity( Diffuse.a, Input.Position.xy, Input.InstanceIndex );
				// Use dithered alpha test for smooth edges

				if ( _HasTreeDitheringEnabled == 1 )
				{
					DitheredAlpha( Diffuse.a, Input.Position.xy, 0.4f );
				}
				else
				{
					clip( Diffuse.a - 0.4f );
				}

				float4 NormalMapSample = PdxTex2D( NormalMap, Input.UV0 );
				float3 NormalSample = UnpackRRxGNormal( NormalMapSample );
				float3x3 TBN = Create3x3( normalize( Input.Tangent ), normalize( Input.Bitangent ), normalize( Input.Normal ) );
				float3 Normal = normalize( mul( NormalSample, TBN ) );

				float4 Properties = PdxTex2D( PropertiesMap, Input.UV0 );

				EffectIntensities ConditionData;
				SampleProvinceEffectsMask( ColorMapCoords, ConditionData );
				ApplyProvinceEffectsTree( ConditionData, Diffuse, ColorMapCoords, Input.WorldSpacePos.xz );

				//Tint
				float3 Tint = PdxTex2DLod0( TintMap, float2( Input.Scale_Seed_Yaw.y, 0.5f ) ).rgb;
				Tint = GetOverlay( Diffuse.rgb, Tint, 1.0 );

				Diffuse.rgb = lerp( Diffuse.rgb, Tint, NormalMapSample.b );

				//Colormap
				float SnowHighlight = 0.0f;
				//Diffuse.rgb = ApplyDynamicMasksDiffuse( Diffuse.rgb, Normal, ColorMapCoords, SnowHighlight );
				ApplySnowMaterialMesh( ConditionData, Diffuse.rgb, Properties, Normal, Input.WorldSpacePos.xz, SnowHighlight );
				Diffuse.a = lerp( Diffuse.a, smoothstep( 0.8f, 0.85f, Diffuse.a ), SnowHighlight );
				clip( Diffuse.a - 0.4f );
#if defined( PDX_OSX ) && defined( PDX_OPENGL )
				// The amount of texture samplers is limited on Mac, so we don't read the data for the ColorMap directly
				// from a texture. Instead we assign a default gray value here. This is also done for the terrain (on Mac)
				// to make sure we have the same color variation for both the terrain and the trees
				float3 ColorMap = float3( vec3( 0.5 ) );
#else
				float3 ColorMap = ToLinear( PdxTex2D( ColorTexture, float2( ColorMapCoords.x, 1.0 - ColorMapCoords.y ) ).rgb);
#endif
				Diffuse.rgb = GetOverlay( Diffuse.rgb, ColorMap, 1.0 );

				float3 Color = CalculateLighting( Input, Diffuse, Normal, Properties, SnowHighlight );

				return float4( Color, Diffuse.a );
			}
		]]
	}

	MainCode PS_shadow
	{
		Input = "VS_OUTPUT_TREE"
		Output = "PDX_COLOR"
		Code
		[[
			PDX_MAIN
			{
				float2 uv = Input.UV0;
				float4 Color = PdxTex2D( DiffuseMap, uv );

				Color.a = ApplyOpacity( Color.a, Input.Position.xy, Input.InstanceIndex );
				clip( Color.a - 0.5f );

				return vec4(1);
			}
		]]
	}
}

BlendState BlendState
{
	BlendEnable = no
	alphatocoverage = yes
}
BlendState BlendStateShadow
{
	BlendEnable = no
	alphatocoverage = no
}
BlendState BlendStateLod
{
	BlendEnable = no
	alphatocoverage = no
}

RasterizerState ShadowRasterizerState
{
	DepthBias = 40000
	SlopeScaleDepthBias = 2
}

#Uncomment this if you want trees to render on top of borders for example
#DepthStencilState DepthStencilState
#{
#	StencilEnable = yes
#	FrontStencilPassOp = replace
#	StencilRef = 1
#}






Effect tree
{
	VertexShader = VS_standard
	PixelShader = PS_leaf
}
Effect treeShadow
{
	VertexShader = VertexPdxMeshStandardShadow
	PixelShader = PixelPdxMeshAlphaBlendShadow
	BlendState = BlendStateShadow
	RasterizerState = ShadowRasterizerState
}

#Map object shaders
Effect tree_mapobject
{
	VertexShader = VS_mapobject
	PixelShader = PS_leaf
}

Effect treeShadow_mapobject
{
	VertexShader = VS_jomini_mapobject_shadow
	PixelShader = PS_jomini_mapobject_shadow_alphablend
	BlendState = BlendStateShadow
	RasterizerState = ShadowRasterizerState
}

Effect tree_lod
{
	VertexShader = VS_standard
	PixelShader = PS_leaf
	BlendState = BlendStateLod
}
Effect tree_lodShadow
{
	VertexShader = VertexPdxMeshStandardShadow
	PixelShader = PixelPdxMeshAlphaBlendShadow
	BlendState = BlendStateShadow
	RasterizerState = ShadowRasterizerState
}

#Map object shaders
Effect tree_lod_mapobject
{
	VertexShader = VS_mapobject
	PixelShader = PS_leaf
	BlendState = BlendStateLod
}

Effect tree_lodShadow_mapobject
{
	VertexShader = VS_jomini_mapobject_shadow
	PixelShader = PS_jomini_mapobject_shadow_alphablend
	BlendState = BlendStateShadow
	RasterizerState = ShadowRasterizerState
}
