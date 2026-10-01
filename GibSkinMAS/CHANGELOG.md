# Changelog — GibSkinMAS

## Revision 2 — 2026-09-30

### Lighting / mobile

- Fixed Quest/mobile point/spot vertex lighting by using the same `VertexLighting()` RGB path as LitMAS Posespace.
- Main/directional light remains per-pixel; point/spot additional lights remain vertex-lit.
- Kept the BONEWORKS fluorescence alpha contribution in a separate mobile vertex accumulator.
- The fluorescence-only second additional-light loop now compiles out when `_FLUORESCENCEMAP` is disabled.

### Lightmapping scope reduction

- Removed static lightmap variants.
- Removed dynamic lightmap variants.
- Removed directional-lightmap variants.
- Removed lightmap UV interpolation.
- Removed directional-lightmap BONEWORKS specular reconstruction.
- Removed Meta and BakedRaytrace passes/files.
- Dynamic skinned meshes now use SH/light probes for indirect diffuse plus the existing BONEWORKS SH-L1 fake-specular fallback.

### Hit-system optimization

- Reworked the 128-hit distance loop to compare squared distances and perform one final square root.
- Moved hit-source endpoint checks before triplanar `_BloodyTex` sampling, avoiding three texture samples on resolved fully-blood/fully-skin pixels.
- Albedo now branches at the original rounded threshold instead of evaluating both blood and skin stacks and lerping afterward.
- Normal and MAS sampling now avoid evaluating both sides when the hit mask is already exactly `0` or `1`.

### Vulkan stability

- Kept the screen-space dither hash in FP32 to prevent FP16 overflow / INF / NaN black-screen failures.
- Kept Vivid-Light hit-mask math in FP32 with explicit singular endpoint handling.
- Keeps FP32 accumulation for the fluorescence vertex-light alpha before converting to half.

### Specular AA

- Replaced projected-space NDF filtering with LitMAS' cheaper Valve-derived `SLZGeometricSpecularAA` implementation on desktop.
- Retroreflective materials bypass geometric Spec AA, matching original BONEWORKS behavior.

### SSR

- Added/retained Temporal Accumulation Factor control.
- Default changed to `0`, matching SLZ LitMAS Posespace guidance for skinned meshes.

## Revision 1

- Initial SLZ-URP 2021 port of BONEWORKS `GibSkinMAS`.
- Preserved the original pose-space matrix hit system, blood triplanar mapping, bloody normal/MAS transitions, fluorescence, and BONEWORKS BRDF modes.
- Added SLZ Forward lighting, shadows/cookies, probes, SSR, fog/volumetrics, depth passes, and initial baked-lighting support.
