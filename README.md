# SLZ-URP 2021 BONEWORKS Shader Ports

Unity `2021.3.16f1` shader ports/reconstructions targeting Stress Level Zero's Custom URP 2021 renderer.

This repository contains two related shaders:

- **`ai_vr_standard`** — a general BONEWORKS-era `vr_standard` material/BRDF reconstruction for SLZ-URP.
- **`GibSkinMAS`** — a dynamic skinned-mesh shader preserving the original BONEWORKS pose-space gib/blood hit system while using SLZ-URP lighting infrastructure.

The goal is to preserve the BONEWORKS material response where it materially affects appearance, while adopting LitMAS/SLZ renderer infrastructure and mobile-safe optimizations where they do not substantially change the look.

> Target: Unity `2021.3.16f1` + Stress Level Zero Custom URP 2021.
>
> These are independent reconstruction/port projects and are not official Valve or Stress Level Zero releases.

## Repository layout

```text
ai_vr_standard/
    BW_VRStandard_SLZ_V1.shader
    Includes/
    Editor/
    README.md
    CHANGELOG.md

GibSkinMAS/
    GibSkinMAS_SLZ.shader
    Includes/
    Editor/
    README.md
    CHANGELOG.md
```

## Shared rendering policy

Both shaders retain the custom BONEWORKS direct-light response rather than replacing it wholesale with `SLZPBRFragment`.

SLZ/LitMAS infrastructure is used for renderer-facing systems such as:

- main/additional light acquisition;
- mobile vertex additional lights;
- shadows and cookies;
- reflection probes and desktop SSR;
- volumetric fog;
- mobile-safe GGX helpers;
- Valve/LitMAS geometric specular anti-aliasing.

The Vulkan/mobile path keeps the SLZ-style split of one per-pixel main/directional light with additional point/spot lights evaluated at the vertex level.

## Revision 3 highlights

- `ai_vr_standard` adds a **HDRP** Detail Blend Mode using LitMAS/HDRP packed detail channels: **R albedo overlay, G normal Y, B smoothness multiplier, A normal X**. The Forward pass samples the packed detail texture once and reuses it for albedo, normal, and smoothness.
- `ai_vr_standard` Mod2x mode adds the BONELAB `SLZ/Mod2x` **Multiplier** and **Alpha** controls. Multiplier scales the final Mod2x source around neutral `0.5`; Alpha uses the source texture/material/vertex alpha to fade the result back toward neutral `0.5`.
- `ai_vr_standard` and `GibSkinMAS` add a **SLZ Specular Horizon Occlusion** toggle directly below Render Queue. It defaults on and attenuates reflection-probe and SSR specular rays that dip below the geometric surface horizon.
- The horizon toggle is runtime shader data only; the new GibSkin editor GUI only exposes the control in the requested inspector location. No runtime scripts are required.

## Revision 2 highlights

- Replaced the heavier projected-space Spec AA port with LitMAS' cheaper Valve-derived `SLZGeometricSpecularAA` path on desktop.
- Kept retroreflective materials exempt from geometric roughness filtering, matching the original BONEWORKS shader.
- Fixed the Vulkan FP16 screen-dither overflow in both shaders by keeping the screen-space hash in FP32.
- `ai_vr_standard` now handles dynamic-lightmap-only variants without accidentally sampling `unity_Lightmap` first.
- `GibSkinMAS` now uses the exact LitMAS/Posespace RGB vertex-light route (`VertexLighting`) on mobile.
- `GibSkinMAS` no longer compiles lightmapping/Meta/BakedRaytrace support; it is treated as a dynamic skinned-mesh shader using SH/light probes.
- `GibSkinMAS` hit evaluation avoids unnecessary blood texture samples at resolved mask endpoints and reduces the hit-distance loop from up to 128 square roots to one.
- GibSkin blood/base texture stacks are no longer both sampled when the hit mask has already resolved to one side.
- GibSkin's fluorescence-only second vertex-light loop compiles out when fluorescence is disabled.
- GibSkin SSR temporal accumulation remains available but defaults to `0`, matching SLZ's Posespace guidance for skinned meshes.

See each shader's README and changelog for details.

## Upstream references

- Stress Level Zero Custom URP: https://github.com/StressLevelZero/Custom-URP
- Kevin Comerford / zero_lab_renderer: https://github.com/KevinComerford/zero_lab_renderer

No license is added by this package; review the upstream source licenses and your own distribution requirements before publishing derivative work.
