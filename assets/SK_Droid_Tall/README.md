# SK_Droid_Tall

Tall slender humanoid droid in matte black / dark gunmetal with open torso cutout revealing internal mechanical spine/struts/pistons, pronounced shoulder pauldrons, spherical ball joints, and Godot 4.7.2 `IKModifier3D`-ready skeleton.

## Specifications
- **Polycount**: 33048 tris (LOD0; Godot 4.7.2 auto-LOD enabled on import)
- **Scale**: Real-world meters (~1.98m height), Y-up glTF 2.0 (`.glb`), pivot at base (`Y = 0`)
- **Material**: `M_Droid_Tall`
- **Textures (2048x2048)**:
  - `T_Droid_Tall_BaseColor.png` (sRGB)
  - `T_Droid_Tall_Normal.png` (OpenGL Y+, Non-Color)
  - `T_Droid_Tall_ORM.png` (Packed: R = Occlusion, G = Roughness, B = Metallic, Non-Color)

## Skeleton & Bone Hierarchy (`Armature_Droid_Tall`)
```
root (non-deform)
├── pelvis (deform)
│   ├── spine (deform)
│   │   └── chest (deform)
│   │       ├── neck -> head (deform)
│   │       ├── clavicle.L -> upper_arm.L -> forearm.L -> hand.L (deform)
│   │       └── clavicle.R -> upper_arm.R -> forearm.R -> hand.R (deform)
│   ├── thigh.L -> shin.L -> foot.L (deform)
│   └── thigh.R -> shin.R -> foot.R (deform)
├── ik_hand_target.L / ik_hand_pole.L (non-deform, IKModifier3D)
├── ik_hand_target.R / ik_hand_pole.R (non-deform, IKModifier3D)
├── ik_foot_target.L / ik_foot_pole.L (non-deform, IKModifier3D)
└── ik_foot_target.R / ik_foot_pole.R (non-deform, IKModifier3D)
```

## Joint Rotation Limits (Degrees, Local XYZ)
| Bone | X (Pitch) | Y (Roll) | Z (Yaw) |
|---|---|---|---|
| `pelvis` | -25° .. +25° | -15° .. +15° | -40° .. +40° |
| `spine` | -20° .. +25° | -15° .. +15° | -30° .. +30° |
| `chest` | -15° .. +20° | -12° .. +12° | -25° .. +25° |
| `neck` | -20° .. +20° | -12° .. +12° | -25° .. +25° |
| `head` | -30° .. +30° | -20° .. +20° | -70° .. +70° |
| `clavicle.L/R` | -15° .. +15° | -15° .. +15° | -20° .. +20° |
| `upper_arm.L/R` | -150° .. +50° | -45° .. +45° | -45° .. +95° |
| `forearm.L/R` | -135° .. +0° | 0° | 0° |
| `hand.L/R` | -55° .. +55° | -25° .. +25° | -35° .. +35° |
| `thigh.L/R` | -110° .. +40° | -30° .. +30° | -25° .. +25° |
| `shin.L/R` | 0° .. +135° | 0° | 0° |
| `foot.L/R` | -40° .. +50° | -20° .. +20° | -15° .. +15° |
