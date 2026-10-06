#ifndef BW_VR_STANDARD_META_INCLUDED
#define BW_VR_STANDARD_META_INCLUDED

// Pull in URP Core/Input first so MetaPass sees unity_LightmapST/unity_DynamicLightmapST.
#include "BWVRStandardCommon.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/MetaInput.hlsl"

struct Attributes
{
    float4 positionOS : POSITION;
    float2 uv0 : TEXCOORD0;
    float2 uv1 : TEXCOORD1;
    float2 uv2 : TEXCOORD2;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS : SV_POSITION;

    // Match BIRP UnityStandardInput::TexCoords():
    //   xy = transformed UV0 for the base texture
    //   zw = transformed UV0/UV1 for detail textures, selected by _UVSec
    float4 texcoord : TEXCOORD0;

#ifdef EDITOR_VISUALIZATION
    float2 vizUV : TEXCOORD1;
    float4 lightCoord : TEXCOORD2;
#endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

Varyings BWMetaVert(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    output.positionCS = UnityMetaVertexPosition(input.positionOS.xyz, input.uv1, input.uv2);

    output.texcoord.xy = input.uv0 * _MainTex_ST.xy + _MainTex_ST.zw;
    float2 detailSourceUV = (_UVSec < 0.5h) ? input.uv0 : input.uv1;
    output.texcoord.zw = detailSourceUV * _DetailAlbedoMap_ST.xy + _DetailAlbedoMap_ST.zw;

#ifdef EDITOR_VISUALIZATION
    UnityEditorVizData(input.positionOS.xyz, input.uv0, input.uv1, input.uv2, output.vizUV, output.lightCoord);
#endif
    return output;
}

// -----------------------------------------------------------------------------
// BIRP vr_standard Meta compatibility
// -----------------------------------------------------------------------------
// Kevin Comerford's BONEWORKS vr_standard Meta pass includes UnityStandardMeta
// without defining UNITY_SETUP_BRDF_INPUT. Unity 2018 therefore falls back to
// SpecularSetup. That pass also does not compile _SPECGLOSSMAP, so the Meta pass
// deliberately uses the scalar _SpecColor + _Glossiness pair, regardless of the
// forward-pass specular workflow or the assigned specular/metallic textures.
//
// UnityStandardConfig enables monochrome specular energy conservation:
//   diffColor = albedo * (1 - max(specColor))
//
// UnityStandardMeta then biases lightmapping albedo by rough specular energy:
//   lightmapAlbedo = diffColor + specColor * roughness * 0.5
//   roughness      = (1 - smoothness)^2
//
// Preserve those exact observable bake semantics here rather than switching the
// Meta pass to ai_vr_standard's forward metallic/specular workflow.
inline half3 BW_BIRPSpecularMetaDiffuse(half3 albedo, half3 specColor)
{
    half specularStrength = max(max(specColor.r, specColor.g), specColor.b);
    half oneMinusReflectivity = half(1.0) - specularStrength;
    return albedo * oneMinusReflectivity;
}

inline half3 BW_BIRPLightmappingAlbedo(half3 diffuse, half3 specular, half smoothness)
{
    half perceptualRoughness = half(1.0) - smoothness;
    half roughness = perceptualRoughness * perceptualRoughness;
    return diffuse + specular * roughness * half(0.5);
}

half4 BWMetaFrag(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    MetaInput meta = (MetaInput)0;

    const float2 baseUV = input.texcoord.xy;
    const float2 detailUV = input.texcoord.zw;

    // Unity Standard Albedo(): Base texture * material color, then detail.
    half4 baseSample = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, baseUV) * _Color;
    half3 albedo = baseSample.rgb;

    // The original BIRP vr_standard Meta pass only compiled _DETAIL_MULX2.
    // Keep that behavior, plus ai_vr_standard's newer HDRP packed-detail mode.
#if defined(_DETAIL_MULX2) || defined(_DETAIL_HDRP)
    half mask = BW_DetailMask(baseUV);
    #if defined(_DETAIL_HDRP)
        half4 detailMap = SAMPLE_TEXTURE2D(_DetailAlbedoMap, sampler_DetailAlbedoMap, detailUV);
        albedo = BW_ApplyHDRPDetailAlbedo(albedo, detailMap, mask);
    #else
        half3 detail = SAMPLE_TEXTURE2D(_DetailAlbedoMap, sampler_DetailAlbedoMap, detailUV).rgb;
        albedo *= lerp(half3(1,1,1), detail * BW_COLORSPACE_DOUBLE_RGB, mask);
    #endif
#endif

    // Match the original BIRP Meta pass's implicit SpecularSetup path.
    // Do NOT sample _SpecGlossMap here and do NOT branch on _SpecularMode.
    half3 specColor = _SpecColor.rgb;
    half smoothness = _Glossiness;
    half3 diffuseColor = BW_BIRPSpecularMetaDiffuse(albedo, specColor);

#ifdef EDITOR_VISUALIZATION
    // UnityStandardMeta uses the energy-conserved diffuse color directly for
    // editor visualization instead of its rough-specular lightmapping bias.
    meta.Albedo = diffuseColor;
#else
    meta.Albedo = BW_BIRPLightmappingAlbedo(diffuseColor, specColor, smoothness);
#endif

    // Keep ai_vr_standard's packed-emission extension while matching the
    // original Meta albedo/specular treatment above.
    half packedEmission = 1.0h;
#if defined(S_PACKING_MAES)
    packedEmission = SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_MetallicGlossMap, baseUV).b;
#endif

#if defined(_EMISSION)
    meta.Emission = BW_BakedEmission(baseUV, packedEmission, albedo);
#endif

#ifdef EDITOR_VISUALIZATION
    meta.VizUV = input.vizUV;
    meta.LightCoord = input.lightCoord;
#endif
    return MetaFragment(meta);
}

#endif
