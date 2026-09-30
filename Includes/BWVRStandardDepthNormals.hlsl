#ifndef BW_VR_STANDARD_DEPTH_NORMALS_INCLUDED
#define BW_VR_STANDARD_DEPTH_NORMALS_INCLUDED

// Common/Core must precede EncodeNormalsTexture on SLZ Core 8148;
// EncodeNormalsTexture reaches Packing.hlsl, which expects `real*` to exist already.
#include "BWVRStandardCommon.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/EncodeNormalsTexture.hlsl"

struct Attributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float2 uv0 : TEXCOORD0;
    float2 uv1 : TEXCOORD1;
    float4 color : COLOR;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS : SV_POSITION;
    float3 positionWS : TEXCOORD0;
    float4 uv01 : TEXCOORD1;
    half4 normalWS_tangentX : TEXCOORD2;
    half4 tangentYZ_bitangentX : TEXCOORD3;
    half bitangentZ : TEXCOORD4;
    half alphaVertex : TEXCOORD5;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

Varyings BWDepthNormalsVert(Attributes input)
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
    output.normalWS_tangentX = half4(ntb.normalWS, ntb.tangentWS.x);
    output.tangentYZ_bitangentX = half4(ntb.tangentWS.yz, ntb.bitangentWS.xy);
    output.bitangentZ = ntb.bitangentWS.z;
    output.alphaVertex = input.color.a;
    return output;
}

half4 BWDepthNormalsFrag(Varyings input, FRONT_FACE_TYPE frontFace : FRONT_FACE_SEMANTIC) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    half faceSign = 1.0h;
#if defined(S_RENDER_BACKFACES)
    faceSign = IS_FRONT_VFACE(frontFace, 1.0h, -1.0h);
#endif

    half3 geometricNormalWS = normalize(input.normalWS_tangentX.xyz) * faceSign;
    half3 tangentWS = normalize(half3(input.normalWS_tangentX.w, input.tangentYZ_bitangentX.xy));
    half3 bitangentWS = normalize(half3(input.tangentYZ_bitangentX.zw, input.bitangentZ));

    float2 baseUV = BW_BaseUV(input.uv01.xy, input.positionWS);
    float2 detailUV = BW_DetailUV(input.uv01.xy, input.uv01.zw, baseUV, input.positionWS);

#if defined(_ALPHATEST_ON)
    half alpha = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, baseUV).a * _Color.a;
    #if defined(_VERTEXTINT)
        alpha *= input.alphaVertex;
    #endif
    clip(alpha - _Cutoff);
#endif

    half3 normalWS = geometricNormalWS;
#if defined(_NORMALMAP) && !defined(S_UNLIT)
    half3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, baseUV), _BumpScale);
    normalTS = BW_ApplyDetailNormal(normalTS, baseUV, detailUV);
    half3x3 tbn = half3x3(
        tangentWS.x, bitangentWS.x, geometricNormalWS.x,
        tangentWS.y, bitangentWS.y, geometricNormalWS.y,
        tangentWS.z, bitangentWS.z, geometricNormalWS.z);
    normalWS = normalize(mul(tbn, normalTS));
#endif

    return half4(EncodeWSNormalForNormalsTex(normalWS), 0);
}

#endif
