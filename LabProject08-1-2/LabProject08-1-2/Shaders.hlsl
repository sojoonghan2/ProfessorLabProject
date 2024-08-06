cbuffer cbPlayerInfo : register(b0)
{
	matrix		gmtxPlayerWorld : packoffset(c0);
};

cbuffer cbCameraInfo : register(b1)
{
	matrix		gmtxView : packoffset(c0);
	matrix		gmtxProjection : packoffset(c4);
};

cbuffer cbGameObjectInfo : register(b2)
{
	matrix		gmtxGameObject : packoffset(c0);
};

cbuffer cbFrameworkInfo : register(b3)
{
	float 		gfCurrentTime;
	float		gfElapsedTime;
	float2		gf2CursorPos;
};

cbuffer cbWaterInfo : register(b4)
{
	matrix		gf4x4TextureAnimation : packoffset(c0);
};

/*
cbuffer cbTerrainInfo : register(b3)
{
	float3		gf3TerrainScale : packoffset(c0);
	float2		gf2TerrainHeightMapSize : packoffset(c1);
};
*/
static float3	gf3TerrainScale = float3(8.0f, 2.0f, 8.0f);
static float2	gf2TerrainHeightMapSize = float2(257.0f, 257.0f);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
struct VS_DIFFUSED_INPUT
{
	float3 position : POSITION;
	float4 color : COLOR;
};

struct VS_DIFFUSED_OUTPUT
{
	float4 position : SV_POSITION;
	float4 color : COLOR;
};

VS_DIFFUSED_OUTPUT VSPlayer(VS_DIFFUSED_INPUT input)
{
	VS_DIFFUSED_OUTPUT output;

	output.position = mul(mul(mul(float4(input.position, 1.0f), gmtxPlayerWorld), gmtxView), gmtxProjection);
	output.color = input.color;

	return(output);
}

float4 PSPlayer(VS_DIFFUSED_OUTPUT input) : SV_TARGET
{
	return(input.color);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
Texture2D gtxtTexture : register(t0);
SamplerState gSamplerState : register(s0);

struct VS_TEXTURED_INPUT
{
	float3 position : POSITION;
	float2 uv : TEXCOORD;
};

struct VS_TEXTURED_OUTPUT
{
	float4 position : SV_POSITION;
	float2 uv : TEXCOORD;
};

VS_TEXTURED_OUTPUT VSTextured(VS_TEXTURED_INPUT input)
{
	VS_TEXTURED_OUTPUT output;

	output.position = mul(mul(mul(float4(input.position, 1.0f), gmtxGameObject), gmtxView), gmtxProjection);
	output.uv = input.uv;

	return(output);
}

float4 PSTextured(VS_TEXTURED_OUTPUT input) : SV_TARGET
{
	float4 cColor = gtxtTexture.Sample(gSamplerState, input.uv);

	return(cColor);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
Texture2D<float4> gtxtTerrainBaseTexture : register(t1);
Texture2D<float4> gtxtTerrainWaterTexture : register(t2);

#define _WITH_HEIGHT_MAP_TEXTURE

#ifdef _WITH_HEIGHT_MAP_TEXTURE
Texture2D<float> gtxtTerrainHeightMapTexture : register(t3);
#else
Buffer<float> gfTerrainHeightMapBuffer : register(t3);
#endif

struct VS_TERRAIN_INPUT
{
	float3 position : POSITION;
	float4 color : COLOR;
	float2 uv : TEXCOORD0;
};

struct VS_TERRAIN_OUTPUT
{
	float4 position : SV_POSITION;
	float4 positionW : POSITION;
	float4 color : COLOR;
	float2 uv : TEXCOORD0;
};

#ifdef _WITH_HEIGHT_MAP_TEXTURE
float GetTerrainHeight(float fx, float fz)
{
	if ((fx < 0.0f) || (fz < 0.0f) || (fx >= gf2TerrainHeightMapSize.x) || (fz >= gf2TerrainHeightMapSize.y)) return(0.0f);

	uint x = (uint)fx;
	uint z = (uint)fz;
	float fxPercent = fx - x;
	float fzPercent = fz - z;
	bool bReverseQuad = ((z % 2) != 0);

	float fBottomLeft = (float)gtxtTerrainHeightMapTexture.Load(float3(x, z, 0));
	float fBottomRight = (float)gtxtTerrainHeightMapTexture.Load(float3((x + 1), z, 0));
	float fTopLeft = (float)gtxtTerrainHeightMapTexture.Load(float3(x, (z + 1), 0));
	float fTopRight = (float)gtxtTerrainHeightMapTexture.Load(float3((x + 1), (z + 1), 0));

	if (bReverseQuad)
	{
		if (fzPercent >= fxPercent)
			fBottomRight = fBottomLeft + (fTopRight - fTopLeft);
		else
			fTopLeft = fTopRight + (fBottomLeft - fBottomRight);
	}
	else
	{
		if (fzPercent < (1.0f - fxPercent))
			fTopRight = fTopLeft + (fBottomRight - fBottomLeft);
		else
			fBottomLeft = fTopLeft + (fBottomRight - fTopRight);
	}
	float fTopHeight = fTopLeft * (1 - fxPercent) + fTopRight * fxPercent;
	float fBottomHeight = fBottomLeft * (1 - fxPercent) + fBottomRight * fxPercent;
	float fHeight = fBottomHeight * (1 - fzPercent) + fTopHeight * fzPercent;

	return(fHeight);
}
#endif

VS_TERRAIN_OUTPUT VSTerrain(VS_TERRAIN_INPUT input)
{
	VS_TERRAIN_OUTPUT output;

	float x = input.position.x / gf3TerrainScale.x;
	float z = input.position.z / gf3TerrainScale.z;
#ifdef _WITH_HEIGHT_MAP_TEXTURE
	input.position.y = GetTerrainHeight(x, z) * 255.0f * gf3TerrainScale.y;
//	input.position.y = gtxtTerrainHeightMapTexture.Load(float3(x, z, 0)) * 255.0f * gf3TerrainScale.y;
#else
	input.position.y = gfTerrainHeightMapBuffer.Load(int(x) + int(z * gf2TerrainHeightMapSize.x)) * 255.0f * gf3TerrainScale.y;
#endif

	output.positionW = mul(float4(input.position, 1.0f), gmtxGameObject);
	output.position = mul(mul(output.positionW, gmtxView), gmtxProjection);
	output.color = input.color;
	output.uv = input.uv;

	return(output);
}

#define _WITH_WATER_FOAM

float4 PSTerrain(VS_TERRAIN_OUTPUT input) : SV_TARGET
{
	float4 cBaseTexColor = gtxtTerrainBaseTexture.Sample(gSamplerState, input.uv);
	float4 cColor = input.color * cBaseTexColor;

#ifdef _WITH_WATER_FOAM
	if ((154.975f < input.positionW.y) && (input.positionW.y < 155.5f))
	{
		cColor.rgb += gtxtTerrainWaterTexture.Sample(gSamplerState, float2(input.uv.x * 50.0f, (input.positionW.y - 155.0f) / 3.0f + 0.65f)).rgb * (1.0f - (input.positionW.y - 155.0f) / 5.5f);
	}
#endif

	return(cColor);
}

struct VS_WATER_INPUT
{
	float3 position : POSITION;
	float2 uv0 : TEXCOORD0;
};

struct VS_WATER_OUTPUT
{
	float4 position : SV_POSITION;
	float2 uv0 : TEXCOORD0;
};

VS_WATER_OUTPUT VSTerrainWater(VS_WATER_INPUT input)
{
	VS_WATER_OUTPUT output;

	output.position = mul(mul(mul(float4(input.position, 1.0f), gmtxGameObject), gmtxView), gmtxProjection);
	output.uv0 = input.uv0;

	return(output);
}

Texture2D<float4> gtxtWaterBaseTexture : register(t4);
Texture2D<float4> gtxtWaterDetail0Texture : register(t5);
Texture2D<float4> gtxtWaterDetail1Texture : register(t6);

static matrix<float, 3, 3> sf3x3TextureAnimation = { { 1.0f, 0.0f, 0.0f }, { 0.0f, 1.0f, 0.0f }, { 0.0f, 0.0f, 0.0f } };

#define _WITH_TEXTURE_ANIMATION

//#define _WITH_BASE_TEXTURE_ONLY
#define _WITH_FULL_TEXTURES

#ifndef _WITH_TEXTURE_ANIMATION
float4 PSTerrainWater(VS_WATER_OUTPUT input) : SV_TARGET
{
	float4 cBaseTexColor = gtxtWaterBaseTexture.Sample(gSamplerState, input.uv);
	float4 cDetail0TexColor = gtxtWaterDetail0Texture.Sample(gSamplerState, input.uv * 20.0f);
	float4 cDetail1TexColor = gtxtWaterDetail1Texture.Sample(gSamplerState, input.uv * 20.0f);

	float4 cColor = float4(0.0f, 0.0f, 0.0f, 1.0f);
#ifdef _WITH_BASE_TEXTURE_ONLY
	cColor = cBaseTexColor;
#else
#ifdef _WITH_FULL_TEXTURES
	cColor = lerp(cBaseTexColor * cDetail0TexColor, cDetail1TexColor.r * 0.5f, 0.35f);
#else
	cColor = cBaseTexColor * cDetail0TexColor;
#endif
#endif

	return(cColor);
}
#else
#define _WITH_CONSTANT_BUFFER_MATRIX
//#define _WITH_STATIC_MATRIX

float4 PSTerrainWater(VS_WATER_OUTPUT input) : SV_TARGET
{
	float2 uv = input.uv0;

#ifdef _WITH_STATIC_MATRIX
	sf3x3TextureAnimation._m21 = gfCurrentTime * 0.00125f;
	uv = mul(float3(input.uv0, 1.0f), sf3x3TextureAnimation).xy;
#else
#ifdef _WITH_CONSTANT_BUFFER_MATRIX
	uv = mul(float3(input.uv0, 1.0f), (float3x3)gf4x4TextureAnimation).xy;
//	uv = mul(float4(uv, 1.0f, 0.0f), gf4x4TextureAnimation).xy;
#else
	uv.y += gfCurrentTime * 0.00125f;
#endif
#endif

	float4 cBaseTexColor = gtxtWaterBaseTexture.SampleLevel(gSamplerState, uv, 0);
	float4 cDetail0TexColor = gtxtWaterDetail0Texture.SampleLevel(gSamplerState, uv * 20.0f, 0);
	float4 cDetail1TexColor = gtxtWaterDetail1Texture.SampleLevel(gSamplerState, uv * 20.0f, 0);

	float4 cColor = float4(0.0f, 0.0f, 0.0f, 1.0f);
#ifdef _WITH_BASE_TEXTURE_ONLY
	cColor = cBaseTexColor;
#else
#ifdef _WITH_FULL_TEXTURES
	cColor = lerp(cBaseTexColor * cDetail0TexColor, cDetail1TexColor.r * 0.5f, 0.35f);
#else
	cColor = cBaseTexColor * cDetail0TexColor;
#endif
#endif

	return(cColor);
}
#endif

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
struct VS_RIPPLE_WATER_INPUT
{
	float3 position : POSITION;
	float4 color : COLOR;
	float2 uv0 : TEXCOORD0;
};

struct VS_RIPPLE_WATER_OUTPUT
{
	float4 position : SV_POSITION;
	float4 color : COLOR;
	float2 uv0 : TEXCOORD0;
};

VS_RIPPLE_WATER_OUTPUT VSRippleWater(VS_RIPPLE_WATER_INPUT input)
{
	VS_RIPPLE_WATER_OUTPUT output;

	//	input.position.y += sin(gfCurrentTime * 0.5f + input.position.x * 0.01f + input.position.z * 0.01f) * 35.0f;
	//	input.position.y += sin(input.position.x * 0.01f) * 45.0f + cos(input.position.z * 0.01f) * 35.0f;
	//	input.position.y += sin(gfCurrentTime * 0.5f + input.position.x * 0.01f) * 45.0f + cos(gfCurrentTime * 1.0f + input.position.z * 0.01f) * 35.0f;
	//	input.position.y += sin(gfCurrentTime * 0.5f + ((input.position.x * input.position.x) + (input.position.z * input.position.z)) * 0.01f) * 35.0f;
	//	input.position.y += sin(gfCurrentTime * 1.0f + (((input.position.x * input.position.x) + (input.position.z * input.position.z)) - (1000 * 1000) * 2) * 0.0001f) * 10.0f;

	//	input.position.y += sin(gfCurrentTime * 1.0f + (((input.position.x * input.position.x) + (input.position.z * input.position.z))) * 0.0001f) * 10.0f;
	input.position.y += sin(gfCurrentTime * 0.35f + input.position.x * 0.35f) * 2.95f + cos(gfCurrentTime * 0.30f + input.position.z * 0.35f) * 2.05f;
	output.position = mul(float4(input.position, 1.0f), gmtxGameObject);
	if (155.0f < output.position.y) output.position.y = 155.0f;
	output.position = mul(mul(output.position, gmtxView), gmtxProjection);

	//	output.color = input.color;
	output.color = (input.position.y / 200.0f) + 0.55f;
	output.uv0 = input.uv0;
	//	output.uv1 = input.uv1;

	return(output);
}

float4 PSRippleWater(VS_RIPPLE_WATER_OUTPUT input) : SV_TARGET
{
	float2 uv = input.uv0;

#ifdef _WITH_STATIC_MATRIX
	sf3x3TextureAnimation._m21 = gfCurrentTime * 0.00125f;
	uv = mul(float3(input.uv0, 1.0f), sf3x3TextureAnimation).xy;
#else
#ifdef _WITH_CONSTANT_BUFFER_MATRIX
	uv = mul(float3(input.uv0, 1.0f), (float3x3)gf4x4TextureAnimation).xy;
	//	uv = mul(float4(uv, 1.0f, 0.0f), gf4x4TextureAnimation).xy;
#else
	uv.y += gfCurrentTime * 0.00125f;
#endif
#endif

	float4 cBaseTexColor = gtxtWaterBaseTexture.SampleLevel(gSamplerState, uv, 0);
	float4 cDetail0TexColor = gtxtWaterDetail0Texture.SampleLevel(gSamplerState, uv * 10.0f, 0);
	float4 cDetail1TexColor = gtxtWaterDetail1Texture.SampleLevel(gSamplerState, uv * 5.0f, 0);

	float4 cColor = float4(0.0f, 0.0f, 0.0f, 1.0f);
	cColor = lerp(cBaseTexColor * cDetail0TexColor, cDetail1TexColor.r * 0.5f, 0.35f);

	return(cColor);
}

