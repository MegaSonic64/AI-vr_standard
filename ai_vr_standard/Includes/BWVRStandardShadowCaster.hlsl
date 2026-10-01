#ifndef BW_VR_STANDARD_SHADOW_CASTER_INCLUDED
#define BW_VR_STANDARD_SHADOW_CASTER_INCLUDED

#include "BWVRStandardCommon.hlsl"

TEXTURE3D(_DitherMaskLOD);
SAMPLER(sampler_DitherMaskLOD);

float3 _LightDirection;
float3 _LightPosition;

struct Attributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float2 uv0 : TEXCOORD0;
    float4 color : COLOR;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS : SV_POSITION;
    float2 uv0 : TEXCOORD0;
    half vertexAlpha : TEXCOORD1;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

inline float2 BW_GetShadowOffsets(float3 N, float3 L)
{
    float cosAlpha = saturate(dot(N, L));
    float offsetN = sqrt(max(0.0, 1.0 - cosAlpha * cosAlpha));
    float offsetL = offsetN / max(cosAlpha, 1e-4);
    return float2(offsetN, min(2.0, offsetL));
}

inline float4 BW_GetShadowPositionHClip(Attributes input)
{
    float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
    float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
#if defined(_CASTING_PUNCTUAL_LIGHT_SHADOW)
    float3 lightDirectionWS = normalize(_LightPosition - positionWS);
#else
    float3 lightDirectionWS = _LightDirection;
#endif
    float2 offsets = BW_GetShadowOffsets(normalWS, lightDirectionWS);
    positionWS -= offsets.y * lightDirectionWS * 0.01;
    float4 positionCS = TransformWorldToHClip(positionWS);
#if UNITY_REVERSED_Z
    positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
#else
    positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
#endif
    return positionCS;
}

Varyings BWShadowVert(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    output.positionCS = BW_GetShadowPositionHClip(input);
    output.uv0 = input.uv0;
    output.vertexAlpha = input.color.a;
    return output;
}

half4 BWShadowFrag(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);

    // BONEWORKS shadow replacement shader always used ordinary UV0, even for world-aligned Forward materials.
    float2 uv = input.uv0 * _MainTex_ST.xy + _MainTex_ST.zw;
    half alpha = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv).a * _Color.a;

    if (_Mode > 1.5h)
    {
        // All ValveTransparent modes shared the same dithered shadow caster and always used vertex alpha.
        alpha *= input.vertexAlpha;
        float dither = SAMPLE_TEXTURE3D(_DitherMaskLOD, sampler_DitherMaskLOD,
                                        float3(input.positionCS.xy * 0.25, alpha * 0.9475)).a;
        clip(dither - 0.01);
    }
    else if (_Mode > 0.5h)
    {
        // AlphaTest shadow did NOT multiply vertex alpha in BONEWORKS.
        clip(alpha - _Cutoff);
    }

    return 0;
}

#endif
