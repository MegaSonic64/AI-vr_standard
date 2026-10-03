# GibSkinMAS — SLZ-URP 2021

Port/reconstruction of the BONEWORKS `SDK/GibSkinMAS` shader for Unity `2021.3.16f1` + Stress Level Zero Custom URP 2021.

Unity shader menu path:

```text
SLZ/Valve/GibSkinMAS
```

Revision 2 treats GibSkinMAS explicitly as a **dynamic skinned-mesh shader**. Static/dynamic lightmapping, Meta, and BakedRaytrace support have been removed to reduce variants and unnecessary shader work.

## Original hit system preserved

This shader still uses the original BONEWORKS hit-decal data contract rather than replacing it with modern `PosespaceImpacts.hlsl`:

- pose-space position from `TEXCOORD1.xyz`;
- `EllipsoidPosArray[128]`;
- `_NumberOfHits`;
- `_ElipsoidMatrices[1]`;
- `_NumberOfElipsoids`;
- original distance/power/Vivid-Light hit mask;
- original bloody triplanar texture behavior;
- original bloody/base normal transitions;
- original MAS transitions;
- hit-distance AO.

## Material / BRDF features

- Main albedo × color.
- Detail albedo using the old Unity Standard `unity_ColorSpaceDouble` Multiply2x behavior.
- Main + detail normal blending.
- MAS packing: **R Metallic, G AO, B Smoothness**.
- Bloody layer with independent blood metallic/smoothness and triplanar bloody normal.
- Original hard albedo switch via `round(Hits)` semantics; normal/MAS remain smoothly blended in transition regions.
- Metallic, Anisotropic Gloss, and Retroreflective BONEWORKS lighting modes.
- BRDF LUT remapping.
- Fluorescence + absorbance.
- BONEWORKS environment Fresnel / reflection scaling.
- Original final screen-space dither ordering.

## SLZ lighting integration

- Main/directional light remains per-pixel.
- Desktop additional lights remain per-pixel.
- Quest/mobile RGB additional lights use SLZ/URP `VertexLighting()`, matching LitMAS Posespace.
- Fluorescence still receives the old BONEWORKS realtime-light alpha contribution through a separate alpha accumulator.
- That second vertex-light loop now compiles out completely when fluorescence is disabled.
- Shadows and cookies use SLZ/URP light data.
- Reflection probes, desktop probe blending/box projection, SSR, fog, and volumetric fog are retained.

## No lightmapping support

GibSkinMAS Revision 2 intentionally removes:

- `LIGHTMAP_ON` variants;
- `DYNAMICLIGHTMAP_ON` variants;
- `DIRLIGHTMAP_COMBINED` variants;
- lightmap UV interpolators;
- directional-lightmap specular reconstruction;
- Meta pass;
- BakedRaytrace pass.

Dynamic characters use SH/light probes for indirect diffuse. The existing BONEWORKS SH-L1 fake specular fallback is retained when the realtime main light contributes no useful highlight.

The remaining passes are:

- UniversalForward
- DepthOnly
- DepthNormals
- ShadowCaster

## Hit-system optimizations

Revision 2 keeps the original visual contract while cutting unnecessary fragment work.

### Squared hit distances

The hit loop now compares squared ellipsoid distances and performs one final `sqrt()`:

```text
old worst case: up to 128 sqrt operations per fragment
new:            1 sqrt operation per fragment
```

### Early Vivid-Light endpoint return

The hit falloff/cutout source mask is evaluated before the three triplanar `_BloodyTex` samples. Fully-blood and fully-skin pixels return immediately without those samples.

The Vivid-Light transition math remains FP32 to avoid Vulkan FP16 `0/0 -> NaN` failures at the endpoints.

### Avoid evaluating both material stacks

- Albedo branches at the original rounded hit threshold, so only the selected blood/skin albedo stack is sampled.
- Normal and MAS paths sample only one side when `hits` has resolved to `0` or `1`.
- Both sides are sampled only inside the actual smooth transition region.

## Specular anti-aliasing

Desktop uses LitMAS' cheaper Valve-derived:

```hlsl
SLZGeometricSpecularAA(...)
```

The geometric normal is used. Retroreflective bypasses geometric roughness filtering, matching original BONEWORKS behavior. Spec AA is compiled out on mobile.

## SLZ Specular Horizon Occlusion

Revision 3 adds a **SLZ Specular Horizon Occlusion** toggle immediately below **Render Queue**. It defaults on and applies `SLZSpecularHorizonOcclusion()` to reflection-probe and SSR contributions using the geometric normal. This suppresses environment/reflection rays that dip below the actual mesh surface while leaving the BONEWORKS direct-light BRDF unchanged.

The custom `GibSkinMASGUI` used to place the control is editor-only; it adds no runtime script dependency.

## SSR

Desktop SLZ SSR remains supported.

**Temporal Accumulation Factor** defaults to `0` because previous object transforms cannot reconstruct previous skinned vertex positions. The control remains available for experimentation.

Mobile does not compile SSR.

## Vulkan / FP16 fixes

- Screen-space dither hash stays FP32 until normalized to prevent FP16 overflow / INF / NaN black-screen failures.
- Vivid-Light hit-mask division remains FP32 with explicit endpoint handling.
- Mobile vertex fluorescence accumulation uses FP32 accumulation before clamping back to FP16 range.

## Installation

Copy the `GibSkinMAS` folder into your project's `Assets` directory. Existing BONEWORKS hit scripts should continue to populate the original matrix/count property names.

This shader depends on SLZ Custom URP shader-library APIs and is not intended to compile against stock URP without adaptation.

## Validation

The source has been statically reviewed outside Unity. Final compile/runtime validation should be performed in Unity `2021.3.16f1` with the target SLZ Custom URP package and the original GibSkin hit scripts.
