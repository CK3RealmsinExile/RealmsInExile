PixelShader
{
	Code [[
		float GH_GetCameraPitchCos()
		{
			float3 CameraLookAtDirXZ = float3(CameraLookAtDir.x, 0.0f, CameraLookAtDir.z);

			return dot(CameraLookAtDir, CameraLookAtDirXZ);
		}
	]]
}
