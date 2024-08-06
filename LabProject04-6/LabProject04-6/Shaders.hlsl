
cbuffer cbFrameworkInfo : register(b0)
{
	float 		gfCurrentTime;
	float		gfElapsedTime;
	float2		gf2CursorPos;
};

cbuffer cbGameObjectInfo : register(b1)
{
	matrix		gmtxWorld : packoffset(c0);
	float3		gf3ObjectColor : packoffset(c4);
};

cbuffer cbCameraInfo : register(b2)
{
	matrix		gmtxView : packoffset(c0);
	matrix		gmtxProjection : packoffset(c4);
	float3		gf3CameraPosition : packoffset(c8);
};

struct VS_INPUT
{
	float3		position : POSITION;
	float3		normal : NORMAL;
	float2		uv : TEXTURECOORD;
};

struct VS_OUTPUT
{
	float4		positionH : SV_POSITION;
	float3		positionW : POSITION;
	float3		normal : NORMAL0;
	float3		normalW : NORMAL1;
	float2		uv : TEXTURECOORD;

	float4		color : COLOR;
};

VS_OUTPUT VSPseudoLighting(VS_INPUT input)
{
	VS_OUTPUT output;

	output.positionW = mul(float4(input.position, 1.0f), gmtxWorld).xyz;
	output.positionH = mul(mul(float4(output.positionW, 1.0f), gmtxView), gmtxProjection);
	output.normalW = mul(float4(input.normal, 0.0f), gmtxWorld).xyz;
	output.normal = input.normal;
	output.uv = input.uv;

	output.color = lerp(float4(normalize(output.positionW), 1.0f), float4(normalize(output.normalW), 1.0f), 0.5f);

	return(output);
}

static float3 gf3LightDirection = float3(1.4142f, 1.4142f * 0.5f, 1.4142f * 0.5f);
static float3 gf3LightColor = float3(0.65f, 0.55f, 0.65f);
static float3 gf3SpecularColor = float3(0.35f, 0.75f, 0.75f);

static float gfSpecular = 2.0f;
static float gfGlossiness = 1.8f;

float4 PSPseudoLighting(VS_OUTPUT input) : SV_TARGET
{
	float4 cColor = input.color;

	float3 f3Normal = normalize(input.normalW);
	float fDiffused = max(0.0f, dot(f3Normal, normalize(gf3LightDirection)));
	cColor.rgb = input.color + gf3LightColor * fDiffused;

	float3 f3ToCamera = normalize(gf3CameraPosition - input.positionW);
	float3 f3Half = normalize(gf3LightDirection + f3ToCamera);
	float fHalf = max(0.0f, dot(f3Normal, f3Half));
	float fSpecular = pow(fHalf, gfSpecular * 128.0f) * gfGlossiness;
	cColor.rgb += gf3SpecularColor * fSpecular + ((f3Normal / 2.0f) + 0.5f) * 0.3f;

	return(cColor);
}
