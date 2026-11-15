# SK_Droid_Small

Left background retro-utilitarian biped droid with weathered white/blue dome head, glowing blue optical eyes, chipped ochre-gold torso, articulated mechanical limbs, and full Godot 4.7.2 `IKModifier3D`-ready skeleton.

## Specifications
- **Polycount**: 33428 tris (LOD0; Godot 4.7.2 auto-LOD enabled on import)
- **Scale**: Real-world meters (~1.03m height), Y-up glTF 2.0 (`.glb`), pivot at base (`Y = 0`)
- **Material**: `M_Droid_Small`
- **Textures (2048x2048)**:
  - `T_Droid_Small_BaseColor.png` (sRGB)
  - `T_Droid_Small_Normal.png` (OpenGL Y+, Non-Color)
  - `T_Droid_Small_ORM.png` (Packed: R = Occlusion, G = Roughness, B = Metallic, Non-Color)
  - `T_Droid_Small_Emissive.png` (sRGB, glowing blue eyes)

## Skeleton & Bone Hierarchy (`Armature_Droid_Small`)
```
root (non-deform)
├── pelvis (deform)
│   ├── torso (deform)
│   │   ├── neck (deform)
│   │   │   └── head (deform)
│   │   ├── shoulder.L -> upper_arm.L -> forearm.L -> hand.L (deform)
│   │   └── shoulder.R -> upper_arm.R -> forearm.R -> hand.R (deform)
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
| `pelvis` | -20° .. +20° | -15° .. +15° | -35° .. +35° |
| `torso` | -15° .. +20° | -12° .. +12° | -25° .. +25° |
| `neck` | -15° .. +15° | -10° .. +10° | -20° .. +20° |
| `head` | -25° .. +25° | -20° .. +20° | -65° .. +65° |
| `shoulder.L/R` | -15° .. +15° | -10° .. +10° | -15° .. +15° |
| `upper_arm.L/R` | -135° .. +45° | -45° .. +45° | -30° .. +90° |
| `forearm.L/R` | -125° .. +0° | 0° | 0° |
| `hand.L/R` | -45° .. +45° | -20° .. +20° | -30° .. +30° |
| `thigh.L/R` | -95° .. +35° | -25° .. +25° | -20° .. +20° |
| `shin.L/R` | 0° .. +120° | 0° | 0° |
| `foot.L/R` | -35° .. +45° | -15° .. +15° | -15° .. +15° |
