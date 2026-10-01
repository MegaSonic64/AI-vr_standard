#ifndef BW_VR_STANDARD_BAKED_RT_INCLUDED
#define BW_VR_STANDARD_BAKED_RT_INCLUDED

#include "UnityRaytracingMeshUtils.cginc"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"

#pragma raytracing BakeHit

struct RayPayload
{
    float4 color;
    float3 dir;
};

struct AttributeData
{
    float2 barycentrics;
};

Texture2D<float4> _MainTex;
SamplerState sampler_MainTex;
Texture2D<float4> _EmissionMap;
SamplerState sampler_EmissionMap;
Texture2D<float4> _MetallicGlossMap;
SamplerState sampler_MetallicGlossMap;

CBUFFER_START(UnityPerMaterial)
float4 _MainTex_ST;
float4 _DetailAlbedoMap_ST;
half4 _Color;
half _Cutoff;
half _Glossiness;
half _AnisotropicRotation;
half _AnisotropicRatio;
half4 _SpecColor;
half g_flReflectanceMin;
half g_flReflectanceMax;
half g_flReflectanceScale;
half g_flReflectanceBias;
half _Metallic;
half _SpecMod;
half _BumpScale;
half _NormalToOcclusion;
half _Parallax;
half _ParallaxIterations;
half _ParallaxOffset;
half _OcclusionStrength;
half _OcclusionStrengthDirectDiffuse;
half _OcclusionStrengthDirectSpecular;
half _OcclusionStrengthIndirectDiffuse;
half _OcclusionStrengthIndirectSpecular;
half g_flFresnelFalloff;
half g_flFresnelExponent;
half g_flCubeMapScalar;
half4 _EmissionColor;
half _EmissionFalloff;
half4 _FluorescenceColor;
half4 _Absorbance;
half _DetailNormalMapScale;
half _UVSec;
half4 _ColorShift1;
half4 _ColorShift2;
half4 _ColorShift3;
float4 g_vWorldAlignedTextureSize;
float4 g_vWorldAlignedTextureNormal;
float4 g_vWorldAlignedTexturePosition;
float4 g_vWorldAlignedNormalTangentU;
float4 g_vWorldAlignedNormalTangentV;
int g_bUnlit;
int g_bCastShadows;
int g_bReceiveShadows;
int g_bRenderBackfaces;
int _EmissiveMode;
int g_bWorldAlignedTexture;
int _SpecularMode;
int _VertexMode;
int _PackingMode;
int _DetailMode;
half _Mode;
int _Surface;
half _FogMultiplier;
half _ColorMultiplier;
half _Test;
float _OffsetFactor;
float _OffsetUnits;
half _SSROff;
float _SSRTemporalMul;
CBUFFER_END

[shader("closesthit")]
void BWClosestHit(inout RayPayload payload, AttributeData attributes : SV_IntersectionAttributes)
{
    payload.color = float4(0,0,0,1);
    payload.dir = float3(1,0,0);

    uint primitiveIndex = PrimitiveIndex();
    uint3 tri = UnityRayTracingFetchTriangleIndices(primitiveIndex);
    float2 uv0 = UnityRayTracingFetchVertexAttribute2(tri.x, kVertexAttributeTexCoord0);
    float2 uv1 = UnityRayTracingFetchVertexAttribute2(tri.y, kVertexAttributeTexCoord0);
    float2 uv2 = UnityRayTracingFetchVertexAttribute2(tri.z, kVertexAttributeTexCoord0);
    float3 bary = float3(1.0 - attributes.barycentrics.x - attributes.barycentrics.y,
                         attributes.barycentrics.x, attributes.barycentrics.y);
    float2 uv = uv0 * bary.x + uv1 * bary.y + uv2 * bary.z;
    uv = uv * _MainTex_ST.xy + _MainTex_ST.zw;

    float3 albedo = _MainTex.SampleLevel(sampler_MainTex, uv, 0).rgb * _Color.rgb;
    float3 emission;
#if defined(S_PACKING_MAES)
    emission = _MetallicGlossMap.SampleLevel(sampler_MetallicGlossMap, uv, 0).b.xxx * _EmissionColor.rgb;
#else
    emission = _EmissionMap.SampleLevel(sampler_EmissionMap, uv, 0).rgb * _EmissionColor.rgb;
#endif
#if defined(S_EMISSIVE_MULTI)
    emission *= albedo;
#endif
#if !defined(_EMISSION)
    emission = 0;
#endif
    payload.color.rgb = emission;
}

#endif
