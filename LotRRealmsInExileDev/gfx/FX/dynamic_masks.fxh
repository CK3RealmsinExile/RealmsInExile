Includes = {
    "cw/utility.fxh"
	"standardfuncsgfx.fxh"
}

#ifndef WINTER_COMBINED_TEXTURE
TextureSampler SnowDiffuseMap
{
	Index = 9
	MagFilter = "Linear"
	MinFilter = "Linear"
	MipFilter = "Linear"
	SampleModeU = "Wrap"
	SampleModeV = "Wrap"
	File = "gfx/map/terrain/snow_diffuse.dds"
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
#ifndef WINTER_COMBINED_TEXTURE
        float4 GetSnowDiffuseValue( in float2 Coordinate )
        {
            return PdxTex2D( SnowDiffuseMap, Coordinate );
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

        float3 ApplySnowDiffuse( in float3 TerrainColor, in float3 Normal, in float2 Coordinate )
        {
            float SnowScale = 150;
            float SnowScaleLarge = 0.0;
            float SnowScaleMedium = SnowScale;
            float SnowScaleSmall = SnowScale * 0.32345;

            float2 MapDimensions = float2( 2, 1 );

            float2 SnowUVLarge = Coordinate * MapDimensions * SnowScaleLarge;
            float2 SnowUVMedium = Coordinate * MapDimensions * SnowScaleMedium;
            float2 SnowUVSmall = Coordinate * MapDimensions *SnowScaleSmall;

            float4 SnowDiffuseMedium = GetSnowDiffuseValue( SnowUVMedium );
            float SnowDiffuseLarge = GetSnowDiffuseValue( SnowUVLarge ).a;
            float SnowDiffuseSmall = GetSnowDiffuseValue( SnowUVSmall ).a;

            float SnowMask = GetWinterSeverityValue( Coordinate ) * 0.6;

            float SnowAlpha = 0;
            SnowAlpha = Overlay( SnowDiffuseLarge, SnowDiffuseMedium.a );
            SnowAlpha = Overlay( SnowAlpha, SnowDiffuseSmall );
            SnowAlpha = ToLinear( SnowAlpha );

            float GradientWidth = 0.3;
            float GradientWidthHalf = GradientWidth * 0.5;

            SnowAlpha = RemapClamped( SnowAlpha, 0, 1, GradientWidthHalf, 1 - GradientWidthHalf );
            SnowAlpha = clamp( SnowAlpha, 0, 1 );

            SnowMask = LevelsScan( SnowAlpha, 1 - SnowMask, GradientWidth );

            SnowMask *= clamp( Normal.g * Normal.g, 0, 1 );
            return lerp( TerrainColor, SnowDiffuseMedium.rgb, SnowMask );
        }

        float3 ApplySnowDiffuse( in float3 TerrainColor, in float3 Normal, in float2 Coordinate, out float SnowMask )
        {
            float SnowScale = 150;
            float SnowScaleLarge = 0.0;
            float SnowScaleMedium = SnowScale;
            float SnowScaleSmall = SnowScale * 0.32345;

            float2 MapDimensions = float2( 2, 1 );

            float2 SnowUVLarge = Coordinate * MapDimensions * SnowScaleLarge;
            float2 SnowUVMedium = Coordinate * MapDimensions * SnowScaleMedium;
            float2 SnowUVSmall = Coordinate * MapDimensions * SnowScaleSmall;

            float4 SnowDiffuseMedium = GetSnowDiffuseValue( SnowUVMedium );
            float SnowDiffuseLarge = GetSnowDiffuseValue( SnowUVLarge ).a;
            float SnowDiffuseSmall = GetSnowDiffuseValue( SnowUVSmall ).a;

            SnowMask = GetWinterSeverityValue( Coordinate ) * 0.6;

            float SnowAlpha = 0;
            SnowAlpha = Overlay( SnowDiffuseLarge, SnowDiffuseMedium.a );
            SnowAlpha = Overlay( SnowAlpha, SnowDiffuseSmall );
            SnowAlpha = ToLinear( SnowAlpha );

            float GradientWidth = 0.3;
            float GradientWidthHalf = GradientWidth * 0.5;

            SnowAlpha = RemapClamped( SnowAlpha, 0, 1, GradientWidthHalf, 1 - GradientWidthHalf );
            SnowAlpha = clamp( SnowAlpha, 0, 1 );

            SnowMask = LevelsScan( SnowAlpha, 1 - SnowMask, GradientWidth );

            SnowMask *= clamp( Normal.g * Normal.g, 0, 1 );
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
