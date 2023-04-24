PixelShader
{
	Code
	[[
		//
		// Constants
		//

		// How bright must a pixel be to bloom? (See GH_ColorToBloomValue().)
		//
		// At 1.0f only extremely bright spots bloom,
		// at 0.0f EVERYTHING blooms (aka welcome to year 2006).
		static const float GH_BLOOM_THRESHOLD = 0.9f;

		// How strongly the bloom effect contributes to pixel color.
		//
		// Must be non-negative.
		// At 0.0f bloom is effectively disabled,
		// higher values produce more pronounced shine/glow but
		// also make shine flickering on smaller details more noticeable.
		static const float GH_BLOOM_STRENGTH = 0.65f;

		//
		// Service
		//

		float GH_ColorToBloomValue(float4 color)
		{
			float Luma           = dot(LUMINANCE_VECTOR, color.rgb);
			float MaxComponent   = max(max(color.r, color.g), color.b);
			float BloomValue     = max(Luma, MaxComponent);

			return step(GH_BLOOM_THRESHOLD, BloomValue);
			//return BloomValue;
		}
	]]
}
