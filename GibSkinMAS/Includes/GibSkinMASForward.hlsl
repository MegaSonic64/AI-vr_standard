#ifndef BW_GIBSKIN_MAS_FORWARD_INCLUDED
#define BW_GIBSKIN_MAS_FORWARD_INCLUDED

// Match LitMAS Posespace's platform lighting policy exactly. This file is included
// with #include_with_pragmas *after* PlatformCompiler.hlsl from the ShaderLab pass.
#if defined(SHADER_API_MOBILE)
    #define _ADDITIONAL_LIGHTS_VERTEX
#else
    #pragma multi_compile_fragment _ _MAIN_LIGHT_SHADOWS_CASCADE
    #pragma multi_compile_fragment _ _ADDITIONAL_LIGHTS
    #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
    #define _SHADOWS_SOFT 1
    #define _REFLECTION_PROBE_BLENDING
    #define _REFLECTION_PROBE_BOX_PROJECTION
    #pragma multi_compile _ _SLZ_SSR_ENABLED
    #pragma shader_feature_local _ _NO_SSR
    #if defined(_SLZ_SSR_ENABLED) && !defined(_NO_SSR)
        #define _SSR_ENABLED
    #endif
#endif

#include "GibSkinMASLighting.hlsl"

struct Attributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float4 uv0 : TEXCOORD0;
    float4 uv1 : TEXCOORD1; // BONEWORKS pose-space position lives in UV1.xyz
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS : SV_POSITION;
    float3 positionWS : TEXCOORD0;
    float3 poseSpace : TEXCOORD1;
    half4 normalWS_tangentX : TEXCOORD3;
    half4 tangentYZ_bitangentX : TEXCOORD4;
    half bitangentZ : TEXCOORD5;
    half3 vertexSH : TEXCOORD6;
    half4 vertexLightFluor : TEXCOORD7;
    half fogFactor : TEXCOORD8;
    float2 uv0 : TEXCOORD9;
#if defined(_SSR_ENABLED) && !defined(SHADER_API_MOBILE)
    float4 lastClipPos : TEXCOORD11;
#endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

Varyings GibVert(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    VertexPositionInputs pos = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs ntb = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    output.positionCS = pos.positionCS;
    output.positionWS = pos.positionWS;
    output.poseSpace = input.uv1.xyz;
    output.uv0 = input.uv0.xy;
    output.normalWS_tangentX = half4(ntb.normalWS, ntb.tangentWS.x);
    output.tangentYZ_bitangentX = half4(ntb.tangentWS.yz, ntb.bitangentWS.xy);
    output.bitangentZ = ntb.bitangentWS.z;

    OUTPUT_SH(ntb.normalWS, output.vertexSH);

#if defined(SHADER_API_MOBILE)
    // Exact LitMAS/Posespace RGB path. Use URP's VertexLighting() instead of a
    // hand-written additional-light loop; this is the path SLZ ships for Quest.
    output.vertexLightFluor.rgb = VertexLighting(pos.positionWS, ntb.normalWS);
    // Preserve the old BONEWORKS fluorescence use of realtime-light alpha.
    output.vertexLightFluor.a = BW_MobileVertexFluorescenceAlpha(pos.positionWS, ntb.normalWS);
#else
    output.vertexLightFluor = 0;
#endif

    half clipZ_0Far = UNITY_Z_0_FAR_FROM_CLIPSPACE(output.positionCS.z);
    output.fogFactor = unity_FogParams.x * clipZ_0Far;

#if defined(_SSR_ENABLED) && !defined(SHADER_API_MOBILE)
    float4 lastWPos = mul(GetPrevObjectToWorldMatrix(), input.positionOS);
    output.lastClipPos = mul(prevVP, lastWPos);
#endif
    return output;
}

half4 GibFrag(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    half3 geometricNormalWS = normalize(input.normalWS_tangentX.xyz);
    half3 tangentWS = normalize(half3(input.normalWS_tangentX.w, input.tangentYZ_bitangentX.xy));
    half3 bitangentWS = normalize(half3(input.tangentYZ_bitangentX.zw, input.bitangentZ));

    GibHitData hit = GibEvaluateHits(input.poseSpace, geometricNormalWS);
    half3 albedo = GibSurfaceAlbedo(input.uv0, input.poseSpace, hit.hits);
    half3 normalTS = GibSurfaceNormalTS(input.uv0, input.poseSpace, hit.hits);
    half3 mas = GibSurfaceMAS(input.uv0, hit.hits);

    half3x3 tbn = half3x3(
        tangentWS.x, bitangentWS.x, geometricNormalWS.x,
        tangentWS.y, bitangentWS.y, geometricNormalWS.y,
        tangentWS.z, bitangentWS.z, geometricNormalWS.z);
    half3 normalWS = normalize(mul(tbn, normalTS));

    half metallic = mas.r;
    half smoothness = mas.b;
    half occlusion = GibSurfaceOcclusion(mas.g, hit.measuredDistance);

    half3 albedoPreMetal = albedo;
    half3 reflectance;
    BW_AlbedoSpecularFromMetallic(albedo, metallic, reflectance);

    half perceptualRoughness = half(1.0) - saturate(smoothness);
#if !defined(SHADER_API_MOBILE) && !defined(S_RETROREFLECTIVE)
    // Match LitMAS' cheaper Valve-derived geometric Spec AA. Retroreflective preserves
    // the original BONEWORKS behavior and deliberately bypasses geometric roughness filtering.
    perceptualRoughness = max(perceptualRoughness, half(1.0) - SLZGeometricSpecularAA(geometricNormalWS));
#endif

    half3 viewDirWS = BW_SafeNormalize((half3)(_WorldSpaceCameraPos - input.positionWS));
    half NoV = saturate(dot(normalWS, viewDirWS));

    // GibSkinMAS exposed no anisotropy controls; the original graph fed 0 rotation / 1 ratio.
    half anisoRotation = 0.0h;
    half anisoRatio = 1.0h;

    BWLightingTerms lighting = (BWLightingTerms)0;

    // GibSkinMAS is intended for dynamic skinned meshes. Do not compile or sample static/dynamic lightmaps;
    // use probes/SH for indirect diffuse and keep the original BONEWORKS-style probe specular reconstruction.
    SLZFragData fragData = SLZGetFragData(
        input.positionCS, input.positionWS, normalWS, float2(0,0), float2(0,0),
#if defined(SHADER_API_MOBILE)
        input.vertexLightFluor.rgb
#else
        half3(0,0,0)
#endif
    );

    lighting.indirectDiffuse = SampleSHPixel(input.vertexSH, normalWS);

    Light mainLight = GetMainLight(fragData.shadowCoord, fragData.position, fragData.shadowMask);
#if !defined(S_RECEIVE_SHADOWS)
    mainLight.shadowAttenuation = 1.0h;
#endif
    half mainLightGate = max(mainLight.color.r, max(mainLight.color.g, mainLight.color.b)) * mainLight.distanceAttenuation * mainLight.shadowAttenuation;
#if !defined(_BRDFMAP)
    mainLightGate *= saturate(dot(normalWS, mainLight.direction));
#endif

    BW_AccumulateLight(lighting.directDiffuse, lighting.directSpecular, mainLight,
                       normalWS, tangentWS, bitangentWS, viewDirWS,
                       perceptualRoughness, anisoRotation, anisoRatio, reflectance, NoV);

#if defined(_ADDITIONAL_LIGHTS) && !defined(SHADER_API_MOBILE)
    uint lightCount = GetAdditionalLightsCount();
    LIGHT_LOOP_BEGIN(lightCount)
        Light light = GetAdditionalLight(lightIndex, fragData.position, fragData.shadowMask);
        #if !defined(S_RECEIVE_SHADOWS)
            light.shadowAttenuation = 1.0h;
        #endif
        BW_AccumulateLight(lighting.directDiffuse, lighting.directSpecular, light,
                           normalWS, tangentWS, bitangentWS, viewDirWS,
                           perceptualRoughness, anisoRotation, anisoRatio, reflectance, NoV);
    LIGHT_LOOP_END
#endif

#if defined(SHADER_API_MOBILE)
    // Match LitMAS Posespace transport: RGB vertex-light irradiance comes from
    // fragData.vertexLighting. Keep fluorescence alpha in the BONEWORKS diffuse bucket.
    lighting.directDiffuse.rgb += fragData.vertexLighting;
    lighting.directDiffuse.a += input.vertexLightFluor.a;
#endif

    // Probe-only fake specular for dynamic characters when no realtime main-light highlight is available.
    if (mainLightGate <= REAL_MIN)
    {
        half3 shDir = SLZSHSpecularDirection();
        half4 shTerms = BW_ComputeDiffuseSpecular(normalWS, tangentWS, bitangentWS, shDir, viewDirWS,
                                                   perceptualRoughness, anisoRotation, anisoRatio, reflectance, NoV);
        lighting.indirectSpecular += shTerms.yzw * max(lighting.indirectDiffuse, half3(0,0,0)) * SLZFakeSpecularFalloff(dot(normalWS, shDir));
    }

    // BONEWORKS metallic energy conservation happens after lighting accumulation.
    lighting.directDiffuse.rgb *= (half3(1,1,1) - reflectance);
    lighting.directDiffuse.a *= (half(1.0) - reflectance.b);
    lighting.indirectDiffuse *= (half3(1,1,1) - reflectance);

    float2 screenUV = GetNormalizedScreenSpaceUV(input.positionCS);
    BWEnvironmentSpecularResult environmentSpec = BW_EnvironmentSpecular(input.positionWS, screenUV, viewDirWS, normalWS,
                                                                          geometricNormalWS, tangentWS, bitangentWS,
                                                                          perceptualRoughness, anisoRotation, anisoRatio,
                                                                          reflectance, NoV);
    lighting.indirectSpecular += environmentSpec.probe;
    half3 ssrContribution = environmentSpec.ssr;

    // Original GibSkinMAS multiplies diffuse and specular by the same hit/MAS AO after ComputeLighting.
    half3 diffuseLighting = (lighting.directDiffuse.rgb + lighting.indirectDiffuse) * occlusion;
    half3 specularLighting = (lighting.directSpecular + lighting.indirectSpecular) * occlusion;
    ssrContribution *= occlusion;

    half3 colorRGB = max(half3(0,0,0), diffuseLighting * albedo) + specularLighting;

#if defined(_SSR_ENABLED) && !defined(SHADER_API_MOBILE)
    colorRGB += BW_ResolveSSRTemporal(colorRGB, ssrContribution, environmentSpec.ssrLerp,
                                      input.lastClipPos, input.positionWS, viewDirWS, input.fogFactor);
#else
    colorRGB += ssrContribution;
#endif

#if defined(_FLUORESCENCEMAP)
    // Preserve the BONEWORKS ordering: fluorescence uses the un-occluded diffuse lighting buckets.
    half3 fluorescence = SAMPLE_TEXTURE2D(_FluorescenceMap, sampler_FluorescenceMap, input.uv0).rgb;
    colorRGB = max(colorRGB, BW_Fluorescence(lighting.directDiffuse, lighting.indirectDiffuse, fluorescence));
#endif

    half4 outColor = half4(colorRGB, 1.0h);
    outColor = MixFogSurf(outColor, -viewDirWS, input.fogFactor, _Surface);
    outColor = VolumetricsSurf(outColor, input.positionWS, _Surface);

    // Original BONEWORKS ordering: dither is last, after fog.
    outColor += BW_ScreenSpaceDither(input.positionCS.xy);
    return outColor;
}

#endif
