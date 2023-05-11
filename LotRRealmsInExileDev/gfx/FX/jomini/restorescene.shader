Includes = {
	"cw/utility.fxh"
	"jomini/posteffect_base.fxh"


	#// TODO: REMOVE
	"jomini/jomini_dof.fxh"

	# MOD(godherja)
	"jomini/posteffect_base.fxh"
	"standardfuncsgfx.fxh"

	"gh_gaussian.fxh"
	# END MOD
}


PixelShader =
{
	TextureSampler MainScene
	{
		Index = 0
		MagFilter = "Point"
		MinFilter = "Point"
		MipFilter = "Point"
		SampleModeU = "Clamp"
		SampleModeV = "Clamp"
	}
	TextureSampler RestoreBloom
	{
		Index = 1
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Point"
		SampleModeU = "Clamp"
		SampleModeV = "Clamp"
	}
	TextureSampler ColorCube
	{
		Index = 2
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Point"
		SampleModeU = "Clamp"
		SampleModeV = "Clamp"
		MaxAnisotropy = 0
	}
	TextureSampler AverageLuminanceTexture
	{
		Index = 3
		MagFilter = "Point"
		MinFilter = "Point"
		MipFilter = "Point"
		SampleModeU = "Clamp"
		SampleModeV = "Clamp"
	}
	TextureSampler DepthOfFieldTexture
	{
		Index = 4
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Clamp"
		SampleModeV = "Clamp"
	}
	TextureSampler DepthOfFieldCocTexture
	{
		Index = 5
		MagFilter = "Point"
		MinFilter = "Point"
		MipFilter = "Point"
		SampleModeU = "Clamp"
		SampleModeV = "Clamp"
	}
	TextureSampler LensFlareTexture
	{
		Index = 6
		MagFilter = "Point"
		MinFilter = "Point"
		MipFilter = "Point"
		SampleModeU = "Clamp"
		SampleModeV = "Clamp"
	}
	TextureSampler LensDirtTexture
	{
		Index = 7
		MagFilter = "Point"
		MinFilter = "Point"
		MipFilter = "Point"
		SampleModeU = "Clamp"
		SampleModeV = "Clamp"
	}
	TextureSampler AdditionalLensFlareTexture
	{
		Index = 8
		MagFilter = "Point"
		MinFilter = "Point"
		MipFilter = "Point"
		SampleModeU = "Clamp"
		SampleModeV = "Clamp"
	}


	MainCode PixelShader
	{
		Input = "VS_OUTPUT_FULLSCREEN"
		Output = "PDX_COLOR"
		Code
		[[

			float3 SampleColorCube(float3 aColor)
			{
				float scale = (CubeSize - 1.0) / CubeSize;
				float offset = 0.5 / CubeSize;

				float x = ((scale * aColor.r + offset) / CubeSize);
				float y = scale * aColor.g + offset;

				float zFloor = floor((scale * aColor.b + offset) * CubeSize);
				float xOffset1 = zFloor / CubeSize;
				float xOffset2 = min(CubeSize - 1.0, zFloor + 1.0) / CubeSize;

				float3 color1 = PdxTex2D( ColorCube, float2(x + xOffset1, y) ).rgb;
				float3 color2 = PdxTex2D( ColorCube, float2(x + xOffset2, y) ).rgb;

				float3 color = lerp(color1, color2, scale * aColor.b * CubeSize - zFloor );

				return color;
			}

			float4 RestoreScene( float3 inColor )
			{
				float3 color = inColor;
			#ifdef LUT_ENABLED
				color = SampleColorCube( color );
			#endif

				float3 HSV_ = RGBtoHSV( color.rgb );
				HSV_.yz *= HSV.yz;
				HSV_.x += HSV.x;
				color = HSVtoRGB( HSV_ );

				color = saturate( color * ColorBalance );
				color = Levels( color, LevelsMin, LevelsMax );

				return float4( color, 1.0 );
			}

			// MOD(godherja)

			//
			// Defines
			//

			// Uncomment to disable bloom in GUI portraits
			//#define GH_PORTRAIT_BLOOM_DISABLED

			//
			// Service
			//

			bool GH_IsPortrait()
			{
				static const float ALPHA_EPSILON = 0.001f;

				return PdxTex2DLod0(MainScene, float2(0.5f, 0.6f)).a >= ALPHA_EPSILON
					&& PdxTex2DLod0(MainScene, float2(0.0f, 0.4f)).a < ALPHA_EPSILON
					&& PdxTex2DLod0(MainScene, float2(1.0f, 0.4f)).a < ALPHA_EPSILON;
			}

			// END MOD

			PDX_MAIN
			{
				float4 color = PdxTex2DLod0( MainScene, Input.uv );

			#ifdef DOF_ENABLED
				float4 DofColor = PdxTex2DLod0( DepthOfFieldTexture, Input.uv );
				float DofCoc = PdxTex2DLod0( DepthOfFieldCocTexture, Input.uv ).r;
				DofCoc = smoothstep( _BlurBlendMin, _BlurBlendMax, DofCoc );	// Tweak to avoid using the low resolution image at small blur values
				color.rgb = lerp( color.rgb, DofColor.rgb, DofCoc );
			#endif

			#ifdef PDX_DEBUG_NO_HDR
				return float4( ToGamma( saturate(color.rgb) ), 1 );
			#endif

			#ifdef BLOOM_ENABLED
				float3 bloom = PdxTex2DLod0( RestoreBloom, Input.uv ).rgb;
				color.rgb = bloom.rgb + color.rgb; // todo * bloomscale?

				#ifdef LENS_FLARE_ENABLED
					float3 LensFlare = PdxTex2DLod0( LensFlareTexture, Input.uv ).rgb;
					float3 LensDirt = PdxTex2DLod0( LensDirtTexture, Input.uv ).rgb;
					color.rgb = ( LensFlare.rgb * LensDirt ) + color.rgb;
				#endif

				#ifdef ADDITIONAL_LENS_FLARE_ENABLED
					float3 AdditionalLensFlare = PdxTex2DLod0( AdditionalLensFlareTexture, Input.uv ).rgb;
					#ifndef LENS_FLARE_ENABLED
						float3 LensDirt = PdxTex2DLod0( LensDirtTexture, Input.uv ).rgb;
					#endif
					color.rgb = ( ( AdditionalLensFlare.rgb ) * LensDirt ) + color.rgb;
				#endif
			#endif

				// MOD(godherja)
				#ifndef GH_PORTRAIT_BLOOM_DISABLED
					if (GH_IsPortrait())
					{
						GH_SGaussOutput GaussOutput = GH_RunGaussFilter(MainScene, Input.uv);

						// FIXME: Debug
						//return float4(GHBloomColor.rgb, color.a + GHBloomColor.a);
						//return float4(GH_BLOOM_STRENGTH*GHBloomColor.rgb, color.a + GH_BLOOM_STRENGTH*GHBloomColor.a);
						//return float4(GH_ColorToBloomValue(color), 0.0f, 0.0f, color.a);
						// END FIXME

						color += GH_BLOOM_STRENGTH*GaussOutput.BloomColor;
					}
				#endif
				// END MOD

				// Tonemapping
				color.rgb = Exposure(color.rgb);
				color.rgb = ToneMap(color.rgb);

			#ifdef ALPHA
				color.rgb = RestoreScene( saturate(color).rgb ).rgb;
			#else
				color = RestoreScene( saturate(color.rgb) );
			#endif

			#ifdef PDX_DEBUG_TONEMAP_CURVE
				float2 uvScale = float2( ddx(Input.uv.x), ddy(Input.uv.y) );
				const float2 AREA_START = float2( 0.8, 0.25 );
				const float2 AREA_EXTENT = float2( 1.0f - AREA_START.x - 0.001, 0.2 );
				//const float NormalScale = vec2(1.0f) / float2(1920,1080);
				//const float2 AREA_EXTENT = float2( 150, 150 ) * lerp( NormalScale, uvScale, 0.7f );
				//const float2 AREA_START = float2( 1.0, 0.66f ) - AREA_EXTENT;
				const float CURVE_ALPHA = 1.0f;
				float2 Coord = ( Input.uv - AREA_START ) / AREA_EXTENT;
				if( Coord.x >= 0 && Coord.x <= 1.0 && Coord.y >= 0 && Coord.y <= 1 )
				{
					float3 v = vec3( Coord.x );
					v = Exposure( v );
					v = ToneMap( v );
					Coord.y = 1.0f - Coord.y;
					color = lerp( color, float4( step( Coord.y, ToLinear(v) ), 1.0f ), CURVE_ALPHA );
				}
			#endif

			#if defined( LUMA_AS_ALPHA ) && !defined( ALPHA )
				float lumaM = dot(LUMINANCE_VECTOR, color.rgb);

				return float4(color.rgb, lumaM);
			#else
				return color;
			#endif
			}
		]]
	}
}


BlendState BlendState
{
	BlendEnable = no
	#[NU] Couldnt figure out why this was needed, but I need the alpha channel for FXAA reasons
	#WriteMask = "RED|GREEN|BLUE"
}
BlendState BlendStateWriteAlpha
{
	BlendEnable = no
	WriteMask = "RED|GREEN|BLUE|ALPHA"
}

DepthStencilState DepthStencilState
{
	DepthEnable = no
	DepthWriteEnable = no
}


Effect Restore
{
	VertexShader = "VertexShaderFullscreen"
	PixelShader = "PixelShader"
}

Effect RestoreAlpha
{
	VertexShader = "VertexShaderFullscreen"
	PixelShader = "PixelShader"
	BlendState = "BlendStateWriteAlpha"
	Defines = { "ALPHA" }
}
