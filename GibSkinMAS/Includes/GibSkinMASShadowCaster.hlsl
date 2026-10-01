#ifndef BW_GIBSKIN_MAS_SHADOW_CASTER_INCLUDED
#define BW_GIBSKIN_MAS_SHADOW_CASTER_INCLUDED
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

float3 _LightDirection;
float3 _LightPosition;

struct Attributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};
struct Varyings
{
    float4 positionCS : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

float2 GibGetShadowOffsets(float3 N, float3 L)
{
    float cosAlpha = saturate(dot(N, L));
    float offsetN = sqrt(max(0.0, 1.0 - cosAlpha * cosAlpha));
    float offsetL = offsetN / max(cosAlpha, 1e-4);
    return float2(offsetN, min(2.0, offsetL));
}

float4 GibGetShadowPositionHClip(Attributes input)
{
    float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
    float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
#if defined(_CASTING_PUNCTUAL_LIGHT_SHADOW)
    float3 lightDirectionWS = normalize(_LightPosition - positionWS);
#else
    float3 lightDirectionWS = _LightDirection;
#endif
    float2 offsets = GibGetShadowOffsets(normalWS, lightDirectionWS);
    positionWS -= offsets.y * lightDirectionWS * 0.01;
    float4 positionCS = TransformWorldToHClip(positionWS);
#if UNITY_REVERSED_Z
    positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
#else
    positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
#endif
    return positionCS;
}

Varyings GibShadowVert(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    output.positionCS = GibGetShadowPositionHClip(input);
    return output;
}
half4 GibShadowFrag(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    return 0;
}
#endif
