Includes = {
	"cw/utility.fxh"
	"cw/pdxterrain.fxh"
	"standardfuncsgfx.fxh"
	"utility_game.fxh"
	"province_effects.fxh"
}

#ifndef WINTER_COMBINED_TEXTURE
TextureSampler SnowMaskMap
{
	Index = 9
	MagFilter = "Linear"
	MinFilter = "Linear"
	MipFilter = "Linear"
	SampleModeU = "Wrap"
	SampleModeV = "Wrap"
	# MOD(lotr)
	#File = "gfx/map/terrain/snow_diffuse.dds"
	File = "gfx/map/terrain/lotr_dynamic_snow_diffuse.dds"
	# END MOD
    sRGB = yes
}
#endif
TextureSampler WinterTexture
{
	Ref = WinterTexture
	MagFilter = "Linear"
	MinFilter = "Linear"
	MipFilter = "Linear"
	SampleModeU = "Wrap"
	SampleModeV = "Wrap"
}

PixelShader =
{
	Code
	[[
		// Debug the game snow mask | Blue = Mild, Green = Normal, Red = Harsh
		//#define DEBUG_OLD_SNOW_MASK

#ifndef WINTER_COMBINED_TEXTURE
		float4 GetSnowDiffuseValue( in float2 Coordinate )
		{
			return PdxTex2D( DetailTextures, float3( Coordinate, _SnowTexIndex ) );
		}
		float GetWinterSeverityValue( in float2 Coordinate )
		{
			return float4( PdxTex2D( WinterTexture, Coordinate ) ).r;
		}
#else
		// The WinterTexture combines the two winter textures, to save one sampler (relevant on macOS with OpenGL):
		// - the winter severity value is in blue, this is what WinterTexture is without this define
		// - SnowDiffuseMap is in red, green, and alpha. We take its blue value from green, because we assume they are basically the same.
		// The texture isn't marked as sRGB, so we undo the double gamma correction for the diffuse value.
		float4 GetSnowDiffuseValue( in float2 Coordinate )
		{
			return ToLinear( PdxTex2D( WinterTexture, Coordinate ).rgga );
		}
		float GetWinterSeverityValue( in float2 Coordinate )
		{
			return PdxTex2D( WinterTexture, Coordinate ).b;
		}
#endif
		void DebugOldSnowMask( inout float3 Diffuse, float2 MapCoords )
		{
			// Snow area
			float SnowOld = GetWinterSeverityValue( MapCoords );

			float MILD_Threshhold = 0.2f;
			float NORMAL_Threshhold = 0.6f;
			float HARSH_Threshhold = 0.9f;
			float3 MILD = float3( 0.0f, 0.0f, 1.0f );
			float3 NORMAL = float3( 0.0f, 1.0f, 0.0f );
			float3 HARSH = float3( 1.0f, 0.0f, 0.0f );
			float MILD_Mask = RemapClamped( SnowOld, 0.0f, MILD_Threshhold, 0.0f, 1.0f );
			float NORMAL_Mask =  RemapClamped( SnowOld, MILD_Threshhold, NORMAL_Threshhold, 0.0f, 1.0f  );
			float HARSH_Mask =  RemapClamped( SnowOld, NORMAL_Threshhold, HARSH_Threshhold, 0.0f, 1.0f  );
			float3 SnowDebug = vec3( 0.0f );
			SnowDebug = lerp( SnowDebug, MILD, MILD_Mask );
			SnowDebug = lerp( SnowDebug, NORMAL, NORMAL_Mask );
			SnowDebug = lerp( SnowDebug, HARSH, HARSH_Mask );

			Diffuse = lerp( Diffuse, ToGamma( SnowDebug ), 1.0f );
		}

		float GetWinterValue()
		{
			// Convert day of year to snow
			float WinterValue = _SnowValue;
			WinterValue += _DebugSeasonWinter;
			WinterValue = saturate( WinterValue );
			return WinterValue * _SnowExtent;
		}

		float GetWinterMask( float WinterValue, float2 MapCoords, float Position, float Contrast, float HemiPosition, float HemiContrast, float Height = 0.0f, float Harshness = 0.0f, float GameSnowMask = 0.0f)
		{
			float2 Coords = float2( MapCoords.x * 2.0f, MapCoords.y ) + vec2( _SnowRandomNumber ) * 0.1f; // + vec2( DebugInt1 ) * 0.1; //;

			// Mountains etc.
			Height = RemapClamped( Height, _SnowTerrainHeightMin, _SnowTerrainHeightMax, 0.0f, 1.0f );

			// Squish start-to-end from top of the map
			float SnowHemisphere = RemapClamped( 1.0f - MapCoords.y, 0.0f, 1.0f, 0.0f, 1.0f );
			float WinterMask = LevelsScan( WinterValue - SnowHemisphere, HemiPosition, HemiContrast );
			WinterMask = lerp( WinterMask, WinterMask + _SnowTerrainHeightAdd, Height * WinterMask );

			float SnowMask = saturate( WinterMask + GameSnowMask - WinterMask * GameSnowMask );

			float NoSnowMask = 1.0f - PdxTex2D( SnowMaskMap, float2( MapCoords.x, 1.0f - MapCoords.y) ).r;
			float Noise = 1.0f - SampleNoTile( SnowMaskMap, Coords * _SnowNoiseTiling ).a;
			float Noise2 = 1.0f - SampleNoTile( SnowMaskMap, Coords * _SnowNoise2Tiling ).a;
			Noise = Overlay( Noise + SnowMask, Noise2 );
			Noise = LevelsScan( Noise, Position - Harshness, Contrast + Harshness );
			Noise = Noise * SnowMask * NoSnowMask;

			return Noise;
		}

		void ApplySnowMaterialTerrain( in EffectIntensities ConditionData, inout float4 Diffuse, inout float3 Normal, inout float4 Properties, in float2 WorldSpacePosXz, out float HighlightMask )
		{
			// UVs
			float2 MapCoords = WorldSpacePosXz * WorldSpaceToTerrain0To1;
			float2 DetailUV = CalcDetailUV( WorldSpacePosXz );
			float Noise = 1.0f - SampleNoTile( SnowMaskMap, MapCoords * 20.0 ).a;
			float GameSnow = GetWinterSeverityValue( MapCoords );
			float GameSnowMask = smoothstep( _SnowGameMaskMin, _SnowGameMaskMax, GameSnow ) * _SnowGameMaskImpact * Noise;

			float Height = GetHeight( WorldSpacePosXz );
			float Winter = GetWinterValue();
			Winter = saturate( Winter + GameSnowMask - Winter * GameSnowMask );

			// Snow data from province effects
			float ProvinceSnowMask = GameSnowMask;

			float Snow = GetWinterMask( Winter, MapCoords, _SnowTerrainAreaPosition, _SnowTerrainAreaContrast, _SnowHemispherePosition, _SnowHemisphereContrast, Height, GameSnowMask, GameSnowMask );
			float Frost = GetWinterMask( Winter, MapCoords, _FrostTerrainAreaPosition, _FrostTerrainAreaContrast, _FrostHemispherePosition, _FrostHemisphereContrast, Height, 0.0, GameSnowMask );
			float WinterSmoothstep = smoothstep( 0.0f, 0.1f, Winter );
			Frost *= _FrostMultiplier * WinterSmoothstep;
			Snow *= WinterSmoothstep;

			// Remove snow from steep angle
			float3 TerrainNormal = CalculateNormal( WorldSpacePosXz );
			TerrainNormal.y = smoothstep( _SnowAngleRemove, 1.0f, abs( TerrainNormal.y ) );
			Snow = lerp( 0.0f, Snow, TerrainNormal.y );
			HighlightMask = Snow;
			
			if ( GameSnow < SKIP_VALUE )
			{
				return;
			}

			// Apply material
			float2 SnowUV = DetailUV * _SnowTextureTiling;
			float4 SnowDiffuse = SampleNoTile( DetailTextures, SnowUV, _SnowTexIndex );
			float4 SnowNormalRRxG = SampleNoTile( NormalTextures, SnowUV, _SnowTexIndex );
			float3 SnowNormal = UnpackRRxGNormal( SnowNormalRRxG ).xyz;
			float4 SnowProperties = SampleNoTile( MaterialTextures, SnowUV, _SnowTexIndex );

			// Terrain material blend
			Diffuse.a = lerp( 0.0f, Diffuse.a, _SnowHeightWeight );
			SnowDiffuse.a = 1.0f - lerp( 1.0f, SnowDiffuse.a, 1.0f - _SnowHeightWeight );
			float2 BlendFactors = CalcHeightBlendFactors( float2( Diffuse.a, SnowDiffuse.a ), float2( 1.0f - Snow, Snow ), DetailBlendRange * _SnowHeightContrast * Snow );

			// Initial Frost Layer
			Diffuse = lerp( Diffuse, SnowDiffuse, Frost );
			Normal = lerp( Normal, SnowNormal, Frost );
			Properties = lerp( Properties, SnowProperties, Frost );

			float BlendValue = BlendFactors.y;

			// Snow Layer
			Diffuse = lerp( Diffuse, SnowDiffuse, BlendValue );
			Normal = lerp( Normal, SnowNormal, BlendValue );
			Properties = lerp( Properties, SnowProperties, BlendValue );

			#if defined( DEBUG_OLD_SNOW_MASK )
				DebugOldSnowMask( Diffuse.rgb, MapCoords );
			#endif
		}

		void ApplySnowMaterialMesh( in EffectIntensities ConditionData, inout float3 Diffuse, inout float4 Properties, inout float3 Normal, in float2 WorldSpacePosXz, out float HighlightMask )
		{
			// UVs
			float2 MapCoords = WorldSpacePosXz * WorldSpaceToTerrain0To1;
			float2 DetailUV = CalcDetailUV( WorldSpacePosXz );

			float Noise = 1.0f - SampleNoTile( SnowMaskMap, MapCoords * 20.0 ).a;
			float GameSnow = GetWinterSeverityValue( MapCoords );
			float GameSnowMask = smoothstep( _SnowGameMaskMin, _SnowGameMaskMax, GameSnow ) * _SnowGameMaskImpact * Noise;

			float Height = GetHeight( WorldSpacePosXz );
			float Winter = GetWinterValue();
			Winter = saturate( Winter + GameSnowMask - Winter * GameSnowMask );

			// Snow data from province
			float ProvinceSnowMask = GameSnowMask;

			float Snow = GetWinterMask( Winter, MapCoords, _SnowAreaPosition, _SnowAreaContrast, _SnowHemispherePosition, _SnowHemisphereContrast, Height, GameSnowMask, ProvinceSnowMask );
			Snow *= smoothstep( 0.0f, 0.1f, Winter );

			// Remove snow from steep angle
			Normal.y = smoothstep( _SnowAngleRemove, 1.0f, abs( Normal.y ) );
			Snow = lerp( 0.0f, Snow, Normal.y );

			// Apply material
			float2 SnowUV = DetailUV * 0.5f * _SnowTextureTiling;
			float3 SnowDiffuse = SampleNoTile( DetailTextures, SnowUV , _SnowTexIndex ).rgb;
			float4 SnowProperties = SampleNoTile( MaterialTextures, SnowUV, _SnowTexIndex );

			Diffuse = lerp( Diffuse, SnowDiffuse, Snow );
			Properties = lerp( Properties, SnowProperties, Snow );

			HighlightMask = Snow;
		}

		float3 ApplySnowDiffuse( in float3 TerrainColor, in float3 Normal, in float2 Coordinate )
		{
			float SnowScale = 150.0f;
			float SnowScaleLarge = 0.0f;
			float SnowScaleMedium = SnowScale;
			float SnowScaleSmall = SnowScale * 0.32345f;

			float2 MapDimensions = float2( 2.0f, 1.0f );

			float2 SnowUVLarge = Coordinate * MapDimensions * SnowScaleLarge;
			float2 SnowUVMedium = Coordinate * MapDimensions * SnowScaleMedium;
			float2 SnowUVSmall = Coordinate * MapDimensions *SnowScaleSmall;

			float4 SnowDiffuseMedium = GetSnowDiffuseValue( SnowUVMedium );
			float SnowDiffuseLarge = GetSnowDiffuseValue( SnowUVLarge ).a;
			float SnowDiffuseSmall = GetSnowDiffuseValue( SnowUVSmall ).a;

			float SnowMask = GetWinterSeverityValue( Coordinate ) * 0.6f;

			float SnowAlpha = 0.0f;
			SnowAlpha = Overlay( SnowDiffuseLarge, SnowDiffuseMedium.a );
			SnowAlpha = Overlay( SnowAlpha, SnowDiffuseSmall );
			SnowAlpha = ToLinear( SnowAlpha );

			float GradientWidth = 0.3f;
			float GradientWidthHalf = GradientWidth * 0.5f;

			SnowAlpha = RemapClamped( SnowAlpha, 0.0f, 1.0f, GradientWidthHalf, 1.0f - GradientWidthHalf );
			SnowAlpha = clamp( SnowAlpha, 0.0f, 1.0f );

			SnowMask = LevelsScan( SnowAlpha, 1.0f - SnowMask, GradientWidth );

			SnowMask *= clamp( Normal.g * Normal.g, 0.0f, 1.0f );
			return lerp( TerrainColor, SnowDiffuseMedium.rgb, SnowMask );
		}

		float3 ApplySnowDiffuse( in float3 TerrainColor, in float3 Normal, in float2 Coordinate, out float SnowMask )
		{
			float SnowScale = 150.0f;
			float SnowScaleLarge = 0.0f;
			float SnowScaleMedium = SnowScale;
			float SnowScaleSmall = SnowScale * 0.32345f;

			float2 MapDimensions = float2( 2.0f, 1.0f );

			float2 SnowUVLarge = Coordinate * MapDimensions * SnowScaleLarge;
			float2 SnowUVMedium = Coordinate * MapDimensions * SnowScaleMedium;
			float2 SnowUVSmall = Coordinate * MapDimensions * SnowScaleSmall;

			float4 SnowDiffuseMedium = GetSnowDiffuseValue( SnowUVMedium );
			float SnowDiffuseLarge = GetSnowDiffuseValue( SnowUVLarge ).a;
			float SnowDiffuseSmall = GetSnowDiffuseValue( SnowUVSmall ).a;

			SnowMask = GetWinterSeverityValue( Coordinate ) * 0.6f;

			float SnowAlpha = 0.0f;
			SnowAlpha = Overlay( SnowDiffuseLarge, SnowDiffuseMedium.a );
			SnowAlpha = Overlay( SnowAlpha, SnowDiffuseSmall );
			SnowAlpha = ToLinear( SnowAlpha );

			float GradientWidth = 0.3f;
			float GradientWidthHalf = GradientWidth * 0.5f;

			SnowAlpha = RemapClamped( SnowAlpha, 0.0f, 1.0f, GradientWidthHalf, 1.0f - GradientWidthHalf );
			SnowAlpha = clamp( SnowAlpha, 0.0f, 1.0f );

			SnowMask = LevelsScan( SnowAlpha, 1.0f - SnowMask, GradientWidth );

			SnowMask *= clamp( Normal.g * Normal.g, 0.0f, 1.0f );
			return lerp( TerrainColor, SnowDiffuseMedium.rgb, SnowMask );
		}

		float3 ApplyDynamicMasksDiffuse( in float3 TerrainColor, in float3 Normal, in float2 Coordinate )
		{
			TerrainColor = ApplySnowDiffuse( TerrainColor, Normal, Coordinate );

			return TerrainColor;
		}

		float3 ApplyDynamicMasksDiffuse( in float3 TerrainColor, in float3 Normal, in float2 Coordinate, inout float Snow )
		{
			TerrainColor = ApplySnowDiffuse( TerrainColor, Normal, Coordinate, Snow );

			return TerrainColor;
		}
	]]
}
