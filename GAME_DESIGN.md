# Projeto Isabela 3D — Game Design & Technical Architecture Spec

**Engine:** Godot `4.7.2-stable` (`Forward+` GPU renderer)  
**Single Source of Truth Balance Data:** [`data/game_balance.json`](file:///D:/Godot/isabela_scene_test/data/game_balance.json)  
**Non-Interference Guarantee:** The playable wave-survival game is built **additively** under `res://scenes/game/`, `res://scripts/game/`, and `res://data/`. The Fase 6 showcase scene (`res://scenes/main_isabela_scene.tscn`) and Fase 1–5 test scenes remain completely untouched and intact.

---

## 1. Core Loop & Arena Topology ("Costa do Deserto — Sobrevivência")

1. **Setting & Scale:** Isabela (`SK_Isabela`, `1.728m` total height / `1.724m` body) defends a `32.0m`-radius shallow coastal water basin (`Y = 0.0m`) surrounded by `SM_DesertDunes` and `SM_ShoreRocks` cover clusters, while the `40.0m` discoidal mothership `SM_Ship` hovers menacingly overhead at `(0.0, 44.0, -18.0)`.
2. **Core Combat Loop:**
   - **Wave Spawning:** `SM_Ship` pulses an orbital drop-beam as waves of `SK_Droid_Small` (fast melee rushers) and `SK_Droid_Tall` (armored ranged/melee sentinels, introduced Wave 2) deploy at `R = 20.0m–28.0m` (`>= 10.0m` from player).
   - **6-Weapon Arsenal Switching (`1`–`6` / Mouse Wheel):** Instant access to all 6 distinct weapons covering precision hitscan, melee cleave + bolt deflection, close-quarters knockback, explosive AoE, high-crit dueling, and piercing battery laser.
   - **Resource & Survival Loop:** Defeated droids drop XP (auto-collected with floating HUD/world feedback) and weighted `SM_Crate_Health` / `SM_Crate_Ammo` pickups (plus 1 ambient supply crate per wave).
   - **Level-Up & Wave-Clear Upgrade Choice:** Reaching `xp_to_next_level` OR clearing a wave triggers a paused **3-Card Upgrade Selection Modal** with rarity tiers (`Comum`, `Raro`, `Épico`, `Lendário`) and 10 stackable build-defining upgrades.

---

## 2. Player (`SK_Isabela`, `1.728m`) Physics, Camera & Animation

### 2.1 Collision, Hitbox & Orientation
- **Root Node:** `Player` (`CharacterBody3D`, `collision_layer = 2`, `collision_mask = 1 | 4 | 16` [world, enemies, bounds]).
- **Body Collider:** `CapsuleShape3D(radius = 0.32m, height = 1.72m)` centered at `(0.0, 0.86, 0.0)`.
- **Hurtbox / Pickup `Area3D`:** `CapsuleShape3D(radius = 0.36m, height = 1.76m)`; pickup magnet radius `2.60m`, instant trigger radius `1.35m`.
- **Visual Facing Alignment:** `SK_Isabela.glb` faces **`+Z`** in rest pose (`SK_Isabela_Eyes` at `Z = +0.11..+0.13m`). Rotate the visual `SK_Isabela` node `rotation.y = PI` (`180°`) inside `Player` so her face/aim aligns with Godot's canonical **`-Z`** forward axis.

### 2.2 Movement, Water Interaction & Tactical Dash
| Parameter | Value | Notes |
|---|---|---|
| Walk / Sprint Speed | `5.8 m/s` / `8.6 m/s` | Aiming/firing reduces speed to `0.85×` (`4.93 m/s`) |
| Ground Accel / Decel | `42.0 m/s²` / `36.0 m/s²` | Air accel `16.0 m/s²`, decel `4.0 m/s²` |
| Shallow-Water Drag | `0.94×` when `Y <= 0.08m` | Emits radial ripple pulses every `0.38m` traveled, on jump landing, and on dash |
| Gravity / Fall Multiplier | `24.0 m/s²` / `1.25×` | Descent gravity `30.0 m/s²` |
| Jump Velocity | `8.8 m/s` | Peak height `~1.61m`; `coyote_time = 0.14s`, `jump_buffer = 0.12s` |
| Tactical Dash (`Q` / `Ctrl`) | `18.5 m/s` for `0.20s` | `0.24s` invulnerability frames (`iframes`), `1.60s` base cooldown (min `0.45s`), `1` base charge |

### 2.3 Over-Shoulder 3rd-Person Camera & Aim Convergence
- **Camera Rig:** `CameraPivot` at `(0.0, 1.48, 0.0)` -> `SpringArm3D` (offset `(0.58, 0.16, 0.0)`, `collision_mask = 1`, `spring_length = 3.2m` normal / `2.1m` RMB aim) -> `Camera3D` (`fov = 62°` normal, `46°` aim, `+5°` dash kick; pitch clamped `[-55°, +65°]`).
- **Parallax-Corrected Aim:** Center-screen raycast (`120.0m`, excluding player) computes world aim target; firearm projectiles/traces fire from weapon muzzle toward that point (clamped to forward cone if `< 1.5m` to prevent backward firing).

### 2.4 Skeleton, Hair Physics & Procedural Rig Animation
Verified `SK_Isabela` skeleton (`Armature_Isabela/Skeleton3D`, `84` bones):
- **Hair Physics:** `SpringBoneSimulator3D` with all 7 chains (`Hair_Front_L/R_01..04`, `Hair_Side_L/R_01..04`, `Hair_Back_L/C/R_01..04`) and 3 `SpringBoneCollisionSphere3D` (`Head`, `Neck`, `UpperChest`), preserving the verified `test_fase5_isabela.tscn` configuration.
- **Procedural Combat Pose (`player_animator.gd`):** Since `SK_Isabela.glb` exports clean rest pose without baked animations, `player_animator.gd` blends additive bone rotations onto `Hips`, `Spine`, `Chest`, `UpperChest`, `Neck`, `Head`, `Left/RightUpperLeg`, `Left/RightLowerLeg`, `Left/RightFoot`, and `Left/RightShoulder/UpperArm/LowerArm/Hand` for: Idle stance, Walk/Sprint stride, Aim pitch/yaw tracking, Firearm recoil kick, Melee 3-hit slash arcs, and Dash lean.
- **ARKit Expressions (`SK_Isabela_Body`, 52 blendshapes):** Periodic natural blink (`eyeBlinkLeft`/`eyeBlinkRight`), combat focus brow (`browDownLeft`/`Right`), and brief damage wince on hit.
- **Weapon Mounting:** `BoneAttachment3D(bone_name = "RightHand")` -> calibrated `WeaponSocket` (`Node3D`) aligning socket `-Z` forward along hand grip aim vector and `+Y` perpendicular to palm.

### 2.5 Survival & Input Map
- **HP:** `120.0` base Max HP, `0.35s` post-hit `iframes`, `0.15s` hit flash + camera trauma shake + HUD red vignette pulse.
- **Inputs (auto-registered cleanly if missing in `InputMap`):**
  - `move_forward/back/left/right`: `W / S / A / D`
  - `jump`: `Space` | `sprint`: `Shift` | `dash`: `Q` (alt `Ctrl`)
  - `fire`: `LMB` (alt `F`) | `aim`: `RMB` | `reload`: `R`
  - `weapon_1..6`: `1..6` | `weapon_next/prev`: `Wheel Up/Down` | `pause`: `Esc`

---

## 3. Arsenal (6 Weapons) — Combat Balance & 3D Modeling Specs

### 3.1 Combat & Ammo Balance Matrix (Base Lv1)
| Slot | ID / Asset | Delivery | Fire Rate | Damage | Crit | Range / AoE | Ammo / Resource | Reload / Cool | Special Trait |
|---:|---|---|---:|---:|---:|---|---|---:|---|
| `1` | `SM_Weapon_Pistol` | Hitscan + tracer | `4.5/s` | `22` (`1.6×` head) | `8% / 1.75×` | `55m` (`0.9°/0.25°`) | `15` mag / `180` (`300` max) | `1.15s` | Fast accurate sidearm |
| `2` | `SM_Weapon_Lightsaber` | Melee cone (`135°`) | `2.1/s` | `48` (`1.0 / 1.05 / 1.35×` combo) | `10% / 1.6×` | `2.75m` cleave (up to 8) | Unlimited | `—` | **Deflects enemy plasma bolts** (`1.75×` dmg) + `+5%` move speed |
| `3` | `SM_Weapon_Shotgun` | 8-pellet hitscan | `1.25/s` | `15.5 × 8` (`124` max) | `6% / 1.5×` | `22m` (`6.8°/4.8°`) | `6` mag / `36` (`64` max) | `1.65s` | Heavy knockback (`10.5 m/s`) |
| `4` | `SM_Weapon_RocketLauncher` | Explosive rocket (`28 m/s`) | `0.65/s` | `30` direct + `135` AoE | `5% / 1.5×` | `4.8m` splash radius | `2` mag / `10` (`20` max) | `2.20s` | High AoE blast (`0.15×` self-dmg safeguard) |
| `5` | `SM_Weapon_Katana` | Melee cone (`95°`) | `3.1/s` | `36` (`1.0 / 1.1 / 1.45×` combo) | `28% / 2.1×` | `2.40m` + `0.55m` lunge | Unlimited | `—` | `1.25×` armor pierce vs `SK_Droid_Tall` + `+8%` move speed |
| `6` | `SM_Weapon_LaserGun` | Piercing beam (`3` targets) | `10.0/s` | `13.5` (`1.4×` head) | `10% / 1.65×` | `60m` (`0.15°/0.05°`) | `100` battery (`4.5`/shot) | `22/s` regen (`1.8s` overheat; `R` vents `45/s`) | Zero ammo reserves; disciplined burst or manual vent |

### 3.2 3D Asset Modeling Specification (`@blender-author` — Start AFTER `#150` Fase 6 wraps)
**Global Weapon Rules (Godot `.glb` Y-up, meters, transforms applied, `0` UV overlaps, `2048×2048` BaseColor / Normal OpenGL Y+ / ORM [R=AO, G=Rough, B=Metal] + Emissive):**
- **Blender-to-Godot Axis Reminder:** Blender glTF `+Y Up` maps Blender `(X, Y, Z)` → Godot `(X, Z, -Y)`. Therefore, **modeling barrel/aim forward along Blender `+Y` and Up along Blender `+Z` exports cleanly as Godot `-Z` forward and `+Y` up**.
- **Grip Origin `(0, 0, 0)`:** Center of the primary hand grip (`~0.032–0.038m` diameter to fit Isabela's `~0.08m` palm).
- **Optional glTF Marker Nodes:** Adding an Empty child named `Muzzle` (for firearms) or `BladeBase` + `BladeTip` (for melee) at the exact offsets below helps Godot snap VFX directly, matching `data/game_balance.json`.

| Asset | Tris Budget | Godot AABB Dimensions (`W_x × H_y × L_z`) | Pivot & Orientation | Key Offsets (`[X, Y, Z]` in Godot m) | Visual & Emissive Spec |
|---|---:|---|---|---|---|
| `SM_Weapon_Pistol` | `2k–4.5k` | `0.036 × 0.155 × 0.240` | Grip center `(0,0,0)`, barrel `-Z`, top `+Y` | `Muzzle = [0.0, 0.058, -0.190]` | Brushed gunmetal slide, polymer textured grip, cyan/amber tritium sights & side charge bar (`Emissive`) |
| `SM_Weapon_Lightsaber` | `2.5k–5k` | `0.048 × 1.200 × 0.048` | Hilt grip center `(0,0,0)`, blade `+Y` (`0.14..1.06`) | `BladeBase = [0, 0.140, 0]`, `BladeTip = [0, 1.060, 0]` | Chrome/matte-black machined hilt (`-0.14..+0.14`); **separate submesh `SM_Weapon_Lightsaber_Blade`** for ignite scaling & cyan-white HDR plasma glow |
| `SM_Weapon_Shotgun` | `3.5k–6k` | `0.056 × 0.210 × 0.820` | Rear pistol-grip `(0,0,0)`, barrel `-Z`, top `+Y` | `Muzzle = [0.0, 0.072, -0.580]` | Industrial dark-steel receiver, vented shroud, ribbed pump, side shell saddle, orange heat-bar & reflex dot (`Emissive`) |
| `SM_Weapon_RocketLauncher` | `3.5k–6k` | `0.150 × 0.280 × 1.160` | Trigger grip `(0,0,0)`, tube above shoulder at `Y=+0.13`, `-Z` | `Muzzle = [0.0, 0.130, -0.680]` | Desert-tan / olive armored launch tube, hazard stripes, side lock-on optic with red/amber reticle (`Emissive`) |
| `SM_Weapon_Katana` | `2.2k–4.8k` | `0.078 × 1.050 × 0.068` | Tsuka grip `(0,0,0)`, blade `+Y` (`0.135..0.915`), sharp edge `-Z` | `BladeBase = [0, 0.135, 0]`, `BladeTip = [0, 0.915, 0.020]` | Wrapped charcoal tsuka, bronze/gunmetal tsuba guard, folded steel blade with crimson-amber thermal edge vein (`Emissive`) |
| `SM_Weapon_LaserGun` | `3.5k–6k` | `0.062 × 0.200 × 0.740` | Rear grip `(0,0,0)`, emitter `-Z`, top `+Y` | `Muzzle = [0.0, 0.068, -0.540]` | Ceramic-white & graphite energy carbine, exposed cyan plasma spine coils, battery canister, emitter rings (`Emissive`) |

---

## 4. World Pickups (2 Crates) — Gameplay & 3D Specs

| Asset | Gameplay Effect | Physics & Drop Rules | Godot Dimensions (`W × H × D`) & Pivot | Visual & Emissive Spec |
|---|---|---|---|---|
| `SM_Crate_Health` | Restores `35.0 HP + 10% Max HP` | Bobs at `Y=0.14 ± 0.08m` (`1.8 Hz`), spins `75°/s`; magnet `2.6m`, collect `1.35m`; base drop weight `0.45` (boosted if HP `< 40%`); `45s` TTL | `0.46 × 0.34 × 0.38m`, **pivot bottom-center `Y_min = 0.0`**, `1.8k–3.8k` tris, `2K PBR+Emissive` | White/silver medical case, chamfered bumpers, bright **emerald-green emissive cross & corner LEDs** |
| `SM_Crate_Ammo` | Refills `+40%` max reserve (Pistol, Shotgun, Rocket) + `100%` Laser battery restore/cool | Same bob/spin/trigger/TTL; base drop weight `0.55` (boosted if ammo low); max `4` active crates in arena | `0.50 × 0.32 × 0.36m`, **pivot bottom-center `Y_min = 0.0`**, `1.8k–3.8k` tris, `2K PBR+Emissive` | Olive-gunmetal ordnance crate, ribbed lid, latches, **warm amber-gold emissive charge bars** |

---

## 5. Enemy AI, IK & Wave Escalation

### 5.1 Enemy Archetypes
1. **`SK_Droid_Small` ("Droide Batedor", `1.035m`, `Capsule(r=0.28, h=1.04)`):**
   - **Behavior:** Agile melee rusher. Navigates toward Isabela using steering + obstacle avoidance around `SM_ShoreRocks`. At `<= 1.55m`, executes `0.35s` telegraph windup -> `12.0` dmg strike (`1.15s` cooldown).
   - **Stats (Wave 1):** `55 HP`, `4.6 m/s` (`+0.18 m/s`/wave up to `7.4 m/s`), `15%` knockback resistance, `18 + 2*(w-1)` XP, `10%` crate drop chance.
2. **`SK_Droid_Tall` ("Droide Sentinela", `1.979m`, `Capsule(r=0.36, h=1.98)`):**
   - **Behavior:** Armored enforcer introduced at **Wave 2**. Maintains `8–22m` combat distance when clear to fire glowing plasma bolts (`16 m/s`, `18` dmg, `0.55s` windup, `2.1s` cooldown — deflectable by `Lightsaber`!), or switches to `24` dmg heavy melee slam if player closes within `2.1m`.
   - **Stats (Wave 1 baseline):** `180 HP`, `3.1 m/s` (`+0.10 m/s`/wave up to `5.0 m/s`), `55%` knockback resistance, `55 + 6*(w-1)` XP, `28%` crate drop chance.
3. **Godot 4.7.2 `IKModifier3D` Integration:** Each droid uses `TwoBoneIK3D` nodes (`thigh.L/R -> shin.L/R -> foot.L/R`) targeting procedural stride foot-plant markers (ground height raycast) and torso/head aim tracking (`LookAtModifier3D` / procedural `head` yaw toward player).

### 5.2 Wave Formulas (Wave $w \ge 1$)
- **Total Enemies:** $N(w) = 6 + \lfloor 3.5 \cdot (w - 1) \rfloor$ (W1: `6`, W2: `9`, W3: `13`, W4: `16`, W5: `20`).
- **Tall Droid Ratio:** $0.0$ at W1; $\min(0.45,\ 0.18 + 0.04 \cdot (w - 2))$ for $w \ge 2$.
- **HP Multiplier:** $1.0 + 0.18(w - 1) + 0.02 \cdot \max(0, w - 5)^2$.
- **Damage Multiplier:** $1.0 + 0.10(w - 1)$.
- **Spawn Pacing:** Interval $\max(0.35,\ 1.35 - 0.10(w - 1))$s, concurrent active cap `min(20, 8 + 2*w)`, `1` ambient supply crate per wave, `2.5s` breather countdown after Upgrade Modal.

---

## 6. XP & Level-Up 3-Card Upgrade System

- **XP Curve:** $\text{XP}_{\text{next}}(L) = \text{round}(80 \cdot 1.28^{L-1})$ (`80`, `102`, `131`, `168`, ...). Wave clear grants `25 + 10*(w-1)` bonus XP AND guarantees at least 1 Upgrade Choice draft.
- **Rarity Roll:** `Comum` (`55%`, `1.0×`), `Raro` (`30%`, `1.5×`), `Épico` (`12%`, `2.1×`), `Lendário` (`3%` + `1%/wave` after W3, `3.0×`).
- **3 Unique Cards Drawn Per Draft** from 10 stackable upgrades (`weapon_damage`, `max_hp_heal`, `reload_speed`, `fire_rate`, `move_speed`, `ammo_capacity`, `blast_pierce`, `melee_crit`, `lifesteal`, `dash_recharge`).

---

## 7. Godot 4.7.2 Runtime Architecture & HUD

### 7.1 Modular File Tree (`< 300 lines` per script)
```
res://data/game_balance.json
res://scenes/game/
  ├── playable_arena.tscn        # Main playable wave-survival scene
  ├── player_isabela.tscn        # CharacterBody3D + SK_Isabela + SpringBoneSimulator3D + CameraRig + WeaponSocket
  ├── droid_small_enemy.tscn     # CharacterBody3D + SK_Droid_Small + TwoBoneIK3D
  ├── droid_tall_enemy.tscn      # CharacterBody3D + SK_Droid_Tall + TwoBoneIK3D
  ├── projectile_rocket.tscn     # Area3D rocket + splash AoE + blast VFX
  ├── projectile_plasma.tscn     # Area3D deflectable droid plasma bolt
  └── pickup_crate.tscn          # Area3D SM_Crate_Health / SM_Crate_Ammo
res://scripts/game/
  ├── balance_db.gd              # JSON loader, stat formulas, weapon/upgrade lookup
  ├── game_manager.gd            # Game state machine, XP/level, wave transitions, pause/game-over
  ├── player_controller.gd       # CharacterBody3D movement, water drag/ripples, coyote jump, dash+iframes, camera rig
  ├── player_animator.gd         # Procedural bone poses + ARKit blendshapes + SpringBoneSimulator3D hair
  ├── weapon_manager.gd          # Slots 1-6, ammo/reload/laser battery, hitscan/pellet/melee/rocket execution
  ├── enemy_droid.gd             # Shared Small/Tall droid AI, obstacle steering, telegraph, TwoBoneIK3D stride
  ├── projectile_controller.gd   # Rocket splash & enemy plasma movement + Lightsaber deflection
  ├── wave_spawner.gd            # Ring spawning, SM_Ship drop-beam VFX, crate drops
  ├── pickup_crate.gd            # Bob/spin/magnet/apply heal or ammo
  ├── upgrade_system.gd          # Weighted 3-card rarity draft + stackable stat multiplier accumulator
  └── hud_controller.gd          # Sci-fi HUD, 1-6 Weapon Bar, Crosshair/Hitmarker, Wave Banner, 3-Card Upgrade Modal
```

### 7.2 HUD & UI Elements (`hud_controller.gd`)
- **Top Center:** Wave indicator (`ONDA 1 — INIMIGOS RESTANTES: 6`) + animated Wave Banner + XP progress bar (`NÍVEL 1 — 0 / 80 XP`).
- **Bottom Left:** HP Bar (`120 / 120`) + Dash Cooldown pip(s) + active upgrade stack badges.
- **Bottom Center / Right:** **1–6 Weapon Hotbar** (slots `1`–`6` showing weapon name, active highlight, mag/reserve or battery % / ∞ icon) + contextual `[RECARREGANDO...]` or `[SUPERAQUECIDO — R PARA RESFRIAR]` indicator.
- **Center Screen:** Dynamic spread crosshair + hitmarker tick (white normal / gold crit) + directional damage vignette.
- **Modal Overlay (`PROCESS_MODE_ALWAYS`):** **3-Card Upgrade Selection UI** (pauses combat, releases mouse cursor, keyboard `1/2/3` or click to pick card cleanly) + **Pause / Victory-Endless / Game-Over** overlay with Restart button.

---

## 8. Verification Criteria (`@verifier`)
1. `Godot_v4.7.2-stable_win64_console.exe --headless --import` and loading `res://scenes/game/playable_arena.tscn` exit `0` with `0` errors / `0` warnings.
2. All 6 weapon `.glb` and 2 crate `.glb` assets meet tris budget (`~2k–6k`), `0` UV overlaps, `2K` PBR+Emissive maps, and exact pivot/scale alignment in Isabela's hand and on the shallow water plane.
3. Automated `--headless` gameplay simulation test verifies: player movement/jump/dash/iframes, switching slots `1..6` and firing all 6 weapons, `Lightsaber` plasma deflection, `RocketLauncher` splash AoE, `LaserGun` overheat/vent, droid AI damage/death/XP, crate pickup restore, and Wave 1 clear -> 3-card Upgrade Modal selection -> Wave 2 spawn (`SK_Droid_Tall` included).
4. Real GPU Forward+ screenshots inspected via `read_file`: Third-person combat framing, weapon in hand + muzzle/blade VFX, shallow water ripples + reflections, HUD + 1–6 bar, and 3-Card Upgrade Modal rendered legibly without overlap or blank frames.
