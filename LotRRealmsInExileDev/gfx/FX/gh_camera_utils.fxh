PixelShader
{
	Code [[
		float GH_GetCameraPitchCos()
		{
			float3 CameraLookAtDirXZ = float3(CameraLookAtDir.x, 0.0f, CameraLookAtDir.z);

			return dot(CameraLookAtDir, CameraLookAtDirXZ);
		}

		float GH_GetCameraPitchAlphaMultiplier(float FullAlphaPitchCos, float MaxAlphaPitchCos)
		{
			return 1.0f - smoothstep(FullAlphaPitchCos, MaxAlphaPitchCos, GH_GetCameraPitchCos());
		}

		float GH_GetDefaultCameraPitchAlphaMultiplier()
		{
			static const float FULL_CAMERA_PITCH_COS = 0.7f;
			static const float MAX_CAMERA_PITCH_COS  = 0.77f;

			return GH_GetCameraPitchAlphaMultiplier(FULL_CAMERA_PITCH_COS, MAX_CAMERA_PITCH_COS);
		}
	]]
}
