Includes = {
	"cw/camera.fxh"
	"cw/random.fxh"
	"jomini/jomini_fog_of_war.fxh"
	"jomini/jomini_water.fxh"
	"standardfuncsgfx.fxh"
}

PixelShader = {
	Code
	[[
		#define AdjustedTime			GlobalTime * 0.01f
		// #define AdjustedTime			3.0f /// Freeze time for debugging
		#define CloudDirection			float2( -1.0, 0.4 )		// Paning direction
		#define CloudOpacity			0.0f //LOTR MOD						// Cloud Opacity

		// Main Cloud settings, works as base for secondary and detail settings
		#define CloudMainTiling			36						// Cloud noise tiling, can control size and amount (increased for smaller clouds)
		#define CloudMainSpeed			2.0						// Cloud pan speed
		#define CloudMainPosition		0.58					// Cloud position, combine with tiling to adjust size (adjusted for better coverage)
		#define CloudMainContrast		0.25					// Cloud sharpness (increased for more defined edges)

		// Secondary clouds settings are adjustedments of main settings
		#define CloudSecondaryTiling 	5.0						// Secondary clouds tiling (increased for smaller secondary patterns)
		#define CloudSecondarySpeed		12.0					// Secondary clouds adjusted speed (slightly slower)
		#define CloudSecondaryPosition	-0.15					// Secondary clouds adjusted position (offset for variation)
		#define CloudSecondaryContrast	0.18					// Secondary clouds adjusted contrast (increased for more definition)

		// Detail clouds settings are adjustedments of on main settings
		#define CloudDetailTiling		11.4					// Detail clouds tiling (increased for smaller detail patterns)
		#define CloudDetailSpeed		25.0					// Detail clouds adjusted speed (slightly slower)
		#define CloudDetailPosition		-0.25					// Detail clouds adjusted position (adjusted for better blending)
		#define CloudDetailContrast		0.35					// Detail clouds adjusted contrast (reduced for softer details)

		float GetCloud( float2 p )
		{
			float f;
			f  = 0.50000 * CalcNoise( p ); p = p * 2.01f;
			f += 0.25000 * CalcNoise( p ); p = p * 2.02f;
			f += 0.12500 * CalcNoise( p ); p = p * 2.03f;
			f += 0.06250 * CalcNoise( p ); p = p * 2.04f;
			f += 0.03125 * CalcNoise( p );

			return f;
		}

		float GetCloudShadowMask( in float2 Coordinate, float FogOfWarAlphaValue )
		{
			#ifdef LOW_SPEC_SHADERS
				return 0.0f;
			#endif

			if ( _HasCloudShadowEnabled != 1 )
			{
				return 0.0f;
			}

			// Skip cloud calculations if in fog of war
			if ( FogOfWarAlphaValue < 0.1f )
			{
				return 0.0f;
			}
			float ZoomedInZoomedOutFactor = GetZoomedInZoomedOutFactor();
			// Apply zoom-based fading - clouds fade out when zooming out
			float ZoomFadeFactor = min( 1.0f, pow( 1.0f - ZoomedInZoomedOutFactor + 0.24f, 6.0f ) );

			// Skip cloud rendering when ZoomFadeFactor is near zero to optimize performance
			if ( ZoomFadeFactor < 0.01f )
			{
				return 0.0f;
			}

			float2 Uv00 = Coordinate * InverseWorldSize * float2( 2.0f, 1.0f );
			float2 CloudMovement = CloudDirection * AdjustedTime;
			float2 Uv01 = Uv00;
			float2 AnimationValue01 = CloudMovement * CloudMainSpeed;
			Uv01 *= CloudMainTiling;
			Uv01 += AnimationValue01;

			float2 Uv02 = Uv00;
			Uv02 *= CloudMainTiling * CloudSecondaryTiling;
			float2 AnimationValue02 = CloudMovement * CloudSecondarySpeed;
			Uv02 += AnimationValue02;

			float2 Uv03 = Uv00;
			Uv03 *= CloudMainTiling * CloudDetailTiling;
			float2 AnimationValue03 = CloudMovement * CloudDetailSpeed;
			Uv03 += AnimationValue03;

			float Clouds01 = GetCloud( Uv01 );
			float Clouds02 = GetCloud( Uv02 );
			float Clouds03 = GetCloud( Uv03 );

			Clouds01 = LevelsScan( Clouds01, CloudMainPosition, CloudMainContrast );
			Clouds02 = LevelsScan( Clouds02, CloudMainPosition + CloudSecondaryPosition, CloudMainContrast + CloudSecondaryContrast );
			Clouds03 = LevelsScan( Clouds03, CloudMainPosition + CloudDetailPosition, CloudMainContrast + CloudDetailContrast );

			float Cloud = Overlay( Clouds01, Clouds02 );
			Cloud = Overlay( Cloud, Clouds03 );

			return Cloud * CloudOpacity * FogOfWarAlphaValue * ZoomFadeFactor;
		}
		float GetCloudShadowMask( in float2 Coordinate )
		{
			#ifdef LOW_SPEC_SHADERS
				return 0.0f;
			#endif

			if ( _HasCloudShadowEnabled != 1 )
			{
				return 0.0f;
			}
			// Get fog of war alpha value
			float FogOfWarAlphaValue = PdxTex2D( FogOfWarAlpha, Coordinate * WorldSpaceToTerrain0To1 ).r;
			return GetCloudShadowMask( Coordinate, FogOfWarAlphaValue );
		}
	]]
}