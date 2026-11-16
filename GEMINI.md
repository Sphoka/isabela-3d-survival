# GEMINI.md — Contexto e Regras para Agentes de IA

Este arquivo fornece contexto técnico estruturado para agentes de IA (Antigravity, Gemini CLI, Claude Code, Codex ou colaboradores assistidos por IA) atuarem com segurança neste repositório e retomarem o trabalho em novas sessões sem perda de contexto.

---

## 1. Visão Geral do Projeto
- **Nome:** Projeto Isabela 3D — Wave Survival Action Game
- **Engine:** Godot `4.7.2-stable` (`Forward+`, `config/features = PackedStringArray("4.7", "Forward Plus")`)
- **Arte 3D / Pipeline:** Blender `5.2+` (`.blend` em `blend_sources/`, exportação `.glb` Y-up em `assets/`)
- **Fonte Única de Balanceamento:** `data/game_balance.json` (lido por `scripts/game/balance_db.gd`)
- **Cena Inicial (`run/main_scene` em `project.godot`):** `res://scenes/game/main_menu.tscn` (Menu Principal → `res://scenes/game/playable_arena.tscn`)
- **CI Automático (`.github/workflows/godot-tests.yml`):** roda em todo `push` e `pull_request` para `main`, aplicando trava `< 300` linhas em `scripts/game/*.gd` e executando todas as `14` suítes `tests/test_*.gd` em Linux headless (`lfs: false`).

---

## 2. Mapa de Diretórios e Arquitetura (Estado Atual — `38` Scripts)

```text
res://
├── .github/workflows/            # godot-tests.yml (trava < 300 linhas + 14 suítes headless)
├── addons/assets2godot/          # Assets2Godot v0.8.2 (GPLv2) — habilitado em project.godot
├── assets/                       # Assets .glb Y-up + texturas VRAM Compressed (compress/mode=2) + audio .ogg
│   ├── ENV_DesertCoast/          # Terreno/dunas, pedras de cobertura (SM_DesertDunes, SM_ShoreRocks)
│   ├── SK_Isabela/               # SK_Isabela.glb (base protegida), SK_Isabela_Leeloo.glb (84 ossos), FPS_Arms.glb
│   ├── SK_Droid_Small/           # Droide Batedor (melee, TwoBoneIK3D)
│   ├── SK_Droid_Tall/            # Droide Sentinela (ranged/melee, TwoBoneIK3D)
│   ├── SM_Ship/                  # Nave-mãe orbital (sombras desativadas em runtime para desempenho)
│   ├── SM_Crate_Health/, SM_Crate_Ammo/, SM_Helmet_A/, SM_Helmet_B/
│   ├── SM_Weapon_*/              # 7 slots: Pistol (1), Sniper (2), Shotgun (3), RocketLauncher (4), Katana (5), LaserGun (6), SMG (7)
│   ├── audio/music/ & sfx/       # punk_rock_loop.ogg + 15+ SFX .ogg (com fallback procedural em ProceduralSFX)
│   └── ui/main_menu_bg.png       # Arte do Menu Principal (mantida sem compressão destrutiva)
├── blend_sources/                # Fontes .blend (rastreadas via Git LFS; .gdignore presente)
├── data/game_balance.json        # Fonte única de verdade: arena, player, 7 armas, pickups, 4 droids, waves, upgrades
├── docs/TRILHA_3_PLAN.md         # Especificação técnica pronta da Trilha 3 (Boss, Skins/Capacetes, Mini-Radar)
├── scenes/
│   ├── main_isabela_scene.tscn   # Cena showcase Fase 6 (PROIBIDO alterar sem pedido explícito)
│   ├── test_fase1..5_*.tscn      # Cenas de validação das Fases 1-5 (PROIBIDO alterar)
│   └── game/                     # main_menu, playable_arena, player_isabela, droid_small_enemy, droid_tall_enemy, droid_spider, droid_sawbox
├── scripts/game/                 # 38 scripts modulares (TODOS estritamente < 300 linhas)
├── shaders/                      # shallow_mirror_water.gdshader + M_ShallowMirrorWater.tres
└── tests/                        # 14 suítes de testes headless Godot
```

### Módulos Principais (`scripts/game/*.gd`)
| Grupo | Scripts e Responsabilidades |
|---|---|
| **Core & Dados** | `balance_db.gd`, `game_manager.gd`, `upgrade_system.gd`, `input_setup.gd`, `settings_manager.gd` (inclui `graphics_quality` `0..2`) |
| **Arena & Mood Sci-Fi** | `arena_coordinator.gd` (`291`L), `arena_props.gd` (coberturas + `SM_Helmet_A/B`), `explosive_barrel.gd` (AoE + cadeia), `arena_electric_perimeter.gd` (`10 dmg/s` nas bordas), `arena_elevators.gd` (4 plataformas oscilantes), `wave_spawner.gd` |
| **Player & Câmera** | `player_controller.gd` (`289`L), `player_camera_rig.gd`, `player_animator.gd` (`299`L), `player_combat_helper.gd`, `fps_viewmodel.gd` (`283`L), `fps_optic_helper.gd` (luneta transparente em ADS) |
| **Armas & Pool `O(1)`** | `weapon_loadout.gd` (`293`L), `weapon_manager.gd` (`297`L), `weapon_pool_helper.gd` (pré-instancia as 7 armas TPS/FPS no boot), `projectile_controller.gd`, `pickup_crate.gd` |
| **Inimigos & VFX** | `enemy_droid.gd` (`296`L), `enemy_variants_helper.gd` (`droid_spider` Onda 5+, `droid_sawbox` Onda 10+), `weapon_vfx.gd` & `droid_destruction_vfx.gd` (caches estáticos compartilhados + `warmup()` + peças físicas `RigidBody3D` com teto `36`) |
| **Áudio & UI** | `audio_manager.gd`, `procedural_sfx.gd`, `main_menu_controller.gd`, `dune_backdrop.gd`, `hud_controller.gd` (`296`L), `hud_crosshair.gd`, `hud_weapon_bar.gd` (styles em cache + dirty-check), `upgrade_modal_ui.gd`, `pause_modal_ui.gd`, `game_over_modal_ui.gd`, `settings_modal_ui.gd` (`291`L), `anim_library_loader.gd` |

---

## 3. Invariantes e Contratos Obrigatórios
1. **Regra dos `< 300` linhas (CI Gate):** Todo arquivo em `scripts/game/*.gd` DEVE ter **estritamente menos de 300 linhas**. Atenção especial a `player_animator.gd` (`299`), `weapon_manager.gd` (`297`), `enemy_droid.gd` (`296`), `hud_controller.gd` (`296`), `weapon_loadout.gd` (`293`), `arena_coordinator.gd` (`291`) e `settings_modal_ui.gd` (`291`) — **sempre criar novos helpers em vez de inflar esses arquivos**.
2. **Proteção de Cenas/Assets Base:** NÃO modificar `assets/SK_Isabela/SK_Isabela.glb`, `scenes/main_isabela_scene.tscn` ou `scenes/test_fase1..5_*.tscn` sem solicitação explícita e verificação regressiva.
3. **Otimização & VRAM:**
   - Toda textura 3D nova em `assets/` deve ser importada com `compress/mode=2` (`VRAM Compressed`) e `process/size_limit` (`1024` ou `2048`), nunca `compress/mode=0` sem compressão.
   - Manter pooling `O(1)` de armas (`WeaponPoolHelper`) e caches compartilhados em `WeaponVFX`/`DroidDestructionVFX`; evitar `new StyleBoxFlat()` ou `find_children()` dentro de `_process()`.
4. **Data-Driven First:** Estatísticas de armas, inimigos, arena, câmera, ondas, pickups e upgrades devem ir em `data/game_balance.json`.
5. **Orientação Blender → Godot:** `-Z` frente / `+Y` cima no Godot equivale a modelar frente em `+Y` e topo em `+Z` no Blender (`glTF +Y Up`), pivô `(0,0,0)` no grip e Empty `Muzzle` / `BladeBase` / `BladeTip`.
6. **Backups, Changelog & Git Windows:**
   - Antes de alterar arquivos existentes, salvar backup com timestamp em `.backups/` (ignorado pelo Git) e registrar no `CHANGELOG.md`.
   - **Nunca** commitar `.godot/`, `.backups/` ou `*.blend1`.
   - No Windows com MSYS `git-lfs`, se `pre-push` falhar em `dofork` sem alteração de `.blend`, usar `git push --no-verify`.

---

## 4. Armadilhas Conhecidas (Lições Já Resolvidas)
- **Facing da Isabela (`SK_Isabela.glb` / `SK_Isabela_Leeloo.glb`):** A personagem olha para `+Z` em rest pose; na cena `player_isabela.tscn`, o nó visual tem `rotation.y = PI` (`180°`) para alinhar com `-Z`.
- **Calibração do `WeaponSocket` (`SK_Isabela`):** Encaixe correto no `RightHandAttachment` é **`Vector3(-0.096, 0.064, 0.100)`**.
- **`WeaponPoolHelper` & Troca de Skin:** Ao trocar o modelo/skin da personagem em runtime, re-vincular `WeaponSocket` e pré-aquecer as 7 armas antes do início do combate.
- **`BalanceDB._is_loaded`:** Verifica `_weapons_by_slot.size() >= 6 and _pickups_by_id.size() == 2`.
- **`WeaponLoadout.select_slot(slot)`:** Retorna `false` quando `slot == _selected_slot`.
- **Testes `SceneTree` Headless:** Garantir `quit(0)` / `quit(1)` em todos os caminhos para não travar o runner.
- **Blender `.blend` no GitHub:** Manter `*.blend` rastreados via **Git LFS** (`.gitattributes`).

---

## 5. Protocolo Obrigatório de Verificação
Antes de concluir qualquer alteração ou abrir PR:

1. **Rodar todas as 14+ suítes headless** (Windows PowerShell):
```powershell
$godot = "D:\Godot\Godot_v4.7.2-stable_win64_console.exe"
Get-ChildItem tests\test_*.gd | Sort-Object Name | ForEach-Object {
    & $godot --headless --path . --script "res://tests/$($_.Name)"
    if ($LASTEXITCODE -ne 0) { throw "Falha em $($_.Name) (EXIT=$LASTEXITCODE)" }
}
```
2. **Conferir trava `< 300` linhas em `scripts/game/*.gd`:**
```powershell
Get-ChildItem scripts\game\*.gd | ForEach-Object {
    $c = (Get-Content $_.FullName).Count
    if ($c -ge 300) { throw "$($_.Name) excedeu 300 linhas ($c)" }
}
```
3. **Se alterar visuais/armas/poses/materiais:** Capturar/inspecionar `playable_arena.tscn` em `Forward+` (sem `--headless`) antes de aprovar.

---

## 6. Contexto de Continuidade & Próxima Etapa (Trilha 3)
- **Já concluído até aqui:**
  - **Base + Combate + Gamepad + FPS/TPS + CI GitHub Actions** (`godot-tests.yml`).
  - **Trilha A:** Mood Sci-Fi Crepúsculo, coberturas (`ArenaProps`), barris explosivos (`ExplosiveBarrel`), desmontagem física `RigidBody3D` (`DroidDestructionVFX`), faíscas/muzzle/rastro duplo (`WeaponVFX`), trilha Punk-Rock + 15 SFX (`AudioManager`).
  - **PR #1 (`Sphoka`):** Menu Principal, Configurações em abas, modais centralizados, Leeloo (`SK_Isabela_Leeloo.glb`), Rifle Sniper (slot 2) com óptica transparente em ADS, perímetro elétrico, 4 elevadores, `droid_spider` (Onda 5+) e `droid_sawbox` (Onda 10+).
  - **Otimização (`0361d86`):** Troca de armas `O(1)` (`WeaponPoolHelper`), compressão VRAM `BPTC/S3TC` (`1.815 MB → 299 MB`), caches estáticos de VFX, `HUDWeaponBar` sem alocações por quadro e preset `Qualidade Gráfica` (`Baixo`/`Médio`/`Alto`).
- **Próxima etapa planejada (a ser implementada pelo colega `Sphoka` ou na próxima sessão):**
  - Ler **`docs/TRILHA_3_PLAN.md`** para o desenho técnico completo dos 3 pilares da **Trilha 3**:
    1. **Boss Orbital a cada 5 Ondas** (`boss_sentinel.tscn/.gd` + ataques telegrafados da `SM_Ship` via `orbital_strike_vfx.gd` + `hud_boss_bar.gd` + carta `legendary` garantida).
    2. **Seletor de Visual / Roupas & Capacetes da Isabela** (`player_skin_helper.gd`: `"leeloo"`, `"isabela_jacket"`, `"isabela_top"`, `"isabela_lingerie"` + `SM_Helmet_A`/`SM_Helmet_B` no osso `Head`).
    3. **Mini-Radar Tático no HUD** (`hud_radar.gd` via `_draw()` rotacionado pelo `yaw` do jogador, com throttle de `0.06 s`).
