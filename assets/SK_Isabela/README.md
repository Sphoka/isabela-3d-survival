# SK_Isabela — Projeto Isabela (Fase 5 Hero Character)

Modular hybrid hero character authored in Blender 5.3 (MPFB2 anatomical base + 2D-projected neutral face albedo + clean quad garments + blowout hair cards) for Godot 4.7.2 (`SkeletonProfileHumanoid` + 52 ARKit blendshapes + `SpringBoneSimulator3D` hair physics).

## Mesh Breakdown (LOD0: 57,924 Tris)
| Mesh | Tris | UV Overlaps | Materials |
|---|---:|---:|---|
| `SK_Isabela_Body` | 26,756 | 0 | `M_Isabela_Body` |
| `SK_Isabela_Eyes` | 1,344 | 0 | `M_Isabela_Eyes` |
| `SK_Isabela_Eyelashes` | 48 | 0 | `M_Isabela_Eyelashes` |
| `SK_Isabela_Top` | 3,484 | 0 | `M_Isabela_Top` |
| `SK_Isabela_Lingerie` | 900 | 0 | `M_Isabela_Lingerie`, `M_Isabela_Lingerie_Trim`, `M_Isabela_Lingerie_Clip` |
| `SK_Isabela_Hair` | 25,392 | 0 | `M_Isabela_Hair`, `M_Isabela_Hair_Scalp` |
| **Total** | **57,924** | **0** | |

## Rig & Facial Blendshapes
- **Armature**: `Armature_Isabela` — **84 bones** (`SkeletonProfileHumanoid` 53 body deform bones incl. `LeftThumbMetacarpal`/`Proximal`/`Distal` & `LeftLittle*`/`RightLittle*` + `Jaw`, `LeftEye`, `RightEye` + 28 hair physics bones across 7 `SpringBoneSimulator3D` chains: `Hair_Front_L/R_01..04`, `Hair_Side_L/R_01..04`, `Hair_Back_L/C/R_01..04`).
- **Facial Blendshapes**: **52 ARKit** shape keys on `SK_Isabela_Body` (all initialized to `0.0`).
- **Dimensions**: `1.724m` height, `Z_min = 0.0`, Y-up in `.glb`.

## Textures (ORM Packed: R=Occlusion, G=Roughness, B=Metallic)
- **Body (4096x4096)**: `T_Isabela_Body_BaseColor.png`, `T_Isabela_Body_Normal.png` (OpenGL Y+), `T_Isabela_Body_ORM.png`
- **Eyes (1024x1024)**: `T_Isabela_Eyes_BaseColor.png`
- **Eyelashes (512x256)**: `T_Isabela_Eyelashes.png`
- **Top (2048x2048)**: `T_Isabela_Top_BaseColor.png`, `T_Isabela_Top_Normal.png`, `T_Isabela_Top_ORM.png`
- **Lingerie (2048x2048)**: `T_Isabela_Lingerie_BaseColor.png`, `T_Isabela_Lingerie_Normal.png`, `T_Isabela_Lingerie_ORM.png`
- **Hair (2048x2048)**: `T_Isabela_Hair_BaseColor.png`, `T_Isabela_Hair_Normal.png`, `T_Isabela_Hair_ORM.png`
