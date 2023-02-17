Code [[
	// This is used to make cloud layer have less of a gray-out effect especially over water,
	// than the visuals produced by an alpha of 1.0f (as suggested by Shadow_Color aka _FoWShadowColor parameter's alpha).
	static const float GH_FOW_SHADOW_ALPHA = 0.25f;

	// Max clouds alpha at the closest zoom level (might be below apparent parallax height, so best use 0)
	static const float GH_FOW_CLOUDS_LOW_ALPHA    = 0.0f;

	// Max clouds alpha at zoom levels where terrain is visible
	// but not filled with overlay colors.
	static const float GH_FOW_CLOUDS_MEDIUM_ALPHA = 0.25f;

	// Max clouds alpha between the first zoom level where
	// terrain overlays are filled and the first flat map zoom level.
	static const float GH_FOW_CLOUDS_HIGH_ALPHA   = 0.6f;

	// Max clouds alpha on flat map.
	static const float GH_FOW_CLOUDS_FLAT_MAP_ALPHA = 0.0f;

	// The values below replace GameFogOfWar constant buffer from Victoria 3's fog_of_war.fxh (gh_vic3_fog_of_war.fxh)
	// and are taken (with minor modifications) from that game's gfx/map/fog_of_war/fog_of_war.settings at version 1.0.3.
	static const float4 _FoWShadowColor = float4(float3(23.0f, 23.0f, 23.0f)/255.0f, GH_FOW_SHADOW_ALPHA); // hsv{ 0.560000 0.85000 0.160000 1.000000 }
	static const float4 _FoWCloudsColor = float4(1.0f, 1.0f, 1.0f, 1.0f); // hsv{ 0.650000 0.100000 1.000000 1.000000 }
	static const float4 _FoWCloudsColorSecondary = float4(float3(200.0f, 200.0f, 200.0f)/255.0f, 1.0f); // hsv{ 0.562500 0.187500 0.804688 1.000000 }
	static const float _FoWCloudsColorGradientMin = 0.0f;
	static const float _FoWCloudsColorGradientMax = 1.0f;
	static const float _FoWCloudHeight = 22.0f;
	static const float _FoWShadowMult = 0.6f;
	static const float _FoWShadowTexStart = 0.0f;
	static const float _FoWShadowTexStop = 1.0f;
	static const float _FoWShadowAlphaStart = 0.0f;
	static const float _FoWShadowAlphaStop = 1.0f;
	static const float _FowShadowLayer1Min = 0.45f;
	static const float _FowShadowLayer1Max = 1.35f;
	static const float _FowShadowLayer2Min = 1.0f;
	static const float _FowShadowLayer2Max = 3.0f;
	static const float _FowShadowLayer3Min = 1.0f;
	static const float _FowShadowLayer3Max = 3.0f;
	static const float _FoWCloudsAlphaStart = 0.0f;
	static const float _FoWCloudsAlphaStop = 1.0f;
	static const float _FoWMasterStart = 0.0f;
	static const float _FoWMasterStop = 1.28f;
	static const int _FoWMasterUVTiling = 1;
	static const float _FoWMasterUVRotation = 0.0f; // absent from Vic3's fog_of_war.settings
	static const float2 _FoWMasterUVScale = float2(1.0f, -0.5f);
	static const float2 _FoWMasterUVSpeed = float2(0.3f, -0.6f);
	static const float _FoWLayer1Min = 0.0f;
	static const float _FoWLayer1Max = 1.0f;
	static const int _FoWLayer1Tiling = 9;
	static const float _FoWLayer2Min = 0.039f;
	static const float _FoWLayer2Max = 0.58f;
	static const float _FoWLayer2Balance = 0.481529f;
	static const int _FoWLayer2Tiling = 12;
	static const float _FoWLayer3Min = 0.46842f;
	static const float _FoWLayer3Max = 1.0f;
	static const float _FoWLayer3Balance = 0.300723f;
	static const int _FoWLayer3Tiling = 20;
	static const float _FoWShowAlphaMask = 0.0f; // no
	static const float2 _FoWLayer1Speed = float2(-0.6f, 0.5f);
	static const float2 _FoWLayer2Speed = float2(-1.6f, 1.2f);
	static const float2 _FoWLayer3Speed = float2(-1.5f, 1.0f);
]]
