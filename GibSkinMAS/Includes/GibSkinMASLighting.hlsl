#ifndef BW_GIBSKIN_MAS_LIGHTING_INCLUDED
#define BW_GIBSKIN_MAS_LIGHTING_INCLUDED

#include "GibSkinMASCommon.hlsl"

#if defined(_SSR_ENABLED) && !defined(SHADER_API_MOBILE)
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SLZLightingSSR.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SLZBlueNoise.hlsl"
#endif

struct BWLightingTerms
{
    half4 directDiffuse;
    half3 directSpecular;
    half3 indirectDiffuse;
    half3 indirectSpecular;
};

inline half BW_LuminanceSafe(half3 c)
{
    return max(Luminance(c), half(1e-4));
}

inline half3 BW_Fresnel(half3 reflectance, half LoH)
{
    // BONEWORKS used Unity's FresnelTerm here. SLZ's Schlick is equivalent for our purposes.
    return SLZSchlickFresnel(saturate(LoH), reflectance);
}

inline half BW_DiffuseExponent(half perceptualRoughness)
{
    return (half(1.0) - perceptualRoughness) * half(0.8) + half(0.6);
}

inline half3 BW_RotateTangent(half3 tangentWS, half3 bitangentWS, half rotation01)
{
    half angle = rotation01 * half(6.28318530718);
    half s, c;
    sincos(angle, s, c);
    return normalize(c * tangentWS - s * bitangentWS);
}

inline float BW_SmithJointGGXVisibilityDesktop(float NdotL, float NdotV, float roughness)
{
    // Exact approximation used by UnityStandardBRDF.cginc in the BONEWORKS-era Built-in renderer.
    float a = roughness;
    float lambdaV = NdotL * (NdotV * (1.0 - a) + a);
    float lambdaL = NdotV * (NdotL * (1.0 - a) + a);
    return 0.5 / (lambdaV + lambdaL + 1e-5);
}

inline half BW_SmithJointGGXVisibilityMobile(half NdotL, half NdotV, half roughness)
{
    // Same BONEWORKS approximation, kept in half precision with a mobile-safe epsilon.
    half lambdaV = NdotL * (NdotV * (half(1.0) - roughness) + roughness);
    half lambdaL = NdotV * (NdotL * (half(1.0) - roughness) + roughness);
    return half(0.5) / max(lambdaV + lambdaL, half(1e-4));
}

inline float BW_GGXTermDesktop(float NdotH, float roughness)
{
    float a2 = roughness * roughness;
    float d = (NdotH * a2 - NdotH) * NdotH + 1.0;
    return (1.0 / PI) * a2 / (d * d + 1e-7);
}

inline half BW_GGXTermMobileGeneric(half x, half roughness)
{
    // Used by retroreflection where x is V.L rather than N.H, so SLZ's NxH-based mobile NDF cannot be used.
    half a2 = roughness * roughness;
    half d = (x * a2 - x) * x + half(1.0);
    return min(half(0.31830988618) * a2 / max(d * d, half(1e-4)), half(100.0));
}

inline half4 BW_ComputeDiffuseSpecular(
    half3 normalWS,
    half3 tangentWS,
    half3 bitangentWS,
    half3 lightDirWS,
    half3 viewDirWS,
    half perceptualRoughness,
    half anisoRotation,
    half anisoRatio,
    half3 reflectance,
    half NoV)
{
    half NoLRaw = dot(normalWS, lightDirWS);
    half NoL = saturate(NoLRaw);

    // BONEWORKS' BRDF LUT is sampled in half-Lambert space and deliberately sees negative N.L.
#if !defined(_BRDFMAP)
    if (NoL <= 0.0h)
        return half4(0,0,0,0);
#endif

    half diffuseTerm;
#if defined(_BRDFMAP)
    diffuseTerm = saturate((NoLRaw + half(1.0)) * half(0.5));
#else
    half diffuseExponent = BW_DiffuseExponent(perceptualRoughness);
    diffuseTerm = pow(NoL, diffuseExponent) * ((diffuseExponent + half(1.0)) * half(0.5));
#endif

#if defined(S_SPECULAR_NONE)
    return half4(diffuseTerm, 0, 0, 0);
#else
    half3 H = BW_SafeNormalize(lightDirWS + viewDirWS);
    half LoH = saturate(dot(lightDirWS, H));
    half NoH = saturate(dot(normalWS, H));
    half roughness = max(perceptualRoughness * perceptualRoughness, half(0.001));
    half3 specularTerm = 0;

    #if defined(S_RETROREFLECTIVE)
        half VdotL = pow(saturate(dot(viewDirWS, lightDirWS) * half(1.003)), half(0.03));
        #if defined(SHADER_API_MOBILE)
            half vis = BW_SmithJointGGXVisibilityMobile(NoL, max(VdotL, half(1e-4)), roughness);
            half D = BW_GGXTermMobileGeneric(VdotL, roughness);
        #else
            float vis = BW_SmithJointGGXVisibilityDesktop(NoL, max(VdotL, half(1e-4)), roughness);
            float D = BW_GGXTermDesktop(VdotL, roughness);
        #endif
        half scalar = (half)(vis * D * PI) * max(NoV, half(0.0));
        specularTerm = scalar * BW_Fresnel(reflectance, LoH) * sqrt(NoL);

    #elif defined(S_ANISOTROPIC_GLOSS)
        half3 rotatedTangent = BW_RotateTangent(tangentWS, bitangentWS, anisoRotation);

        #if defined(SHADER_API_MOBILE)
            // SLZ's FP16-safe Burley anisotropic NDF/visibility, while retaining BONEWORKS' final lobe shaping.
            half aspect = min(saturate(half(1.0) - anisoRatio), half(0.98));
            half roughT = max(roughness * (half(1.0) + aspect), half(0.001));
            half roughB = max(roughness * (half(1.0) - aspect), half(0.001));
            half3 rotatedB = normalize(cross(normalWS, rotatedTangent));
            half ToH = dot(rotatedTangent, H);
            half BoH = dot(rotatedB, H);
            half ToL = dot(rotatedTangent, lightDirWS);
            half BoL = dot(rotatedB, lightDirWS);
            half ToV = dot(rotatedTangent, viewDirWS);
            half BoV = dot(rotatedB, viewDirWS);
            half NoH2 = NoH * NoH;
            half lambdaV = length(half3(roughT * ToV, roughB * BoV, NoV * NoV));
            half D = SLZGGXSpecularDAniso(NoH2, ToH, BoH, roughT, roughB, aspect);
            half vis = SLZSmithVisibilityAniso(NoV, NoL, ToL, BoL, lambdaV, roughT, roughB);
            half scalar = D * vis * half(PI) * half(0.8) * max(NoV, half(0.0));
            specularTerm = scalar * BW_Fresnel(reflectance, LoH) * pow(NoL, half(5.0));
            specularTerm = clamp(specularTerm - REAL_MIN, 0.0h, 100.0h);
        #else
            // Preserve the BONEWORKS 2020 anisotropic direct-light model on desktop.
            half3 specNormal = H - rotatedTangent * dot(H, rotatedTangent);
            half projectedNoH = dot(specNormal, H);
            half anisoNoH = saturate(lerp(projectedNoH, NoH, anisoRatio));
            float vis = BW_SmithJointGGXVisibilityDesktop(NoL, max(NoV, half(1e-4)), roughness);
            float D = BW_GGXTermDesktop(anisoNoH, roughness);
            half scalar = (half)(vis * D * PI * 0.8) * max(NoV, half(0.0));
            specularTerm = scalar * BW_Fresnel(reflectance, LoH) * pow(NoL, half(5.0));
        #endif

    #else
        // The original BONEWORKS isotropic branch normalized a scalar N.L before the Smith term,
        // which evaluates to 1 for a front-facing light. Preserve that quirk for compatibility.
        half visibilityNoL = NoL > 0.0h ? half(1.0) : half(0.0);
        #if defined(SHADER_API_MOBILE)
            half3 NxH = cross(normalWS, H);
            half D = SLZGGXSpecularDMobile(NoH, saturate(dot(NxH, NxH)), roughness);
            half vis = BW_SmithJointGGXVisibilityMobile(visibilityNoL, max(NoV, half(1e-4)), roughness);
            half scalar = vis * D * half(PI) * half(0.8);
        #else
            float D = BW_GGXTermDesktop(NoH, roughness);
            float vis = BW_SmithJointGGXVisibilityDesktop(visibilityNoL, max(NoV, half(1e-4)), roughness);
            half scalar = (half)(vis * D * PI * 0.8);
        #endif
        specularTerm = scalar * BW_Fresnel(reflectance, LoH) * sqrt(NoL);
    #endif

    return half4(diffuseTerm, specularTerm);
#endif
}

inline void BW_AccumulateLight(
    inout half4 diffuse,
    inout half3 specular,
    Light light,
    half3 normalWS,
    half3 tangentWS,
    half3 bitangentWS,
    half3 viewDirWS,
    half perceptualRoughness,
    half anisoRotation,
    half anisoRatio,
    half3 reflectance,
    half NoV)
{
    half attenuation = light.distanceAttenuation * light.shadowAttenuation;
    if (attenuation <= 0.0h)
        return;

    half4 terms = BW_ComputeDiffuseSpecular(normalWS, tangentWS, bitangentWS, light.direction, viewDirWS,
                                            perceptualRoughness, anisoRotation, anisoRatio, reflectance, NoV);

#if defined(_BRDFMAP)
    half3 remapped = BDRFLUTSAMPLER(half2(terms.x, NoV)).rgb;
    diffuse.rgb += remapped * light.color.rgb * attenuation;
    diffuse.a += remapped.b * light.color.a * attenuation;
#else
    diffuse += terms.xxxx * light.color * attenuation;
#endif
    specular += terms.yzw * light.color.rgb * attenuation;
}

// SLZ LitMAS/Posespace owns RGB mobile vertex lighting through URP's VertexLighting().
// GibSkin keeps only the BONEWORKS fluorescence alpha accumulator here because stock
// VertexLighting intentionally returns RGB irradiance only.
inline half BW_MobileVertexFluorescenceAlpha(float3 positionWS, half3 normalWS)
{
#if defined(_FLUORESCENCEMAP) && defined(_ADDITIONAL_LIGHTS_VERTEX)
    float alphaSum = 0.0;
    uint count = GetAdditionalLightsCount();
    LIGHT_LOOP_BEGIN(count)
        Light light = GetAdditionalLight(lightIndex, positionWS);
        half NoL = saturate(dot(normalWS, light.direction));
        alphaSum += (float)light.color.a * (float)light.distanceAttenuation * (float)NoL;
    LIGHT_LOOP_END
    return (half)min(max(alphaSum, 0.0), 65504.0);
#else
    return half(0.0);
#endif
}

inline half3 BW_ReflectionDirection(half3 viewDirWS, half3 normalWS, half3 tangentWS, half3 bitangentWS,
                                    half anisoRotation, half anisoRatio)
{
    half3 reflectionDir = reflect(-viewDirWS, normalWS);
#if !defined(SHADER_API_MOBILE)
    #if defined(S_RETROREFLECTIVE)
        // Original BONEWORKS only changed retro probe direction when box projection was active.
        reflectionDir = viewDirWS;
    #elif defined(S_ANISOTROPIC_GLOSS)
        half3 rotatedTangent = BW_RotateTangent(tangentWS, bitangentWS, anisoRotation);
        half3 anisoNormal = cross(cross(viewDirWS, rotatedTangent), rotatedTangent);
        half3 reflectionNormal = normalize(lerp(-normalWS, anisoNormal, (half(1.0) - anisoRatio) * half(0.666666)));
        half3 anisoReflection = viewDirWS - half(2.0) * dot(reflectionNormal, viewDirWS) * reflectionNormal;
        reflectionDir = -anisoReflection;
    #endif
#endif
    return reflectionDir;
}

struct BWEnvironmentSpecularResult
{
    half3 probe;
    half3 ssr;
    half ssrLerp;
};

inline BWEnvironmentSpecularResult BW_EnvironmentSpecular(
    float3 positionWS,
    float2 screenUV,
    half3 viewDirWS,
    half3 normalWS,
    half3 geometricNormalWS,
    half3 tangentWS,
    half3 bitangentWS,
    half perceptualRoughness,
    half anisoRotation,
    half anisoRatio,
    half3 reflectance,
    half NoV)
{
    BWEnvironmentSpecularResult result = (BWEnvironmentSpecularResult)0;
#if !defined(S_SPECULAR_NONE)
    half3 reflectionDir = BW_ReflectionDirection(viewDirWS, normalWS, tangentWS, bitangentWS, anisoRotation, anisoRatio);
    half3 environment = GlossyEnvironmentReflection(reflectionDir, positionWS, perceptualRoughness, half(1.0));

#if defined(_SSR_ENABLED) && !defined(SHADER_API_MOBILE)
    half RdotV = saturate(half(0.95) * dot(reflectionDir, -viewDirWS) + half(0.05));
    half ssrBlend = saturate((perceptualRoughness - half(0.5)) / (half(0.4) - half(0.5)));
    half temp = half(2.0) * saturate((half(1.0) / half(0.6666667)) * RdotV);
    temp = temp > 1.0h ? -half(0.5) * temp * temp + (half(2.0) * temp - half(1.0)) : half(0.5) * temp * temp;
    ssrBlend *= temp;
    if (ssrBlend > half(0.008))
    {
        // IMPORTANT: GetScreenNoiseRGBA expects normalized UVs derived from the fragment's raster
        // SV_POSITION. Passing homogeneous clip coordinates here makes the stochastic SSR ray offset
        // slide with camera motion, producing the characteristic wobbling/floating reflection.
        half4 noise = GetScreenNoiseRGBA(screenUV);
        SSRData ssrData = GetSSRData(positionWS, viewDirWS, reflectionDir, geometricNormalWS,
                                     perceptualRoughness, RdotV, 0.0, noise);
        float4 ssr = getSSRColor(ssrData);
        result.ssrLerp = saturate(ssr.a * ssrBlend);
        result.ssr = ssr.rgb * result.ssrLerp;
        environment *= (half(1.0) - result.ssrLerp);
    }
#endif

#if defined(S_SPECULAR_BLINNPHONG)
    half3 maxReflectance = ((reflectance + half3(0.001,0.001,0.001)) / BW_LuminanceSafe(reflectance + half3(0.001,0.001,0.001))) * g_flReflectanceMax;
#else
    half3 maxReflectance = (reflectance + half3(0.001,0.001,0.001)) / BW_LuminanceSafe(reflectance + half3(0.001,0.001,0.001));
#endif
    half fresnelPower = pow(half(1.0) - saturate(NoV), g_flFresnelExponent);
    half3 fresnel = lerp(reflectance, maxReflectance * g_flFresnelFalloff, fresnelPower);
    half3 iblFactor = fresnel * g_flCubeMapScalar;
    result.probe = environment * iblFactor;
    result.ssr *= iblFactor;
#endif
    return result;
}

inline half3 BW_ResolveSSRTemporal(
    half3 baseColor,
    half3 currentSSR,
    half ssrLerp,
    float4 lastClipPos,
    float3 positionWS,
    half3 viewDirWS,
    half fogFactor)
{
#if defined(_SSR_ENABLED) && !defined(SHADER_API_MOBILE)
    // Transparent surfaces do not participate in stable opaque-buffer temporal SSR history.
    // Force temporal accumulation off at runtime even if a MaterialPropertyBlock or animation
    // attempts to override the inspector-forced value.
    if (_Surface != 0 || _SSRTemporalMul == 0.0 || ssrLerp < half(0.0008) || lastClipPos.w == 0.0)
        return currentSSR;

    float oldVertDepth = lastClipPos.z / lastClipPos.w;
    float ddzOld = GetDepthDerivativeSum(oldVertDepth);
    float2 oldScreenUV = SLZComputeNDCFromClip(lastClipPos);

    bool inBounds = oldScreenUV.x >= 0.0 && oldScreenUV.y >= 0.0 && oldScreenUV.x <= 1.0 && oldScreenUV.y <= 1.0;
    if (!inBounds)
        return currentSSR;

    float oldDepth = LOAD_TEXTURE2D_X(_PrevHiZ0Texture, oldScreenUV.xy * _HiZDim.xy).r;
    bool depthValid = abs(oldDepth - oldVertDepth) < 2.0 * ddzOld + HALF_MIN;
    if (!depthValid)
        return currentSSR;

    float3 oldColor = SAMPLE_TEXTURE2D_X_LOD(_CameraOpaqueTexture, sampler_TrilinearClamp,
                                              UnityStereoTransformScreenSpaceTex(oldScreenUV), 0).rgb;

#if defined(_VOLUMETRICS_ENABLED)
    float4 volColor = GetVolumetricColor(positionWS);
    oldColor = (oldColor - volColor.rgb) / max(volColor.a, 0.0001);
#endif

#if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
    half4 fogFactors = CalcFogFactors(-viewDirWS, fogFactor);
    oldColor = invertFogLerp(fogFactors.w, fogFactors.rgb, oldColor);
#endif

    // Recover the previous frame's SSR-only contribution using the same approach as SLZPBRFragmentSSR.
    oldColor = max(0.0, oldColor - baseColor);

    float frameTemp = _SSRTemporalMul < 0.5
        ? lerp(1.0, _SSRTemporalWeight, _SSRTemporalMul)
        : lerp(_SSRTemporalWeight, 0.0078, _SSRTemporalMul - 1.0);

    return (half3)(frameTemp * currentSSR + (1.0 - frameTemp) * oldColor);
#else
    return currentSSR;
#endif
}

inline void BW_ApplyOcclusion(inout BWLightingTerms terms, half occlusion)
{
    terms.directDiffuse *= BW_LerpOneTo(occlusion, _OcclusionStrength * _OcclusionStrengthDirectDiffuse);
    terms.directSpecular *= BW_LerpOneTo(occlusion, _OcclusionStrength * _OcclusionStrengthDirectSpecular);
    terms.indirectDiffuse *= BW_LerpOneTo(occlusion, _OcclusionStrength * _OcclusionStrengthIndirectDiffuse);
    terms.indirectSpecular *= BW_LerpOneTo(occlusion, _OcclusionStrength * _OcclusionStrengthIndirectSpecular);
}

inline half3 BW_Fluorescence(half4 directDiffuse, half3 indirectDiffuse, half3 fluorescence)
{
    half4 absorbed = (directDiffuse + half4(indirectDiffuse, 0)) * _Absorbance;
    half b = absorbed.b + absorbed.a;
    half g = b + absorbed.g;
    half r = g + absorbed.r;
    return half3(r, g, b) * fluorescence;
}

#endif
