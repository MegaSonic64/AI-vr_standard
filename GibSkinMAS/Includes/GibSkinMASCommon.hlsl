#ifndef BW_GIBSKIN_MAS_COMMON_INCLUDED
#define BW_GIBSKIN_MAS_COMMON_INCLUDED

// SLZ/Core must be first on the 8148 package line so `real*` aliases exist for downstream includes.
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"

// GibSkinMAS is a dynamic skinned-mesh shader; baked lightmap transport is intentionally omitted.
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SLZLighting.hlsl"

#if defined(UNITY_COLORSPACE_GAMMA)
    #define GIB_COLORSPACE_DOUBLE_RGB half3(2.0h, 2.0h, 2.0h)
#else
    // Built-in unity_ColorSpaceDouble.rgb in Linear color space.
    #define GIB_COLORSPACE_DOUBLE_RGB half3(4.59479380h, 4.59479380h, 4.59479380h)
#endif

TEXTURE2D(_MainTex);                 SAMPLER(sampler_MainTex);
TEXTURE2D(_BumpMap);                 SAMPLER(sampler_BumpMap);
TEXTURE2D(_MetallicGlossMap);        SAMPLER(sampler_MetallicGlossMap);
TEXTURE2D(_BloodyTex);               SAMPLER(sampler_BloodyTex);
TEXTURE2D(_BloodyNormal);            SAMPLER(sampler_BloodyNormal);
TEXTURE2D(_FluorescenceMap);         SAMPLER(sampler_FluorescenceMap);
TEXTURE2D(_DetailAlbedoMap);         SAMPLER(sampler_DetailAlbedoMap);
TEXTURE2D(_DetailNormalMap);         SAMPLER(sampler_DetailNormalMap);

CBUFFER_START(UnityPerMaterial)
half4 _Color;
half4 _BloodyColor;
float _BloodyTexScale;
half _BloodyNormalScale;
half _BloodyMetallic;
half _BloodySmoothness;
float _Power;
half4 _Absorbance;
float4 _DetailAlbedoMap_ST;
half _DetailNormalMapScale;
half g_flFresnelFalloff;
half g_flFresnelExponent;
half g_flCubeMapScalar;
half _SpecularHorizonOcclusion;
int _NumberOfHits;
int _NumberOfElipsoids;
int _Surface;
float _SSRTemporalMul;

// Original BONEWORKS hit/cut matrices. These names and layouts are intentionally preserved so the
// old hit-decal scripts can keep sending their existing MaterialPropertyBlock/Material arrays.
float4x4 EllipsoidPosArray[128];
float4x4 _ElipsoidMatrices[1];
CBUFFER_END

// The original GibSkin shader inherited this default from vr_lighting.cginc rather than exposing it.
static const half g_flReflectanceMax = half(1.0);

// Keep the BONEWORKS AO behavior: the computed MAS/hit AO multiplies all four lighting buckets 1:1.
static const half _OcclusionStrength = half(1.0);
static const half _OcclusionStrengthDirectDiffuse = half(1.0);
static const half _OcclusionStrengthDirectSpecular = half(1.0);
static const half _OcclusionStrengthIndirectDiffuse = half(1.0);
static const half _OcclusionStrengthIndirectSpecular = half(1.0);

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
    // of the screen. Convert back to half only after the hash is normalized.
    float hash = dot(float2(171.0, 231.0), screenPos + _Time.y.xx);
    float3 dither = frac(hash.xxx / float3(103.0, 71.0, 97.0)) - float3(0.5, 0.5, 0.5);
    return (half4)float4(dither.r, dither.g, dither.b, dither.r) * (half(0.375) / half(255.0));
}

inline void BW_AlbedoSpecularFromMetallic(inout half3 albedo, half metallic, out half3 specColor)
{
    half oneMinusReflectivity = OneMinusReflectivityMetallic(metallic);
    specColor = lerp(kDielectricSpec.rgb, albedo, metallic);
    albedo *= oneMinusReflectivity;
}

struct GibHitData
{
    float measuredDistance;
    half hits; // 0 = bloody surface, 1 = original skin surface
};

inline float GibHitDistance(float3 poseSpace)
{
    // Compare squared distances in the hit loop and take one square root at the end.
    // sqrt() is monotonic for non-negative values, so this preserves the original min-distance result
    // while avoiding up to 128 square roots per fragment.
    float hitDistanceSq = 1.0;
    int hitCount = clamp(_NumberOfHits, 0, 128);
    [loop]
    for (int h = 0; h < hitCount; ++h)
    {
        // Original Amplify expression subtracts matrix row 3 before applying the matrix's 3x3 part.
        float3 localPos = poseSpace - EllipsoidPosArray[h][3].xyz;
        float3 ellipsoidPos = mul(localPos, (float3x3)EllipsoidPosArray[h]);
        hitDistanceSq = min(hitDistanceSq, saturate(dot(ellipsoidPos, ellipsoidPos)));
    }
    return sqrt(hitDistanceSq);
}

inline float GibCutoutEllipsoidDistance(float3 poseSpace)
{
    float hitDistance = 1.0;
    int ellipsoidCount = clamp(_NumberOfElipsoids, 0, 128);
    [loop]
    for (int h = 0; h < ellipsoidCount; ++h)
    {
        // Fidelity: the BONEWORKS shader intentionally/accidentally reused element zero for every loop.
        float3 center = _ElipsoidMatrices[0][3].xyz;
        float3 transformed = mul(float4(poseSpace - center, 0.0), _ElipsoidMatrices[0]).xyz;
        hitDistance *= saturate(length(transformed));
    }
    return hitDistance;
}

inline float GibSafeBloodyScale()
{
    return abs(_BloodyTexScale) > 1e-6 ? _BloodyTexScale : (_BloodyTexScale < 0.0 ? -1e-6 : 1e-6);
}

inline half3 GibBloodTextureSamples(float3 poseSpace)
{
    float3 p = poseSpace / GibSafeBloodyScale();
    half xy = SAMPLE_TEXTURE2D(_BloodyTex, sampler_BloodyTex, p.xy).r;
    half yz = SAMPLE_TEXTURE2D(_BloodyTex, sampler_BloodyTex, p.yz).r;
    half xz = SAMPLE_TEXTURE2D(_BloodyTex, sampler_BloodyTex, p.xz).r;
    return half3(xy, yz, xz);
}

inline GibHitData GibEvaluateHits(float3 poseSpace, half3 geometricNormalWS)
{
    GibHitData data;
    data.measuredDistance = GibHitDistance(poseSpace);

    // Keep the complete Amplify hit-mask/Vivid-Light path in FP32. The original BONEWORKS
    // graph generated this math as float. On Vulkan, true FP16 can flush tiny half
    // denominators to zero, turning the endpoint divisions into 0/0 -> NaN. That NaN
    // then contaminates the albedo, normal, and MAS lerps and can black out the material.
    float hitFalloff = saturate(pow(max(data.measuredDistance, 0.0), _Power) * 2.0 - 1.0);
    float cutoutDistance = saturate(GibCutoutEllipsoidDistance(poseSpace));
    float src = saturate(hitFalloff * cutoutDistance);

    // Resolve fully blood / fully skin pixels before the triplanar blood-pattern fetch.
    // This removes three _BloodyTex samples anywhere the hit mask is already at an endpoint.
    UNITY_BRANCH if (src <= 1e-6)
    {
        data.hits = half(0.0);
        return data;
    }
    UNITY_BRANCH if (src >= 1.0 - 1e-6)
    {
        data.hits = half(1.0);
        return data;
    }

    float3 bloodSamples = (float3)GibBloodTextureSamples(poseSpace);
    float3 absN = abs((float3)geometricNormalWS);

    // Original triplanar weighting: XY*|Nz| + YZ*|Nx| + XZ*|Ny|, then /3 (not normalized by sum).
    float bloodPattern = (bloodSamples.x * absN.z + bloodSamples.y * absN.x + bloodSamples.z * absN.y) / 3.0;

    // Amplify Vivid Light:
    // src > .5 ? dest / ((1-src)*2) : 1 - (((1-dest)*.5)/src)
    // The generated shader leaves src=0/1 singular. Resolve those endpoints to the
    // intended spatial mask values, then evaluate the exact formula everywhere else.
    float vivid;
    if (src > 0.5)
    {
        vivid = bloodPattern / ((1.0 - src) * 2.0);
    }
    else
    {
        vivid = 1.0 - (((1.0 - bloodPattern) * 0.5) / src);
    }

    data.hits = (half)saturate(vivid);
    return data;
}

inline half3 GibBloodNormalTS(float3 poseSpace)
{
    float3 p = poseSpace / GibSafeBloodyScale();
    half3 nXY = UnpackNormalScale(SAMPLE_TEXTURE2D(_BloodyNormal, sampler_BloodyNormal, p.xy), _BloodyNormalScale);
    half3 nYZ = UnpackNormalScale(SAMPLE_TEXTURE2D(_BloodyNormal, sampler_BloodyNormal, p.yz), _BloodyNormalScale);
    half3 nXZ = UnpackNormalScale(SAMPLE_TEXTURE2D(_BloodyNormal, sampler_BloodyNormal, p.xz), _BloodyNormalScale);
    return (nXY + nYZ + nXZ) / half(3.0);
}

inline half3 GibBaseNormalTS(float2 uv0)
{
    half3 baseN = UnpackNormal(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, uv0));
    float2 detailUV = uv0 * _DetailAlbedoMap_ST.xy + _DetailAlbedoMap_ST.zw;
    half3 detailN = UnpackNormalScale(SAMPLE_TEXTURE2D(_DetailNormalMap, sampler_DetailNormalMap, detailUV), _DetailNormalMapScale);
    return BlendNormal(baseN, detailN);
}

inline half3 GibSurfaceNormalTS(float2 uv0, float3 poseSpace, half hits)
{
    // Avoid evaluating both normal stacks once the hit mask has resolved to an endpoint.
    UNITY_BRANCH if (hits <= half(0.0)) return GibBloodNormalTS(poseSpace);
    UNITY_BRANCH if (hits >= half(1.0)) return GibBaseNormalTS(uv0);
    return lerp(GibBloodNormalTS(poseSpace), GibBaseNormalTS(uv0), hits);
}

inline half3 GibBaseAlbedo(float2 uv0)
{
    float2 detailUV = uv0 * _DetailAlbedoMap_ST.xy + _DetailAlbedoMap_ST.zw;
    half3 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv0).rgb * _Color.rgb;
    albedo *= SAMPLE_TEXTURE2D(_DetailAlbedoMap, sampler_DetailAlbedoMap, detailUV).rgb * GIB_COLORSPACE_DOUBLE_RGB;
    return albedo;
}

inline half3 GibBloodAlbedo(float3 poseSpace)
{
    float3 p = poseSpace / GibSafeBloodyScale();
    half bloodyR = SAMPLE_TEXTURE2D(_BloodyTex, sampler_BloodyTex, p.xy).r;
    return lerp(bloodyR * _BloodyColor.rgb, _BloodyColor.rgb, _BloodyColor.a);
}

inline half3 GibSurfaceAlbedo(float2 uv0, float3 poseSpace, half hits)
{
    // Original graph rounds only the albedo switch. Branching is mathematically equivalent to
    // lerp(blood, skin, round(hits)) but prevents sampling the unused material stack.
    half roundedHits = round(hits);
    UNITY_BRANCH if (roundedHits > half(0.0)) return GibBaseAlbedo(uv0);
    return GibBloodAlbedo(poseSpace);
}

inline half3 GibSurfaceMAS(float2 uv0, half hits)
{
    half3 bloodyMAS = half3(_BloodyMetallic, half(1.0), _BloodySmoothness);
    UNITY_BRANCH if (hits <= half(0.0)) return bloodyMAS;
    half3 skinMAS = SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_MetallicGlossMap, uv0).rgb;
    UNITY_BRANCH if (hits >= half(1.0)) return skinMAS;
    return lerp(bloodyMAS, skinMAS, hits);
}

inline half GibSurfaceOcclusion(half masAO, float measuredDistance)
{
    half hitAO = smoothstep(half(0.2), half(0.8), saturate((half)measuredDistance * half(1.5)));
    return masAO * hitAO;
}

#endif
