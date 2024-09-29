includes = {
	"jomini/texture_decals_base.fxh"
	"jomini/portrait_user_data.fxh"
	# MOD(godherja)
	"standardfuncsgfx.fxh"
	"gh_portrait_decal_data.fxh"
	"gh_markers.fxh"
	#"gh_constants.fxh"
	"gh_utils.fxh"
	# END MOD
}

Code
[[
	//
	// Interface
	//

	float GH_MipLevelToLod(float MipLevel)
	{
		// This function (originally GetMIP6Level()) was graciously provided by Buck (EK2).

		#ifndef PDX_OPENGL
			// If running on DX or Vulkan, use the below to get decal texture size.
			float3 TextureSize;
			DecalDiffuseArray._Texture.GetDimensions( TextureSize.x , TextureSize.y , TextureSize.z );
		#else
			// If running on OpenGL, use the below to get decal texture size.
			ivec3 TextureSize = textureSize(DecalDiffuseArray, 0);
		#endif

		// Get log base 2 for current texture size (1024px - 10, 512px - 9, etc.)
		// Take that away from 10 to find the current MIP level.
		// Take that away from MipLevel to find which MIP We need to sample in the texture buffer to retrieve the "absolute" MIP6 containing our encoded pixels

		return MipLevel - (10.0f - log2(TextureSize.x));
	}

	GH_SMarkerTexels GH_ExtractMarkerTexels(uint DiffuseIndex)
	{
		// Max pixel coordinate for the GH_MARKER_MIP_LEVEL-th mip-map.
		// TODO: Actually use a formula based on GH_MARKER_MIP_LEVEL here, instead of a literal?
		static const int MAX_MARKER_PIXEL_COORD = 15; // 6th mip-map is 16x16 for decals

		static int MarkerLod = int(GH_MipLevelToLod(GH_MARKER_MIP_LEVEL));

		static const int2 TOP_LEFT_UV     = int2(0, 0);
		static const int2 TOP_RIGHT_UV    = int2(MAX_MARKER_PIXEL_COORD, 0);
		static const int2 BOTTOM_RIGHT_UV = int2(MAX_MARKER_PIXEL_COORD, MAX_MARKER_PIXEL_COORD);
		static const int2 BOTTOM_LEFT_UV  = int2(0, MAX_MARKER_PIXEL_COORD);

		GH_SMarkerTexels MarkerTexels;
		MarkerTexels.TopLeftTexel     = GH_PdxTex2DArrayLoad(DecalDiffuseArray, int3(TOP_LEFT_UV, DiffuseIndex), MarkerLod);
		MarkerTexels.TopRightTexel    = GH_PdxTex2DArrayLoad(DecalDiffuseArray, int3(TOP_RIGHT_UV, DiffuseIndex), MarkerLod);

		#ifndef PIXEL_SHADER
			MarkerTexels.BottomRightTexel = GH_PdxTex2DArrayLoad(DecalDiffuseArray, int3(BOTTOM_RIGHT_UV, DiffuseIndex), MarkerLod);
			MarkerTexels.BottomLeftTexel  = GH_PdxTex2DArrayLoad(DecalDiffuseArray, int3(BOTTOM_LEFT_UV, DiffuseIndex), MarkerLod);
		#else
			// The other two corners are not currently used by pixel shaders, so no use sampling them from there.
			MarkerTexels.BottomRightTexel = float4(0.0f, 0.0f, 0.0f, 0.0f);
			MarkerTexels.BottomLeftTexel  = float4(0.0f, 0.0f, 0.0f, 0.0f);
		#endif // !PIXEL_SHADER

		return MarkerTexels;
	}
]]
