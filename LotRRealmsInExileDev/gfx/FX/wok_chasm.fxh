PixelShader
{
	Code
	[[
		//
		// Defines
		//

		#define WOK_CHASM_ENABLED
		//#define WOK_CHASM_SYMMETRY_ENABLED
		//#define WOK_CHASM_SYMMETRY_GUIDES_ENABLED

		// This is intended to be defined from *LowSpec map Effects in pdxterrain.shader
		// so that a less performance-intensive config is used for players with low graphics settings.
		//#define WOK_LOW_SPEC

		//
		// Config
		//

		// Controls how smooth the color change between flat terrain and chasm wall should be,
		// normals notwithstanding. 1.0 means completely smooth, the closer to 0.0 the more abrupt.
		static const float  CHASM_BRINK_COLOR_LERP_VALUE = 0.8;

		static const float3 CHASM_BOTTOM_COLOR = float3(0.0, 0.0, 0.0);

		static const float2 CHASM_SYMMETRY_CENTER = float2(6945.0, 1102.0);
		static const float  CHASM_SYMMETRY_RANGE  = 155.0;

		static const float3 CHASM_SYMMETRY_GUIDES_COLOR = float3(1.0, 1.0, 1.0);

		static const float CHASM_WALL_NORMALS_SAMPLE_DISTANCE = 0.5;

		#ifndef WOK_LOW_SPEC
			// Higher fidelity setup

			static const float CHASM_MAX_FAKE_DEPTH   = 6.0;
			static const float CHASM_MAX_SAMPLE_RANGE = 64.0;
			static const float CHASM_SAMPLE_STEP      = 0.3;
			static const float CHASM_SAMPLE_PRECISION = 0.005;

			static const int CHASM_WALL_NORMALS_SAMPLE_COUNT = 12;
		#else
			// Higher FPS setup

			static const float CHASM_MAX_FAKE_DEPTH   = 6.0;
			static const float CHASM_MAX_SAMPLE_RANGE = 16.0;
			static const float CHASM_SAMPLE_STEP      = 0.6;
			static const float CHASM_SAMPLE_PRECISION = 0.25;

			static const int CHASM_WALL_NORMALS_SAMPLE_COUNT = 0;
		#endif // !WOK_LOW_SPEC

		//
		// Constants
		//

		static const float CHASM_VALUE_EPSILON = 0.001;

		//
		// Service
		//

		#ifdef PDX_DIRECTX_11
			#define WOK_LOOP [loop]
			#define WOK_UNROLL [unroll]
		#else
			#define WOK_LOOP
			#define WOK_UNROLL
		#endif

		float WoKSampleRedPropsChannelCartesian(float2 WorldSpacePosXZ)
		{
			// Based on vanilla CalculateDetailsLowSpec() but interested only in red channel of the properties texture

			float2 DetailCoordinates = WorldSpacePosXZ * WorldSpaceToDetail;
			float2 DetailCoordinatesScaled = DetailCoordinates * DetailTextureSize;
			float2 DetailCoordinatesScaledFloored = floor( DetailCoordinatesScaled );
			float2 DetailCoordinatesFrac = DetailCoordinatesScaled - DetailCoordinatesScaledFloored;
			DetailCoordinates = DetailCoordinatesScaledFloored * DetailTexelSize + DetailTexelSize * 0.5;

			float4 Factors = float4(
				(1.0 - DetailCoordinatesFrac.x) * (1.0 - DetailCoordinatesFrac.y),
				DetailCoordinatesFrac.x * (1.0 - DetailCoordinatesFrac.y),
				(1.0 - DetailCoordinatesFrac.x) * DetailCoordinatesFrac.y,
				DetailCoordinatesFrac.x * DetailCoordinatesFrac.y
			);

			float4 DetailIndex = PdxTex2DLod0( DetailIndexTexture, DetailCoordinates ) * 255.0;
			float4 DetailMask = PdxTex2DLod0( DetailMaskTexture, DetailCoordinates ) * Factors[0];

			float2 Offsets[3];
			Offsets[0] = float2( DetailTexelSize.x, 0.0 );
			Offsets[1] = float2( 0.0, DetailTexelSize.y );
			Offsets[2] = float2( DetailTexelSize.x, DetailTexelSize.y );

			for ( int k = 0; k < 3; ++k )
			{
				float2 DetailCoordinates2 = DetailCoordinates + Offsets[k];

				float4 DetailIndices = PdxTex2DLod0( DetailIndexTexture, DetailCoordinates2 ) * 255.0;
				float4 DetailMasks = PdxTex2DLod0( DetailMaskTexture, DetailCoordinates2 ) * Factors[k+1];

				for ( int i = 0; i < 4; ++i )
				{
					for ( int j = 0; j < 4; ++j )
					{
						if ( DetailIndex[j] == DetailIndices[i] )
						{
							DetailMask[j] += DetailMasks[i];
						}
					}
				}
			}

			float2 DetailUV = CalcDetailUV( WorldSpacePosXZ );

			float4 DiffuseTexture0 = PdxTex2DLod0( DetailTextures, float3( DetailUV, DetailIndex[0] ) ) * smoothstep( 0.0, 0.1, DetailMask[0] );
			float4 DiffuseTexture1 = PdxTex2DLod0( DetailTextures, float3( DetailUV, DetailIndex[1] ) ) * smoothstep( 0.0, 0.1, DetailMask[1] );
			float4 DiffuseTexture2 = PdxTex2DLod0( DetailTextures, float3( DetailUV, DetailIndex[2] ) ) * smoothstep( 0.0, 0.1, DetailMask[2] );
			float4 DiffuseTexture3 = PdxTex2DLod0( DetailTextures, float3( DetailUV, DetailIndex[3] ) ) * smoothstep( 0.0, 0.1, DetailMask[3] );

			float4 BlendFactors = CalcHeightBlendFactors( float4( DiffuseTexture0.a, DiffuseTexture1.a, DiffuseTexture2.a, DiffuseTexture3.a ), DetailMask, DetailBlendRange );

			float DetailMaterialR = 0.0;

			for (int i = 0; i < 4; ++i)
			{
				float BlendFactor = BlendFactors[i];
				if (BlendFactor > CHASM_VALUE_EPSILON)
				{
					float3 ArrayUV = float3( DetailUV, DetailIndex[i] );
					float4 MaterialTexture = PdxTex2DLod0( MaterialTextures, ArrayUV );

					DetailMaterialR += MaterialTexture.r * BlendFactor;
				}
			}

			return DetailMaterialR;
		}

		float WoKSampleRedPropsChannelPolar(float2 Center, float R, float Phi)
		{
			float2 Offset = float2(R*cos(Phi), R*sin(Phi));

			return WoKSampleRedPropsChannelCartesian(Center - Offset);
		}

		float WoKSampleChasmValueSymmetricalImpl(float2 SymmetryCenter, float SymmetryRange, float2 WorldSpacePosXZ)
		{
			static const float PI_BY_4 = PI/4.0;

			float2 ToSymmetryCenter = SymmetryCenter - WorldSpacePosXZ;

			// Polar coords
			float R   = length(ToSymmetryCenter);
			float Phi = atan2(ToSymmetryCenter.y, ToSymmetryCenter.x) + 2*PI;

			float SymmetryPhi         = mod(Phi, PI_BY_4);
			float SymmetryMirroredPhi = lerp(SymmetryPhi, PI_BY_4 - SymmetryPhi, step(PI_BY_4, mod(Phi, 2*PI_BY_4)));

			float SelectedPhi = lerp(SymmetryMirroredPhi, Phi, step(SymmetryRange, R));

			return WoKSampleRedPropsChannelPolar(SymmetryCenter, R, SelectedPhi);
		}

		float WoKSampleChasmValue(float2 WorldSpacePosXZ)
		{
			#ifdef WOK_CHASM_SYMMETRY_ENABLED
				return WoKSampleChasmValueSymmetricalImpl(CHASM_SYMMETRY_CENTER, CHASM_SYMMETRY_RANGE, WorldSpacePosXZ);
			#else
				return WoKSampleRedPropsChannelCartesian(WorldSpacePosXZ);
			#endif
		}

		void WoKDrawChasmSymmetryGuides(float2 WorldSpacePosXZ, inout float3 PixelColor)
		{
			float2 ToSymmetryCenter = CHASM_SYMMETRY_CENTER - WorldSpacePosXZ;
			float  R   = length(ToSymmetryCenter);
			float  Phi = atan2(ToSymmetryCenter.y, ToSymmetryCenter.x);

			if (R < 2.0 || (R > CHASM_SYMMETRY_RANGE && R < CHASM_SYMMETRY_RANGE + 1.0) ||
				((Phi > PI/4 && Phi < PI/4 + 0.01) || (Phi > 0.0 && Phi < 0.0 + 0.01)) && R < CHASM_SYMMETRY_RANGE)
			{
				PixelColor = CHASM_SYMMETRY_GUIDES_COLOR;
			}
		}

		float3 WoKDetermineChasmWallNormal(float2 BrinkWorldSpacePosXZ)
		{
			static const float SAMPLE_ANGLE_INCREMENT = 2.0*PI/float(CHASM_WALL_NORMALS_SAMPLE_COUNT);

			float3 RawNormal = float3(0.0, 0.0, 0.0);

			// TODO: Optimize. We probably can get away with sampling only in the semicircle facing the camera,
			//       since we can't see away-facing chasm walls anyhow.

			WOK_UNROLL
			for (int i = 0; i < CHASM_WALL_NORMALS_SAMPLE_COUNT; i++)
			{
				float  SampleAngle      = float(i)*SAMPLE_ANGLE_INCREMENT;
				float2 SampleDirection  = float2(cos(SampleAngle), sin(SampleAngle));
				float2 SampleOffset     = CHASM_WALL_NORMALS_SAMPLE_DISTANCE*SampleDirection;
				float  SampleChasmValue = WoKSampleChasmValue(BrinkWorldSpacePosXZ + SampleOffset);

				RawNormal += SampleChasmValue*float3(SampleDirection.x, 0.0, SampleDirection.y);
			}

			return normalize(RawNormal);
		}

		void WoKPrepareChasmEffectImpl(
			in    float3 WorldSpacePos,
			inout float3 BaseNormal,
			inout float4 DetailDiffuse,
			inout float3 DetailNormal,
			inout float4 DetailMaterial,
			out   float  RelativeChasmDepth
		)
		{
			float3 FromCamera       = WorldSpacePos - CameraPosition;
			float3 FromCameraNorm   = normalize(FromCamera);
			float3 FromCameraXZ     = float3(FromCamera.x, 0.0, FromCamera.z);
			float3 FromCameraXZNorm = normalize(FromCameraXZ);
			float  CameraAngleSin   = length(cross(FromCameraNorm, FromCameraXZNorm));
			float  CameraAngleCos   = dot(FromCameraNorm, FromCameraXZNorm);
			float  CameraAngleTan   = CameraAngleSin/max(CameraAngleCos, 0.05);

			float2 SampleDistanceUnit = FromCameraXZNorm.xz;
			float  SampleRange        = min(CHASM_MAX_FAKE_DEPTH/CameraAngleTan, CHASM_MAX_SAMPLE_RANGE);

			float SurfaceDistanceToBrink = SampleRange;

			for (float SampleDistance = 0.0; SampleDistance < SampleRange; SampleDistance += CHASM_SAMPLE_STEP)
			{
				float2 SampleWorldSpacePosXZ = WorldSpacePos.xz + SampleDistance*SampleDistanceUnit;
				float  SampledChasmValue     = WoKSampleChasmValue(SampleWorldSpacePosXZ);

				if (SampledChasmValue < CHASM_VALUE_EPSILON)
				{
					SurfaceDistanceToBrink = SampleDistance;
					break;
				}
			}

			// Binary search to reach CHASM_SAMPLE_PRECISION for distance to brink
			float MinSurfaceDistanceToBrink = SurfaceDistanceToBrink - CHASM_SAMPLE_STEP;
			while (SurfaceDistanceToBrink - MinSurfaceDistanceToBrink > CHASM_SAMPLE_PRECISION)
			{
				float  Midpoint                = 0.5*(MinSurfaceDistanceToBrink + SurfaceDistanceToBrink);
				float2 MidpointWorldSpacePosXZ = WorldSpacePos.xz + Midpoint*SampleDistanceUnit;
				float  MidpointChasmValue      = WoKSampleChasmValue(MidpointWorldSpacePosXZ);

				float StepValue           = step(CHASM_VALUE_EPSILON, MidpointChasmValue);
				SurfaceDistanceToBrink    = lerp(SurfaceDistanceToBrink, Midpoint, 1.0 - StepValue);
				MinSurfaceDistanceToBrink = lerp(MinSurfaceDistanceToBrink, Midpoint, StepValue);
			}

			float FakeDepth = CameraAngleTan*SurfaceDistanceToBrink;
			//float FakeDepth = SurfaceDistanceToBrink/CameraAngleCos;

			//
			// Texture mapping of the chasm walls
			//

			float2 BrinkOffset          = SampleDistanceUnit*SurfaceDistanceToBrink;
			float2 BrinkWorldSpacePosXZ = WorldSpacePos.xz + BrinkOffset;

			// Sample in the negative Y direction by default, so that texture mapping
			// looks fine from the most common camera viewing angles players use during the game,
			// even if we choose not to determine the actual chasm wall normal.
			float2 SampleOffset = float2(0.0, -FakeDepth);

			if (CHASM_WALL_NORMALS_SAMPLE_COUNT > 0)
			{
				BaseNormal = WoKDetermineChasmWallNormal(BrinkWorldSpacePosXZ);

				SampleOffset = FakeDepth*BaseNormal.xz;
			}

			float2 SampleWorldSpacePosXZ = BrinkWorldSpacePosXZ + SampleOffset;

			CalculateDetails(SampleWorldSpacePosXZ, DetailDiffuse, DetailNormal, DetailMaterial);

			RelativeChasmDepth = saturate(FakeDepth / CHASM_MAX_FAKE_DEPTH);
		}

		//
		// Interface
		//

		void WoKPrepareChasmEffect(
			in    float3 WorldSpacePos,
			inout float3 BaseNormal,
			inout float4 DetailDiffuse,
			inout float3 DetailNormal,
			inout float4 DetailMaterial,
			out   float  RelativeChasmDepth
		)
		{
			#ifdef WOK_CHASM_ENABLED

				#ifdef WOK_CHASM_SYMMETRY_ENABLED
					float ChasmValue = WoKSampleChasmValue(WorldSpacePos.xz);
				#else
					float ChasmValue = DetailMaterial.r;
				#endif // WOK_CHASM_SYMMETRY_ENABLED

				if (ChasmValue <= CHASM_VALUE_EPSILON) // if we are outside the chasm
				{
					RelativeChasmDepth = 0.0;

					return;
				}

				WoKPrepareChasmEffectImpl(
					WorldSpacePos,
					BaseNormal,
					DetailDiffuse,
					DetailNormal,
					DetailMaterial,
					RelativeChasmDepth
				);

			#else

				RelativeChasmDepth = 0.0;

			#endif // WOK_CHASM_ENABLED
		}

		void WoKAdjustChasmFinalColor(inout float3 FinalColor, in float RelativeChasmDepth, in float2 WorldSpacePosXZ)
		{
			#ifdef WOK_CHASM_ENABLED

				float BaseColorLerpValue  = lerp(1.0, CHASM_BRINK_COLOR_LERP_VALUE, step(0.005, RelativeChasmDepth));
				float FinalColorLerpValue = BaseColorLerpValue*(1.0 - RelativeChasmDepth);

				// Fade color to CHASM_BOTTOM_COLOR as "depth" increases
				FinalColor = lerp(CHASM_BOTTOM_COLOR, FinalColor, FinalColorLerpValue);

				#ifdef WOK_CHASM_SYMMETRY_GUIDES_ENABLED
					WoKDrawChasmSymmetryGuides(WorldSpacePosXZ, FinalColor);
				#endif // WOK_CHASM_SYMMETRY_GUIDES_ENABLED

			#endif // WOK_CHASM_ENABLED
		}
	]]
}
