# ai_vr_standard

A Unity 2021 / SLZ-URP reconstruction of the BONEWORKS-era `vr_standard` material model.

Unity shader menu path:

```text
SLZ/Valve/ai_vr_standard
```

Target:

```text
Unity 2021.3.16f1
Stress Level Zero Custom URP 2021
```

The shader keeps the original BONEWORKS material/BRDF behavior where practical while replacing the Built-in Render Pipeline renderer plumbing with SLZ-URP infrastructure.

## Material features

- Opaque, AlphaTest, AlphaBlend, Glass, Additive, Mod2x, and Multiply render modes.
- Unlit mode.
- Specular workflows:
  - None
  - BlinnPhong / specular-color BONEWORKS GGX
  - Metallic
  - Anisotropic
  - Retroreflective
- Albedo tint and vertex tint.
- Three-way color-mask tinting.
- Normal mapping and Normal-to-Occlusion.
- Desktop parallax mapping.
- BRDF LUT remapping.
- Fluorescence and absorbance.
- Emission and view falloff.
- Detail albedo/detail normals with Multiply2x, Multiply, Add, Lerp, and LitMAS/HDRP packed-detail modes.
- Separate AO influence controls for direct/indirect diffuse/specular.
- World-aligned planar mapping.
- Cast Shadows, Receive Shadows, Render Backfaces, depth offset, and smoothness scaling.

## Detail blend modes

The original BONEWORKS detail modes remain available, and Revision 3 adds **HDRP** packing based on LitMAS' detail-map path.

| HDRP detail channel | Meaning |
| --- | --- |
| R | Albedo overlay |
| G | Detail normal Y |
| B | Smoothness multiplier (`2 * B`) |
| A | Detail normal X |

The existing **Detail Mask** is applied to albedo, packed detail normal, and packed smoothness. In the Forward pass the HDRP detail texture is sampled once and reused for all three operations. The existing detail texture scale/offset and UV0/UV1 selection remain in use.

## Texture packing

| Mode | R | G | B | A |
| --- | --- | --- | --- | --- |
| MAES | Metallic | AO | Grayscale Emission | Smoothness |
| RMA | Roughness | Metallic | AO | — |
| MAS | Metallic | AO | Smoothness | — |
| MASK | Metallic | AO | Unused | Smoothness |
| MRA | Metallic | Roughness | AO | — |
| ORM | AO | Roughness | Metallic | — |
| Alloy | Metallic | AO | Unused | Roughness |

Roughness-packed modes are inverted internally to smoothness. MAES is the only packed mode that supplies emission.

## Mod2x controls

When **Rendering Mode = Mod2x**, the inspector exposes the BONELAB `SLZ/Mod2x` controls:

- **Multiplier** — scales the shader output around Mod2x neutral gray (`0.5`): `(color - 0.5) * Multiplier + 0.5`.
- **Alpha** — when enabled, fades that result toward neutral `0.5` using the original Mod2x source alpha. The source alpha is base texture alpha × material color alpha × vertex alpha, matching BONELAB's Mod2x behavior where vertex alpha remains part of the mask even when RGB vertex tint is disabled.

The existing `Blend DstColor SrcColor` rendering state remains unchanged.

## BONEWORKS BRDF policy

This shader deliberately does **not** replace the BONEWORKS direct-light model with `SLZPBRFragment`.

The retained BONEWORKS response includes:

- roughness-shaped diffuse;
- BONEWORKS direct GGX shaping;
- BRDF LUT mode;
- anisotropic and retroreflective branches;
- custom environment Fresnel and reflection scaling;
- fluorescence behavior.

SLZ renderer APIs are used around that BRDF for lights, shadows, probes, SSR, fog, and mobile-safe helpers.

## SLZ-URP integration

- SLZ main and additional lights.
- Main/additional light shadows and cookies.
- Reflection probes / sky fallback.
- Desktop probe blending and box projection.
- Desktop SLZ SSR.
- SLZ volumetric fog.
- DepthOnly, DepthNormals, ShadowCaster, Meta, and BakedRaytrace passes.
- GPU instancing and stereo plumbing.

## Specular anti-aliasing

Revision 2 uses LitMAS' cheaper Valve-derived geometric Spec AA:

```hlsl
SLZGeometricSpecularAA(...)
```

The returned smoothness cap is converted back into the shader's perceptual-roughness representation. The geometric normal is used so normal-map detail is not unnecessarily blurred.

The filter is desktop-only and is disabled for:

- Specular None
- Retroreflective
- mobile/Vulkan Quest path

This replaces the previous projected-space NDF filtering implementation.

## Lightmapping

`ai_vr_standard` remains the general-purpose shader and keeps baked/dynamic GI support:

- static lightmaps;
- dynamic lightmaps;
- directional lightmaps;
- lightmap shadow mixing / shadow masks;
- SH/light-probe fallback;
- directional-lightmap BONEWORKS specular reconstruction;
- SH-L1 fake specular fallback when no lightmap is active.

Revision 2 fixes the **dynamic-lightmap-only** variant. `SLZGetLightmapLighting()` always samples `unity_Lightmap` first, so the shader now samples `unity_DynamicLightmap` directly when `DYNAMICLIGHTMAP_ON` is active without `LIGHTMAP_ON`.

## Desktop vs Quest/mobile

### Desktop

- Per-pixel main and additional lights.
- SSR with temporal accumulation.
- Reflection-probe blending and box projection.
- Parallax.
- LitMAS geometric Spec AA.
- Full desktop anisotropic / reflection behavior.

### Quest / mobile Vulkan

- One per-pixel main light.
- Additional point/spot lights at vertices.
- SLZ mobile-safe GGX helpers where appropriate.
- Aggressive half precision where safe.
- No SSR.
- No parallax.
- No geometric Spec AA.
- No probe blending or box projection.

The screen-space dither hash remains FP32 on Vulkan to prevent FP16 overflow -> INF/NaN black-screen failures.

## SLZ Specular Horizon Occlusion

A **SLZ Specular Horizon Occlusion** toggle is shown directly below **Render Queue** and defaults on. It applies SLZ's `SLZSpecularHorizonOcclusion()` to reflection-probe and SSR contributions using the geometric normal, reducing invalid reflection rays that point below the actual mesh surface. Disable it for legacy comparison or materials that intentionally rely on those grazing reflections.

## SSR

- Per-material **Disable SSR** control.
- **Temporal Accumulation Factor** control.
- Transparent modes force temporal accumulation to `0`.
- Skinned meshes should generally use temporal accumulation `0` because the previous object matrix does not contain previous skinned vertex positions.

## Alpha / shadow behavior

- AlphaTest uses hard `clip(alpha - _Cutoff)`.
- AlphaToCoverage is removed.
- Alpha-clipped ShadowCaster culling follows Render Backfaces.
- Transparent shadow behavior remains dithered where appropriate.

The custom inspector also removes Unity's legacy "consider switching to a Mobile shader" warning and instead shows Quest-specific warnings below Render Backfaces for alpha-clip and transparent modes.

## Installation

Copy the `ai_vr_standard` folder into your Unity project's `Assets` directory and select:

```text
SLZ/Valve/ai_vr_standard
```

This shader depends on SLZ Custom URP shader-library APIs and is not intended to compile against stock URP without adaptation.

## Scope intentionally omitted

The following old renderer systems are not recreated as separate systems:

- ValveCamera / ValveRealtimeLight custom light arrays;
- replacement-camera shadows;
- old custom light-cookie arrays;
- legacy PCSS path;
- matrix-palette skinning;
- override-lightmap renderer plumbing.

SLZ-URP equivalents are used where applicable.

## References

- Stress Level Zero Custom URP: https://github.com/StressLevelZero/Custom-URP
- Kevin Comerford / zero_lab_renderer: https://github.com/KevinComerford/zero_lab_renderer

## Validation

The source has been statically reviewed outside Unity. Final shader compilation and visual validation should be performed in the target Unity `2021.3.16f1` + SLZ Custom URP 2021 project.
