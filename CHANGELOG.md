# Changelog

## Current revision

### Naming and repository documentation

- Renamed the Unity shader menu path from `SLZ/BONEWORKS/vr_standard V1` to `SLZ/Valve/ai_vr_standard`.
- Added a GitHub-ready `README.md` covering requirements, installation, features, renderer integration, desktop/mobile behavior, texture packing, baking, limitations, and upstream references.
- Added upstream source/reference links for SLZ Custom URP, `zero_lab_renderer`, and Unity Graphics' projected-space geometric specular AA implementation.

### Rendering and lighting

- Added SLZ screen-space reflection integration on desktop.
- Added SSR temporal accumulation control.
- Forced SSR temporal accumulation to `0` for AlphaBlend, Glass, Additive, Mod2x, and Multiply modes.
- Added projected-space geometric specular anti-aliasing on supported desktop specular workflows using the geometric normal.
- Added SLZ static, dynamic, and directional lightmap support.
- Fixed dynamic-lightmap-only variants so they use baked GI instead of incorrectly falling back to SH.
- Prevented SH-L1 fake specular from being added on top of dynamic lightmaps.
- Added SLZ Meta and BakedRaytrace integration.
- Added SLZ volumetric fog support.

### Material features

- Added texture packing modes: MAES, RMA, MAS, MASK, MRA, ORM, and Alloy.
- Corrected desktop parallax tangent-space projection.
- Kept parallax fully compiled out on mobile.
- Preserved BRDF LUT, fluorescence, anisotropic, retroreflective, detail, color-shift, emission, AO, and world-aligned mapping workflows.

### Alpha and shadows

- Removed AlphaToCoverage / `AlphaToMask` behavior.
- AlphaTest now uses a hard `clip(alpha - _Cutoff)` path.
- Added alpha-clipped shadow support for Render Backfaces through a dedicated shadow-cull state.
- Kept other shadow-culling behavior consistent with the intended original shader behavior.

### Mobile / Quest

- One per-pixel main light with additional lights evaluated at vertex level.
- Aggressive half-precision material and lighting math where practical.
- Uses SLZ mobile-safe GGX paths.
- SSR, parallax, projected geometric specular AA, probe blending, and box projection remain disabled on mobile.

## Earlier V1 / V1.2 reconstruction work

- Ported the BONEWORKS-era `vr_standard` material model from Unity Built-in rendering to SLZ-URP 2021.
- Replaced old Valve custom renderer light/shadow infrastructure with SLZ-URP lighting and shadow APIs.
- Added native Forward, DepthOnly, DepthNormals, ShadowCaster, Meta, and BakedRaytrace passes.
- Restored original render modes, specular workflows, material keywords, detail modes, world-aligned mapping, fluorescence, parallax, and packed-texture behavior.
