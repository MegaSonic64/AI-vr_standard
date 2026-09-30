#ifndef BW_VR_STANDARD_COMMON_INCLUDED
#define BW_VR_STANDARD_COMMON_INCLUDED

// Core must be the first rendering include on this SLZ/Core 8148 build.
// Some Core library files (notably Packing.hlsl) use `real*` aliases immediately.
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"
// We provide BONEWORKS baked specular ourselves; avoid calculating and discarding SLZ's default lobe.
#define _SLZ_DISABLE_BAKED_SPEC 1
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SLZLighting.hlsl"


// UnityCG.cginc exposed this in the Built-in RP, but URP does not.
// Keep BONEWORKS Detail Multiply2x numerically identical to Unity Standard.
#if defined(UNITY_COLORSPACE_GAMMA)
    #define BW_COLORSPACE_DOUBLE_RGB half3(2.0h, 2.0h, 2.0h)
#else
    #define BW_COLORSPACE_DOUBLE_RGB half3(4.59479380h, 4.59479380h, 4.59479380h)
#endif

#if defined(_DETAIL_MULX2) || defined(_DETAIL_MUL) || defined(_DETAIL_ADD) || defined(_DETAIL_LERP)
    #define BW_DETAIL_ON 1
#endif

TEXTURE2D(_MainTex);                 SAMPLER(sampler_MainTex);
TEXTURE2D(_BumpMap);                 SAMPLER(sampler_BumpMap);
TEXTURE2D(_SpecGlossMap);            SAMPLER(sampler_SpecGlossMap);
TEXTURE2D(_MetallicGlossMap);        SAMPLER(sampler_MetallicGlossMap);
TEXTURE2D(_OcclusionMap);            SAMPLER(sampler_OcclusionMap);
TEXTURE2D(_ParallaxMap);             SAMPLER(sampler_ParallaxMap);
TEXTURE2D(_EmissionMap);             SAMPLER(sampler_EmissionMap);
TEXTURE2D(_FluorescenceMap);         SAMPLER(sampler_FluorescenceMap);
TEXTURE2D(_DetailMask);              SAMPLER(sampler_DetailMask);
TEXTURE2D(_DetailAlbedoMap);         SAMPLER(sampler_DetailAlbedoMap);
TEXTURE2D(_DetailNormalMap);         SAMPLER(sampler_DetailNormalMap);
TEXTURE2D(_ColorMask);               SAMPLER(sampler_ColorMask);

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

inline half BW_LerpOneTo(half value, half strength)
{
    return lerp(half(1.0), value, saturate(strength));
}

inline half3 BW_SafeNormalize(half3 v)
{
    return SLZSafeHalf3Normalize(v);
}

inline half4 BW_ScreenSpaceDither(float2 screenPos)
{
    // Keep the screen-space hash in FP32. On Vulkan, `half` may be true FP16;
    // dot(171,231) against pixel-space SV_POSITION easily exceeds 65504,
    // producing INF -> frac(INF) -> NaN and black/invalid fragments over most
    // of the screen. Only narrow low-coordinate regions (typically bottom-left)
    // survive, which matches the observed Vulkan failure exactly.
    float hash = dot(float2(171.0, 231.0), screenPos + _Time.y.xx);
    float3 dither = frac(hash.xxx / float3(103.0, 71.0, 97.0)) - float3(0.5, 0.5, 0.5);
    return (half4)float4(dither.r, dither.g, dither.b, dither.r) * (half(0.375) / half(255.0));
}

inline float2 BW_WorldAlignedUV(float3 positionWS)
{
    float3 size = g_vWorldAlignedTextureSize.xyz;
    float3 safeSize = sign(size) * max(abs(size), float3(1e-5, 1e-5, 1e-5));
    // sign(0) is 0, so explicitly choose positive epsilon for zero components.
    safeSize = lerp(float3(1e-5, 1e-5, 1e-5), safeSize, step(float3(1e-8,1e-8,1e-8), abs(size)));
    float3 scaled = (positionWS - g_vWorldAlignedTexturePosition.xyz) / safeSize;
    return float2(dot(scaled, g_vWorldAlignedNormalTangentU.xyz), dot(scaled, g_vWorldAlignedNormalTangentV.xyz));
}

inline float2 BW_BaseUV(float2 uv0, float3 positionWS)
{
#if defined(S_WORLD_ALIGNED_TEXTURE)
    return BW_WorldAlignedUV(positionWS);
#else
    return uv0 * _MainTex_ST.xy + _MainTex_ST.zw;
#endif
}

inline float2 BW_DetailUV(float2 uv0, float2 uv1, float2 baseUV, float3 positionWS)
{
#if defined(S_WORLD_ALIGNED_TEXTURE)
    return baseUV * _DetailAlbedoMap_ST.xy + _DetailAlbedoMap_ST.zw;
#else
    float2 sourceUV = (_UVSec < 0.5h) ? uv0 : uv1;
    return sourceUV * _DetailAlbedoMap_ST.xy + _DetailAlbedoMap_ST.zw;
#endif
}

inline half BW_DetailMask(float2 baseUV)
{
    return SAMPLE_TEXTURE2D(_DetailMask, sampler_DetailMask, baseUV).a;
}

inline float2 BW_ParallaxUV(float2 uv, half3 viewDirTS)
{
#if defined(_PARALLAXMAP) && !defined(SHADER_API_MOBILE)
    // BONEWORKS' original helper chain has a parameter-order quirk, but its
    // effective projection is the standard tangent-space parallax vector:
    // (T dot V, B dot V) / (N dot V).
    float denom = abs(viewDirTS.z) > 1e-4 ? viewDirTS.z : (viewDirTS.z >= 0 ? 1e-4 : -1e-4);
    float2 plane = viewDirTS.xy / denom;
    int iterations = clamp((int)round(_ParallaxIterations), 1, 32);
    float scale = _Parallax / iterations;
    [loop]
    for (int p = 0; p < iterations; ++p)
    {
        half height = half(1.0) - SAMPLE_TEXTURE2D(_ParallaxMap, sampler_ParallaxMap, uv).b;
        half h = height * scale + _ParallaxOffset;
        uv += (h * height) * plane;
    }
#endif
    return uv;
}

inline void BW_AlbedoSpecularFromMetallic(inout half3 albedo, half metallic, out half3 specColor)
{
    half oneMinusReflectivity = OneMinusReflectivityMetallic(metallic);
    specColor = lerp(kDielectricSpec.rgb, albedo, metallic);
    albedo *= oneMinusReflectivity;
}

inline half3 BW_ApplyDetailAlbedo(half3 albedo, float2 baseUV, float2 detailUV)
{
#if defined(BW_DETAIL_ON)
    half mask = BW_DetailMask(baseUV);
    half3 detail = SAMPLE_TEXTURE2D(_DetailAlbedoMap, sampler_DetailAlbedoMap, detailUV).rgb;
    #if defined(_DETAIL_MULX2)
        albedo *= lerp(half3(1,1,1), detail * BW_COLORSPACE_DOUBLE_RGB, mask);
    #elif defined(_DETAIL_MUL)
        albedo *= lerp(half3(1,1,1), detail, mask);
    #elif defined(_DETAIL_ADD)
        albedo += detail * mask;
    #elif defined(_DETAIL_LERP)
        albedo = lerp(albedo, detail, mask);
    #endif
#endif
    return albedo;
}

inline half3 BW_ApplyDetailNormal(half3 normalTS, float2 baseUV, float2 detailUV)
{
#if defined(BW_DETAIL_ON) && defined(_NORMALMAP)
    half mask = BW_DetailMask(baseUV);
    half3 detailTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_DetailNormalMap, sampler_DetailNormalMap, detailUV), _DetailNormalMapScale);
    #if defined(_DETAIL_LERP)
        normalTS = normalize(lerp(normalTS, detailTS, mask));
    #else
        normalTS = normalize(lerp(normalTS, BlendNormal(normalTS, detailTS), mask));
    #endif
#endif
    return normalTS;
}

inline half3 BW_ApplyColorShift(half3 color, float2 uv)
{
#if defined(_COLORSHIFT)
    half3 mask = half3(1,1,1) - SAMPLE_TEXTURE2D(_ColorMask, sampler_ColorMask, uv).rgb;
    half3 shifter = max(_ColorShift1.rgb, mask.rrr) * max(_ColorShift2.rgb, mask.ggg) * max(_ColorShift3.rgb, mask.bbb);
    color *= shifter;
#endif
    return color;
}

inline half3 BW_Emission(float2 uv, half packedEmission, half3 albedoPreMetal, half NoV)
{
#if !defined(_EMISSION)
    return half3(0,0,0);
#else
    half3 emission;
    #if defined(S_PACKING_MAES)
        emission = packedEmission.xxx * _EmissionColor.rgb;
    #else
        emission = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, uv).rgb * _EmissionColor.rgb;
    #endif
    #if !defined(S_UNLIT)
        emission *= saturate(pow(saturate(NoV), _EmissionFalloff * half(2.0)));
    #endif
    #if defined(S_EMISSIVE_MULTI)
        emission *= albedoPreMetal;
    #endif
    return emission;
#endif
}

inline half3 BW_BakedEmission(float2 uv, half packedEmission, half3 albedo)
{
    half4 emissionTex;
#if defined(S_PACKING_MAES)
    emissionTex = half4(packedEmission.xxx, 0);
#else
    emissionTex = SAMPLE_TEXTURE2D_LOD(_EmissionMap, sampler_EmissionMap, uv, 0);
#endif
    half3 emission = emissionTex.rgb * _EmissionColor.rgb;
#if defined(S_EMISSIVE_MULTI)
    emission *= albedo;
#endif
    return emission;
}

inline half BW_ProjectedSpecAA(half perceptualRoughness, half3 geometricNormalWS)
{
#if !defined(SHADER_API_MOBILE)
    float3 dNdx = ddx_fine((float3)geometricNormalWS);
    float3 dNdy = ddy_fine((float3)geometricNormalWS);
    float variance = 0.1 * (dot(dNdx, dNdx) + dot(dNdy, dNdy));
    float alpha = perceptualRoughness * perceptualRoughness;
    float alpha2 = min(alpha * alpha, 0.9999);
    float projectedVariance = alpha2 / max(1.0 - alpha2, 1e-5);
    projectedVariance += min(2.0 * variance, 0.2 * 0.2);
    projectedVariance = max(projectedVariance, 0.0);
    alpha2 = projectedVariance / (projectedVariance + 1.0);
    perceptualRoughness = (half)sqrt(sqrt(saturate(alpha2)));
#endif
    return perceptualRoughness;
}

#endif
