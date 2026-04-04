Includes = {
	"cw/pdxterrain.fxh"
	"jomini/jomini_colormap.fxh"
	"jomini/jomini_colormap_constants.fxh"
	"jomini/jomini_province_overlays.fxh"
	"cw/utility.fxh"
	"standardfuncsgfx.fxh"
}

PixelShader = {

	TextureSampler PatternTexture
	{
		Index = 7
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
		File = "gfx/map/textures/political_mapmode_pattern.dds"
		srgb = yes
	}
	
	Code
	[[
		float4 GetHighlightColor( in float2 WorldSpacePosXZ )
		{
			float4 HighlightColor = BilinearColorSampleAtOffset( WorldSpacePosXZ, IndirectionMapSize, InvIndirectionMapSize, ProvinceColorIndirectionTexture, ProvinceColorTexture, HighlightProvinceColorsOffset );
			// MOD(lotr)
			LOTR_TryDiscardOverlayColor(HighlightColor);
			// END MOD
			HighlightColor.rgb *= 0.25;
			
			float3 Desaturated = vec3( ( HighlightColor.r + HighlightColor.g + HighlightColor.b ) / 3 );
			HighlightColor.rgb = lerp( HighlightColor.rgb, Desaturated, 0.35 );

			return HighlightColor;
		}

		void ApplyHighlightColor( inout float3 Diffuse, in float4 HighlightColor, in float Lerp )
		{
			Diffuse = lerp( Diffuse, HighlightColor.rgb, saturate( HighlightColor.a * Lerp * MapHighlightIntensity * 0.8f ) );
		}

		void ApplyHighlightColor( inout float3 Diffuse,  in float4 HighlightColor )
		{
			ApplyHighlightColor( Diffuse, HighlightColor, 1.0f );
		}

		void CompensateWhiteHighlightColor( inout float3 Diffuse, in float4 HighlightColor, in float Opacity )
		{
			float ColorMask = smoothstep( 1.0f, 0.9f, HighlightColor.a );	// Mask out opaque highlights
			HighlightColor.a = Opacity * smoothstep( 0.0f, 1.0f, HighlightColor.a );

			Diffuse = Add( Diffuse, HighlightColor.rgb * SnowHighlightIntensity, HighlightColor.a * ColorMask * MapHighlightIntensity );
		}

		void GetBorderColorAndBlendGameLerp( float2 WorldSpacePosXZ, float3 Flatmap, 
			out float3 BorderColor, out float BorderPreLightingBlend, 
			out float BorderPostLightingBlend, float FlatmapLerp )
		{
			float PatternTiling = 15;
			float2 ColorMapCoords = WorldSpacePosXZ * WorldSpaceToTerrain0To1;
			float3 PatternMap = PdxTex2D( PatternTexture, float2( ColorMapCoords.x * 
				PatternTiling * 2.0f, 1.0f - ( ColorMapCoords.y * PatternTiling ) ) ).rgb;

			GetProvinceOverlayAndBlend( ColorMapCoords, BorderColor, 
				BorderPreLightingBlend, BorderPostLightingBlend );

			float Luminance = dot (BorderColor, float3( 0.299f, 0.587f, 0.114f ) );
			float3 Gray = float3( Luminance, Luminance, Luminance );
			BorderColor = lerp( BorderColor, Gray, 0.1f ); // desaturation

			float3 OverlayColor = Overlay( PatternMap, BorderColor, 1.0f );
			BorderColor = lerp(BorderColor, OverlayColor, 1.0f - FlatmapLerp * 0.5f);

			float3 Desaturated = vec3( ( Flatmap.r + Flatmap.g + Flatmap.b ) / 3 );
			BorderColor = HardLight( BorderColor, Desaturated, FlatmapLerp * 0.9f );
		}

		void GetBorderColorAndBlendGame( float2 WorldSpacePosXZ, float3 Flatmap, 
			out float3 BorderColor, out float BorderPreLightingBlend, 
			out float BorderPostLightingBlend )
		{
			GetBorderColorAndBlendGameLerp( WorldSpacePosXZ, Flatmap, BorderColor, 
				BorderPreLightingBlend, BorderPostLightingBlend, 0.0f );
		}

		void LerpBorderColorWithFogOfWarAlphaValue( inout float3 Diffuse, float FogOfWarAlphaValue, 
			in float3 BorderColor, in float BorderPreLightingBlend )
		{
			Diffuse = lerp( Diffuse, BorderColor, BorderPreLightingBlend * FogOfWarAlphaValue );
		}

		void LerpBorderColorWithFogOfWar( inout float3 Diffuse, in float2 WorldSpacePosXZ, 
			in float3 BorderColor, in float BorderPreLightingBlend )
		{
			float FogOfWarAlphaValue = PdxTex2D( FogOfWarAlpha, WorldSpacePosXZ * WorldSpaceToTerrain0To1 ).r;
			Diffuse = lerp( Diffuse, BorderColor, BorderPreLightingBlend * FogOfWarAlphaValue );
		}

		#define GAME_SECONDARY_COLORS_INTENSITY 0.1

		void ApplySecondaryColorGame( inout float3 Diffuse, in float2 WorldSpacePosXZ )
		{
			float4 SecondaryColor = BilinearColorSampleAtOffset( WorldSpacePosXZ, IndirectionMapSize, InvIndirectionMapSize, ProvinceColorIndirectionTexture, ProvinceColorTexture, SecondaryProvinceColorsOffset );
			ApplyDiagonalStripes( Diffuse, SecondaryColor.rgb, SecondaryColor.a * GAME_SECONDARY_COLORS_INTENSITY, WorldSpacePosXZ );	
		}
	]]
}
