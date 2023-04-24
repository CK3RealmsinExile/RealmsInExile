Includes = {
	"gh_gaussian/gh_gaussian_bloom.fxh"
	#"gh_gaussian/gh_gaussian_shade.fxh"
}

PixelShader
{
	Code
	[[
		//
		// Constants
		//

		// Determines the Gaussian blur strength.
		// For bloom effect this determines how much blooming spots "bleed".
		// No direct effect on FPS per se, but may require changing
		// GH_GAUSS_KERNEL_SIZE for better visual results.
		//
		// Must be positive.
		static const float GH_GAUSS_SIGMA = 5.0f;

		// Kernel size for Gaussian filter.
		// This is the primary FPS drain for bloom and other effects using blur!
		//
		// Must be an odd number.
		// For best visual results should generally be about 6 times bigger than GH_GAUSS_SIGMA
		// (see reasoning here https://stackoverflow.com/a/62002971/1051764).
		// For best performance should be as small as possible,
		// but if too small the blur edges will look boxy.
		// So there is some space for a visuals/performance trade-off here.
		static const int GH_GAUSS_KERNEL_SIZE = 31;

		// Determines whether to adjust the size of Gauss filter mask and by how much.
		//
		// At 1.0f the Gauss filter exactly matches texels of the underlying texture.
		// Higher values can be used to make the blur effect more spread out around the edges
		// at the cost of losing quality (blurred regions will take on a grid-like look).
		static const float GH_GAUSS_TEXEL_OFFSET_MULTIPLIER = 1.0f;

		// Flags for selecting Gaussian effects
		// static const uint GH_GAUSS_EFFECT_NONE  = 0;
		// static const uint GH_GAUSS_EFFECT_BLOOM = 1 << 0;
		// static const uint GH_GAUSS_EFFECT_SHADE = 1 << 1;

		//
		// Types
		//

		struct GH_SGaussOutput
		{
			float4 BloomColor;
			// float  BlackShadeAlpha;
			// float  TrippyShadeAlpha;
		};

		//
		// Interface
		//

		GH_SGaussOutput GH_RunGaussFilter(PdxTextureSampler2D Texture, float2 UV/*, uint GaussEffects*/)
		{
			GH_SGaussOutput Out;
			Out.BloomColor  = float4(0.0f, 0.0f, 0.0f, 0.0f);
			// Out.BlackShadeAlpha  = 0.0f;
			// Out.TrippyShadeAlpha = 0.0f;

			// if (GaussEffects == GH_GAUSS_EFFECT_NONE)
			// 	return Out;

			// The following Gaussian blur logic is "heavily inspired by"
			// mrharicot's Gaussian Blur shader at https://www.shadertoy.com/view/XdfGDH

			static const int GAUSS_KERNEL_SIZE = GH_GAUSS_KERNEL_SIZE;
			static const int GAUSS_MAX_OFFSET  = (GAUSS_KERNEL_SIZE - 1)/2;

			static const float SIGMA = GH_GAUSS_SIGMA;

			float GaussKernel[GAUSS_KERNEL_SIZE];

			for (int i = 0; i <= GAUSS_MAX_OFFSET; ++i)
			{
				float Element = 0.39894*exp(-0.5*float(i)*float(i)/(SIGMA*SIGMA))/SIGMA;

				GaussKernel[GAUSS_MAX_OFFSET + i] = Element;
				GaussKernel[GAUSS_MAX_OFFSET - i] = Element;
			}

			float2 TextureSize;
			PdxTex2DSize(Texture, TextureSize);

			float2 TexelSizeUV = float2(1.0f/TextureSize.x, 1.0f/TextureSize.y);

			for (int DeltaY = -GAUSS_MAX_OFFSET; DeltaY <= GAUSS_MAX_OFFSET; ++DeltaY)
			{
				for (int DeltaX = -GAUSS_MAX_OFFSET; DeltaX <= GAUSS_MAX_OFFSET; ++DeltaX)
				{
					float  Weight     = GaussKernel[GAUSS_MAX_OFFSET + DeltaY]*GaussKernel[GAUSS_MAX_OFFSET + DeltaX];
					float2 UVOffset   = float2(float(DeltaX), float(DeltaY))*TexelSizeUV;

					float4 TexelColor = PdxTex2DLod0(Texture, UV + GH_GAUSS_TEXEL_OFFSET_MULTIPLIER*UVOffset);

					float BloomValue = GH_ColorToBloomValue(TexelColor);

					Out.BloomColor += Weight*BloomValue*saturate(TexelColor);

					// float BlackShadeValue  = GH_ColorToBlackShadeValue(TexelColor);
					// float TrippyShadeValue = GH_ColorToTrippyShadeValue(TexelColor);

					// Out.BlackShadeAlpha  += Weight*BlackShadeValue;
					// Out.TrippyShadeAlpha += Weight*TrippyShadeValue;
				}
			}

			float Z = 0.0f;
			for (int k = 0; k < GAUSS_KERNEL_SIZE; ++k)
			{
				Z += GaussKernel[k];
			}

			float ZZ = Z*Z;

			Out.BloomColor  /= ZZ;
			// Out.BlackShadeAlpha  /= ZZ;
			// Out.TrippyShadeAlpha /= ZZ;

			return Out;
		}
	]]
}
