# SM_Ship — Projeto Isabela (Fase 4 Hero Spacecraft)

Modular discoidal spacecraft authored in Blender 5.3 for Godot 4.7.2 (`~40.0m` diameter × `~10.8m` height, real meters scale, Y-up in `.glb`, `Y_min = 0.0` at lowest ventral point, transforms applied).

## Mesh Breakdown (LOD0: 99,096 Tris)
| Mesh | Tris | UV Overlaps | Material |
|---|---:|---:|---|
| `SM_Ship_Hull_Upper` | 16,634 | 0 | `M_Ship` |
| `SM_Ship_Rim_Trench` | 18,148 | 0 | `M_Ship` |
| `SM_Ship_Hull_Ventral` | 18,426 | 0 | `M_Ship` |
| `SM_Ship_Greebles` | 45,888 | 0 | `M_Ship` |
| **Total** | **99,096** | **0** | |

## Textures (4096x4096 Cycles CPU Bake, Unified Non-Overlapping Quadrant Atlas)
- `T_Ship_BaseColor.png` — Weathered warm grey-beige titanium armor plates, gunmetal trench interiors, and desert grime crevices.
- `T_Ship_Normal.png` — Tangent-space normal map (OpenGL Y+) with baked edge bevels.
- `T_Ship_ORM.png` — Packed `R=Occlusion`, `G=Roughness`, `B=Metallic`.
- `T_Ship_Emissive.png` — Amber-orange trench slits/thrusters, cyan-blue rim/antenna beacons, and emerald-green nav accents.
