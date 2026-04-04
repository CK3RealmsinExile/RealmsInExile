Includes = {
	"cw/lighting_util.fxh"
	"cw/shadow.fxh"
	"jomini/jomini.fxh"
	"constants.fxh"
	"shadow_tint.fxh"
}

PixelShader =
{
	TextureSampler TerrainSunnyEnvironmentMap
	{
		Index = 26
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Clamp"
		SampleModeV = "Clamp"
		Type = "Cube"
		File = "gfx/map/environment/environment_terrain_sunny.dds"
		srgb = yes
	}
	TextureSampler TerrainShadowEnvironmentMap
	{
		Index = 27
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Clamp"
		SampleModeV = "Clamp"
		Type = "Cube"
		File = "gfx/map/environment/environment_terrain_shadow.dds"
		srgb = yes
	}
	TextureSampler MapObjectsSunnyEnvironmentMap
	{
		Index = 28
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Clamp"
		SampleModeV = "Clamp"
		Type = "Cube"
		File = "gfx/map/environment/environment_mapobjects_sunny.dds"
		srgb = yes
	}
	TextureSampler MapObjectsShadowEnvironmentMap
	{
		Index = 29
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Clamp"
		SampleModeV = "Clamp"
		Type = "Cube"
		File = "gfx/map/environment/environment_mapobjects_shadow.dds"
		srgb = yes
	}

	Code
	[[
		//-------------------------------
		// Lighting configuration -------
		//-------------------------------

		// Sun position coordinates (0-1 range)
		// Azimuth: 0.0=north, 0.25=west, 0.5=south, 0.75=east, 1.0=north again
		// Elevation: 0.0=horizon, 0.5=45 degrees up, 1.0=zenith (straight up)

		// Terrain sunny scenario lighting parameters
		#define TERRAIN_SUNNY_SPECULAR_FACTOR          0.75f //LotR - Vanilla = 1.0
		#define TERRAIN_SUNNY_SUN_COLOR                float3( 1.0f, 0.9f, 0.8f )
		#define TERRAIN_SUNNY_SUN_INTENSITY            9.0f
		#define TERRAIN_SUNNY_IBL_SCALE		           0.5f //LotR - Vanilla = 0.25

		// Terrain shadow scenario lighting parameters
		#define TERRAIN_OVERCAST_SPECULAR_FACTOR         1.0f
		#define TERRAIN_OVERCAST_SUN_COLOR               float3( 0.4f, 0.4f, 0.7f )
		#define TERRAIN_OVERCAST_SUN_INTENSITY           2.0f
		#define TERRAIN_OVERCAST_IBL_SCALE               0.5f

		// Map objects sunny scenario lighting parameters
		#define MAP_OBJECTS_SUNNY_SPECULAR_FACTOR      0.3f //LotR - Vanilla = 1.0
		#define MAP_OBJECTS_SUNNY_SUN_COLOR            float3( 1.0f, 0.9f, 0.6f ) //LotR - Vanilla = 1.0/0.9/0.8
		#define MAP_OBJECTS_SUNNY_SUN_INTENSITY        20.0f //LotR - Vanilla = 10.0
		#define MAP_OBJECTS_SUNNY_IBL_SCALE            1.7f //LotR - Vanilla = 1.5

		// Map objects shadow scenario lighting parameters
		#define MAP_OBJECTS_OVERCAST_SPECULAR_FACTOR     1.0f
		#define MAP_OBJECTS_OVERCAST_SUN_COLOR           float3( 0.4f, 0.4f, 0.7f )
		#define MAP_OBJECTS_OVERCAST_SUN_INTENSITY       3.0f
		#define MAP_OBJECTS_OVERCAST_IBL_SCALE           1.2f

		// Water sunny scenario lighting parameters
		#define WATER_SUNNY_GLOSS_SCALE                20.0f
		#define WATER_SUNNY_SPECULAR_FACTOR            0.1f
		#define WATER_SUNNY_SUN_INTENSITY_MULTIPLIER   1.0f
		#define WATER_SUNNY_IBL_SCALE                  0.1f

		// Water shadow scenario lighting parameters
		#define WATER_OVERCAST_GLOSS_SCALE               5.0f
		#define WATER_OVERCAST_SPECULAR_FACTOR           0.1f
		#define WATER_OVERCAST_SUN_INTENSITY_MULTIPLIER  0.3f
		#define WATER_OVERCAST_IBL_SCALE                 1.0f

		//-------------------------------
		// Core lighting functions ------
		//-------------------------------

		SLightingProperties GetMapLightingProperties( float3 WorldSpacePos, float ShadowTerm )
		{
			SLightingProperties LightingProps;
			LightingProps._ToCameraDir = normalize( CameraPosition - WorldSpacePos );
			LightingProps._ToLightDir = ToSunDir;
			LightingProps._LightIntensity = SunDiffuse * SunIntensity;
			LightingProps._ShadowTerm = ShadowTerm;
			LightingProps._CubemapIntensity = CubemapIntensity;
			LightingProps._CubemapYRotation = CubemapYRotation;

			return LightingProps;
		}

		SLightingProperties GetMapLightingProperties( float3 WorldSpacePos, PdxTextureSampler2DCmp ShadowMap )
		{
			float4 ShadowProj = mul( ShadowMapTextureMatrix, float4( WorldSpacePos, 1.0f ) );
			float ShadowTerm = CalculateShadow( ShadowProj, ShadowMap );

			return GetMapLightingProperties( WorldSpacePos, ShadowTerm );
		}

		//-------------------------------
		// Unified lighting system ------
		//-------------------------------

		float3 CalculateMapLighting( in SLightingProperties LightingProps, SMaterialProperties MaterialProps, PdxTextureSamplerCube EnvironmentMap, float SpecularFactor )
		{
			float3 DiffuseLight;
			float3 SpecularLight;
			CalculateLightingFromLight( MaterialProps, LightingProps, DiffuseLight, SpecularLight );

			float3 DiffuseIBL;
			float3 SpecularIBL;
			CalculateLightingFromIBL( MaterialProps, LightingProps, EnvironmentMap, DiffuseIBL, SpecularIBL );

			return DiffuseLight + DiffuseIBL + ( SpecularIBL + SpecularLight ) * SpecularFactor;
		}

		// Scenario-specific lighting functions using separate cubemap files
		float3 CalculateTerrainSunnyLighting( in SLightingProperties LightingProps, SMaterialProperties MaterialProps, PdxTextureSamplerCube EnvironmentMap )
		{
			#ifndef TERRAIN_FLAT_MAP_LERP
				LightingProps._ToLightDir = ToTerrainSunnySunDir;
				LightingProps._LightIntensity = TERRAIN_SUNNY_SUN_COLOR * TERRAIN_SUNNY_SUN_INTENSITY;
				LightingProps._CubemapIntensity = CubemapIntensity * TERRAIN_SUNNY_IBL_SCALE;
			#endif
			#if defined( PDX_OSX ) && defined( PDX_OPENGL )
				return CalculateMapLighting( LightingProps, MaterialProps, EnvironmentMap, TERRAIN_SUNNY_SPECULAR_FACTOR );
			#else
				return CalculateMapLighting( LightingProps, MaterialProps, TerrainSunnyEnvironmentMap, TERRAIN_SUNNY_SPECULAR_FACTOR );
			#endif
		}

		float3 CalculateTerrainShadowLighting( in SLightingProperties LightingProps, SMaterialProperties MaterialProps, PdxTextureSamplerCube EnvironmentMap )
		{
			LightingProps._ToLightDir = ToTerrainOvercastSunDir;
			LightingProps._LightIntensity = TERRAIN_OVERCAST_SUN_COLOR * TERRAIN_OVERCAST_SUN_INTENSITY;
			LightingProps._CubemapIntensity = CubemapIntensity * TERRAIN_OVERCAST_IBL_SCALE;
			#if defined( PDX_OSX ) && defined( PDX_OPENGL )
				return CalculateMapLighting( LightingProps, MaterialProps, EnvironmentMap, TERRAIN_OVERCAST_SPECULAR_FACTOR );
			#else
				return CalculateMapLighting( LightingProps, MaterialProps, TerrainShadowEnvironmentMap, TERRAIN_OVERCAST_SPECULAR_FACTOR );
			#endif
		}

		float3 CalculateMapObjectsSunnyLighting( in SLightingProperties LightingProps, SMaterialProperties MaterialProps, PdxTextureSamplerCube EnvironmentMap )
		{
			LightingProps._ToLightDir = ToMapObjectsSunnySunDir;
			LightingProps._LightIntensity = MAP_OBJECTS_SUNNY_SUN_COLOR * MAP_OBJECTS_SUNNY_SUN_INTENSITY;
			LightingProps._CubemapIntensity = CubemapIntensity * MAP_OBJECTS_SUNNY_IBL_SCALE;
			#if defined( PDX_OSX ) && defined( PDX_OPENGL )
				return CalculateMapLighting( LightingProps, MaterialProps, EnvironmentMap, MAP_OBJECTS_SUNNY_SPECULAR_FACTOR );
			#else
				return CalculateMapLighting( LightingProps, MaterialProps, MapObjectsSunnyEnvironmentMap, MAP_OBJECTS_SUNNY_SPECULAR_FACTOR );
			#endif
		}

		float3 CalculateMapObjectsShadowLighting( in SLightingProperties LightingProps, SMaterialProperties MaterialProps, PdxTextureSamplerCube EnvironmentMap )
		{
			LightingProps._ToLightDir = ToMapObjectsOvercastSunDir;
			LightingProps._LightIntensity = MAP_OBJECTS_OVERCAST_SUN_COLOR * MAP_OBJECTS_OVERCAST_SUN_INTENSITY;
			LightingProps._CubemapIntensity = CubemapIntensity * MAP_OBJECTS_OVERCAST_IBL_SCALE;
			#if defined( PDX_OSX ) && defined( PDX_OPENGL )
				return CalculateMapLighting( LightingProps, MaterialProps, EnvironmentMap, MAP_OBJECTS_OVERCAST_SPECULAR_FACTOR );
			#else
				return CalculateMapLighting( LightingProps, MaterialProps, MapObjectsShadowEnvironmentMap, MAP_OBJECTS_OVERCAST_SPECULAR_FACTOR );
			#endif
		}

		//-------------------------------
		// Dual scenario functions -----
		//-------------------------------

		// Terrain dual scenario lighting - uses IBL for both sunny and shadow scenarios
		float3 CalculateTerrainDualScenarioLighting( SLightingProperties LightingProps, SMaterialProperties MaterialProps, float ShadowMask, PdxTextureSamplerCube EnvironmentMap )
		{
			if ( ShadowMask > 0.99f )
			{
				return CalculateTerrainShadowLighting( LightingProps, MaterialProps, EnvironmentMap );
			}
			if ( ShadowMask > 0.0f )
			{
				// Calculate both lighting scenarios
				float3 SunnyLighting = CalculateTerrainSunnyLighting( LightingProps, MaterialProps, EnvironmentMap );
				float3 ShadowLighting = CalculateTerrainShadowLighting( LightingProps, MaterialProps, EnvironmentMap );

				// Blend between scenarios based on shadow mask
				return lerp( SunnyLighting, ShadowLighting, ShadowMask );
			}

			return CalculateTerrainSunnyLighting( LightingProps, MaterialProps, EnvironmentMap );
		}

		// Map objects dual scenario lighting - uses IBL for both sunny and shadow scenarios
		float3 CalculateMapObjectsDualScenarioLighting( SLightingProperties LightingProps, SMaterialProperties MaterialProps, float ShadowMask, PdxTextureSamplerCube EnvironmentMap)
		{
			if ( ShadowMask > 0.99f )
			{
				return CalculateMapObjectsShadowLighting( LightingProps, MaterialProps, EnvironmentMap );
			}
			if ( ShadowMask > 0.0f )
			{
				// Calculate both lighting scenarios
				float3 SunnyLighting = CalculateMapObjectsSunnyLighting( LightingProps, MaterialProps, EnvironmentMap );
				float3 ShadowLighting = CalculateMapObjectsShadowLighting( LightingProps, MaterialProps, EnvironmentMap );

				// Blend between scenarios based on shadow masks
				return lerp( SunnyLighting, ShadowLighting, ShadowMask );
			}

			return CalculateMapObjectsSunnyLighting( LightingProps, MaterialProps, EnvironmentMap );
		}

		//-------------------------------
		// Water scenario functions -----
		//-------------------------------

		// Get water gloss scale based on shadow mask
		float GetWaterGlossScale( float ShadowMask )
		{
			return lerp( WATER_SUNNY_GLOSS_SCALE, WATER_OVERCAST_GLOSS_SCALE, ShadowMask );
		}

		// Get water specular factor based on shadow mask
		float GetWaterSpecularFactor( float ShadowMask )
		{
			return lerp( WATER_SUNNY_SPECULAR_FACTOR, WATER_OVERCAST_SPECULAR_FACTOR, ShadowMask );
		}

		// Get water cubemap intensity based on shadow mask
		float GetWaterCubemapIntensity( float ShadowMask )
		{
			return lerp( WATER_SUNNY_IBL_SCALE, WATER_OVERCAST_IBL_SCALE, ShadowMask );
		}

		// Get water sun direction based on shadow mask
		float3 GetWaterToSunDirection( float ShadowMask )
		{
			float3 SunnyDir = ToWaterSunnySunDir;
			float3 ShadowDir = ToWaterOvercastSunDir;
			return normalize( lerp( SunnyDir, ShadowDir, ShadowMask ) );
		}

		// Get water sun intensity based on shadow mask
		float GetWaterSunIntensity( float ShadowMask )
		{
			return lerp( WATER_SUNNY_SUN_INTENSITY_MULTIPLIER, WATER_OVERCAST_SUN_INTENSITY_MULTIPLIER, ShadowMask );
		}

		//-------------------------------
		// Shadow tint wrapper functions
		//-------------------------------

		// Apply shadow tint for terrain using terrain lighting directions
		float3 ApplyTerrainShadowTintWithClouds( float3 Color, float2 WorldPosition, float CloudMask, float ShadowTerm, float3 Normal, float3 TerrainNormal )
		{
			#ifdef LOW_SPEC_SHADERS
				return Color;
			#endif

			// Calculate terrain-specific values
			float3 ToLightDir = ToTerrainSunnySunDir;
			float2 ColorMapCoords = WorldPosition * WorldSpaceToTerrain0To1;
			SShadowTintData ShadowTintData = GetShadowTintData( ColorMapCoords );

			// Calculate shadow tint mask for terrain
			float ShadowTintMask = GetTerrainShadowTintMask( ShadowTintData, ToLightDir, ShadowTerm, Normal );
			float DiffuseShadowTintMask = GetTerrainShadowTintMask( ShadowTintData, ToLightDir, ShadowTerm, TerrainNormal );

			Color = ApplySunnyShadowTintWithClouds( Color, ShadowTintData._TintColor.rgb, CloudMask, ShadowTintMask, 1.0f );

			float BlendAmount = DiffuseShadowTintMask * CloudMask;

			Color = ApplyOvercastContrast( Color, BlendAmount );

			return Color;
		}

		float3 ApplyTerrainShadowTintWithClouds( float3 Color, float2 WorldPosition, float CloudMask, float ShadowTerm )
		{
			#ifdef LOW_SPEC_SHADERS
				return Color;
			#endif

			float3 TerrainNormal = CalculateNormal( WorldPosition );
			return ApplyTerrainShadowTintWithClouds( Color, WorldPosition, CloudMask, ShadowTerm, TerrainNormal, TerrainNormal );
		}

		// Apply shadow tint for map objects using map objects lighting directions
		float3 ApplyMapObjectsShadowTintWithClouds( float3 Color, float2 ColorMapCoords, float CloudMask, float ShadowTerm, float3 ObjectNormal, float3 TerrainNormal )
		{
			#ifdef LOW_SPEC_SHADERS
				return Color;
			#endif

			// Calculate map objects-specific values
			float3 ToLightDir = ToMapObjectsSunnySunDir;

			SShadowTintData ShadowTintData = GetShadowTintData( ColorMapCoords );
			// Calculate shadow tint mask for map objects (uses both terrain and object normals)
			float ShadowTintMask = GetShadowTintMask( ShadowTintData, ToLightDir, ShadowTerm, TerrainNormal, ObjectNormal );

			return ApplySunnyShadowTintWithClouds( Color, ShadowTintData._TintColor.rgb, CloudMask, ShadowTintMask, 1.0f );
		}

		float3 ApplyTreeShadowTintWithClouds( float3 Color, SShadowTintData ShadowTintData, float CloudMask, float ShadowTerm, float3 ObjectNormal, float3 TerrainNormal )
		{
			#ifdef LOW_SPEC_SHADERS
				return Color;
			#endif

			// Calculate terrain-specific values
			float3 ToLightDir = ToTerrainSunnySunDir;
			// Calculate shadow tint mask for terrain
			float ShadowTintMask = GetShadowTintMask( ShadowTintData, ToLightDir, ShadowTerm, TerrainNormal, ObjectNormal );
			float DiffuseShadowTintMask = GetTerrainShadowTintMask( ShadowTintData, ToLightDir, ShadowTerm, TerrainNormal );

			Color = ApplySunnyShadowTintWithClouds( Color, ShadowTintData._TintColor.rgb, CloudMask, ShadowTintMask, 1.0f );

			float BlendAmount = DiffuseShadowTintMask * CloudMask;

			Color = ApplyOvercastContrast( Color, BlendAmount );

			return Color;
		}
	]]
}
