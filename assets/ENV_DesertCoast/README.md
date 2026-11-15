# ENV_DesertCoast — Projeto Isabela (Fase 6 Environment)

Desert coastline environment assets and shallow mirror water specification for Godot 4.7.2 (`Forward+`), authored in Blender 5.3 (meters, Y-up in `.glb`, transforms applied).

## Mesh Assets
| Asset | Tris | UV Overlaps | Textures (2048x2048) |
|---|---:|---:|---|
| `SM_DesertDunes.glb` | 16,800 | 0 | `T_DesertDunes_BaseColor.png`, `T_DesertDunes_Normal.png` (OpenGL Y+), `T_DesertDunes_ORM.png` |
| `SM_ShoreRocks.glb` | 960 | 0 | `T_ShoreRocks_BaseColor.png`, `T_ShoreRocks_Normal.png` (OpenGL Y+), `T_ShoreRocks_ORM.png` |

## Shallow Mirror Water Specification (Planar Shader — NOT a baked mesh)
- **Geometry**: Planar `PlaneMesh` (`300m × 300m`) at `Y = 0.0` (Godot Y-up), centered at `(0.0, 0.0, -40.0)`.
- **Surface Material (`M_ShallowMirrorWater.tres` / `shallow_mirror_water.gdshader`)**:
  - `Roughness`: `0.04` (range `0.03–0.08`) for crisp mirror reflections of `SK_Isabela`, `SK_Droid_Small`, `SK_Droid_Tall`, `SM_Ship`, and sunset sky.
  - `Metallic`: `0.0`, `Specular`: `0.55`, Fresnel-weighted reflection boost at grazing angles.
  - **Animated Multi-Directional Micro-Normals**: Dual scrolling normal-wave octaves (`0.08–0.15 m/s`) with subtle amplitude (`0.025`) so reflections remain legible.
  - **Concentric Circular Ripple Centers (Godot `(X, Z)` in meters at `Y = 0.0`)**:
    1. Isabela front (planted) foot: `(0.02, 0.20)`
    2. Isabela rear (trailing) foot: `(-0.06, -0.22)`
    3. `SK_Droid_Small`: `(-1.55, -2.40)`
    4. `SK_Droid_Tall`: `(1.75, -2.85)`
  - **Godot 4.7.2 `Environment` SSR**: `ssr_enabled = true`, `ssr_max_steps = 64`, `ssr_fade_in = 0.15`, `ssr_fade_out = 2.0`, `ssr_depth_tolerance = 0.25`.
