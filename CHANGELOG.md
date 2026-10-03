# Changelog

## Revision 3 — 2026-10-02

### Shared

- Added **SLZ Specular Horizon Occlusion** as a material toggle below Render Queue in both shader inspectors.
- Horizon occlusion defaults on and applies SLZ's `SLZSpecularHorizonOcclusion()` to reflection-probe and SSR contributions using the geometric normal.

### ai_vr_standard

- Added **HDRP** to Detail Blend Modes using LitMAS/HDRP packing: R = albedo overlay, G = normal Y, B = smoothness multiplier, A = normal X.
- Reuses the packed detail sample across albedo, normal, and smoothness in the Forward pass; the existing Detail Mask still controls the packed effect.
- Added BONELAB `SLZ/Mod2x` **Multiplier** and **Alpha** controls to Mod2x rendering mode.
- Mod2x Multiplier scales around neutral `0.5`; Alpha lerps the result toward `0.5` using source texture/material alpha multiplied by vertex alpha, matching the BONELAB shader behavior.

### GibSkinMAS

- Added an editor-only `GibSkinMASGUI` so the horizon-occlusion toggle appears immediately below Render Queue while retaining the normal material controls.
- No runtime script dependency was added.

## Revision 2 — 2026-09-30

### Shared

- Switched desktop geometric Spec AA to LitMAS' cheaper Valve-derived `SLZGeometricSpecularAA` implementation.
- Preserved the original BONEWORKS retroreflective exclusion from geometric roughness filtering.
- Retained the FP32 Vulkan screen-space dither hash fix to prevent FP16 overflow/NaN black-screen failures.

### ai_vr_standard

- Fixed dynamic-lightmap-only evaluation so it no longer calls `SLZGetLightmapLighting`, which unconditionally samples the static lightmap first.
- Kept static + dynamic lightmap support for the general-purpose shader.
- Preserved the working mobile policy: one per-pixel main light, additional point/spot lights at vertices.
- Kept the updated inspector without Unity's legacy "Mobile shaders" warning and with Quest alpha/transparent cost warnings.

### GibSkinMAS

- Removed static/dynamic lightmap variants and lightmap UV interpolation.
- Removed `Meta` and `BakedRaytrace` passes; GibSkinMAS is now explicitly a dynamic skinned-mesh shader.
- Uses SH/light probes for indirect diffuse and BONEWORKS SH-L1 fake specular fallback.
- Uses LitMAS/Posespace `VertexLighting()` for mobile RGB additional lights.
- Compiles the extra fluorescence-alpha vertex-light loop only when fluorescence is enabled.
- Default SSR temporal accumulation changed to `0` for skinned meshes while keeping the control available.
- Optimized hit distance by comparing squared ellipsoid distances and taking one final square root.
- Early-outs the hit-mask Vivid-Light calculation before three triplanar `_BloodyTex` samples when the mask is already fully blood or fully skin.
- Avoids sampling both blood and skin albedo/normal/MAS stacks when the hit mask is at a resolved endpoint.
- Retained the FP32 Vivid-Light endpoint fix and FP32 screen-dither hash fix for Vulkan.

## Revision 1

- Initial SLZ-URP 2021 reconstruction/port work for `ai_vr_standard` and `GibSkinMAS`.
- Replaced legacy BONEWORKS renderer light/shadow plumbing with SLZ-URP infrastructure while retaining BONEWORKS material behavior.

## 3.0.1 - Git/UPM ShaderGUI Fix
- Added Editor-only assembly definitions for `ai_vr_standard` and `GibSkinMAS` so their ShaderGUI scripts compile when installed through Unity Package Manager from a Git URL.
- Made `UnityEditor.BoneworksVRStandardGUI` public for reliable CustomEditor discovery across the package Editor assembly.
- No rendering/HLSL behavior changed in this patch.
