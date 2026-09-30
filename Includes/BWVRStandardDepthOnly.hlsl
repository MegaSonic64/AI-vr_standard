#ifndef BW_VR_STANDARD_DEPTH_ONLY_INCLUDED
#define BW_VR_STANDARD_DEPTH_ONLY_INCLUDED

#include "BWVRStandardCommon.hlsl"

struct Attributes
{
    float4 positionOS : POSITION;
    float2 uv0 : TEXCOORD0;
    float4 color : COLOR;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS : SV_POSITION;
    float3 positionWS : TEXCOORD0;
    float2 uv0 : TEXCOORD1;
    half alphaVertex : TEXCOORD2;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

Varyings BWDepthVert(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
    VertexPositionInputs pos = GetVertexPositionInputs(input.positionOS.xyz);
    output.positionCS = pos.positionCS;
    output.positionWS = pos.positionWS;
    output.uv0 = input.uv0;
    output.alphaVertex = input.color.a;
    return output;
}

half4 BWDepthFrag(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
#if defined(_ALPHATEST_ON)
    float2 uv = BW_BaseUV(input.uv0, input.positionWS);
    half alpha = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv).a * _Color.a;
    #if defined(_VERTEXTINT)
        alpha *= input.alphaVertex;
    #endif
    clip(alpha - _Cutoff);
#endif
    return 0;
}

#endif
