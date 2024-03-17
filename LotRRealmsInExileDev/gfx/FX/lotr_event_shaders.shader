# adapted from https://github.com/dementive/JominiGuiPixelShaders

Includes = {
	"cw/pdxgui.fxh"
	"cw/pdxgui_sprite.fxh"
	"standardfuncsgfx.fxh"
}

VertexShader =
{
	MainCode VS_Default
	{
		Input = "VS_INPUT_PDX_GUI"
		Output = "VS_OUTPUT_PDX_GUI"
		Code
		[[
			PDX_MAIN
			{
				return PdxGuiDefaultVertexShader( Input );
			}
		]]
	}
}

PixelShader =
{
	TextureSampler Texture
	{
		Ref = PdxTexture0
		MagFilter = "Point"
		MinFilter = "Point"
		MipFilter = "Point"
		SampleModeU = "Clamp"
		SampleModeV = "Clamp"
	}
	MainCode PS_Default
	{	
		Input = "VS_OUTPUT_PDX_GUI"
		Output = "PDX_COLOR"
		Code
		[[
			PDX_MAIN
			{
				float4 OutColor = SampleImageSprite( Texture, Input.UV0 );
				OutColor *= Input.Color;
				
				#ifdef DISABLED
					OutColor.rgb = DisableColor( OutColor.rgb );
				#endif
				
			    return OutColor;
			}
		]]
	}
	MainCode PS_Sparks
	{	
		Input = "VS_OUTPUT_PDX_GUI"
		Output = "PDX_COLOR"
		Code
		[[
			// adapted from https://www.shadertoy.com/view/wl2Gzc
			//Shader License: CC BY 3.0
			//Author: Jan Mróz (jaszunio15)

			// ********************

			// Sparks moving right-to-left
			#define MOVEMENT_DIRECTION float2(1.0, -0.7)
			#define PARTICLE_SCALE (float2(1.6, 0.5))
			#define PARTICLE_SCALE_VAR (float2(0.2, 0.25))
			#define PARTICLE_BLOOM_SCALE (float2(0.8, 0.5))
			#define PARTICLE_BLOOM_SCALE_VAR (float2(0.1, 0.3))

			// Sparks moving left-to-right
			//#define MOVEMENT_DIRECTION float2(-1.0, -0.7)
			//#define PARTICLE_SCALE (float2(0.5, 1.6))
			//#define PARTICLE_SCALE_VAR (float2(0.25, 0.2))
			//#define PARTICLE_BLOOM_SCALE (float2(0.5, 0.8))
			//#define PARTICLE_BLOOM_SCALE_VAR (float2(0.3, 0.1))

			// ********************

			#define TWO_PI 6.283185

			#define ANIMATION_SPEED 1.5
			#define MOVEMENT_SPEED 0.7

			#define PARTICLE_SIZE 0.005

			#define SPARK_COLOR float3(1.0, 0.4, 0.05) * 1.5
			#define BLOOM_COLOR float3(1.0, 0.4, 0.05) * 0.8
			#define SMOKE_COLOR float3(0.8, 0.7, 0.7) * 1.0

			#define SIZE_MOD 1.08
			#define ALPHA_MOD 0.9
			#define LAYERS_COUNT 15

			float hash1_2(in float2 x)
			{
				float d = dot(x, float2(52.127, 61.2871));
				return frac(sin(d) * 521.582);   
			}

			float2 hash2_2(in float2 x)
			{
				float2 m = mul(x, float2x2(20.52, 24.1994, 70.291, 80.171));
				float2 s = float2(sin(m.x),sin(m.y));
				return frac(s * 492.194);
			}

			//Simple interpolated noise
			float2 noise2_2(float2 uv)
			{
				//float2 f = frac(uv);
				float2 f = smoothstep(0.0, 1.0, frac(uv));
				
				float2 uv00 = floor(uv);
				float2 uv01 = uv00 + float2(0,1);
				float2 uv10 = uv00 + float2(1,0);
				float2 uv11 = uv00 + 1.0;
				float2 v00 = hash2_2(uv00);
				float2 v01 = hash2_2(uv01);
				float2 v10 = hash2_2(uv10);
				float2 v11 = hash2_2(uv11);
				
				float2 v0 = lerp(v00, v01, f.y);
				float2 v1 = lerp(v10, v11, f.y);
				float2 v = lerp(v0, v1, f.x);
				
				return v;
			}

			//Simple interpolated noise
			float noise1_2(in float2 uv)
			{
				float2 f = frac(uv);
				//float2 f = smoothstep(0.0, 1.0, frac(uv));
				
				float2 uv00 = floor(uv);
				float2 uv01 = uv00 + float2(0,1);
				float2 uv10 = uv00 + float2(1,0);
				float2 uv11 = uv00 + 1.0;
				
				float v00 = hash1_2(uv00);
				float v01 = hash1_2(uv01);
				float v10 = hash1_2(uv10);
				float v11 = hash1_2(uv11);
				
				float v0 = lerp(v00, v01, f.y);
				float v1 = lerp(v10, v11, f.y);
				float v = lerp(v0, v1, f.x);
				
				return v;
			}

			float layeredNoise1_2(in float2 uv, in float sizeMod, in float alphaMod, in int layers, in float animation)
			{
				float noise = 0.0;
				float alpha = 1.0;
				float size = 1.0;
				float2 offset;
				for (int i = 0; i < layers; i++)
				{
					offset += hash2_2(float2(alpha, size)) * 10.0;
					
					//Adding noise with movement
					noise += noise1_2(uv * size + GlobalTime * animation * 8.0 * MOVEMENT_DIRECTION * MOVEMENT_SPEED + offset) * alpha;
					alpha *= alphaMod;
					size *= sizeMod;
				}
				
				noise *= (1.0 - alphaMod)/(1.0 - pow(alphaMod, float(layers)));
				return noise;
			}

			//Rotates point around 0,0
			float2 rotate(in float2 coord, in float deg)
			{
				float s = sin(deg);
				float c = cos(deg);
				return mul(float2x2(s, c, -c, s), coord);
			}

			//Cell center from point on the grid
			float2 voronoiPointFromRoot(in float2 root, in float deg)
			{
				float2 coord = hash2_2(root) - 0.5;
				float s = sin(deg);
				float c = cos(deg);
				coord = mul(float2x2(s, c, -c, s), coord) * 0.66;
				coord += root + 0.5;
				return coord;
			}

			//Voronoi cell point rotation degrees
			float degFromRootUV(in float2 uv)
			{
				return GlobalTime * ANIMATION_SPEED * (hash1_2(uv) - 0.5) * 2.0;   
			}

			float2 randomAround2_2(in float2 coord, in float2 range, in float2 uv)
			{
				return coord + (hash2_2(uv) - 0.5) * range;
			}


			float3 fireParticles(in float2 uv, in float2 originalUV)
			{
				float3 particles = float3(0.0,0.0,0.0);
				float2 rootUV = floor(uv);
				float deg = degFromRootUV(rootUV);
				float2 pointUV = voronoiPointFromRoot(rootUV, deg);
				float dist = 2.0;
				float distBloom = 0.0;
			
				//UV manipulation for the faster particle movement
				float2 tempUV = uv + (noise2_2(uv * 2.0) - 0.5) * 0.1;
				tempUV += -(noise2_2(uv * 3.0 + GlobalTime) - 0.5) * 0.07;

				//Sparks sdf
				dist = length(rotate(tempUV - pointUV, 0.7) * randomAround2_2(PARTICLE_SCALE, PARTICLE_SCALE_VAR, rootUV));
				
				//Bloom sdf
				distBloom = length(rotate(tempUV - pointUV, 0.7) * randomAround2_2(PARTICLE_BLOOM_SCALE, PARTICLE_BLOOM_SCALE_VAR, rootUV));

				//Add sparks
				particles += (1.0 - smoothstep(PARTICLE_SIZE * 0.6, PARTICLE_SIZE * 3.0, dist)) * SPARK_COLOR;
				
				//Add bloom
				particles += pow((1.0 - smoothstep(0.0, PARTICLE_SIZE * 6.0, distBloom)) * 1.0, 3.0) * BLOOM_COLOR;

				//Upper disappear curve randomization
				float border = (hash1_2(rootUV) - 0.5) * 2.0;
				float disappear = 1.0 - smoothstep(border, border + 0.5, originalUV.y);
				
				//Lower appear curve randomization
				border = (hash1_2(rootUV + 0.214) - 1.8) * 0.7;
				float appear = smoothstep(border, border + 0.4, originalUV.y);
				
				return particles * disappear * appear;
			}


			//Layering particles to imitate 3D view
			float3 layeredParticles(in float2 uv, in float sizeMod, in float alphaMod, in int layers, in float smoke) 
			{ 
				float3 particles = float3(0.0,0.0,0.0);
				float size = 1.0;
				float alpha = 1.0;
				float2 offset = float2(0.0,0.0);
				float2 noiseOffset;
				float2 bokehUV;
				
				for (int i = 0; i < layers; i++)
				{
					//Particle noise movement
					noiseOffset = (noise2_2(uv * size * 2.0 + 0.5) - 0.5) * 0.15;
					
					//UV with applied movement
					bokehUV = (uv * size + GlobalTime * MOVEMENT_DIRECTION * MOVEMENT_SPEED) + offset + noiseOffset; 
					
					//Adding particles								if there is more smoke, remove smaller particles
					particles += fireParticles(bokehUV, uv) * alpha * (1.0 - smoothstep(0.0, 1.0, smoke) * (float(i) / float(layers)));
					
					//Moving uv origin to avoid generating the same particles
					offset += hash2_2(float2(alpha, alpha)) * 10.0;
					
					alpha *= alphaMod;
					size *= sizeMod;
				}
				
				return particles;
			}

			PDX_MAIN
			{
				float2 uv = Input.UV0;

				float2 TextureSize;
				PdxTex2DSize(Texture, TextureSize);

				uv = float2(uv.x,0.5-uv.y);

				uv.x *= TextureSize.x / TextureSize.y;
				
				//float vignette = 1.0 - smoothstep(0.4, 1.4, length(uv + float2(0.0, 0.3)));
				
				uv *= 1.8;
				
				float smokeIntensity = layeredNoise1_2(uv * 10.0 + GlobalTime * 4.0 * MOVEMENT_DIRECTION * MOVEMENT_SPEED, 1.7, 0.7, 6, 0.2);
				smokeIntensity *= pow(1.0 - smoothstep(-1.0, 1.6, uv.y), 2.0); 
				float3 smoke = smokeIntensity * SMOKE_COLOR * 0.8;
				//float3 smoke = smokeIntensity * SMOKE_COLOR * 0.8 * vignette;
				
				//Cutting holes in smoke
				smoke *= pow(layeredNoise1_2(uv * 4.0 + GlobalTime * 0.5 * MOVEMENT_DIRECTION * MOVEMENT_SPEED, 1.8, 0.5, 3, 0.2), 2.0) * 1.5;
				
				float3 particles = layeredParticles(uv, SIZE_MOD, ALPHA_MOD, LAYERS_COUNT, smokeIntensity);
				
				float3 col = particles + smoke + SMOKE_COLOR * 0.02;
				//col *= vignette;
				
				col = smoothstep(-0.08, 1.0, col);

				float alpha = SampleImageSprite(Texture,Input.UV0).a * col.r;

				return float4(col, alpha);
			}
		]]
	}
	MainCode PS_Fire
	{	
		Input = "VS_OUTPUT_PDX_GUI"
		Output = "PDX_COLOR"
		Code
		[[
			// adapted from https://www.shadertoy.com/view/MlKSWm

			//
			// Description : Array and textureless GLSL 2D/3D/4D simplex 
			//							 noise functions.
			//			Author : Ian McEwan, Ashima Arts.
			//	Maintainer : ijm
			//		 Lastmod : 20110822 (ijm)
			//		 License : Copyright (C) 2011 Ashima Arts. All rights reserved.
			//							 Distributed under the MIT License. See LICENSE file.
			//							 https://github.com/ashima/webgl-noise
			// 
 
			#define SPEED 0.7

			#define CLIP 410.0
			#define XFUELPOW 0.5
			#define FLAMESMOD1 0.3
			#define FLAMESMOD2 0.3

			float3 mod289(float3 x) {
				return x - floor(x * (1.0 / 289.0)) * 289.0;
			}

			float4 mod289(float4 x) {
				return x - floor(x * (1.0 / 289.0)) * 289.0;
			}

			float4 permute(float4 x) {
					return mod289(((x*34.0)+1.0)*x);
			}

			float4 taylorInvSqrt(float4 r)
			{
				return 1.79284291400159 - 0.85373472095314 * r;
			}

			float snoise(float3 v)
				{ 
				const float2	C = float2(1.0/6.0, 1.0/3.0) ;
				const float4	D = float4(0.0, 0.5, 1.0, 2.0);

			// First corner
				float3 i	= floor(v + dot(v, C.yyy) );
				float3 x0 	=	 v - i + dot(i, C.xxx) ;

			// Other corners
				float3 g = step(x0.yzx, x0.xyz);
				float3 l = 1.0 - g;
				float3 i1 = min( g.xyz, l.zxy );
				float3 i2 = max( g.xyz, l.zxy );

				//	 x0 = x0 - 0.0 + 0.0 * C.xxx;
				//	 x1 = x0 - i1	+ 1.0 * C.xxx;
				//	 x2 = x0 - i2	+ 2.0 * C.xxx;
				//	 x3 = x0 - 1.0 + 3.0 * C.xxx;
				float3 x1 = x0 - i1 + C.xxx;
				float3 x2 = x0 - i2 + C.yyy; // 2.0*C.x = 1/3 = C.y
				float3 x3 = x0 - D.yyy;			// -1.0+3.0*C.x = -0.5 = -D.y

			// Permutations
				i = mod289(i); 
				float4 p = permute( permute( permute( 
									i.z + float4(0.0, i1.z, i2.z, 1.0 ))
								+ i.y + float4(0.0, i1.y, i2.y, 1.0 )) 
								+ i.x + float4(0.0, i1.x, i2.x, 1.0 ));

			// Gradients: 7x7 points over a square, mapped onto an octahedron.
			// The ring size 17*17 = 289 is close to a multiple of 49 (49*6 = 294)
				float n_ = 0.142857142857; // 1.0/7.0
				float3	ns = n_ * D.wyz - D.xzx;

				float4 j = p - 49.0 * floor(p * ns.z * ns.z);	//	mod(p,7*7)

				float4 x_ = floor(j * ns.z);
				float4 y_ = floor(j - 7.0 * x_ );		// mod(j,N)

				float4 x = x_ *ns.x + ns.yyyy;
				float4 y = y_ *ns.x + ns.yyyy;
				float4 h = 1.0 - abs(x) - abs(y);

				float4 b0 = float4( x.xy, y.xy );
				float4 b1 = float4( x.zw, y.zw );

				//float4 s0 = float4(lessThan(b0,0.0))*2.0 - 1.0;
				//float4 s1 = float4(lessThan(b1,0.0))*2.0 - 1.0;
				float4 s0 = floor(b0)*2.0 + 1.0;
				float4 s1 = floor(b1)*2.0 + 1.0;
				float4 sh = -step(h, float4(0.0,0.0,0.0,0.0));

				float4 a0 = b0.xzyw + s0.xzyw*sh.xxyy ;
				float4 a1 = b1.xzyw + s1.xzyw*sh.zzww ;

				float3 p0 = float3(a0.xy,h.x);
				float3 p1 = float3(a0.zw,h.y);
				float3 p2 = float3(a1.xy,h.z);
				float3 p3 = float3(a1.zw,h.w);

			//Normalise gradients
				//float4 norm = taylorInvSqrt(float4(dot(p0,p0), dot(p1,p1), dot(p2, p2), dot(p3,p3)));
				float4 norm = rsqrt(float4(dot(p0,p0), dot(p1,p1), dot(p2, p2), dot(p3,p3)));
				p0 *= norm.x;
				p1 *= norm.y;
				p2 *= norm.z;
				p3 *= norm.w;

			// Mix final noise value
				float4 m = max(0.6 - float4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
				m = m * m;
				return 42.0 * dot( m*m, float4( dot(p0,x0), dot(p1,x1), dot(p2,x2), dot(p3,x3) ) );
				}

			//////////////////////////////////////////////////////////////

			// PRNG
			// From https://www.shadertoy.com/view/4djSRW
			float prng(in float2 seed) {
				seed = frac(seed * float2 (5.3983, 5.4427));
				seed += dot (seed.yx, seed.xy + float2 (21.5351, 14.3137));
				return frac(seed.x * seed.y * 95.4337);
			}

			//////////////////////////////////////////////////////////////

			float noiseStack(float3 pos,int octaves,float falloff){
				float noise = snoise(float3(pos));
				float off = 1.0;
				if (octaves>1) {
					pos *= 2.0;
					off *= falloff;
					noise = (1.0-off)*noise + off*snoise(float3(pos));
				}
				if (octaves>2) {
					pos *= 2.0;
					off *= falloff;
					noise = (1.0-off)*noise + off*snoise(float3(pos));
				}
				if (octaves>3) {
					pos *= 2.0;
					off *= falloff;
					noise = (1.0-off)*noise + off*snoise(float3(pos));
				}
				return (1.0+noise)/2.0;
			}

			float2 noiseStackUV(float3 pos,int octaves,float falloff,float diff){
				float displaceA = noiseStack(pos,octaves,falloff);
				float displaceB = noiseStack(pos+float3(3984.293,423.21,5235.19),octaves,falloff);
				return float2(displaceA,displaceB);
			}

			PDX_MAIN
			{
				float time = GlobalTime;
				float2 uv = Input.UV0;
				uv.y = 1.0 - uv.y;

				float2 TextureSize;
				PdxTex2DSize(Texture, TextureSize);
				
				//uv.x *= 0.95;
				//uv.x *= TextureSize.x / TextureSize.y;

				float2 fragPosition = uv * TextureSize;
				//
				float xpart = uv.x;
				float ypart = uv.y;
				//
				float clip = CLIP;
				//float clip = 210.0;
				float ypartClip = fragPosition.y/clip;
				float ypartClippedFalloff = clamp(2.0-ypartClip,0.0,1.0);
				float ypartClipped = min(ypartClip,1.0);
				float ypartClippedn = 1.0-ypartClipped;
				//
				float xfuel = pow(xpart+0.2,XFUELPOW);
				//float xfuel = pow(1.5-abs(2.0*xpart-1.0),XFUELPOW);
				//float xfuel = pow(1.0-abs(2.0*xpart-1.0),XFUELPOW);
				//float xfuel = 1.0-abs(2.0*xpart-1.0);//pow(1.0-abs(2.0*xpart-1.0),0.5);
				//
				float timeSpeed = SPEED;
				float realTime = timeSpeed*time;
				//
				float2 coordScaled = 0.01*fragPosition;
				float3 position = float3(coordScaled,0.0);
				//float3 position = float3(coordScaled,0.0) + float3(1223.0,6434.0,8425.0);
				float3 flow = float3(4.1*(0.5-xpart)*pow(ypartClippedn,4.0),-2.0*xfuel*pow(ypartClippedn,64.0),0.0);
				float3 timing = realTime*float3(0.0,-1.7,1.1) + flow;
				//
				float3 displacePos = float3(1.0,0.5,1.0)*2.4*position+realTime*float3(0.01,-0.7,1.3);
				float3 displace3 = float3(noiseStackUV(displacePos,2,0.4,0.1),0.0);
				//
				float3 noiseCoord = (float3(2.0,1.0,1.0)*position+timing+0.4*displace3)/1.0;
				float noise = noiseStack(noiseCoord,3,0.4);
				//
				float flames = pow(ypartClipped,FLAMESMOD1*xfuel)*pow(noise,FLAMESMOD2*xfuel);
				//
				float f = ypartClippedFalloff*pow(1.0-flames*flames*flames,8.0);
				float fff = f*f*f;
				float3 fire = 1.5*float3(f, fff, fff*fff);
				//
				// smoke
				float smokeNoise = 0.5+snoise(0.4*position+timing*float3(1.0,1.0,0.2))/2.0;
				float smokeScalar = 0.3*pow(xfuel,3.0)*pow(ypart,2.0)*(smokeNoise+0.4*(1.0-noise));
				float3 smoke = float3(smokeScalar,smokeScalar,smokeScalar);
				//
				// sparks
				float sparkGridSize = 30.0;
				float2 sparkCoord = fragPosition;
				sparkCoord -= 30.0*noiseStackUV(0.01*float3(sparkCoord,30.0*time),1,0.4,0.1);
				sparkCoord += 100.0*flow.xy;
				if (mod(sparkCoord.y/sparkGridSize,2.0)<1.0) sparkCoord.x += 0.5*sparkGridSize;
				float2 sparkGridIndex = float2(floor(sparkCoord/sparkGridSize));
				float sparkRandom = prng(sparkGridIndex);
				float sparkLife = min(10.0*(1.0-min((sparkGridIndex.y+(190.0*realTime/sparkGridSize))/(24.0-20.0*sparkRandom),1.0)),1.0);
				float3 sparks = float3(0.0,0.0,0.0);
				if (sparkLife>0.0) {
					float sparkSize = xfuel*xfuel*sparkRandom*0.08;
					float sparkRadians = 999.0*sparkRandom*2.0*PI + 2.0*time;
					float2 sparkCircular = float2(sin(sparkRadians),cos(sparkRadians));
					float2 sparkOffset = (0.5-sparkSize)*sparkGridSize*sparkCircular;
					float2 sparkModulus = mod(sparkCoord+sparkOffset,sparkGridSize) - 0.5*float2(sparkGridSize,sparkGridSize);
					float sparkLength = length(sparkModulus);
					float sparksGray = max(0.0, 1.0 - sparkLength/(sparkSize*sparkGridSize));
					sparks = sparkLife*sparksGray*float3(1.0,0.3,0.0);
				}
				//
				float3 color = max(fire,sparks) + smoke;
				float alpha = SampleImageSprite(Texture,Input.UV0).a * color.r;
				return float4(color, alpha);
			}
		]]
	}
	MainCode PS_Snow
	{	
		Input = "VS_OUTPUT_PDX_GUI"
		Output = "PDX_COLOR"
		Code
		[[
			// adapted from https://www.shadertoy.com/view/Mdt3Df
			
			#define SIZE_MOD 3.5

			PDX_MAIN
			{
				float2 uv = Input.UV0;
				uv.y = 1.0 - uv.y;
				
				float2 TextureSize;
				PdxTex2DSize(Texture, TextureSize);

				float2 coord = float2(uv.x * TextureSize.x, uv.y * TextureSize.y);
				coord.x *= TextureSize.x / TextureSize.y;
				float time = GlobalTime;

				float snow = 0.0;
				float random = frac(sin(dot(coord.xy,float2(12.9898,78.233)))* 43758.5453);

				for(int k=0;k<6;k++){
					for(int i=0;i<12;i++){
						float cellSize = 2.0 + (float(i)*3.0);
						float downSpeed = 0.3+(sin(time*0.4+float(k+i*20))+1.0)*0.00008;
						float2 snowUV = (coord.xy / TextureSize.x)+float2(0.01*sin((time+float(k*6185))*0.6+float(i))*(5.0/float(i)),downSpeed*(time+float(k*1352))*(1.0/float(i)));
						float2 uvStep = (ceil((snowUV)*cellSize-float2(0.5,0.5))/cellSize);
						float x = frac(sin(dot(uvStep.xy,float2(12.9898+float(k)*12.0,78.233+float(k)*315.156)))* 43758.5453+float(k)*12.0)-0.5;
						float y = frac(sin(dot(uvStep.xy,float2(62.2364+float(k)*23.0,94.674+float(k)*95.0)))* 62159.8432+float(k)*12.0)-0.5;

						float randomMagnitude1 = sin(time*2.5)*0.7/cellSize;
						float randomMagnitude2 = cos(time*2.5)*0.7/cellSize;

						float d = SIZE_MOD*distance((uvStep.xy + float2(x*sin(y),y)*randomMagnitude1 + float2(y,x)*randomMagnitude2),snowUV.xy);

						float omiVal = frac(sin(dot(uvStep.xy,float2(32.4691,94.615)))* 31572.1684);
						if(omiVal<0.08){
							float newd = (x+1.0)*0.4*clamp(1.9-d*(15.0+(x*6.3))*(cellSize/1.4),0.0,1.0);
							snow += newd;
						}
					}
				}
				
				float alpha = SampleImageSprite(Texture,Input.UV0).a * snow;
				float3 col = float3(1.,1.,1.);
				return float4(col,alpha);
			}
		]]
	}
}

# SampleImageSprite( Texture, Input.UV0 );

BlendState BlendState
{
	BlendEnable = yes
	SourceBlend = "SRC_ALPHA"
	DestBlend = "INV_SRC_ALPHA"
}

BlendState BlendStateNoAlpha
{
	BlendEnable = no
}

BlendState PreMultipliedAlpha
{
	BlendEnable = yes
	SourceBlend = "ONE"
	DestBlend = "INV_SRC_ALPHA"
}

DepthStencilState DepthStencilState
{
	DepthEnable = no
}

Effect PdxGuiDefault
{
	VertexShader = "VS_Default"
	PixelShader = "PS_Default"
}
Effect PdxGuiDefaultDisabled
{
	VertexShader = "VS_Default"
	PixelShader = "PS_Default"
	
	Defines = { "DISABLED" }
}

Effect PdxGuiDefaultNoAlpha
{
	VertexShader = "VS_Default"
	PixelShader = "PS_Default"
	BlendState = BlendStateNoAlpha
}
Effect PdxGuiDefaultNoAlphaDisabled
{
	VertexShader = "VS_Default"
	PixelShader = "PS_Default"
	BlendState = BlendStateNoAlpha
	
	Defines = { "DISABLED" }
}

Effect PdxGuiPreMultipliedAlpha
{
	VertexShader = "VS_Default"
	PixelShader = "PS_Default"
	BlendState = PreMultipliedAlpha
}
Effect PdxGuiPreMultipliedAlphaDisabled
{
	VertexShader = "VS_Default"
	PixelShader = "PS_Default"
	BlendState = PreMultipliedAlpha
	
	Defines = { "DISABLED" }
}

Effect Sparks
{
	VertexShader = "VS_Default"
	PixelShader = "PS_Sparks"
}
Effect SparksDisabled
{
	VertexShader = "VS_Default"
	PixelShader = "PS_Sparks"
	
	Defines = { "DISABLED" }
}

Effect Fire
{
	VertexShader = "VS_Default"
	PixelShader = "PS_Fire"
}
Effect FireDisabled
{
	VertexShader = "VS_Default"
	PixelShader = "PS_Fire"
	
	Defines = { "DISABLED" }
}

Effect Snow
{
	VertexShader = "VS_Default"
	PixelShader = "PS_Snow"
}
Effect SnowDisabled
{
	VertexShader = "VS_Default"
	PixelShader = "PS_Snow"
	
	Defines = { "DISABLED" }
}