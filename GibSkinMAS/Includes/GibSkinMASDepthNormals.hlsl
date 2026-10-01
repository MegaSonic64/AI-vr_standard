#ifndef BW_GIBSKIN_MAS_DEPTH_NORMALS_INCLUDED
#define BW_GIBSKIN_MAS_DEPTH_NORMALS_INCLUDED
#include "GibSkinMASCommon.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/EncodeNormalsTexture.hlsl"

struct Attributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float2 uv0 : TEXCOORD0;
    float4 uv1 : TEXCOORD1;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};
struct Varyings
{
    float4 positionCS : SV_POSITION;
    float2 uv0 : TEXCOORD0;
    float3 poseSpace : TEXCOORD1;
    half4 normalWS_tangentX : TEXCOORD2;
    half4 tangentYZ_bitangentX : TEXCOORD3;
    half bitangentZ : TEXCOORD4;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};
Varyings GibDepthNormalsVert(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
    VertexPositionInputs pos = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs ntb = GetVertexNormalInputs(input.normalOS, input.tangentOS);
    output.positionCS = pos.positionCS;
    output.uv0 = input.uv0;
    output.poseSpace = input.uv1.xyz;
    output.normalWS_tangentX = half4(ntb.normalWS, ntb.tangentWS.x);
    output.tangentYZ_bitangentX = half4(ntb.tangentWS.yz, ntb.bitangentWS.xy);
    output.bitangentZ = ntb.bitangentWS.z;
    return output;
}
half4 GibDepthNormalsFrag(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    half3 geometricNormalWS = normalize(input.normalWS_tangentX.xyz);
    half3 tangentWS = normalize(half3(input.normalWS_tangentX.w, input.tangentYZ_bitangentX.xy));
    half3 bitangentWS = normalize(half3(input.tangentYZ_bitangentX.zw, input.bitangentZ));

    GibHitData hit = GibEvaluateHits(input.poseSpace, geometricNormalWS);
    half3 normalTS = GibSurfaceNormalTS(input.uv0, input.poseSpace, hit.hits);
    half3x3 tbn = half3x3(
        tangentWS.x, bitangentWS.x, geometricNormalWS.x,
        tangentWS.y, bitangentWS.y, geometricNormalWS.y,
        tangentWS.z, bitangentWS.z, geometricNormalWS.z);
    half3 normalWS = normalize(mul(tbn, normalTS));
    return half4(EncodeWSNormalForNormalsTex(normalWS), 0);
}
#endif
