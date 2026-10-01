#ifndef BW_VR_STANDARD_FORWARD_INCLUDED
#define BW_VR_STANDARD_FORWARD_INCLUDED

#include "BWVRStandardLighting.hlsl"

struct Attributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float4 color : COLOR;
    float2 uv0 : TEXCOORD0;
    float2 uv1 : TEXCOORD1;
    float2 uv2 : TEXCOORD2;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS : SV_POSITION;
    float3 positionWS : TEXCOORD0;
    float4 uv01 : TEXCOORD1;
#if defined(LIGHTMAP_ON) || defined(DYNAMICLIGHTMAP_ON)
    float4 lightmapUV : TEXCOORD2;
#endif
    half4 normalWS_tangentX : TEXCOORD3;
    half4 tangentYZ_bitangentX : TEXCOORD4;
    half2 bitangentYZ : TEXCOORD5;
    half4 color : COLOR;
    half3 vertexSH : TEXCOORD6;
    half4 vertexLightFluor : TEXCOORD7;
    half fogFactor : TEXCOORD8;
#if defined(_SSR_ENABLED) && !defined(SHADER_API_MOBILE)
    float4 lastClipPos : TEXCOORD9;
#endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

Varyings BWVert(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    VertexPositionInputs pos = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs ntb = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    output.positionCS = pos.positionCS;
    output.positionWS = pos.positionWS;
    output.uv01 = float4(input.uv0, input.uv1);
    output.color = input.color;

    output.normalWS_tangentX = half4(ntb.normalWS, ntb.tangentWS.x);
    output.tangentYZ_bitangentX = half4(ntb.tangentWS.yz, ntb.bitangentWS.x, ntb.bitangentWS.y);
    output.bitangentYZ = half2(ntb.bitangentWS.z, input.tangentOS.w);

#if defined(LIGHTMAP_ON)
    OUTPUT_LIGHTMAP_UV(input.uv1, unity_LightmapST, output.lightmapUV.xy);
#endif
#if defined(DYNAMICLIGHTMAP_ON)
    OUTPUT_LIGHTMAP_UV(input.uv2, unity_DynamicLightmapST, output.lightmapUV.zw);
#endif

    OUTPUT_SH(ntb.normalWS, output.vertexSH);

#if defined(SHADER_API_MOBILE)
    output.vertexLightFluor = BW_MobileVertexLighting(pos.positionWS, ntb.normalWS);
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

inline void BW_GetTBN(Varyings input, half faceSign, out half3 geometricNormalWS, out half3 tangentWS, out half3 bitangentWS)
{
    geometricNormalWS = normalize(input.normalWS_tangentX.xyz) * faceSign;
    tangentWS = normalize(half3(input.normalWS_tangentX.w, input.tangentYZ_bitangentX.xy));
    bitangentWS = normalize(half3(input.tangentYZ_bitangentX.zw, input.bitangentYZ.x));
}

half4 BWFrag(Varyings input, FRONT_FACE_TYPE frontFace : FRONT_FACE_SEMANTIC) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    half faceSign = 1.0h;
#if defined(S_RENDER_BACKFACES)
    faceSign = IS_FRONT_VFACE(frontFace, 1.0h, -1.0h);
#endif

    half3 geometricNormalWS, tangentWS, bitangentWS;
    BW_GetTBN(input, faceSign, geometricNormalWS, tangentWS, bitangentWS);

    half3 viewDirWS = BW_SafeNormalize((half3)(_WorldSpaceCameraPos - input.positionWS));
    half NoVGeom = saturate(dot(geometricNormalWS, viewDirWS));

    float2 baseUV = BW_BaseUV(input.uv01.xy, input.positionWS);
    float2 detailUV = BW_DetailUV(input.uv01.xy, input.uv01.zw, baseUV, input.positionWS);

#if defined(_PARALLAXMAP) && !defined(SHADER_API_MOBILE)
    half3 viewDirTS = half3(dot(viewDirWS, tangentWS), dot(viewDirWS, bitangentWS), dot(viewDirWS, geometricNormalWS));
    float2 preParallaxUV = baseUV;
    baseUV = BW_ParallaxUV(baseUV, viewDirTS);
    #if defined(BW_DETAIL_ON)
        detailUV += (baseUV - preParallaxUV) * _DetailAlbedoMap_ST.xy;
    #endif
#endif

    half4 baseSample = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, baseUV);
    half4 baseColor = baseSample * _Color;
    half3 albedo = baseColor.rgb;
    half baseAlpha = baseColor.a;

    albedo = BW_ApplyDetailAlbedo(albedo, baseUV, detailUV);

    half3 normalTS = half3(0,0,1);
#if defined(_NORMALMAP) && !defined(S_UNLIT)
    normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, baseUV), _BumpScale);
    normalTS = BW_ApplyDetailNormal(normalTS, baseUV, detailUV);
#endif

    half3 normalWS = geometricNormalWS;
#if defined(_NORMALMAP) && !defined(S_UNLIT)
    // Match BONEWORKS: when rendering backfaces only N is flipped; T/B stay unchanged.
    half3x3 tbn = half3x3(
        tangentWS.x, bitangentWS.x, geometricNormalWS.x,
        tangentWS.y, bitangentWS.y, geometricNormalWS.y,
        tangentWS.z, bitangentWS.z, geometricNormalWS.z);
    normalWS = normalize(mul(tbn, normalTS));
#endif

    half NoV = saturate(dot(normalWS, viewDirWS));

    // BONEWORKS transparency/view-angle behavior.
    half alpha = 1.0h;
#if defined(_ALPHABLEND_ON) || defined(_ALPHAPREMULTIPLY_ON) || defined(_ALPHATEST_ON)
    #if defined(_ALPHATEST_ON) || defined(S_UNLIT)
        alpha = baseAlpha;
    #else
        alpha = saturate(baseAlpha + (half(1.0) - NoV) * _Cutoff);
    #endif
    #if defined(_VERTEXTINT)
        alpha *= input.color.a;
    #endif
    #if defined(_ALPHATEST_ON)
        clip(alpha - _Cutoff);
    #endif
#endif

#if defined(_ALPHAPREMULTIPLY_ON)
    albedo *= baseAlpha;
#endif

    half packedMetallic = _Metallic;
    half packedAO = 1.0h;
    half packedSmoothness = _Glossiness;
    half packedEmission = 1.0h;
    half4 packed = 0;

#if defined(S_PACKING_MAES) || defined(S_PACKING_RMA) || defined(S_PACKING_MAS) || defined(S_PACKING_MASK) || defined(S_PACKING_MRA) || defined(S_PACKING_ORM) || defined(S_PACKING_ALLOY) || defined(_METALLICGLOSSMAP)
    packed = SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_MetallicGlossMap, baseUV);
#endif

#if defined(S_PACKING_MAES)
    // MAES: Metallic R, AO G, grayscale Emission B, Smoothness A.
    packedMetallic = packed.r;
    packedAO = packed.g;
    packedSmoothness = packed.a;
    packedEmission = packed.b;
#elif defined(S_PACKING_RMA)
    // RMA: Roughness R, Metallic G, AO B.
    packedMetallic = packed.g;
    packedAO = packed.b;
    packedSmoothness = half(1.0) - packed.r;
#elif defined(S_PACKING_MAS)
    // MAS: Metallic R, AO G, Smoothness B.
    packedMetallic = packed.r;
    packedAO = packed.g;
    packedSmoothness = packed.b;
#elif defined(S_PACKING_MASK)
    // Fan recreation MASK packing: same M/A/S channel extraction as MAES, but B is not emission.
    packedMetallic = packed.r;
    packedAO = packed.g;
    packedSmoothness = packed.a;
#elif defined(S_PACKING_MRA)
    // MRA: Metallic R, Roughness G, AO B.
    packedMetallic = packed.r;
    packedAO = packed.b;
    packedSmoothness = half(1.0) - packed.g;
#elif defined(S_PACKING_ORM)
    // ORM: AO R, Roughness G, Metallic B.
    packedMetallic = packed.b;
    packedAO = packed.r;
    packedSmoothness = half(1.0) - packed.g;
#elif defined(S_PACKING_ALLOY)
    // Alloy: Metallic R, AO G, Roughness A.
    packedMetallic = packed.r;
    packedAO = packed.g;
    packedSmoothness = half(1.0) - packed.a;
#endif

    half3 fluorescence = 0;
#if defined(_FLUORESCENCEMAP) && !defined(S_UNLIT)
    fluorescence = SAMPLE_TEXTURE2D(_FluorescenceMap, sampler_FluorescenceMap, baseUV).rgb * _FluorescenceColor.rgb;
#endif

    half3 albedoPreMetal = albedo;
    half3 reflectance = 0;
    half perceptualRoughness = 1.0h;
    half anisoRotation = _AnisotropicRotation;
    half anisoRatio = _AnisotropicRatio;

#if defined(S_SPECULAR_METALLIC)
    half metallic = _Metallic;
    half smoothness = _Glossiness;
    #if defined(_METALLICGLOSSMAP)
        #if defined(S_PACKING_MAES) || defined(S_PACKING_RMA) || defined(S_PACKING_MAS) || defined(S_PACKING_MASK) || defined(S_PACKING_MRA) || defined(S_PACKING_ORM) || defined(S_PACKING_ALLOY)
            metallic = packedMetallic;
            smoothness = packedSmoothness;
        #else
            metallic = packed.r;
            smoothness = packed.a;
        #endif
    #endif
    BW_AlbedoSpecularFromMetallic(albedo, metallic, reflectance);
    perceptualRoughness = half(1.0) - saturate(smoothness * _SpecMod);

#elif defined(S_SPECULAR_BLINNPHONG)
    half4 specGloss = half4(_SpecColor.rgb, _Glossiness);
    #if defined(_SPECGLOSSMAP)
        specGloss = SAMPLE_TEXTURE2D(_SpecGlossMap, sampler_SpecGlossMap, baseUV);
    #endif
    specGloss.rgb = specGloss.rgb * g_flReflectanceScale + g_flReflectanceBias;
    reflectance = specGloss.rgb;
    perceptualRoughness = half(1.0) - saturate(specGloss.a * _SpecMod);

#elif defined(S_ANISOTROPIC_GLOSS)
    half metallic = _Metallic;
    half smoothness = _Glossiness;
    #if defined(_METALLICGLOSSMAP)
        half4 a = SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_MetallicGlossMap, baseUV).ragb;
        metallic = a.x;
        smoothness = a.y;
        anisoRotation = frac(a.z + _AnisotropicRotation);
        anisoRatio = a.w;
    #endif
    BW_AlbedoSpecularFromMetallic(albedo, metallic, reflectance);
    perceptualRoughness = half(1.0) - saturate(smoothness * _SpecMod);

#elif defined(S_RETROREFLECTIVE)
    half metallic = _Metallic;
    half smoothness = _Glossiness;
    #if defined(_METALLICGLOSSMAP)
        half4 mr = SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_MetallicGlossMap, baseUV);
        metallic = mr.r;
        smoothness = mr.a;
    #endif
    BW_AlbedoSpecularFromMetallic(albedo, metallic, reflectance);
    perceptualRoughness = half(1.0) - saturate(smoothness * _SpecMod);
#endif

#if !defined(SHADER_API_MOBILE) && !defined(S_SPECULAR_NONE) && !defined(S_RETROREFLECTIVE)
    // LitMAS/Valve geometric specular AA: cheaper than projected-space NDF filtering.
    // SLZGeometricSpecularAA returns a smoothness cap, so convert it back to perceptual roughness.
    perceptualRoughness = max(perceptualRoughness, half(1.0) - SLZGeometricSpecularAA(geometricNormalWS));
#endif

    half occlusion = 1.0h;
#if defined(S_OCCLUSION)
    #if defined(S_PACKING_MAES) || defined(S_PACKING_RMA) || defined(S_PACKING_MAS) || defined(S_PACKING_MASK) || defined(S_PACKING_MRA) || defined(S_PACKING_ORM) || defined(S_PACKING_ALLOY)
        occlusion = packedAO;
    #else
        occlusion = SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, baseUV).g;
    #endif
#endif
#if defined(_NORMALMAP) && !defined(S_UNLIT)
    half2 normalABS = abs(normalTS.xy * normalTS.xy);
    half normalOcclusion = (half(1.0) - (normalABS.x + normalABS.y)) * normalTS.z;
    occlusion *= BW_LerpOneTo(normalOcclusion, _NormalToOcclusion);
#endif

    half3 emission = BW_Emission(baseUV, packedEmission, albedoPreMetal, NoV);

    half3 colorRGB;

#if defined(S_UNLIT)
    colorRGB = albedo + emission;
#else
    BWLightingTerms lighting;
    lighting.directDiffuse = 0;
    lighting.directSpecular = 0;
    lighting.indirectDiffuse = 0;
    lighting.indirectSpecular = 0;

    float2 lmUV = 0;
    float2 dynLmUV = 0;
#if defined(LIGHTMAP_ON) || defined(DYNAMICLIGHTMAP_ON)
    lmUV = input.lightmapUV.xy;
    dynLmUV = input.lightmapUV.zw;
#endif

    SLZFragData fragData = SLZGetFragData(input.positionCS, input.positionWS, normalWS, lmUV, dynLmUV, half3(0,0,0));

#if defined(LIGHTMAP_ON)
    // SLZ's helper always samples unity_Lightmap first, so only call it when a static lightmap exists.
    // It will also add the dynamic lightmap when DYNAMICLIGHTMAP_ON is compiled alongside LIGHTMAP_ON.
    SLZSurfData lmSurf = SLZGetSurfDataMetallicGloss(albedo, 0, half(1.0) - perceptualRoughness, occlusion, 0, alpha);
    half3 slzSpecUnused = 0;
    SLZGetLightmapLighting(lighting.indirectDiffuse, slzSpecUnused, fragData, lmSurf);
#elif defined(DYNAMICLIGHTMAP_ON)
    // Dynamic-lightmap-only variants must not call SLZGetLightmapLighting(), because that helper
    // unconditionally samples unity_Lightmap before it reaches the dynamic-lightmap block.
    half3 dynLmDiffuse = SAMPLE_TEXTURE2D(unity_DynamicLightmap, samplerunity_DynamicLightmap, dynLmUV).rgb;
    #if defined(DIRLIGHTMAP_COMBINED) && !defined(SHADER_API_MOBILE)
        half4 dynDirectionalMap = SAMPLE_TEXTURE2D(unity_DynamicDirectionality, samplerunity_DynamicLightmap, dynLmUV);
        half3 dynLmDirection = half(2.0) * dynDirectionalMap.rgb - half(1.0);
        dynLmDiffuse = SLZApplyLightmapDirectionality(dynLmDiffuse, dynLmDirection, normalWS, dynDirectionalMap.w);
    #endif
    lighting.indirectDiffuse = dynLmDiffuse;
#else
    lighting.indirectDiffuse = SampleSHPixel(input.vertexSH, normalWS);
#endif

    // SLZ mobile: one pixel/main light; additional lights are vertex diffuse.
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
    lighting.directDiffuse += input.vertexLightFluor;
#endif

#if !defined(S_SPECULAR_NONE)
    // Directional-lightmap specular is evaluated through the BONEWORKS BRDF. On mobile this automatically
    // selects SLZ's FP16-safe GGX path, matching the cost model of LitMAS without changing the material workflow.
    #if defined(LIGHTMAP_ON) && defined(DIRLIGHTMAP_COMBINED)
        half4 lmDirTex = SAMPLE_TEXTURE2D(unity_LightmapInd, samplerunity_Lightmap, lmUV);
        half3 lmDir = BW_SafeNormalize(lmDirTex.xyz * half(2.0) - half(1.0));
        half4 bakedTerms = BW_ComputeDiffuseSpecular(normalWS, tangentWS, bitangentWS, lmDir, viewDirWS,
                                                      perceptualRoughness, anisoRotation, anisoRatio, reflectance, NoV);
        lighting.indirectSpecular += bakedTerms.yzw * max(lighting.indirectDiffuse, half3(0,0,0));
    #elif !defined(LIGHTMAP_ON) && !defined(DYNAMICLIGHTMAP_ON)
        // Match SLZ's policy: use the SH-L1 fake highlight only when no static or dynamic lightmap is active.
        if (mainLightGate <= REAL_MIN)
        {
            half3 shDir = SLZSHSpecularDirection();
            half4 shTerms = BW_ComputeDiffuseSpecular(normalWS, tangentWS, bitangentWS, shDir, viewDirWS,
                                                       perceptualRoughness, anisoRotation, anisoRatio, reflectance, NoV);
            lighting.indirectSpecular += shTerms.yzw * max(lighting.indirectDiffuse, half3(0,0,0)) * SLZFakeSpecularFalloff(dot(normalWS, shDir));
        }
    #endif
#endif

    // BONEWORKS applies reflectance energy loss to diffuse after the lighting is accumulated.
    // Keep the unmodified baked/SH illumination available to the specular reconstruction above.
    lighting.directDiffuse.rgb *= (half3(1,1,1) - reflectance);
    lighting.directDiffuse.a *= (half(1.0) - reflectance.b);
    lighting.indirectDiffuse *= (half3(1,1,1) - reflectance);

    // SLZ SSR noise is indexed from the rasterized fragment position (SV_POSITION), not from
    // a world->clip reconstruction. This must match SLZGetFragData().screenUV for stable rays.
    float2 screenUV = GetNormalizedScreenSpaceUV(input.positionCS);
    BWEnvironmentSpecularResult environmentSpec = BW_EnvironmentSpecular(input.positionWS, screenUV, viewDirWS, normalWS, geometricNormalWS,
                                                                          tangentWS, bitangentWS, perceptualRoughness,
                                                                          anisoRotation, anisoRatio, reflectance, NoV);
    lighting.indirectSpecular += environmentSpec.probe;
    half3 ssrContribution = environmentSpec.ssr;

    BW_ApplyOcclusion(lighting, occlusion);
    ssrContribution *= BW_LerpOneTo(occlusion, _OcclusionStrength * _OcclusionStrengthIndirectSpecular);

    colorRGB = max(half3(0,0,0), (lighting.directDiffuse.rgb + lighting.indirectDiffuse) * albedo);
    colorRGB = BW_ApplyColorShift(colorRGB, baseUV);

#if defined(_FLUORESCENCEMAP)
    colorRGB = max(colorRGB, BW_Fluorescence(lighting.directDiffuse, lighting.indirectDiffuse, fluorescence));
#endif

#if !defined(S_SPECULAR_NONE)
    colorRGB += lighting.directSpecular;
#endif
    colorRGB += lighting.indirectSpecular;
    colorRGB += emission;
#endif

#if defined(_VERTEXTINT)
    colorRGB *= input.color.rgb;
    #if !defined(S_UNLIT)
        ssrContribution *= input.color.rgb;
    #endif
#endif

#if !defined(S_UNLIT)
    #if defined(_SSR_ENABLED) && !defined(SHADER_API_MOBILE)
        colorRGB += BW_ResolveSSRTemporal(colorRGB, ssrContribution, environmentSpec.ssrLerp,
                                          input.lastClipPos, input.positionWS, viewDirWS, input.fogFactor);
    #else
        colorRGB += ssrContribution;
    #endif
#endif

    half4 outColor = half4(colorRGB, alpha);

#if !defined(S_UNLIT)
    half3 finalViewDir = BW_SafeNormalize((half3)(_WorldSpaceCameraPos - input.positionWS));
#else
    half3 finalViewDir = viewDirWS;
#endif

    outColor = MixFogSurf(outColor, -finalViewDir, input.fogFactor, _Surface);
    outColor = VolumetricsSurf(outColor, input.positionWS, _Surface);

    // Match BONEWORKS ordering: screen dither is the final operation after fog.
    outColor += BW_ScreenSpaceDither(input.positionCS.xy);
    return outColor;
}

#endif
