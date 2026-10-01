Shader "SLZ/Valve/GibSkinMAS"
{
    Properties
    {
        [NoScaleOffset][MainTexture]_MainTex("Main Texture", 2D) = "white" {}
        [MainColor]_Color("Color", Color) = (1,1,1,1)
        [NoScaleOffset][Normal]_BumpMap("Normal", 2D) = "bump" {}
        [NoScaleOffset]_MetallicGlossMap("MAS Metallic", 2D) = "white" {}

        [Space(20)][Header(Bloody Properties)]
        [NoScaleOffset]_BloodyTex("BloodyTex", 2D) = "white" {}
        _BloodyColor("BloodyColor", Color) = (1,1,1,0.5607843)
        _BloodyTexScale("Bloody Tex Scaling", Float) = 1
        [NoScaleOffset][Normal]_BloodyNormal("BloodyNormal", 2D) = "bump" {}
        _BloodyNormalScale("Bloody Normal Scale", Float) = 1
        _BloodyMetallic("BloodyMetallic", Range(0,1)) = 0
        _BloodySmoothness("BloodySmoothness", Range(0,1)) = 0
        [HideInInspector][PerRendererData]_NumberOfElipsoids("NumberOfElipsoids", Int) = 0
        [HideInInspector][PerRendererData]_NumberOfHits("Number Of Hits", Int) = 0
        _Power("Power", Float) = 0.25

        [NoScaleOffset]_FluorescenceMap("Fluorescence Map", 2D) = "black" {}
        _Absorbance("Absorbance", Color) = (0.469,0.636,0.832,1)
        _DetailAlbedoMap("Detail Albedo Map", 2D) = "gray" {}
        [NoScaleOffset][Normal]_DetailNormalMap("Detail Normal Map", 2D) = "bump" {}
        _DetailNormalMapScale("Detail Normal Map Scale", Float) = 1

        [Space(20)][Header(General Properties)]
        [KeywordEnum(Specular_Metallic, Anisotropic_Gloss, Retroreflective)] S("Specular mode", Float) = 0
        g_flFresnelFalloff("Fresnel Falloff Scalar", Range(0,10)) = 1
        g_flFresnelExponent("Fresnel Exponent", Range(0.5,10)) = 5
        [Space(5)]
        [Toggle(_BRDFMAP)] EnableBRDFMAP("Enable BRDF remap", Int) = 0
        [NoScaleOffset]g_tBRDFMap("BRDF LUT", 2D) = "grey" {}

        [Space(10)][Header(Override Properties)]
        g_flCubeMapScalar("Cube Map Scalar", Range(0,2)) = 1
        [Toggle(S_RECEIVE_SHADOWS)] ReceiveShadows("Receive Shadows", Int) = 1
        [Toggle(_FLUORESCENCEMAP)] Fluorescence("Enable Fluorescence", Int) = 0

        [Space(20)][Header(Screen Space Reflections)]
        [Toggle(_NO_SSR)] _SSROff("Disable SSR", Float) = 0
        _SSRTemporalMul("Temporal Accumulation Factor", Range(0,2)) = 0.0

        [HideInInspector]_Surface("Surface Type", Float) = 0
        [HideInInspector]_Cull("Cull", Float) = 2
    }

    // Vulkan/mobile subshader: matches LitMAS' split so PlatformCompiler can select mobile-safe code cleanly.
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" "Queue"="Geometry" "PerformanceChecks"="False" }
        LOD 200
        ZTest LEqual
        ColorMask RGBA

        Pass
        {
            Name "Forward"
            Tags { "LightMode"="UniversalForward" }
            Blend One Zero
            ZWrite On
            Cull [_Cull]
            HLSLPROGRAM
            #pragma only_renderers vulkan
            #pragma target 5.0
            #pragma vertex GibVert
            #pragma fragment GibFrag

            #pragma multi_compile S_SPECULAR_METALLIC S_ANISOTROPIC_GLOSS S_RETROREFLECTIVE
            #pragma shader_feature_local_fragment _BRDFMAP
            #pragma shader_feature_local_fragment S_RECEIVE_SHADOWS
            #pragma shader_feature_local _FLUORESCENCEMAP

            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile_fragment _ _VOLUMETRICS_ENABLED
            #pragma multi_compile_fog
            #pragma skip_variants FOG_LINEAR FOG_EXP
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer

            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/PlatformCompiler.hlsl"
            #include_with_pragmas "Includes/GibSkinMASForward.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode"="DepthOnly" }
            ZWrite On
            Cull [_Cull]
            ColorMask 0
            HLSLPROGRAM
            #pragma only_renderers vulkan
            #pragma target 4.5
            #pragma vertex GibDepthVert
            #pragma fragment GibDepthFrag
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/PlatformCompiler.hlsl"
            #include "Includes/GibSkinMASDepthOnly.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "DepthNormals"
            Tags { "LightMode"="DepthNormals" }
            ZWrite On
            Cull [_Cull]
            HLSLPROGRAM
            #pragma only_renderers vulkan
            #pragma target 5.0
            #pragma vertex GibDepthNormalsVert
            #pragma fragment GibDepthNormalsFrag
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/PlatformCompiler.hlsl"
            #include "Includes/GibSkinMASDepthNormals.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode"="ShadowCaster" }
            ZWrite On
            ZTest LEqual
            Cull [_Cull]
            ColorMask 0
            HLSLPROGRAM
            #pragma only_renderers vulkan
            #pragma target 4.5
            #pragma vertex GibShadowVert
            #pragma fragment GibShadowFrag
            #pragma multi_compile _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/PlatformCompiler.hlsl"
            #include "Includes/GibSkinMASShadowCaster.hlsl"
            ENDHLSL
        }
    }

    // Desktop/non-Vulkan subshader.
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" "Queue"="Geometry" "PerformanceChecks"="False" }
        LOD 200
        ZTest LEqual
        ColorMask RGBA

        Pass
        {
            Name "Forward"
            Tags { "LightMode"="UniversalForward" }
            Blend One Zero
            ZWrite On
            Cull [_Cull]
            HLSLPROGRAM
            #pragma exclude_renderers vulkan
            #pragma target 5.0
            #pragma vertex GibVert
            #pragma fragment GibFrag

            #pragma multi_compile S_SPECULAR_METALLIC S_ANISOTROPIC_GLOSS S_RETROREFLECTIVE
            #pragma shader_feature_local_fragment _BRDFMAP
            #pragma shader_feature_local_fragment S_RECEIVE_SHADOWS
            #pragma shader_feature_local _FLUORESCENCEMAP

            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile_fragment _ _VOLUMETRICS_ENABLED
            #pragma multi_compile_fog
            #pragma skip_variants FOG_LINEAR FOG_EXP
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer

            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/PlatformCompiler.hlsl"
            #include_with_pragmas "Includes/GibSkinMASForward.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode"="DepthOnly" }
            ZWrite On
            Cull [_Cull]
            ColorMask 0
            HLSLPROGRAM
            #pragma exclude_renderers vulkan
            #pragma target 4.5
            #pragma vertex GibDepthVert
            #pragma fragment GibDepthFrag
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/PlatformCompiler.hlsl"
            #include "Includes/GibSkinMASDepthOnly.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "DepthNormals"
            Tags { "LightMode"="DepthNormals" }
            ZWrite On
            Cull [_Cull]
            HLSLPROGRAM
            #pragma exclude_renderers vulkan
            #pragma target 5.0
            #pragma vertex GibDepthNormalsVert
            #pragma fragment GibDepthNormalsFrag
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/PlatformCompiler.hlsl"
            #include "Includes/GibSkinMASDepthNormals.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode"="ShadowCaster" }
            ZWrite On
            ZTest LEqual
            Cull [_Cull]
            ColorMask 0
            HLSLPROGRAM
            #pragma exclude_renderers vulkan
            #pragma target 4.5
            #pragma vertex GibShadowVert
            #pragma fragment GibShadowFrag
            #pragma multi_compile _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/PlatformCompiler.hlsl"
            #include "Includes/GibSkinMASShadowCaster.hlsl"
            ENDHLSL
        }
    }

    FallBack Off
}
