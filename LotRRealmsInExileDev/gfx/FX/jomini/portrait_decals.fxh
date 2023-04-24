includes = {
	"jomini/texture_decals_base.fxh"
	"jomini/portrait_user_data.fxh"
	# MOD(godherja)
	"standardfuncsgfx.fxh"
	"gh_portrait_decals_shared.fxh"
	#"gh_portrait_effects.fxh"
	#"gh_constants.fxh"
	"gh_utils.fxh"
	# END MOD
}

PixelShader =
{
	# MOD(godherja)
	# The following definitions were moved into gh_portrait_decal_data.fxh,
	# since Godherja needs them to be shared between pixel and vertex shaders across several files.
	# That file needs to be kept in sync with vanilla as new patches come out.

	#TextureSampler DecalDiffuseArray
	#{
	#	Ref = JominiPortraitDecalDiffuseArray
	#	MagFilter = "Linear"
	#	MinFilter = "Linear"
	#	MipFilter = "Linear"
	#	SampleModeU = "Clamp"
	#	SampleModeV = "Clamp"
	#	type = "2darray"
	#}

	#TextureSampler DecalNormalArray
	#{
	#	Ref = JominiPortraitDecalNormalArray
	#	MagFilter = "Linear"
	#	MinFilter = "Linear"
	#	MipFilter = "Linear"
	#	SampleModeU = "Clamp"
	#	SampleModeV = "Clamp"
	#	type = "2darray"
	#}

	#TextureSampler DecalPropertiesArray
	#{
	#	Ref = JominiPortraitDecalPropertiesArray
	#	MagFilter = "Linear"
	#	MinFilter = "Linear"
	#	MipFilter = "Linear"
	#	SampleModeU = "Clamp"
	#	SampleModeV = "Clamp"
	#	type = "2darray"
	#}

	#BufferTexture DecalDataBuffer
	#{
	#	Ref = JominiPortraitDecalData
	#	type = uint
	#}
	# END MOD

	Code
	[[		
		// MOD(godherja)

		// This definition was commented out here and extracted into gh_portrait_decal_data.fxh
		// because custom Godherja code from gh_portrait_effects.fxh also depends on it.
		// Any vanilla patches' changes to this definition need to be merged into gh_portrait_decal_data.fxh as well.

		// struct DecalData
		// {
		// 	uint _DiffuseIndex;
		// 	uint _NormalIndex;
		// 	uint _PropertiesIndex;
		// 	uint _BodyPartIndex;

		// 	uint _DiffuseBlendMode;
		// 	uint _NormalBlendMode;
		// 	uint _PropertiesBlendMode;
		// 	float _Weight;

		// 	uint2 _AtlasPos;
		// 	float2 _UVOffset;

		// 	uint _AtlasSize;
		// };

		// END MOD

		DecalData GetDecalData( int Index, uint MaxValue )
		{
			// Data for each decal is stored in multiple texels as specified by DecalData

			DecalData Data;

			Data._DiffuseIndex = PdxReadBuffer( DecalDataBuffer, Index );
			Data._NormalIndex = PdxReadBuffer( DecalDataBuffer, Index + 1 );
			Data._PropertiesIndex = PdxReadBuffer( DecalDataBuffer, Index + 2 );
			Data._BodyPartIndex = PdxReadBuffer( DecalDataBuffer, Index + 3 );

			Data._DiffuseBlendMode = PdxReadBuffer( DecalDataBuffer, Index + 4 );
			Data._NormalBlendMode = PdxReadBuffer( DecalDataBuffer, Index + 5 );
			if ( Data._NormalBlendMode == BLEND_MODE_OVERLAY )
			{
				Data._NormalBlendMode = BLEND_MODE_OVERLAY_NORMAL;
			}
			Data._PropertiesBlendMode = PdxReadBuffer( DecalDataBuffer, Index + 6 );
			Data._Weight = float( PdxReadBuffer( DecalDataBuffer, Index + 7 ) ) / MaxValue;

			Data._AtlasPos = uint2( PdxReadBuffer( DecalDataBuffer, Index + 8 ), PdxReadBuffer( DecalDataBuffer, Index + 9 ) );
			Data._UVOffset = float2( PdxReadBuffer( DecalDataBuffer, Index + 10 ), PdxReadBuffer( DecalDataBuffer, Index + 11 ) );
			Data._UVOffset /= MaxValue;

			Data._AtlasSize = PdxReadBuffer( DecalDataBuffer, Index + 12 );

			return Data;
		}

		// MOD(godherja)

		bool GH_MustApplyDecalPulseEffect(DecalData Data)
		{
			GH_SMarkerTexels MarkerTexels = GH_ExtractMarkerTexels(Data._DiffuseIndex);

			return GH_CheckMarkerTexels(MarkerTexels, GH_MARKER_TOP_LEFT_DECAL, GH_MARKER_TOP_RIGHT_DECAL_PULSE);
		}

		void GH_TryApplyDecalPulseEffect(inout float3 Color, in float2 UV, in DecalData Data)
		{
			if (!GH_MustApplyDecalPulseEffect(Data))
				return;

			float PulsePhase    = pow(sin(1.25f*GlobalTime + 20.0f*UV.y - 7.5f*UV.x), 3.0f);
			float PulseAnimTerm = 0.64f + 0.36f*PulsePhase;

			Color *= PulseAnimTerm;
		}
		// END MOD

		// MOD(godherja)
		//void AddDecals( inout float3 Diffuse, inout float3 Normals, inout float4 Properties, float2 UV, uint InstanceIndex, int From, int To )
		void AddDecals( inout float3 Diffuse, inout float3 Normals, inout float4 Properties, inout float3 Emissive, float2 UV, uint InstanceIndex, int From, int To )
		// END MOD
		{
			// Body part index is scripted on the mesh asset and should match ECharacterPortraitPart
			uint BodyPartIndex = GetBodyPartIndex( InstanceIndex );

			const int TEXEL_COUNT_PER_DECAL = 13;
			int FromDataTexel = From * TEXEL_COUNT_PER_DECAL;
			int ToDataTexel = To * TEXEL_COUNT_PER_DECAL;

			const uint MAX_VALUE = 65535;

			// Sorted after priority
			for ( int i = FromDataTexel; i <= ToDataTexel; i += TEXEL_COUNT_PER_DECAL )
			{
				DecalData Data = GetDecalData( i, MAX_VALUE );

				// Max index => unused
				if ( Data._BodyPartIndex == BodyPartIndex )
				{
					float Weight = Data._Weight;

					// Assumes that the cropped area size corresponds to the atlas factor
					float AtlasFactor = 1.0f / Data._AtlasSize;
					if ( ( ( UV.x >= Data._UVOffset.x ) && ( UV.x < ( Data._UVOffset.x + AtlasFactor ) ) ) &&
						 ( ( UV.y >= Data._UVOffset.y ) && ( UV.y < ( Data._UVOffset.y + AtlasFactor ) ) ) )
					{
						float2 DecalUV = ( UV - Data._UVOffset ) + ( Data._AtlasPos * AtlasFactor );

						// MOD(godherja)
						float4 DiffuseSample  = float4(0.0f, 0.0f, 0.0f, 0.0f);
						float  OriginalWeight = Weight;
						// END MOD

						if ( Data._DiffuseIndex < MAX_VALUE )
						{
							// MOD(godherja)
							//float4 DiffuseSample = PdxTex2D( DecalDiffuseArray, float3( DecalUV, Data._DiffuseIndex ) );
							DiffuseSample = PdxTex2D( DecalDiffuseArray, float3( DecalUV, Data._DiffuseIndex ) );
							// END MOD
							Weight = DiffuseSample.a * Weight;
							Diffuse = BlendDecal( Data._DiffuseBlendMode, float4( Diffuse, 0.0f ), DiffuseSample, Weight ).rgb;
						}

						if ( Data._NormalIndex < MAX_VALUE )
						{
							// MOD(godherja)
							//float3 NormalSample = UnpackDecalNormal( PdxTex2D( DecalNormalArray, float3( DecalUV, Data._NormalIndex ) ), Weight );
							float4 RawNormalSample = PdxTex2D( DecalNormalArray, float3( DecalUV, Data._NormalIndex ) );
							float3 NormalSample    = UnpackDecalNormal(RawNormalSample, Weight );

							float  Emission       = RawNormalSample.b;
							float3 EmissiveSample = Emission*DiffuseSample.a*DiffuseSample.rgb;

							GH_TryApplyDecalPulseEffect(EmissiveSample, UV, Data);

							Emissive = BlendDecal(BLEND_MODE_ADDITIVE, float4( Emissive, 0.0f ), float4(EmissiveSample, 0.0f), OriginalWeight).rgb;
							// END MOD

							Normals = BlendDecal( Data._NormalBlendMode, float4( Normals, 0.0f ), float4( NormalSample, 0.0f ), Weight ).xyz;
						}

						if ( Data._PropertiesIndex < MAX_VALUE )
						{
							float4 PropertiesSample = PdxTex2D( DecalPropertiesArray, float3( DecalUV, Data._PropertiesIndex ) );
							Properties = BlendDecal( Data._PropertiesBlendMode, Properties, PropertiesSample, Weight );
						}
					}
				}
			}

			Normals = normalize( Normals );
		}
	]]
}
