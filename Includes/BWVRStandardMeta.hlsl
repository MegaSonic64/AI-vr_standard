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
    float2 uv : TEXCOORD0;
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
    output.uv = input.uv0 * _MainTex_ST.xy + _MainTex_ST.zw;
#ifdef EDITOR_VISUALIZATION
    UnityEditorVizData(input.positionOS.xyz, input.uv0, input.uv1, input.uv2, output.vizUV, output.lightCoord);
#endif
    return output;
}

half4 BWMetaFrag(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    MetaInput meta = (MetaInput)0;
    half4 baseSample = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv) * _Color;
    half3 albedo = baseSample.rgb;

#if defined(_DETAIL_MULX2)
    half mask = BW_DetailMask(input.uv);
    float2 detailUV = input.uv * _DetailAlbedoMap_ST.xy + _DetailAlbedoMap_ST.zw;
    half3 detail = SAMPLE_TEXTURE2D(_DetailAlbedoMap, sampler_DetailAlbedoMap, detailUV).rgb;
    albedo *= lerp(half3(1,1,1), detail * BW_COLORSPACE_DOUBLE_RGB, mask);
#endif

    half packedEmission = 1.0h;
#if defined(S_PACKING_MAES)
    packedEmission = SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_MetallicGlossMap, input.uv).b;
#endif

    meta.Albedo = albedo;
#if defined(_EMISSION)
    meta.Emission = BW_BakedEmission(input.uv, packedEmission, albedo);
#endif

#ifdef EDITOR_VISUALIZATION
    meta.VizUV = input.vizUV;
    meta.LightCoord = input.lightCoord;
#endif
    return MetaFragment(meta);
}

#endif
