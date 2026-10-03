Shader "SLZ/Valve/ai_vr_standard"
{
    Properties
    {
        [HideInInspector][Toggle(S_UNLIT)] g_bUnlit("g_bUnlit", Int) = 0
        [HideInInspector] _Color("Color", Color) = (1,1,1,1)
        [HideInInspector] _MainTex("Albedo", 2D) = "white" {}
        [HideInInspector] g_tBRDFMap("BRDF Map", 2D) = "grey" {}
        [HideInInspector] _ColorMask("Color Mask", 2D) = "white" {}
        [HideInInspector] _ColorShift1("Color Shift 1", Color) = (1,1,1,1)
        [HideInInspector] _ColorShift2("Color Shift 2", Color) = (1,1,1,1)
        [HideInInspector] _ColorShift3("Color Shift 3", Color) = (1,1,1,1)
        [HideInInspector] _Cutoff("Alpha Cutoff", Range(0,1)) = 0.5
        [HideInInspector] _Glossiness("Smoothness", Range(0,1)) = 0.5
        [HideInInspector] _AnisotropicRotation("Anisotropic Rotation", Range(0,1)) = 0.5
        [HideInInspector][Gamma] _AnisotropicRatio("Anisotropic Ratio", Range(0,1)) = 0.5
        [HideInInspector] _SpecColor("Specular", Color) = (0.2,0.2,0.2,1)
        [HideInInspector] _SpecGlossMap("Specular", 2D) = "white" {}
        [HideInInspector] g_flReflectanceMin("g_flReflectanceMin", Range(0,1)) = 0
        [HideInInspector] g_flReflectanceMax("g_flReflectanceMax", Range(0,1)) = 1
        [HideInInspector] g_flReflectanceScale("g_flReflectanceScale", Range(0,1)) = 1
        [HideInInspector] g_flReflectanceBias("g_flReflectanceBias", Range(0,1)) = 0
        [HideInInspector][Gamma] _Metallic("Metallic", Range(0,1)) = 0
        [HideInInspector] _MetallicGlossMap("Metallic", 2D) = "black" {}
        [HideInInspector] _SpecMod("Specular Mod", Range(0,2)) = 1
        [HideInInspector] _BumpScale("Scale", Float) = 1
        [HideInInspector][Normal] _BumpMap("Normal Map", 2D) = "bump" {}
        [HideInInspector] _NormalToOcclusion("Normal To Occlusion", Range(0,2)) = 1
        [HideInInspector] _Parallax("Height Scale", Float) = -0.02
        [HideInInspector] _ParallaxMap("Height Map", 2D) = "black" {}
        [HideInInspector] _ParallaxIterations("Parallax Iterations", Range(1,32)) = 1
        [HideInInspector] _ParallaxOffset("Parallax Offset", Float) = 0
        [HideInInspector] _OcclusionStrength("Strength", Range(0,1)) = 1
        [HideInInspector] _OcclusionMap("Occlusion", 2D) = "white" {}
        [HideInInspector] _OcclusionStrengthDirectDiffuse("StrengthDirectDiffuse", Range(0,1)) = 1
        [HideInInspector] _OcclusionStrengthDirectSpecular("StrengthDirectSpecular", Range(0,1)) = 1
        [HideInInspector] _OcclusionStrengthIndirectDiffuse("StrengthIndirectDiffuse", Range(0,1)) = 1
        [HideInInspector] _OcclusionStrengthIndirectSpecular("StrengthIndirectSpecular", Range(0,1)) = 1
        [HideInInspector] g_flFresnelFalloff("Fresnel Falloff Scalar", Range(0,2)) = 1
        [HideInInspector] g_flFresnelExponent("Fresnel Exponent", Range(0.5,10)) = 5
        [HideInInspector] g_flCubeMapScalar("Cube Map Scalar", Range(0,2)) = 1
        [HideInInspector][HDR] _EmissionColor("Emissive Color", Color) = (0,0,0,0)
        [HideInInspector] _EmissionMap("Emission", 2D) = "white" {}
        [HideInInspector] _EmissionFalloff("Emission Falloff", Range(0,10)) = 0
        [HideInInspector] _FluorescenceMap("Fluorescence", 2D) = "white" {}
        [HideInInspector] _FluorescenceColor("Fluorescence Color", Color) = (0,0,0,0)
        [HideInInspector] _Absorbance("Absorbance Color", Color) = (0.1,0.25,0.5,1)
        [HideInInspector] _DetailMask("Detail Mask", 2D) = "white" {}
        [HideInInspector] _DetailAlbedoMap("Detail Albedo x2", 2D) = "grey" {}
        [HideInInspector] _DetailNormalMapScale("Scale", Float) = 1
        [HideInInspector] _DetailNormalMap("Normal Map", 2D) = "bump" {}
        [HideInInspector][Enum(UV0,0,UV1,1)] _UVSec("UV Set for secondary textures", Float) = 0
        [HideInInspector][Toggle(D_CASTSHADOW)] g_bCastShadows("g_bCastShadows", Int) = 1
        [HideInInspector][Toggle(S_RECEIVE_SHADOWS)] g_bReceiveShadows("g_bReceiveShadows", Int) = 1
        [HideInInspector][Toggle(S_RENDER_BACKFACES)] g_bRenderBackfaces("g_bRenderBackfaces", Int) = 0
        [HideInInspector][Toggle(S_EMISSIVE_MULTI)] _EmissiveMode("__emissiveMode", Int) = 0
        [HideInInspector][Toggle(S_WORLD_ALIGNED_TEXTURE)] g_bWorldAlignedTexture("g_bWorldAlignedTexture", Int) = 0
        [HideInInspector] g_vWorldAlignedTextureSize("g_vWorldAlignedTextureSize", Vector) = (1,1,1,0)
        [HideInInspector] g_vWorldAlignedTextureNormal("g_vWorldAlignedTextureNormal", Vector) = (0,1,0,0)
        [HideInInspector] g_vWorldAlignedTexturePosition("g_vWorldAlignedTexturePosition", Vector) = (0,0,0,0)
        [HideInInspector] g_vWorldAlignedNormalTangentU("g_vWorldAlignedNormalTangentU", Vector) = (-1,0,0,0)
        [HideInInspector] g_vWorldAlignedNormalTangentV("g_vWorldAlignedNormalTangentV", Vector) = (0,0,1,0)
        [HideInInspector] _SpecularMode("__specularmode", Int) = 1
        [HideInInspector] _Cull("__cull", Int) = 2
        [HideInInspector] _ShadowCull("__shadowcull", Int) = 2
        [HideInInspector] _VertexMode("__VetexMode", Int) = 0
        [HideInInspector] _PackingMode("__PackingMode", Int) = 0
        [HideInInspector] _DetailMode("__DetailMode", Int) = 0
        [HideInInspector] _Mode("__mode", Float) = 0
        [HideInInspector] _SrcBlend("__src", Float) = 1
        [HideInInspector] _DstBlend("__dst", Float) = 0
        [HideInInspector] _ZWrite("__zw", Float) = 1
        [HideInInspector] _FogMultiplier("__fogmult", Float) = 1
        [HideInInspector] _OffsetFactor("__fac", Float) = 0
        [HideInInspector] _OffsetUnits("__units", Float) = 0
        [HideInInspector] _ColorMultiplier("target color", Float) = 0
        [HideInInspector] _Multiplier("Multiplier", Float) = 1
        [HideInInspector][Toggle(_ALPHA_ON)] _alpha("Alpha", Float) = 0
        [HideInInspector] _SpecularHorizonOcclusion("SLZ Specular Horizon Occlusion", Float) = 1
        [HideInInspector] _Surface("__surface", Int) = 0
        [HideInInspector][Toggle(_NO_SSR)] _SSROff("Disable SSR", Float) = 0
        [HideInInspector] _SSRTemporalMul("Temporal Accumulation Factor", Range(0, 2)) = 1.0
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" "Queue"="Geometry" "PerformanceChecks"="False" }
        LOD 300
        ZTest LEqual
        ColorMask RGBA

        Pass
        {
            Name "Forward"
            Tags { "LightMode"="UniversalForward" }
            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]
            Cull [_Cull]
            Offset [_OffsetFactor], [_OffsetUnits]
            HLSLPROGRAM
            #pragma only_renderers vulkan
            #pragma target 5.0
            #pragma vertex BWVert
            #pragma fragment BWFrag

            #pragma shader_feature _VERTEXTINT
            #pragma shader_feature _ALPHATEST_ON
            #pragma shader_feature _ALPHABLEND_ON
            #pragma shader_feature _ALPHAPREMULTIPLY_ON
            #pragma shader_feature _ALPHAMULTIPLY_ON
            #pragma shader_feature _ALPHAMOD2X_ON
            #pragma shader_feature _ALPHA_ON
            #pragma shader_feature _EMISSION
            #pragma shader_feature S_EMISSIVE_MULTI
            #pragma shader_feature _DETAIL_MULX2
            #pragma shader_feature _DETAIL_MUL
            #pragma shader_feature _DETAIL_ADD
            #pragma shader_feature _DETAIL_LERP
            #pragma shader_feature _DETAIL_HDRP
            #if !defined(SHADER_API_MOBILE)
                #pragma shader_feature _PARALLAXMAP
            #endif
            #pragma shader_feature _COLORSHIFT
            #pragma shader_feature S_WORLD_ALIGNED_TEXTURE
            #pragma shader_feature S_RENDER_BACKFACES
            #pragma shader_feature S_UNLIT
            #pragma shader_feature _NORMALMAP
            #pragma shader_feature _FLUORESCENCEMAP
            #pragma shader_feature S_SPECULAR_NONE
            #pragma shader_feature S_SPECULAR_BLINNPHONG
            #pragma shader_feature S_SPECULAR_METALLIC
            #pragma shader_feature S_ANISOTROPIC_GLOSS
            #pragma shader_feature S_RETROREFLECTIVE
            #pragma shader_feature _METALLICGLOSSMAP
            #pragma shader_feature _SPECGLOSSMAP
            #pragma shader_feature S_PACKING_RMA
            #pragma shader_feature S_PACKING_MAES
            #pragma shader_feature S_PACKING_MAS
            #pragma shader_feature S_PACKING_MASK
            #pragma shader_feature S_PACKING_MRA
            #pragma shader_feature S_PACKING_ORM
            #pragma shader_feature S_PACKING_ALLOY
            #pragma shader_feature S_OCCLUSION
            #pragma shader_feature _BRDFMAP
            #pragma shader_feature S_RECEIVE_SHADOWS

            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile_fragment _ _VOLUMETRICS_ENABLED
            #pragma multi_compile_fog
            #pragma skip_variants FOG_LINEAR FOG_EXP
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer

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
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/PlatformCompiler.hlsl"
            #include "Includes/BWVRStandardForward.hlsl"
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
            #pragma vertex BWDepthVert
            #pragma fragment BWDepthFrag
            #pragma shader_feature _ALPHATEST_ON
            #pragma shader_feature _VERTEXTINT
            #pragma shader_feature S_WORLD_ALIGNED_TEXTURE
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/PlatformCompiler.hlsl"
            #include "Includes/BWVRStandardDepthOnly.hlsl"
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
            #pragma target 4.5
            #pragma vertex BWDepthNormalsVert
            #pragma fragment BWDepthNormalsFrag
            #pragma shader_feature _ALPHATEST_ON
            #pragma shader_feature _VERTEXTINT
            #pragma shader_feature S_WORLD_ALIGNED_TEXTURE
            #pragma shader_feature S_RENDER_BACKFACES
            #pragma shader_feature S_UNLIT
            #pragma shader_feature _NORMALMAP
            #pragma shader_feature _DETAIL_MULX2
            #pragma shader_feature _DETAIL_MUL
            #pragma shader_feature _DETAIL_ADD
            #pragma shader_feature _DETAIL_LERP
            #pragma shader_feature _DETAIL_HDRP
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/PlatformCompiler.hlsl"
            #include "Includes/BWVRStandardDepthNormals.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode"="ShadowCaster" }
            ZWrite On
            ZTest LEqual
            Cull [_ShadowCull]
            ColorMask 0
            HLSLPROGRAM
            #pragma only_renderers vulkan
            #pragma target 4.5
            #pragma vertex BWShadowVert
            #pragma fragment BWShadowFrag
            #pragma multi_compile _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/PlatformCompiler.hlsl"
            #include "Includes/BWVRStandardShadowCaster.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "Meta"
            Tags { "LightMode"="Meta" }
            Cull Off
            HLSLPROGRAM
            #pragma only_renderers vulkan
            #pragma target 4.5
            #pragma vertex BWMetaVert
            #pragma fragment BWMetaFrag
            #pragma shader_feature _EMISSION
            #pragma shader_feature S_EMISSIVE_MULTI
            #pragma shader_feature _DETAIL_MULX2
            #pragma shader_feature _DETAIL_HDRP
            #pragma shader_feature S_PACKING_MAES
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/PlatformCompiler.hlsl"
            #include "Includes/BWVRStandardMeta.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "BakedRaytrace"
            Tags { "LightMode"="BakedRaytrace" }
            HLSLPROGRAM
            #pragma only_renderers vulkan
            #pragma shader_feature _EMISSION
            #pragma shader_feature S_EMISSIVE_MULTI
            #pragma shader_feature S_PACKING_MAES
            #include "Includes/BWVRStandardBakedRT.hlsl"
            ENDHLSL
        }
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" "Queue"="Geometry" "PerformanceChecks"="False" }
        LOD 300
        ZTest LEqual
        ColorMask RGBA

        Pass
        {
            Name "Forward"
            Tags { "LightMode"="UniversalForward" }
            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]
            Cull [_Cull]
            Offset [_OffsetFactor], [_OffsetUnits]
            HLSLPROGRAM
            #pragma exclude_renderers vulkan
            #pragma target 5.0
            #pragma vertex BWVert
            #pragma fragment BWFrag

            #pragma shader_feature _VERTEXTINT
            #pragma shader_feature _ALPHATEST_ON
            #pragma shader_feature _ALPHABLEND_ON
            #pragma shader_feature _ALPHAPREMULTIPLY_ON
            #pragma shader_feature _ALPHAMULTIPLY_ON
            #pragma shader_feature _ALPHAMOD2X_ON
            #pragma shader_feature _ALPHA_ON
            #pragma shader_feature _EMISSION
            #pragma shader_feature S_EMISSIVE_MULTI
            #pragma shader_feature _DETAIL_MULX2
            #pragma shader_feature _DETAIL_MUL
            #pragma shader_feature _DETAIL_ADD
            #pragma shader_feature _DETAIL_LERP
            #pragma shader_feature _DETAIL_HDRP
            #if !defined(SHADER_API_MOBILE)
                #pragma shader_feature _PARALLAXMAP
            #endif
            #pragma shader_feature _COLORSHIFT
            #pragma shader_feature S_WORLD_ALIGNED_TEXTURE
            #pragma shader_feature S_RENDER_BACKFACES
            #pragma shader_feature S_UNLIT
            #pragma shader_feature _NORMALMAP
            #pragma shader_feature _FLUORESCENCEMAP
            #pragma shader_feature S_SPECULAR_NONE
            #pragma shader_feature S_SPECULAR_BLINNPHONG
            #pragma shader_feature S_SPECULAR_METALLIC
            #pragma shader_feature S_ANISOTROPIC_GLOSS
            #pragma shader_feature S_RETROREFLECTIVE
            #pragma shader_feature _METALLICGLOSSMAP
            #pragma shader_feature _SPECGLOSSMAP
            #pragma shader_feature S_PACKING_RMA
            #pragma shader_feature S_PACKING_MAES
            #pragma shader_feature S_PACKING_MAS
            #pragma shader_feature S_PACKING_MASK
            #pragma shader_feature S_PACKING_MRA
            #pragma shader_feature S_PACKING_ORM
            #pragma shader_feature S_PACKING_ALLOY
            #pragma shader_feature S_OCCLUSION
            #pragma shader_feature _BRDFMAP
            #pragma shader_feature S_RECEIVE_SHADOWS

            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile_fragment _ _VOLUMETRICS_ENABLED
            #pragma multi_compile_fog
            #pragma skip_variants FOG_LINEAR FOG_EXP
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer

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
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/PlatformCompiler.hlsl"
            #include "Includes/BWVRStandardForward.hlsl"
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
            #pragma vertex BWDepthVert
            #pragma fragment BWDepthFrag
            #pragma shader_feature _ALPHATEST_ON
            #pragma shader_feature _VERTEXTINT
            #pragma shader_feature S_WORLD_ALIGNED_TEXTURE
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/PlatformCompiler.hlsl"
            #include "Includes/BWVRStandardDepthOnly.hlsl"
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
            #pragma target 4.5
            #pragma vertex BWDepthNormalsVert
            #pragma fragment BWDepthNormalsFrag
            #pragma shader_feature _ALPHATEST_ON
            #pragma shader_feature _VERTEXTINT
            #pragma shader_feature S_WORLD_ALIGNED_TEXTURE
            #pragma shader_feature S_RENDER_BACKFACES
            #pragma shader_feature S_UNLIT
            #pragma shader_feature _NORMALMAP
            #pragma shader_feature _DETAIL_MULX2
            #pragma shader_feature _DETAIL_MUL
            #pragma shader_feature _DETAIL_ADD
            #pragma shader_feature _DETAIL_LERP
            #pragma shader_feature _DETAIL_HDRP
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/PlatformCompiler.hlsl"
            #include "Includes/BWVRStandardDepthNormals.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode"="ShadowCaster" }
            ZWrite On
            ZTest LEqual
            Cull [_ShadowCull]
            ColorMask 0
            HLSLPROGRAM
            #pragma exclude_renderers vulkan
            #pragma target 4.5
            #pragma vertex BWShadowVert
            #pragma fragment BWShadowFrag
            #pragma multi_compile _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/PlatformCompiler.hlsl"
            #include "Includes/BWVRStandardShadowCaster.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "Meta"
            Tags { "LightMode"="Meta" }
            Cull Off
            HLSLPROGRAM
            #pragma exclude_renderers vulkan
            #pragma target 4.5
            #pragma vertex BWMetaVert
            #pragma fragment BWMetaFrag
            #pragma shader_feature _EMISSION
            #pragma shader_feature S_EMISSIVE_MULTI
            #pragma shader_feature _DETAIL_MULX2
            #pragma shader_feature _DETAIL_HDRP
            #pragma shader_feature S_PACKING_MAES
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/PlatformCompiler.hlsl"
            #include "Includes/BWVRStandardMeta.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "BakedRaytrace"
            Tags { "LightMode"="BakedRaytrace" }
            HLSLPROGRAM
            #pragma exclude_renderers vulkan
            #pragma shader_feature _EMISSION
            #pragma shader_feature S_EMISSIVE_MULTI
            #pragma shader_feature S_PACKING_MAES
            #include "Includes/BWVRStandardBakedRT.hlsl"
            ENDHLSL
        }
    }

    CustomEditor "UnityEditor.BoneworksVRStandardGUI"
}
