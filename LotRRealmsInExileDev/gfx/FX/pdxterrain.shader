Includes = {
	"cw/pdxterrain.fxh"
	"cw/heightmap.fxh"
	"cw/shadow.fxh"
	"cw/utility.fxh"
	"cw/camera.fxh"
	"jomini/jomini_fog.fxh"
	"jomini/jomini_lighting.fxh"
	# MOD(godherja)
	#"jomini/jomini_fog_of_war.fxh"
	"gh_atmospheric.fxh"
	# END MOD
	"jomini/jomini_water.fxh"
	"standardfuncsgfx.fxh"
	"bordercolor.fxh"
	"lowspec.fxh"
	"legend.fxh"
	"cw/lighting.fxh"
	"dynamic_masks.fxh"
	"disease.fxh"
	"province_effects.fxh"
}

VertexStruct VS_OUTPUT_PDX_TERRAIN
{
	float4 Position			: PDX_POSITION;
	float3 WorldSpacePos	: TEXCOORD1;
	float4 ShadowProj		: TEXCOORD2;
};

VertexStruct VS_OUTPUT_PDX_TERRAIN_LOW_SPEC
{
	float4 Position			: PDX_POSITION;
	float3 WorldSpacePos	: TEXCOORD1;
	float4 ShadowProj		: TEXCOORD2;
	float3 DetailDiffuse	: TEXCOORD3;
	float4 DetailMaterial	: TEXCOORD4;
	float3 ColorMap			: TEXCOORD5;		
	float3 FlatMap			: TEXCOORD6;
	float3 Normal			: TEXCOORD7;
};

# Limited JominiEnvironment data to get nicer transitions between the Flatmap lighting and Terrain lighting
# Only used in terrain shader while lerping between flatmap and terrain.
ConstantBuffer( FlatMapLerpEnvironment )
{
	float	FlatMapLerpCubemapIntensity;
	float3	FlatMapLerpSunDiffuse;
	float	FlatMapLerpSunIntensity;
	float4x4 FlatMapLerpCubemapYRotation;
};

VertexShader =
{
	TextureSampler DetailTextures
	{
		Ref = PdxTerrainTextures0
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
		type = "2darray"
	}
	TextureSampler NormalTextures
	{
		Ref = PdxTerrainTextures1
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
		type = "2darray"
	}
	TextureSampler MaterialTextures
	{
		Ref = PdxTerrainTextures2
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
		type = "2darray"
	}
	TextureSampler DetailIndexTexture
	{
		Ref = PdxTerrainTextures3
		MagFilter = "Point"
		MinFilter = "Point"
		MipFilter = "Point"
		SampleModeU = "Clamp"
		SampleModeV = "Clamp"
	}
	TextureSampler DetailMaskTexture
	{
		Ref = PdxTerrainTextures4
		MagFilter = "Point"
		MinFilter = "Point"
		MipFilter = "Point"
		SampleModeU = "Clamp"
		SampleModeV = "Clamp"
	}
	TextureSampler ColorTexture
	{
		Ref = PdxTerrainColorMap
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Clamp"
		SampleModeV = "Clamp"
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
	
	Code
	[[
		VS_OUTPUT_PDX_TERRAIN TerrainVertex( float2 WithinNodePos, float2 NodeOffset, float NodeScale, float2 LodDirection, float LodLerpFactor )
		{
			STerrainVertex Vertex = CalcTerrainVertex( WithinNodePos, NodeOffset, NodeScale, LodDirection, LodLerpFactor );

			#ifdef TERRAIN_FLAT_MAP_LERP
				Vertex.WorldSpacePos.y = lerp( Vertex.WorldSpacePos.y, FlatMapHeight, FlatMapLerp );
			#endif
			#ifdef TERRAIN_FLAT_MAP
				Vertex.WorldSpacePos.y = FlatMapHeight;
			#endif

			VS_OUTPUT_PDX_TERRAIN Out;
			Out.WorldSpacePos = Vertex.WorldSpacePos;

			Out.Position = FixProjectionAndMul( ViewProjectionMatrix, float4( Vertex.WorldSpacePos, 1.0 ) );
			Out.ShadowProj = mul( ShadowMapTextureMatrix, float4( Vertex.WorldSpacePos, 1.0 ) );

			return Out;
		}
		
		// Copies of the pixels shader CalcHeightBlendFactors and CalcDetailUV functions
		float4 CalcHeightBlendFactors( float4 MaterialHeights, float4 MaterialFactors, float BlendRange )
		{
			float4 Mat = MaterialHeights + MaterialFactors;
			float BlendStart = max( max( Mat.x, Mat.y ), max( Mat.z, Mat.w ) ) - BlendRange;
			
			float4 MatBlend = max( Mat - vec4( BlendStart ), vec4( 0.0 ) );
			
			float Epsilon = 0.00001;
			return float4( MatBlend ) / ( dot( MatBlend, vec4( 1.0 ) ) + Epsilon );
		}
		
		float2 CalcDetailUV( float2 WorldSpacePosXZ )
		{
			return WorldSpacePosXZ * DetailTileFactor;
		}
		
		// A low spec vertex buffer version of CalculateDetails
		void CalculateDetailsLowSpec( float2 WorldSpacePosXZ, out float3 DetailDiffuse, out float4 DetailMaterial )
		{
			float2 DetailCoordinates = WorldSpacePosXZ * WorldSpaceToDetail;
			float2 DetailCoordinatesScaled = DetailCoordinates * DetailTextureSize;
			float2 DetailCoordinatesScaledFloored = floor( DetailCoordinatesScaled );
			float2 DetailCoordinatesFrac = DetailCoordinatesScaled - DetailCoordinatesScaledFloored;
			DetailCoordinates = DetailCoordinatesScaledFloored * DetailTexelSize + DetailTexelSize * 0.5;
			
			float4 Factors = float4(
				(1.0 - DetailCoordinatesFrac.x) * (1.0 - DetailCoordinatesFrac.y),
				DetailCoordinatesFrac.x * (1.0 - DetailCoordinatesFrac.y),
				(1.0 - DetailCoordinatesFrac.x) * DetailCoordinatesFrac.y,
				DetailCoordinatesFrac.x * DetailCoordinatesFrac.y
			);
			
			float4 DetailIndex = PdxTex2DLod0( DetailIndexTexture, DetailCoordinates ) * 255.0;
			float4 DetailMask = PdxTex2DLod0( DetailMaskTexture, DetailCoordinates ) * Factors[0];
			
			float2 Offsets[3];
			Offsets[0] = float2( DetailTexelSize.x, 0.0 );
			Offsets[1] = float2( 0.0, DetailTexelSize.y );
			Offsets[2] = float2( DetailTexelSize.x, DetailTexelSize.y );
			
			for ( int k = 0; k < 3; ++k )
			{
				float2 DetailCoordinates2 = DetailCoordinates + Offsets[k];
				
				float4 DetailIndices = PdxTex2DLod0( DetailIndexTexture, DetailCoordinates2 ) * 255.0;
				float4 DetailMasks = PdxTex2DLod0( DetailMaskTexture, DetailCoordinates2 ) * Factors[k+1];
				
				for ( int i = 0; i < 4; ++i )
				{
					for ( int j = 0; j < 4; ++j )
					{
						if ( DetailIndex[j] == DetailIndices[i] )
						{
							DetailMask[j] += DetailMasks[i];
						}
					}
				}
			}

			float2 DetailUV = CalcDetailUV( WorldSpacePosXZ );

			float4 DiffuseTexture0 = PdxTex2DLod0( DetailTextures, float3( DetailUV, DetailIndex[0] ) ) * smoothstep( 0.0, 0.1, DetailMask[0] );
			float4 DiffuseTexture1 = PdxTex2DLod0( DetailTextures, float3( DetailUV, DetailIndex[1] ) ) * smoothstep( 0.0, 0.1, DetailMask[1] );
			float4 DiffuseTexture2 = PdxTex2DLod0( DetailTextures, float3( DetailUV, DetailIndex[2] ) ) * smoothstep( 0.0, 0.1, DetailMask[2] );
			float4 DiffuseTexture3 = PdxTex2DLod0( DetailTextures, float3( DetailUV, DetailIndex[3] ) ) * smoothstep( 0.0, 0.1, DetailMask[3] );

			float4 BlendFactors = CalcHeightBlendFactors( float4( DiffuseTexture0.a, DiffuseTexture1.a, DiffuseTexture2.a, DiffuseTexture3.a ), DetailMask, DetailBlendRange );
			//BlendFactors = DetailMask;
			
			DetailDiffuse = DiffuseTexture0.rgb * BlendFactors.x + 
							DiffuseTexture1.rgb * BlendFactors.y + 
							DiffuseTexture2.rgb * BlendFactors.z + 
							DiffuseTexture3.rgb * BlendFactors.w;
			
			DetailMaterial = vec4( 0.0 );
			
			for ( int i = 0; i < 4; ++i )
			{
				float BlendFactor = BlendFactors[i];
				if ( BlendFactor > 0.0 )
				{
					float3 ArrayUV = float3( DetailUV, DetailIndex[i] );
					float4 NormalTexture = PdxTex2DLod0( NormalTextures, ArrayUV );
					float4 MaterialTexture = PdxTex2DLod0( MaterialTextures, ArrayUV );

					DetailMaterial += MaterialTexture * BlendFactor;
				}
			}
		}
	
		VS_OUTPUT_PDX_TERRAIN_LOW_SPEC TerrainVertexLowSpec( float2 WithinNodePos, float2 NodeOffset, float NodeScale, float2 LodDirection, float LodLerpFactor )
		{
			STerrainVertex Vertex = CalcTerrainVertex( WithinNodePos, NodeOffset, NodeScale, LodDirection, LodLerpFactor );

			#ifdef TERRAIN_FLAT_MAP_LERP
				Vertex.WorldSpacePos.y = lerp( Vertex.WorldSpacePos.y, FlatMapHeight, FlatMapLerp );
			#endif
			#ifdef TERRAIN_FLAT_MAP
				Vertex.WorldSpacePos.y = FlatMapHeight;
			#endif

			VS_OUTPUT_PDX_TERRAIN_LOW_SPEC Out;
			Out.WorldSpacePos = Vertex.WorldSpacePos;

			Out.Position = FixProjectionAndMul( ViewProjectionMatrix, float4( Vertex.WorldSpacePos, 1.0 ) );
			Out.ShadowProj = mul( ShadowMapTextureMatrix, float4( Vertex.WorldSpacePos, 1.0 ) );
			
			CalculateDetailsLowSpec( Vertex.WorldSpacePos.xz, Out.DetailDiffuse, Out.DetailMaterial );
			
			float2 ColorMapCoords = Vertex.WorldSpacePos.xz * WorldSpaceToTerrain0To1;

#if defined( PDX_OSX ) && defined( PDX_OPENGL )
			// We're limited to the amount of samplers we can bind at any given time on Mac, so instead
			// we disable the usage of ColorTexture (since its effects are very subtle) and assign a
			// default value here instead.
			Out.ColorMap = float3( vec3( 0.5 ) );
#else
			Out.ColorMap = PdxTex2DLod0( ColorTexture, float2( ColorMapCoords.x, 1.0 - ColorMapCoords.y ) ).rgb;
#endif

			Out.FlatMap = float3( vec3( 0.5f ) ); // neutral overlay
			#ifdef TERRAIN_FLAT_MAP_LERP
				Out.FlatMap = lerp( Out.FlatMap, PdxTex2DLod0( FlatMapTexture, float2( ColorMapCoords.x, 1.0 - ColorMapCoords.y ) ).rgb, FlatMapLerp );
			#endif

			Out.Normal = CalculateNormal( Vertex.WorldSpacePos.xz );

			return Out;
		}
	]]
	
	MainCode VertexShader
	{
		Input = "VS_INPUT_PDX_TERRAIN"
		Output = "VS_OUTPUT_PDX_TERRAIN"
		Code
		[[
			PDX_MAIN
			{
				return TerrainVertex( Input.UV, Input.NodeOffset_Scale_Lerp.xy, Input.NodeOffset_Scale_Lerp.z, Input.LodDirection, Input.NodeOffset_Scale_Lerp.w );
			}
		]]
	}

	MainCode VertexShaderSkirt
	{
		Input = "VS_INPUT_PDX_TERRAIN_SKIRT"
		Output = "VS_OUTPUT_PDX_TERRAIN"
		Code
		[[
			PDX_MAIN
			{
				VS_OUTPUT_PDX_TERRAIN Out = TerrainVertex( Input.UV, Input.NodeOffset_Scale_Lerp.xy, Input.NodeOffset_Scale_Lerp.z, Input.LodDirection, Input.NodeOffset_Scale_Lerp.w );

				float3 Position = FixPositionForSkirt( Out.WorldSpacePos, Input.VertexID );
				Out.Position = FixProjectionAndMul( ViewProjectionMatrix, float4( Position, 1.0 ) );

				return Out;
			}
		]]
	}
	
	MainCode VertexShaderLowSpec
	{
		Input = "VS_INPUT_PDX_TERRAIN"
		Output = "VS_OUTPUT_PDX_TERRAIN_LOW_SPEC"
		Code
		[[
			PDX_MAIN
			{
				return TerrainVertexLowSpec( Input.UV, Input.NodeOffset_Scale_Lerp.xy, Input.NodeOffset_Scale_Lerp.z, Input.LodDirection, Input.NodeOffset_Scale_Lerp.w );
			}
		]]
	}

	MainCode VertexShaderLowSpecSkirt
	{
		Input = "VS_INPUT_PDX_TERRAIN_SKIRT"
		Output = "VS_OUTPUT_PDX_TERRAIN_LOW_SPEC"
		Code
		[[
			PDX_MAIN
			{
				VS_OUTPUT_PDX_TERRAIN_LOW_SPEC Out = TerrainVertexLowSpec( Input.UV, Input.NodeOffset_Scale_Lerp.xy, Input.NodeOffset_Scale_Lerp.z, Input.LodDirection, Input.NodeOffset_Scale_Lerp.w );

				float3 Position = FixPositionForSkirt( Out.WorldSpacePos, Input.VertexID );
				Out.Position = FixProjectionAndMul( ViewProjectionMatrix, float4( Position, 1.0 ) );

				return Out;
			}
		]]
	}
}


PixelShader =
{
	# PdxTerrain uses texture index 0 - 6

	# Jomini specific
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

	# Game specific
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
	TextureSampler FlatMapEnvironmentMap
	{
		Ref = FlatMapEnvironmentMap
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

	Code
	[[
		SLightingProperties GetFlatMapLerpSunLightingProperties( float3 WorldSpacePos, float ShadowTerm )
		{
			SLightingProperties LightingProps;
			LightingProps._ToCameraDir = normalize( CameraPosition - WorldSpacePos );
			LightingProps._ToLightDir = ToSunDir;
			LightingProps._LightIntensity = FlatMapLerpSunDiffuse * 5;
			LightingProps._ShadowTerm = ShadowTerm;
			LightingProps._CubemapIntensity = FlatMapLerpCubemapIntensity;
			LightingProps._CubemapYRotation = FlatMapLerpCubemapYRotation;

			return LightingProps;
		}
	]]

	MainCode PixelShader
	{
		Input = "VS_OUTPUT_PDX_TERRAIN"
		Output = "PDX_COLOR"
		Code
		[[
			PDX_MAIN
			{
				clip( vec2(1.0) - Input.WorldSpacePos.xz * WorldSpaceToTerrain0To1 );

				float4 DetailDiffuse;
				float3 DetailNormal;
				float4 DetailMaterial;
				CalculateDetails( Input.WorldSpacePos.xz, DetailDiffuse, DetailNormal, DetailMaterial );

				float2 ColorMapCoords = Input.WorldSpacePos.xz * WorldSpaceToTerrain0To1;
#if defined( PDX_OSX ) && defined( PDX_OPENGL )
				// We're limited to the amount of samplers we can bind at any given time on Mac, so instead
				// we disable the usage of ColorTexture (since its effects are very subtle) and assign a
				// default value here instead.
				float3 ColorMap = float3( vec3( 0.5 ) );
#else
				float3 ColorMap = PdxTex2D( ColorTexture, float2( ColorMapCoords.x, 1.0 - ColorMapCoords.y ) ).rgb;
#endif
				float WaterNormalLerp = 0.0;
				EffectIntensities ConditionData;
				SampleProvinceEffectsMask( ColorMapCoords, ConditionData );
				ApplyProvinceEffectsTerrain( ConditionData, DetailDiffuse, DetailNormal, DetailMaterial, Input.WorldSpacePos, WaterNormalLerp );

				float3 FlatMap = float3( vec3( 0.5f ) ); // neutral overlay
				#ifdef TERRAIN_FLAT_MAP_LERP
					FlatMap = lerp( FlatMap, PdxTex2D( FlatMapTexture, float2( ColorMapCoords.x, 1.0 - ColorMapCoords.y ) ).rgb, FlatMapLerp );
				#endif

				float3 Normal = CalculateNormal( Input.WorldSpacePos.xz );

				float3 ReorientedNormal = ReorientNormal( lerp( Normal, float3( 0.0, 1.0, 0.0 ), WaterNormalLerp ), DetailNormal );

				float SnowHighlight = 0.0f;
				#ifndef UNDERWATER
					ApplySnowMaterialTerrain( ConditionData, DetailDiffuse, DetailNormal, DetailMaterial, Input.WorldSpacePos.xz, SnowHighlight );
				#endif

				float3 Diffuse = GetOverlay( DetailDiffuse.rgb, ColorMap, ( 1 - DetailMaterial.r ) * COLORMAP_OVERLAY_STRENGTH );


				#ifdef TERRAIN_COLOR_OVERLAY
					float3 BorderColor;
					float BorderPreLightingBlend;
					float BorderPostLightingBlend;
					GetBorderColorAndBlendGame( Input.WorldSpacePos.xz, FlatMap, BorderColor, BorderPreLightingBlend, BorderPostLightingBlend );

					Diffuse = lerp( Diffuse, BorderColor, BorderPreLightingBlend );

					#ifdef TERRAIN_FLAT_MAP_LERP
						float3 FlatColor;
						GetBorderColorAndBlendGameLerp( Input.WorldSpacePos.xz, FlatMap, FlatColor, BorderPreLightingBlend, BorderPostLightingBlend, FlatMapLerp );
						
						FlatMap = lerp( FlatMap, FlatColor, saturate( BorderPreLightingBlend + BorderPostLightingBlend ) );
					#endif
				#endif

				#ifdef TERRAIN_COLOR_OVERLAY
					ApplyHighlightColor( Diffuse, ColorMapCoords );
					CompensateWhiteHighlightColor( Diffuse, ColorMapCoords, SnowHighlight );
				#endif

				float ShadowTerm = CalculateShadow( Input.ShadowProj, ShadowMap );

				#ifdef TERRAIN_FLAT_MAP_LERP
				if ( HasFlatMapLightingEnabled == 1 )
				{
 					SMaterialProperties FlatMapMaterialProps = GetMaterialProperties( FlatMap, float3( 0.0, 1.0, 0.0 ), 1.0, 0.0, 0.0 );
 					SLightingProperties FlatMapLightingProps = GetFlatMapLerpSunLightingProperties( Input.WorldSpacePos, ShadowTerm );
 					FlatMap = CalculateSunLighting( FlatMapMaterialProps, FlatMapLightingProps, FlatMapEnvironmentMap );
				}
				#endif

				SMaterialProperties MaterialProps = GetMaterialProperties( Diffuse, ReorientedNormal, DetailMaterial.a, DetailMaterial.g, DetailMaterial.b );
				SLightingProperties LightingProps = GetSunLightingProperties( Input.WorldSpacePos, ShadowTerm );

				float3 FinalColor = CalculateSunLighting( MaterialProps, LightingProps, EnvironmentMap );

				#ifdef TERRAIN_COLOR_OVERLAY
					FinalColor.rgb = lerp( FinalColor.rgb, BorderColor, BorderPostLightingBlend );
				#endif

				#ifdef TERRAIN_COLOR_OVERLAY
					ApplyHighlightColor( FinalColor.rgb, ColorMapCoords, 0.25 );
				#endif

				#ifdef TERRAIN_COLOR_OVERLAY
					ApplyDiseaseDiffuse( FinalColor, ColorMapCoords );
					ApplyLegendDiffuse( FinalColor, ColorMapCoords );
				#endif

				// MOD(godherja)
				#ifndef UNDERWATER
					// FinalColor = ApplyFogOfWar( FinalColor, Input.WorldSpacePos, FogOfWarAlpha );
					FinalColor = GH_ApplyAtmosphericEffects( FinalColor, Input.WorldSpacePos, FogOfWarAlpha );
					FinalColor = ApplyDistanceFog( FinalColor, Input.WorldSpacePos );
				#endif
				// END MOD

				#ifdef TERRAIN_FLAT_MAP_LERP
					FinalColor = lerp( FinalColor, FlatMap, FlatMapLerp );
				#endif

				float Alpha = 1.0;
				#ifdef UNDERWATER
					Alpha = CompressWorldSpace( Input.WorldSpacePos );
				#endif

				#ifdef TERRAIN_DEBUG
					TerrainDebug( FinalColor, Input.WorldSpacePos );
				#endif

				DebugReturn( FinalColor, MaterialProps, LightingProps, EnvironmentMap );
				return float4( FinalColor, Alpha );
			}
		]]
	}

	MainCode PixelShaderLowSpec
	{
		Input = "VS_OUTPUT_PDX_TERRAIN_LOW_SPEC"
		Output = "PDX_COLOR"
		Code
		[[
			PDX_MAIN
			{
				clip( vec2(1.0) - Input.WorldSpacePos.xz * WorldSpaceToTerrain0To1 );

				float3 DetailDiffuse = Input.DetailDiffuse;
				float4 DetailMaterial = Input.DetailMaterial;

				float2 ColorMapCoords = Input.WorldSpacePos.xz * WorldSpaceToTerrain0To1;

				float3 ColorMap = Input.ColorMap;
				float3 FlatMap = Input.FlatMap;

				float3 Normal = Input.Normal;
				
				float SnowHighlight = 0.0f;
				#ifndef UNDERWATER
					DetailDiffuse = ApplyDynamicMasksDiffuse( DetailDiffuse, Normal, ColorMapCoords );
				#endif

				float3 Diffuse = GetOverlay( DetailDiffuse.rgb, ColorMap, ( 1 - DetailMaterial.r ) * COLORMAP_OVERLAY_STRENGTH );
				float3 ReorientedNormal = Normal;

				#ifdef TERRAIN_COLOR_OVERLAY
					float3 BorderColor;
					float BorderPreLightingBlend;
					float BorderPostLightingBlend;
					GetBorderColorAndBlendGame( Input.WorldSpacePos.xz, FlatMap, BorderColor, BorderPreLightingBlend, BorderPostLightingBlend );

					Diffuse = lerp( Diffuse, BorderColor, BorderPreLightingBlend );

					#ifdef TERRAIN_FLAT_MAP_LERP
						float3 FlatColor;
						GetBorderColorAndBlendGameLerp( Input.WorldSpacePos.xz, FlatMap, FlatColor, BorderPreLightingBlend, BorderPostLightingBlend, FlatMapLerp );
						
						FlatMap = lerp( FlatMap, FlatColor, saturate( BorderPreLightingBlend + BorderPostLightingBlend ) );
					#endif 
				#endif

				//float ShadowTerm = CalculateShadow( Input.ShadowProj, ShadowMap );
				float ShadowTerm = 1.0;

				SMaterialProperties MaterialProps = GetMaterialProperties( Diffuse, ReorientedNormal, DetailMaterial.a, DetailMaterial.g, DetailMaterial.b );
				SLightingProperties LightingProps = GetSunLightingProperties( Input.WorldSpacePos, ShadowTerm );

				float3 FinalColor = CalculateSunLightingLowSpec( MaterialProps, LightingProps );

				#ifndef UNDERWATER
					// MOD(godherja)
					//FinalColor = ApplyFogOfWar( FinalColor, Input.WorldSpacePos, FogOfWarAlpha );
					FinalColor = GH_ApplyAtmosphericEffects( FinalColor, Input.WorldSpacePos, FogOfWarAlpha );
					// END MOD
					FinalColor = ApplyDistanceFog( FinalColor, Input.WorldSpacePos );
				#endif

				#ifdef TERRAIN_COLOR_OVERLAY
					FinalColor.rgb = lerp( FinalColor.rgb, BorderColor, BorderPostLightingBlend );
				#endif

				#ifdef TERRAIN_COLOR_OVERLAY
					ApplyHighlightColor( FinalColor.rgb, ColorMapCoords );
					CompensateWhiteHighlightColor( FinalColor.rgb, ColorMapCoords, SnowHighlight );
				#endif

				#ifdef TERRAIN_FLAT_MAP_LERP
					FinalColor = lerp( FinalColor, FlatMap, FlatMapLerp );
				#endif

				float Alpha = 1.0;
				#ifdef UNDERWATER
					Alpha = CompressWorldSpace( Input.WorldSpacePos );
				#endif

				#ifdef TERRAIN_DEBUG
					TerrainDebug( FinalColor, Input.WorldSpacePos );
				#endif

				DebugReturn( FinalColor, MaterialProps, LightingProps, EnvironmentMap );
				return float4( FinalColor, Alpha );
			}
		]]
	}

	MainCode PixelShaderFlatMap
	{
		Input = "VS_OUTPUT_PDX_TERRAIN"
		Output = "PDX_COLOR"
		Code
		[[
			PDX_MAIN
			{
				#ifdef TERRAIN_SKIRT
					return float4( 0, 0, 0, 0 );
				#endif

				clip( vec2(1.0) - Input.WorldSpacePos.xz * WorldSpaceToTerrain0To1 );

				float2 ColorMapCoords = Input.WorldSpacePos.xz * WorldSpaceToTerrain0To1;
				float3 FlatMap = PdxTex2D( FlatMapTexture, float2( ColorMapCoords.x, 1.0 - ColorMapCoords.y ) ).rgb;

				#ifdef TERRAIN_COLOR_OVERLAY
					float3 BorderColor;
					float BorderPreLightingBlend;
					float BorderPostLightingBlend;
					
					GetBorderColorAndBlendGameLerp( Input.WorldSpacePos.xz, FlatMap, BorderColor, BorderPreLightingBlend, BorderPostLightingBlend, 1.0f );
					
					FlatMap = lerp( FlatMap, BorderColor, saturate( BorderPreLightingBlend + BorderPostLightingBlend ) );
				#endif

				float3 FinalColor = FlatMap;
				#ifdef TERRAIN_FLATMAP_LIGHTING
					if ( HasFlatMapLightingEnabled == 1 )
					{
						float ShadowTerm = CalculateShadow( Input.ShadowProj, ShadowMap );
						SMaterialProperties FlatMapMaterialProps = GetMaterialProperties( FlatMap, float3( 0.0, 1.0, 0.0 ), 1.0, 0.0, 0.0 );
						SLightingProperties FlatMapLightingProps = GetSunLightingProperties( Input.WorldSpacePos, ShadowTerm );
						FinalColor = CalculateSunLighting( FlatMapMaterialProps, FlatMapLightingProps, EnvironmentMap );
					}
				#endif

				#ifdef TERRAIN_COLOR_OVERLAY
					ApplyHighlightColor( FinalColor, ColorMapCoords, 0.5 );
				#endif

				#ifdef TERRAIN_DEBUG
					TerrainDebug( FinalColor, Input.WorldSpacePos );
				#endif

				// Make flatmap transparent based on the SurroundFlatMapMask
				float SurroundMapAlpha = 1 - PdxTex2D( SurroundFlatMapMask, float2( ColorMapCoords.x, 1.0 - ColorMapCoords.y ) ).b;
				SurroundMapAlpha *= FlatMapLerp;

				return float4( FinalColor, SurroundMapAlpha );
			}
		]]
	}
}


Effect PdxTerrain
{
	VertexShader = "VertexShader"
	PixelShader = "PixelShader"

	Defines = { "TERRAIN_FLAT_MAP_LERP" }
}

Effect PdxTerrainLowSpec
{
	VertexShader = "VertexShaderLowSpec"
	PixelShader = "PixelShaderLowSpec"
}

Effect PdxTerrainSkirt
{
	VertexShader = "VertexShaderSkirt"
	PixelShader = "PixelShader"
}

Effect PdxTerrainLowSpecSkirt
{
	VertexShader = "VertexShaderLowSpecSkirt"
	PixelShader = "PixelShaderLowSpec"
}

### FlatMap Effects

BlendState BlendStateAlpha
{
	BlendEnable = yes
	SourceBlend = "SRC_ALPHA"
	DestBlend = "INV_SRC_ALPHA"
}

Effect PdxTerrainFlat
{
	VertexShader = "VertexShader"
	PixelShader = "PixelShaderFlatMap"
	BlendState = BlendStateAlpha

	Defines = { "TERRAIN_FLAT_MAP" "TERRAIN_FLATMAP_LIGHTING" }
}

Effect PdxTerrainFlatSkirt
{
	VertexShader = "VertexShaderSkirt"
	PixelShader = "PixelShaderFlatMap"
	BlendState = BlendStateAlpha

	Defines = { "TERRAIN_FLAT_MAP" "TERRAIN_SKIRT" }
}

# Low Spec flat map the same as regular effect
Effect PdxTerrainFlatLowSpec
{
	VertexShader = "VertexShader"
	PixelShader = "PixelShaderFlatMap"
	BlendState = BlendStateAlpha

	Defines = { "TERRAIN_FLAT_MAP" }
}

Effect PdxTerrainFlatLowSpecSkirt
{
	VertexShader = "VertexShaderSkirt"
	PixelShader = "PixelShaderFlatMap"
	BlendState = BlendStateAlpha

	Defines = { "TERRAIN_FLAT_MAP" "TERRAIN_SKIRT" }
}
