# CHANGELOG — Projeto Isabela 3D

## 2026-11-13
- **Created** `data/game_balance.json`: Added full playable wave-survival game configuration (arena bounds, `SK_Isabela` player physics/camera/dash, 6 weapons with combat balance and 3D `.glb` modeling specs/offsets, 2 pickup crates, `SK_Droid_Small` & `SK_Droid_Tall` enemy stats, wave progression curves, rarity weights, and 10 stackable upgrades). Validated via Godot 4.7.2 `--headless` JSON parse check (`JSON_OK weapons=6 pickups=2 upgrades=10`).
- **Created** `GAME_DESIGN.md`: Added complete Game Design & Godot 4.7.2 modular technical architecture document (`res://scenes/game/` + `res://scripts/game/`), non-interference rules preserving `main_isabela_scene.tscn`, verified bone/blendshape references, 3D modeling briefs for `@blender-author`, and verification acceptance criteria.
- **Created** `scripts/game/balance_db.gd` (`111` lines): JSON configuration loader (`res://data/game_balance.json`), weapon/pickup/enemy/progression lookup, and wave/XP math helpers (`get_wave_spec`, `get_xp_for_next_level`, `get_waves_cfg`).
- **Created** `scripts/game/upgrade_system.gd` (`158` lines): Stackable upgrade accumulator, weighted rarity roller with wave pity, and duplicate-free 3-card draft generator. Replaced global `BalanceDB` type reference with explicit `preload` (`BalanceDBRef`) after initial headless test uncovered Godot class-cache parse failure prior to `--import`.
- **Created** `scripts/game/input_setup.gd` (`47` lines): Idempotent `InputMap` bootstrap for WASD/Jump/Sprint/Dash/Fire/Aim/Reload/Slots 1–6/Upgrade keys.
- **Created** `scripts/game/weapon_loadout.gd` (`250` lines): Per-slot runtime ammo, reload timer, Laser Gun battery drain/overheat/manual vent, 3-hit melee combo progression, and upgrade stat scaling.
- **Created** `scripts/game/game_manager.gd` (`154` lines): Game state machine (`PLAYING`, `UPGRADE_MODAL`, `PAUSED`, `GAME_OVER`), XP/level-up queueing, wave clear upgrade guarantee, and lifesteal/countdown signals.
- **Created** `tests/test_balance_and_upgrades.gd` (`97` lines) & `tests/test_combat_core.gd` (`112` lines): Headless Godot 4.7.2 TDD verification suites covering JSON schema, wave scaling, 3-card drafts, 6-weapon firing/reload/overheat/combo logic, and wave transitions.
- **Created** `scripts/game/wave_spawner.gd` (`177` lines), `scripts/game/pickup_crate.gd` (`109` lines), `scripts/game/projectile_controller.gd` (`191` lines), and `tests/test_spawner_projectiles_pickups.gd` (`121` lines).
  - Updated `wave_spawner.gd` low-HP `health_crate` weight boost from `2.8x` to `3.2x` after initial TDD probability run (`64/100`), then verified `ALL_TESTS_PASSED: test_spawner_projectiles_pickups`.
- **Created** `scripts/game/player_controller.gd`, `scripts/game/player_camera_rig.gd`, `scripts/game/player_animator.gd`, `scripts/game/weapon_manager.gd`, `scripts/game/enemy_droid.gd`, `scripts/game/upgrade_modal_ui.gd`, `scripts/game/hud_controller.gd`, `scripts/game/arena_coordinator.gd`, plus TDD suites `tests/test_player_enemy_weapons.gd` and `tests/test_hud_and_arena_loop.gd`.
  - Refactored `PlayerCameraRig` out of `player_controller.gd` (`259` lines) and `UpgradeModalUI` out of `hud_controller.gd` (`280` lines) so every script stays `<= 280` lines.
  - Added idempotent `_ensure_ui()`/`_ensure_layout()`, `_connect_once()` signal guards, `InputSetupRef.ensure_default_actions()` inside `PlayerController`, `Target_Foot_L`/`Target_Foot_R` `TwoBoneIK3D` stride support in `enemy_droid.gd`, and dynamic `ripple_center_0..3` shallow-water tracking in `arena_coordinator.gd`.
  - Verified all 5 headless TDD suites (`test_balance_and_upgrades.gd`, `test_combat_core.gd`, `test_spawner_projectiles_pickups.gd`, `test_player_enemy_weapons.gd`, `test_hud_and_arena_loop.gd`) pass (`exit 0`).

## [2026-11-13 20:48] WaveSpawner, GameManager, WeaponManager, HUD Refactor & E2E Stabilization
- **`scripts/game/wave_spawner.gd`**:
  - Removed `_entities_root.add_child(enemy)` before `enemy.global_position = spawn_pos` in `_spawn_enemy` and `_entities_root.add_child(crate)` before position assignment in `_instantiate_crate`.
  - Added pre-insert local `position = _entities_root.to_local(...)` assignment before `add_child(...)` so spawned droids/crates never overlap `Player` at `(0,0,0)` inside `PhysicsServer3D`.
- **`scripts/game/upgrade_system.gd` & `scripts/game/game_manager.gd`**:
  - Added `DEFAULT_STATS` and `UpgradeSystem.reset()`; updated `GameManager.start_run()` to reuse/reset `upgrades` and `loadout` instead of reallocating new instances so `Player`, `WeaponManager`, `HUD`, and `PickupCrate` keep referencing the single live objects.
- **`scripts/game/weapon_manager.gd`**:
  - Fixed GDScript `Array[RID]` ternary type error in `_fire_piercing_laser`; separated `_get_combat_ray_origin(muzzle_fallback)` (chest/weapon height `Y+0.94m`) from `muzzle_pos` for physics raycast/rocket origin while preserving `muzzle_pos` for flash/beam FX.
- **`scripts/game/hud_weapon_bar.gd` (new, 75 lines), `scripts/game/hud_controller.gd` (345 -> 298 lines), `scripts/game/player_controller.gd` (304 -> 297 lines)**:
  - Extracted `HUDWeaponBar` (`hud_weapon_bar.gd`) and tightened `PlayerController` movement/signal wiring so every script in `scripts/game/` remains strictly under 300 lines.
- **`tests/test_playable_arena_e2e.gd`**:
  - Added PhysicsServer3D sync steps (`await _step_frames`), dedicated target dummy checks for Katana/LaserGun/RocketLauncher, Health+Ammo `PickupCrate` verification using `get_slot_hud_state`, and Level-Up/Wave-Clear 3-card modal + Wave 2 transition checks. Verified all 6 `--headless` suites green.

## [2026-11-13 20:57] Visual Polish — Upgrade Modal Padding, HUD Outlines & Animator Pose
- **`scripts/game/upgrade_modal_ui.gd`**:
  - Wrapped card `VBoxContainer` inside a `MarginContainer` (`16px` horizontal, `14px` vertical margins) so card text no longer hugs colored card borders.
- **`scripts/game/hud_controller.gd`**:
  - Added dark `font_outline_color` (`outline_size = 4`) in `_make_label` for crisp HUD readability against bright sky and dark water; kept file at `292` lines (`< 300`).
- **`scripts/game/player_animator.gd`**:
  - Fixed firearm `RightUpperArm` pose (`-1.18` overhead -> `-0.48` shoulder aim), kept `RightHand` neutral to prevent wrist mesh twisting, and lowered `LeftUpperArm` (`Z = -0.62`) for natural athletic stance.

## [2026-11-14 08:35] Desktop Launcher Shortcut
- **Created `C:\Users\thiag\Desktop\Iniciar Isabela 3D.bat` (new file, nothing removed)**:
  - Added ASCII/CRLF batch launcher verifying `D:\Godot\Godot_v4.7.2-stable_win64.exe`, `D:\Godot\isabela_scene_test\project.godot`, and `D:\Godot\isabela_scene_test\scenes\game\playable_arena.tscn` before invoking Godot 4.7.2 directly into `res://scenes/game/playable_arena.tscn` via `--path` and `--scene`, so double-clicking starts the wave-survival game without modifying `run/main_scene` in `project.godot`.

## [2026-11-14 09:25] Fase 8 TPS Animation Library & FPS Viewmodel Arms
- **Backup created**: `D:\Godot\isabela_scene_test\.backups\CHANGELOG.md.20261114_092448.bak` before appending entry (`SK_Isabela.glb`, `main_isabela_scene.tscn`, `.gd`, and `data/game_balance.json` untouched).
- **Created `D:\Godot\isabela_scene_test\blend_sources\fase8_isabela_animations.blend` & `D:\Godot\isabela_scene_test\assets\SK_Isabela\SK_Isabela_Anims.glb` (`4,760,108` bytes)**:
  - Retargeted 16 UAL clips (`Idle_Loop`, `Walk_Loop`, `Jog_Fwd_Loop`, `Sprint_Loop`, `Crouch_Idle_Loop`, `Jump_Start`, `Jump_Loop`, `Jump_Land`, `Roll`, `Pistol_Idle_Loop`, `Pistol_Shoot`, `Pistol_Reload`, `Sword_Idle`, `Sword_Attack`, `Hit_Chest`, `Death01`) via exact world-basis A-pose -> T-pose quaternion conversion onto untouched 84-bone `Armature_Isabela` (`Max bone rest origin diff: 0.0` vs `SK_Isabela.glb`, verified in Godot 4.7.2 `--headless`).
  - Authored 12 combat clips (`Rifle_Idle_Loop`, `Rifle_Shoot`, `Rifle_Reload`, `Rocket_Idle_Loop`, `Rocket_Shoot`, `Rocket_Reload`, `Katana_Combo_1..3`, `Saber_Combo_1..3`) plus 3 additive/layer finger-grip tracks (`Grip_RightHand`, `Grip_LeftHand`, `Grip_BothHands`) using rigid shared-pivot curl matching `SK_Isabela_Body` skinning; left `Hair_*`, `Jaw`, `LeftEye`, `RightEye` unkeyed so Godot `SpringBoneSimulator3D` and facial tracks compose cleanly. Added microscopic `0.0002m` `Armature_SkinProxy` (`export_skins=True, export_materials='NONE'`) so Godot generates `Skeleton3D` tracks (`Armature_Isabela/Skeleton3D:*`).
- **Created `D:\Godot\isabela_scene_test\blend_sources\fase8_fps_arms.blend` & `D:\Godot\isabela_scene_test\assets\SK_Isabela\FPS_Arms.glb` (`12,895,116` bytes)**:
  - Extracted dedicated 1st-person arms + red vinyl sleeves (`FPS_Arms_Skin`, `FPS_Arms_Sleeves`) with planar bicep bisects and smooth topological 5-finger per-hand rigging (39 bones, `FPS_Root` + `Left/RightShoulder..Hand` + 30 finger bones, 55% forearm pronation twist distribution, opaque PBR materials), oriented in Godot `-Z` forward with `BoneAttachment3D("RightHand")/FPSWeaponSocket` (`world pos=(0.0917, -0.1111, -0.3655)`, `fwd=-Z`).
  - Baked 9 FPS NLA tracks at 24 FPS: `FPS_Idle` (2.0s), `FPS_Walk` (1.0s), `FPS_Fire_Pistol` (0.333s), `FPS_Fire_Heavy` (0.583s), `FPS_Reload` (1.5s), `FPS_Melee_1` (0.583s), `FPS_Melee_2` (0.583s), `FPS_Melee_3` (0.833s), `FPS_Draw` (0.5s).
- **Verified**: Cycles multi-pose inspection renders `tps_anims_sheet.png` and `fps_arms_preview.png` inspected visually + Godot 4.7.2 headless `GLTFDocument` check (`GODOT_GLB_VERIFY=PASS`).

## [2026-11-14 09:38] Fase 8 V2 — Closer TPS Camera, Retargeted SK_Isabela Animations, Finger Grips & Seamless TPS/FPS Toggle
- **Backups created**: `D:\Godot\isabela_scene_test\.backups\20261114_085506\`, `20261114_093000\`, and `20261114_093700\` prior to file edits (`SK_Isabela.glb` and `scenes/main_isabela_scene.tscn` left strictly untouched).
- **`data/game_balance.json`**:
  - Replaced distant Phase 7 `player.camera` values (`pivot_height_m=1.52`, `shoulder_offset_m=[0.52,0.14,0.0]`, `spring_length_normal_m=2.75`, `spring_length_aim_m=1.80`, `fov_normal_deg=64.0`, `fov_aim_deg=50.0`, `pitch_min_deg=-48.0`, `pitch_max_deg=42.0`) with tighter over-the-shoulder TPS framing (`pivot_height_m=1.30`, `shoulder_offset_m=[0.40,0.08,0.0]`, `spring_length_normal_m=1.80`, `spring_length_aim_m=1.18`, `fov_normal_deg=66.0`, `fov_aim_deg=50.0`, `pitch_min_deg=-58.0`, `pitch_max_deg=50.0`) and added FPS view settings (`fps_eye_height_m=1.58`, `fps_fov_normal_deg=86.0`, `fps_fov_aim_deg=66.0`, `fps_pitch_min_deg=-82.0`, `fps_pitch_max_deg=82.0`).
- **`scenes/game/player_isabela.tscn`**:
  - Updated `CameraPivot` Y `1.52 -> 1.3`, `SpringArm3D` offset `(0.52, 0.14, 0) -> (0.4, 0.08, 0)` and `spring_length` `2.75 -> 1.8`, `Camera3D` `fov=66.0`, `near=0.03`.
  - Updated `RightHandAttachment/WeaponSocket` transform (`position=(-0.015, 0.085, 0.015), rotation=(1.096067, 2.06996, 0.912807)` -> `position=(0.012, 0.068, 0.01), rotation=(1.35, 0.54, -0.26)`) verified against Forward+ renders for retargeted Pistol, Shotgun, and Katana grip alignment.
- **`scripts/game/input_setup.gd`**:
  - Added `toggle_view` (`KEY_V`) and `toggle_fps_centered` (`KEY_H`) input action registration in `ensure_default_actions()`.
- **`scripts/game/anim_library_loader.gd` (`207` lines) & `scripts/game/player_animator.gd` (`292` lines)**:
  - Replaced procedural-only animator with runtime loader (`load_clips_into_player` + `setup_isabela_anim_tree`) importing all 31 clips from `res://assets/SK_Isabela/SK_Isabela_Anims.glb`, setting `LOOP_LINEAR` on cyclic clips (`Idle`, `Walk`, `Jog_Fwd`, `Sprint`, `Crouch_Idle`, `Jump`, `Pistol_Idle`, `Rifle_Idle`, `Rocket_Idle`, `Sword_Idle`), and stripping `Hair_`/`LeftEye`/`RightEye` tracks to preserve `SpringBoneSimulator3D` hair physics and ARKit blink/focus/wince blendshapes.
  - Built layered `AnimationNodeBlendTree` combining `Loco` (`idle/walk/jog/sprint/jump_start/jump_loop/jump_land/roll/hit/death`), bone-filtered `UpperBlend` (`UpperIdle` + `UpperAction` OneShot for Pistol/Rifle/Rocket/Katana 1-3/Lightsaber 1-3), and finger-filtered `GripBlend` (`GripChoice` switching `Grip_RightHand` vs `Grip_BothHands`), plus additive strafe/pitch torso twist and `set_first_person_shadow_only()`.
- **`scripts/game/fps_viewmodel.gd` (`241` lines) & `scripts/game/player_camera_rig.gd` (`162` lines)**:
  - Created `FPSViewmodel` mounting `res://assets/SK_Isabela/FPS_Arms.glb` and active `SM_Weapon_*` under `Camera3D`, setting `LOOP_LINEAR` on `FPS_Idle`/`FPS_Walk`, disabling shadows on viewmodel meshes, and driving mouse inertia sway, idle/move bob, per-weapon hip/ADS/Doom-centered offsets, recoil, reload dips, and 3-step FPS melee slashes.
  - Added seamless TPS <-> FPS toggling (`toggle_view_mode`, `sync_player_view`, FPS eye height/FOV/pitch clamp, and center-screen aim ray with `min_dist=0.35`).
- **`scripts/game/weapon_vfx.gd` (`107` lines) & `scripts/game/weapon_manager.gd` (`285` lines)**:
  - Extracted `WeaponVFX` (`107` lines) with directional crescent `spawn_blade_trail()` meshes for Katana/Lightsaber 3-hit combos; wired `WeaponManager` to source FPS muzzle FX from `FPSViewmodel.get_muzzle_world_position()`, keep exact center-screen FPS raycast accuracy, and set `SHADOWS_ONLY` on TPS weapon visuals in FPS mode.
- **`scripts/game/hud_crosshair.gd` (`131` lines), `scripts/game/hud_controller.gd` (`291` lines), `scripts/game/player_combat_helper.gd` (`99` lines), `scripts/game/player_controller.gd` (`289` lines)**:
  - Extracted `HUDCrosshair` + dynamic crosshair/hitmarker + `[V] Visão: 3ª Pessoa / 1ª Pessoa (FPS)` indicator (`get_view_mode_text()`).
  - Extracted `PlayerCombatHelper` to keep `player_controller.gd` under `300` lines; wired `[V]`/`[H]`, `view_mode_changed`, animator combat triggers, and strafe input forwarding.
- **`tests/test_v2_camera_anims_fps.gd` & `manifest.json`**:
  - Added automated headless suite testing camera distances, `[V]`/`[H]` inputs, TPS<->FPS toggle + `SHADOWS_ONLY` + `FPSViewmodel` + muzzle origin + Doom offset + HUD indicator, plus all 31 `SK_Isabela_Anims.glb` clips, loop modes, hair track stripping, `AnimationTree` states, and all 9 `FPS_Arms.glb` clips. Updated `manifest.json` with `SK_Isabela_Anims`, `FPS_Arms`, and V2 validation renders.
  - Verified `--headless --import` (`exit 0`), `main_isabela_scene.tscn --quit` (`exit 0`), `playable_arena.tscn --quit` (`exit 0`), all 22 `scripts/game/*.gd` `< 300` lines (`max = 293`), and all 7 headless test suites (`exit 0`).

## [2026-11-14 17:52] Full Gamepad / Controller Support & Upgrade Modal Focus Navigation
- **Backups created**: `D:\Godot\isabela_scene_test\.backups\game_balance.json.20261114_174507.bak`, `input_setup.gd.20261114_174507.bak`, `player_camera_rig.gd.20261114_174507.bak`, `upgrade_modal_ui.gd.20261114_174507.bak`, `hud_controller.gd.20261114_174507.bak`, and `CHANGELOG.md.20261114_175147.bak` prior to edits (`SK_Isabela.glb` and `scenes/main_isabela_scene.tscn` left strictly untouched).
- **`data/game_balance.json`**:
  - Added `"controller_sensitivity": 3.4` and `"controller_aim_sensitivity_multiplier": 0.65` under `"player"."camera"` to allow smooth proportional analog stick camera rotation and ADS fine-aim dampening.
- **`scripts/game/input_setup.gd`**:
  - Extended idempotent `ensure_default_actions()`:
    - Registered analog look axes: `look_left`/`look_right` (`JOY_AXIS_RIGHT_X`), `look_up`/`look_down` (`JOY_AXIS_RIGHT_Y`).
    - Registered analog movement & D-pad: `move_left`/`move_right` (`JOY_AXIS_LEFT_X`, `JOY_BUTTON_DPAD_LEFT`, `JOY_BUTTON_DPAD_RIGHT`), `move_forward`/`move_back` (`JOY_AXIS_LEFT_Y`, `JOY_BUTTON_DPAD_UP`, `JOY_BUTTON_DPAD_DOWN`).
    - Registered action buttons: `fire` (RT `JOY_AXIS_TRIGGER_RIGHT`), `aim` (LT `JOY_AXIS_TRIGGER_LEFT`), `jump` (A `JOY_BUTTON_A`), `dash` (B `JOY_BUTTON_B`), `reload` (X `JOY_BUTTON_X`), `toggle_view` (Y `JOY_BUTTON_Y`), `sprint` (L3 `JOY_BUTTON_LEFT_STICK`), `toggle_fps_centered` (R3 `JOY_BUTTON_RIGHT_STICK`), `pause_game` (Start `JOY_BUTTON_START`), `prev_weapon` (LB `JOY_BUTTON_LEFT_SHOULDER`), `next_weapon` (RB `JOY_BUTTON_RIGHT_SHOULDER`).
    - Registered Upgrade Modal card selection shortcuts: `upgrade_select_1` (`JOY_BUTTON_X`, `JOY_BUTTON_DPAD_LEFT`), `upgrade_select_2` (`JOY_BUTTON_Y`, `JOY_BUTTON_DPAD_UP`), `upgrade_select_3` (`JOY_BUTTON_B`, `JOY_BUTTON_DPAD_RIGHT`).
- **`scripts/game/player_camera_rig.gd`**:
  - Added `apply_controller_look(look_vec: Vector2, delta: float, is_aiming: bool)` scaling look vector by `controller_sensitivity * (controller_aim_sensitivity_multiplier if is_aiming else 1.0) * delta` and updating `yaw_rad` / `pitch_rad`.
  - Added analog right-stick polling in `update_rig()` via `Input.get_vector("look_left", "look_right", "look_up", "look_down")` with automatic deadzone processing.
- **`scripts/game/upgrade_modal_ui.gd`**:
  - Configured card buttons with `FOCUS_ALL`, neighbouring navigation shortcuts (`focus_neighbor_left`/`right`), and gold highlight border (`focus_style`).
  - Added automatic focus grabbing `_buttons[0].grab_focus()` when modal opens (`if is_inside_tree()`).
  - Added controller shortcut badges on cards (`[1/X]`, `[2/Y]`, `[3/B]`) and controller button listeners in `_unhandled_input()` with safe `get_viewport()` null-guards.
- **`scripts/game/hud_controller.gd`**:
  - Wired `_pause_btn.grab_focus()` when pausing or entering game over state so gamepads can select "REINICIAR PARTIDA" immediately via `JOY_BUTTON_A` (`ui_accept`).
- **`tests/test_gamepad_support.gd` (new, 140 lines)**:
  - Created automated test suite verifying Joypad action bindings, analog stick look integration, upgrade modal button focus / D-pad / shortcut navigation, and pause menu focus.
- **Verification**:
  - All 8 headless test suites (`test_balance_and_upgrades`, `test_combat_core`, `test_player_enemy_weapons`, `test_spawner_projectiles_pickups`, `test_hud_and_arena_loop`, `test_playable_arena_e2e`, `test_v2_camera_anims_fps`, `test_gamepad_support`) passed (`exit 0`).
  - All 22 scripts in `scripts/game/` confirmed strictly `< 300` lines (range 64 to 250 lines).

## [2026-11-15 17:16] Correção de Poke-Through na Jaqueta, Alinhamento de Grip das Armas, SMG Automática (Slot 7) e Assets2Godot
- **Backups created**: `D:\Godot\isabela_scene_test\.backups\*` (`20261115_165827`, `20261115_170706`, `20261115_171403` cobrindo `project.godot`, `player_isabela.tscn`, `game_balance.json`, `balance_db.gd`, `weapon_loadout.gd`, `hud_weapon_bar.gd`, `input_setup.gd`, `player_combat_helper.gd`, `player_animator.gd`, `fps_viewmodel.gd`, `test_balance_and_upgrades.gd`, `test_hud_and_arena_loop.gd`, `test_jacket_and_weapon_grip.gd`, `CHANGELOG.md`). `SK_Isabela.glb` e `scenes/main_isabela_scene.tscn` mantidos intactos.
- **Correção da jaqueta nas costas (`SK_Isabela_Top`) e grip das armas (TPS/FPS)**:
  - Removido/substituído offset antigo do `WeaponSocket` (`Vector3(-0.068, 0.178, 0.032)` -> `Vector3(-0.120, 0.162, 0.098)` -> calibrado para `Vector3(-0.096, 0.064, 0.100)`) em `scenes/game/player_isabela.tscn` (linha 95) e no fallback de `scripts/game/player_animator.gd` (linha 61), posicionando o encaixe diretamente no centróide real dos vértices esfolados da palma e dedos (`RightHand`, `RightThumbDistal`, `RightIndexDistal`, `RightMiddleDistal`) em espaço local de `RightHandAttachment` (eliminando o afastamento de ~10 cm visível antes).
  - Atualizado `data/game_balance.json` para `lightsaber` e `katana` com `"tps_grip_pos": [0.0, 0.0, 0.0]` e `"tps_grip_rot_deg": [-85.0, 0.0, 0.0]` para alinhar as lâminas para frente/fora na mão direita em 3ª pessoa, e `"fps_grip_rot_deg": [-15.0, 0.0, 0.0]`.
  - Validado visualmente nas prévias de jog, TPS (`pistol`, `smg`, `katana`, `lightsaber`) e FPS (`smg`, `katana`, `lightsaber`).
- **Nova arma: SMG Automática (`SM_Weapon_SMG`, Slot 7)**:
  - Asset obtido via API pública do BlendKit (`SMG Sci Fi submachine gun concept`, licença `royalty_free`, formato `gltf_godot`), normalizado no Blender 5.2 para `assets/SM_Weapon_SMG/SM_Weapon_SMG.glb` (pivô no grip `(0,0,0)`, cano apontado em `-Z`, topo em `+Y`, nó `Muzzle` adicionado, texturas reduzidas para `<= 1024px`, malha otimizada de `128.568` para `62.335` vértices) e importado no Godot 4.7.2.
  - Adicionado Slot `7` `"id": "smg"` (`"SMG Automática"`, `"fire_mode": "auto"`, `14.0` de dano, `12.5 Hz` / 750 RPM, carregador `36`, reserva `216`/`360`, recarga `1.45s`) em `data/game_balance.json`.
  - Atualizado `scripts/game/balance_db.gd` (`_weapons_by_slot.size() >= 6`), `scripts/game/input_setup.gd` (`weapon_1`..`weapon_7`), `scripts/game/weapon_loadout.gd` (`cycle_slot` usando `maxi(1, _slots.size())`), `scripts/game/player_combat_helper.gd` (`range(1, 8)`), `scripts/game/hud_weapon_bar.gd` (7 slots em `114x56`), `scripts/game/player_animator.gd` (`"smg"` em `rifle_shoot`, `rifle_reload` e `UpperIdle="rifle"` / `GripChoice="both"`) e `scripts/game/fps_viewmodel.gd` (`WEAPON_TWEAKS["smg"]` + `FPS_Fire_Heavy`).
- **Plugin `Assets2Godot` (`D:\Godot\addons\assets2godot` -> `res://addons/assets2godot`)**:
  - Copiado `Assets2Godot v0.8.2` de `D:\Godot\addons\assets2godot` para `D:\Godot\isabela_scene_test\addons\assets2godot` e habilitado em `project.godot` sob `[editor_plugins] enabled=PackedStringArray("res://addons/assets2godot/plugin.cfg")`.
- **Verificação**:
  - Atualizados `tests/test_balance_and_upgrades.gd`, `tests/test_hud_and_arena_loop.gd` e `tests/test_jacket_and_weapon_grip.gd` (com medição real do centróide esfolado da mão direita e wrap `7 -> 1`).
  - Todas as **9 suítes headless** passaram com `EXIT=0` (`ALL_TESTS_PASSED`).
  - Todos os **22 scripts** em `scripts/game/*.gd` verificados abaixo de 300 linhas (máximo `299` em `player_animator.gd`).

## [2026-11-15 17:34] Preparação de Documentação, Contexto para Agentes e Publicação no GitHub
- **Arquivos criados**:
  - `.gitignore`: ignora cache `.godot/`, `.backups/`, backups do Blender (`*.blend1`, `*.blend2`, `*.blend@`), executáveis baixados pelo `Assets2Godot` (`addons/assets2godot/client/**`), `.venv/` e metadados locais de SO/IDE (preservando `*.import` e `*.uid`).
  - `.gitattributes`: normaliza fins de linha de recursos texto do Godot e configura **Git LFS** para `*.blend` (necessário para `blend_sources/fase6_validation_scene.blend`, ~117,5 MB).
  - `README.md`: documentação para colaboradores com visão geral do jogo, tabela do arsenal (7 armas), requisitos passo-a-passo (Git + Git LFS, Godot `4.7.2-stable`, Blender `5.2+` opcional, `Assets2Godot v0.8.2`), controles completos (Teclado/Mouse e Gamepad), comandos para as 9 suítes de testes headless e regras de contribuição.
  - `GEMINI.md`: guia de contexto técnico para agentes de IA com arquitetura modular dos 22 scripts em `scripts/game/`, invariantes (`< 300` linhas/script, proteção de `SK_Isabela.glb` e `main_isabela_scene.tscn`), armadilhas resolvidas (`WeaponSocket`, `SceneTree.quit`, facing `+Z`/`-Z`) e protocolo obrigatório de verificação.
- **Publicação Git / GitHub**: repositório `floodnet666/isabela-3d-survival` inicializado em `main` com Git LFS para `*.blend` e enviado ao GitHub (`public`).

## [2026-11-15 17:49] Correção de Pausa (Esc) — Congelamento de Inimigos, Projéteis e Spawner
- **Backups criados**: `D:\Godot\isabela_scene_test\.backups\arena_coordinator.gd.20261115_*.bak`, `test_hud_and_arena_loop.gd.20261115_*.bak`, `CHANGELOG.md.20261115_*.bak`.
- **`scripts/game/arena_coordinator.gd` (linha 26)**:
  - **Removido**: `process_mode = Node.PROCESS_MODE_ALWAYS`
  - **Adicionado**: `process_mode = Node.PROCESS_MODE_PAUSABLE`
  - **Motivo**: como `PlayableArena` é o nó raiz da cena, `PROCESS_MODE_ALWAYS` fazia todos os filhos com `INHERIT` (`Entities`, `EnemyDroid`, `WaveSpawner`, `ProjectileController`, `PickupCrate`, `Player`, `SM_Ship`) continuarem processando e atacando mesmo com `get_tree().paused = true`. `HUD` (`hud_controller.gd`) e `UpgradeModalUI` (`upgrade_modal_ui.gd`) já definem `PROCESS_MODE_ALWAYS` explicitamente e continuam recebendo `Esc`/`Start` e cliques normalmente.
- **`tests/test_hud_and_arena_loop.gd`**:
  - Adicionado teste de regressão `_test_pause_freezes_enemies_and_spawner()` simulando `pause` (`Esc`) com inimigo a `1,0 m` do jogador durante 35 frames de física (verificando zero dano/movimento em pausa, `HUD` processável e retomada limpa no segundo `Esc`).
- **Verificação**:
  - Todas as **9 suítes headless** passaram com `EXIT=0` (`ALL_9_TESTS_PASSED`).
  - `scripts/game/*.gd` mantidos abaixo de 300 linhas (`arena_coordinator.gd` com 203 linhas).

## [2026-11-15 17:57] Workflow CI no GitHub Actions (`.github/workflows/godot-tests.yml`)
- **Backup criado**: `D:\Godot\isabela_scene_test\.backups\CHANGELOG.md.20261115_175716.bak`.
- **Adicionado [`.github/workflows/godot-tests.yml`](file:///D:/Godot/isabela_scene_test/.github/workflows/godot-tests.yml)**:
  - **Triggers**: `pull_request` (`branches: [main]`), `push` (`branches: [main]`) e `workflow_dispatch`, com `concurrency` cancelando execuções anteriores no mesmo ref.
  - **Checkout enxuto**: `actions/checkout@v4` com `lfs: false` para não baixar os `.blend` de `blend_sources/` via Git LFS no CI.
  - **Trava `< 300` linhas**: verifica cada arquivo em `scripts/game/*.gd` via `wc -l`, emitindo erro `::error file=...::` se atingir `>= 300` linhas.
  - **Godot `4.7.2-stable` Linux headless + cache**: faz cache do binário `Godot_v4.7.2-stable_linux.x86_64` em `~/.cache/godot/4.7.2-stable` e de `.godot/imported`, executa `--headless --path . --import` (`timeout 180s`) e roda sequencialmente todas as suítes `tests/test_*.gd` (`timeout 120s` por suíte).

