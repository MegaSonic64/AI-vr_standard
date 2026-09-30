# ai_vr_standard - ChatGPT Sol 5.6

A Unity 2021 / SLZ-URP AI port and reconstruction of Valve's `vr_standard` material model as used by the modified Valve VR renderer lineage associated with BONEWORKS.

The shader is exposed in Unity as:

```text
SLZ/Valve/ai_vr_standard
```

This project keeps the original material workflow and visual behavior where practical, while replacing the old Built-in Render Pipeline renderer plumbing with Stress Level Zero's custom Universal Render Pipeline infrastructure.

> **Target:** Unity `2021.3.16f1` + Stress Level Zero Custom URP 2021.
>
> This is an independent reconstruction/port and is not an official Valve or Stress Level Zero release.

## Features

### Original `vr_standard` material features

- Unlit mode.
- Rendering modes: Opaque, AlphaTest, AlphaBlend, Glass, Additive, Mod2x, and Multiply.
- Specular workflows:
  - None
  - BlinnPhong / specular-color workflow using the BONEWORKS-era custom GGX lighting path
  - Metallic
  - Anisotropic
  - Retroreflective
- Albedo tint and vertex tint.
- Three-way color-mask tinting.
- Normal mapping and Normal-to-Occlusion.
- Parallax mapping with configurable iterations on desktop.
- BRDF LUT / lightwarp-style remapping.
- Fluorescence and absorbance response.
- Emission, view falloff, and Multiply Albedo emission mode.
- Detail albedo and detail normal maps.
- Detail blend modes: Multiply2x, Multiply, Add, and Lerp.
- Separate AO influence controls for direct diffuse, direct specular, indirect diffuse, and indirect specular.
- World-aligned planar texture mapping.
- Per-material cast-shadows, receive-shadows, render-backfaces, depth offset, and smoothness scaling.

### Texture packing

The Metallic texture slot supports the following packing layouts:

| Mode | R | G | B | A |
| --- | --- | --- | --- | --- |
| **MAES** | Metallic | AO | Grayscale Emission | Smoothness |
| **RMA** | Roughness | Metallic | AO | — |
| **MAS** | Metallic | AO | Smoothness | — |
| **MASK** | Metallic | AO | Unused | Smoothness |
| **MRA** | Metallic | Roughness | AO | — |
| **ORM** | AO | Roughness | Metallic | — |
| **Alloy** | Metallic | AO | Unused | Roughness |

Roughness-packed modes are inverted internally to the shader's smoothness representation. MAES is the only packing mode that supplies packed emission; the other modes continue to use the normal Emission texture.

## SLZ-URP integration

The old custom Valve renderer systems are replaced by SLZ-URP equivalents.

- SLZ main and additional lights.
- Main-light and additional-light shadows.
- Light cookies.
- SLZ volumetric fog integration.
- Reflection probes / sky fallback.
- Desktop reflection-probe blending and box projection.
- SLZ screen-space reflections on supported desktop paths.
- Native `DepthOnly`, `DepthNormals`, `ShadowCaster`, `Meta`, and `BakedRaytrace` passes.
- GPU instancing and standard URP stereo/instance plumbing.

### Screen-space reflections

Desktop builds can use SLZ SSR when the renderer enables it.

- Per-material **Disable SSR** control.
- **Temporal Accumulation Factor** control.
- Transparent modes force the temporal factor to `0` because their history is not stable against the opaque-buffer SSR path.
- The inspector warns that skinned meshes should use a temporal factor of `0`.
- SSR is compiled out on the mobile path.

### Geometric specular anti-aliasing

Desktop non-retroreflective specular workflows use projected-space geometric specular anti-aliasing based on Unity Graphics' newer projected-space NDF filtering approach. The filter uses the **geometric normal**, not the normal-mapped shading normal, to reduce geometry-driven specular shimmer without blurring normal-map detail.

This path is compiled out on mobile.

## Lightmapping and baked lighting

The Forward pass supports SLZ/Unity baked GI infrastructure:

- Static lightmaps (`LIGHTMAP_ON`).
- Dynamic lightmaps (`DYNAMICLIGHTMAP_ON`).
- Directional lightmaps (`DIRLIGHTMAP_COMBINED`).
- Lightmap shadow mixing and shadow masks.
- SH/light-probe fallback when no static or dynamic lightmap is active.
- Directional-lightmap specular reconstructed through the BONEWORKS BRDF instead of using SLZ's generic baked-specular lobe.
- SH-L1 approximate specular fallback for probe-lit objects when appropriate.
- Meta pass for albedo and baked emission.
- SLZ `BakedRaytrace` pass.

Unlit materials intentionally bypass normal lighting and lightmap evaluation.

## Alpha and shadow behavior

- AlphaTest uses a normal hard alpha clip with `_Cutoff`.
- Alpha-to-coverage has been removed.
- AlphaTest shadows can follow **Render Backfaces** through the dedicated shadow-cull state.
- Other shadow modes retain the intended original culling behavior.
- Transparent modes retain the original blend-mode behavior and dithered transparent-shadow logic where applicable.

## Parallax

The desktop parallax path preserves the original iterative height-map behavior while using the corrected tangent-space projection:

```text
(T · V, B · V) / (N · V)
```

Parallax is completely compiled out on the mobile path.

## Desktop vs mobile / Quest

The mobile Vulkan path is intentionally cheaper than desktop.

### Desktop

- Per-pixel main and additional lights.
- SSR.
- Reflection-probe blending.
- Reflection-probe box projection.
- Parallax mapping.
- Projected-space geometric specular AA.
- Full desktop anisotropic / reflection behavior.

### Mobile / Quest

- One per-pixel main light.
- Additional lights accumulated at the vertex level.
- Aggressive `half` precision where practical.
- SLZ mobile-safe GGX paths.
- No SSR.
- No parallax.
- No projected geometric specular AA.
- No reflection-probe blending.
- No reflection-probe box projection.
- Single-probe environment reflection path.

The mobile path is designed to preserve the BONEWORKS material response while avoiding the more expensive desktop-only features.

## Installation

1. Use a Unity `2021.3.x` project running the Stress Level Zero Custom URP 2021 renderer.
2. Copy this folder into your project's `Assets` directory.
3. Let Unity compile the shader and editor script.
4. Create or select a material and choose:

   ```text
   SLZ/Valve/ai_vr_standard
   ```

5. Configure the material through the custom inspector.

The shader depends on SLZ-URP shader-library APIs and is not intended to compile against stock Unity URP without adaptation.

## Project scope

This port focuses on the `vr_standard` **material and BRDF behavior** rather than recreating the old Valve renderer itself. The following legacy renderer systems are intentionally not reproduced as separate systems:

- ValveCamera / ValveRealtimeLight custom light arrays and culling.
- The old replacement-camera shadow renderer.
- Legacy custom light-cookie arrays.
- Legacy PCSS path.
- Matrix-palette skinning support.
- Override-lightmap renderer plumbing.

Equivalent SLZ-URP lighting, shadowing, reflection, fog, and baking infrastructure is used instead where applicable.

## Source references

This project was reconstructed and ported using the following upstream codebases and shader references:

- [Stress Level Zero — Custom-URP](https://github.com/StressLevelZero/Custom-URP) — target SLZ-URP rendering infrastructure.
- [Kevin Comerford — zero_lab_renderer](https://github.com/KevinComerford/zero_lab_renderer) — modified Valve VR renderer / `vr_standard` lineage and material behavior reference.
- [Unity Technologies — Graphics / CommonMaterial.hlsl](https://github.com/Unity-Technologies/Graphics/blob/master/Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl) — projected-space geometric specular anti-aliasing reference (`ProjectedSpaceNormalFiltering` / `ProjectedSpaceGeometricNormalFiltering`).

The projected-space filtering implementation in Unity references Yusuke Tokuyoshi and Anton Kaplanyan's *Stable Geometric Specular Antialiasing with Projected-Space NDF Filtering*.

## Status

- The shader is provided "as is" and will not be actively supported. - MegaSonic64
