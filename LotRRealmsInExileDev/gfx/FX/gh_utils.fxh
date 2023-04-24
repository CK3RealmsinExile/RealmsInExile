includes = {
	#"gh_constants.fxh"
}

Code [[
	//
	// Macros
	//

	#ifndef PDX_OPENGL
		#define GH_LOOP [loop]
		#define GH_UNROLL [unroll]
		#define GH_UNROLL_EXACT(ITERATIONS_COUNT) [unroll(ITERATIONS_COUNT)]
	#else
		#define GH_LOOP
		#define GH_UNROLL
		#define GH_UNROLL_EXACT(ITERATIONS_COUNT)
	#endif

	#ifndef PDX_OPENGL
		#define GH_PdxTex2DArrayLoad(samp,uvi,lod) (samp)._Texture.Load( int4((uvi), (lod)) )
	#else
		#define GH_PdxTex2DArrayLoad texelFetch
	#endif

	//
	// Interface
	//

	float3 GH_ToWorldSpace(float3 LocalSpacePos, float4x4 WorldMatrix)
	{
		float3 WorldSpacePos = mul(WorldMatrix, float4(LocalSpacePos, 1.0)).xyz;
		WorldSpacePos /= WorldMatrix[3][3];

		return WorldSpacePos;
	}
]]
