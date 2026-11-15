# GEMINI.md — Contexto e Regras para Agentes de IA

Este arquivo fornece contexto técnico estruturado para agentes de IA (Antigravity, Gemini CLI, Claude Code, Codex ou colaboradores assistidos por IA) atuarem com segurança neste repositório.

---

## 1. Visão Geral do Projeto
- **Nome:** Projeto Isabela 3D — Wave Survival Action Game
- **Engine:** Godot `4.7.2-stable` (`Forward+`, `config/features = PackedStringArray("4.7", "Forward Plus")`)
- **Arte 3D / Pipeline:** Blender `5.2+` (`.blend` em `blend_sources/`, exportação `.glb` Y-up em `assets/`)
- **Fonte Única de Balanceamento:** `data/game_balance.json` (lido por `scripts/game/balance_db.gd`)
- **Cena Principal Jogável:** `res://scenes/game/playable_arena.tscn`
- **Nota sobre `project.godot`:** `run/main_scene` atualmente aponta para `res://scenes/test_fase1_helmets.tscn`; testes e execução do jogo principal usam `res://scenes/game/playable_arena.tscn` (`[F6]` no Editor).

---

## 2. Mapa de Diretórios e Arquitetura

```text
res://
├── addons/assets2godot/          # Assets2Godot v0.8.2 (GPLv2) — habilitado em project.godot
├── assets/                       # Assets .glb Y-up + texturas PBR + .import/.uid
│   ├── ENV_DesertCoast/          # Terreno/dunas, pedras de cobertura (SM_DesertDunes, SM_ShoreRocks)
│   ├── SK_Isabela/               # SK_Isabela.glb (84 ossos), SK_Isabela_Anims.glb, FPS_Arms.glb
│   ├── SK_Droid_Small/           # Droide Batedor (melee, TwoBoneIK3D)
│   ├── SK_Droid_Tall/            # Droide Sentinela (ranged/melee, TwoBoneIK3D)
│   ├── SM_Ship/                  # Nave-mãe orbital + orbita/beam
│   ├── SM_Crate_Health/          # Pickup de vida
│   ├── SM_Crate_Ammo/            # Pickup de munição / bateria
│   └── SM_Weapon_*/              # 7 armas: Pistol, Lightsaber, Shotgun, RocketLauncher, Katana, LaserGun, SMG
├── blend_sources/                # Fontes .blend (rastreadas via Git LFS; .gdignore presente)
├── data/
│   └── game_balance.json         # Única fonte da verdade: arena, player, 7 armas, pickups, droids, waves, upgrades
├── scenes/
│   ├── main_isabela_scene.tscn   # Cena showcase Fase 6 (PROIBIDO quebrar/alterar sem pedido explícito)
│   ├── test_fase1..5_*.tscn      # Cenas de validação das Fases 1-5
│   └── game/                     # Cenas do jogo jogável (playable_arena, player_isabela, droid_small/tall)
├── scripts/game/                 # 22 scripts modulares (TODOS estritamente < 300 linhas)
├── shaders/                      # shallow_mirror_water.gdshader + M_ShallowMirrorWater.tres
└── tests/                        # 9 suítes de testes headless Godot
```

### Módulos Principais (`scripts/game/*.gd`)
| Script | Responsabilidade |
|---|---|
| `balance_db.gd` | Carrega `data/game_balance.json`; lookup de armas/pickups/inimigos e fórmulas de XP/wave |
| `game_manager.gd` | Máquina de estados da partida, XP/nível, transições de wave, pause/game-over |
| `arena_coordinator.gd` | Orquestração da arena (`playable_arena.tscn`), ambiente/nave e spawn inicial |
| `wave_spawner.gd` | Spawn em anel (`20m–28m`), teleporte/beam da nave, drops de caixas |
| `player_controller.gd` | `CharacterBody3D`: movimento, arrasto na água rasa, coyote jump, dash + iframes, troca TPS/FPS |
| `player_camera_rig.gd` | Rig orbital TPS (`SpringArm3D`) + câmera FPS + look analógico de gamepad |
| `player_animator.gd` | `AnimationTree` (`UpperIdle`, `GripChoice` `one`/`both`/`katana`), poses, piscada ARKit e `WeaponSocket` |
| `player_combat_helper.gd` | Roteamento de tiro/recarga/slots `1..7` e raycast de mira |
| `fps_viewmodel.gd` | Braços FPS (`FPS_Arms.glb`), offsets `WEAPON_TWEAKS`, ADS e recuo em 1ª pessoa |
| `weapon_loadout.gd` | Estado em runtime dos slots `1..7` (munição, carregador, bateria/superaquecimento, combos) |
| `weapon_manager.gd` | Instancia malha equipada no `WeaponSocket`, hitscan/pellets/melee/rocket e deflexão de plasma |
| `weapon_vfx.gd` | Beams, traços de lâmina, explosões e efeitos visuais de disparo |
| `enemy_droid.gd` | IA compartilhada (`SK_Droid_Small` e `SK_Droid_Tall`), steering e `TwoBoneIK3D` |
| `projectile_controller.gd` | Foguetes AoE + projéteis de plasma (inclui deflexão com Sabre de Luz) |
| `pickup_crate.gd` | Bob/spin, imã e aplicação de cura/munição |
| `upgrade_system.gd` | Sorteio de raridades e acúmulo de modificadores dos 10 upgrades |
| `input_setup.gd` | Registro idempotente do `InputMap` (Teclado/Mouse + Gamepad completo) |
| `hud_controller.gd`, `hud_crosshair.gd`, `hud_weapon_bar.gd`, `upgrade_modal_ui.gd` | HUD sci-fi, barra de 7 armas, mira dinâmica e modal de 3 cartas com foco de gamepad |
| `anim_library_loader.gd` | Carregamento de `SK_Isabela_Anims.glb` e limpeza de trilhas de cabelo |

---

## 3. Invariantes e Contratos Obrigatórios
1. **Regra dos `< 300` linhas:** Todo arquivo em `scripts/game/*.gd` DEVE ter estritamente menos de 300 linhas. Se um script crescer além disso, extrair um helper coeso (ex.: `player_combat_helper.gd`, `hud_weapon_bar.gd`).
2. **Proteção de Cenas/Assets Base:** NÃO modificar `assets/SK_Isabela/SK_Isabela.glb`, `scenes/main_isabela_scene.tscn` ou `scenes/test_fase1..5_*.tscn` sem solicitação explícita e verificação regressiva.
3. **Data-Driven First:** Estatísticas de armas, inimigos, arena, câmera, ondas, pickups e upgrades devem ir em `data/game_balance.json` (nunca hardcoded espalhado).
4. **Orientação Blender → Godot:**
   - Godot usa `-Z` para frente e `+Y` para cima.
   - No Blender (`glTF +Y Up`), modelar o cano/frente da arma ao longo de **`+Y`** e o topo em **`+Z`** exporta corretamente para Godot `-Z` frente e `+Y` cima.
   - Pivô `(0, 0, 0)` no centro da empunhadura (grip); incluir Empty `Muzzle` (armas de fogo) ou `BladeBase`/`BladeTip` (corpo a corpo).
5. **Backups e Changelog (Fluxo do Projeto):**
   - Antes de alterar arquivos existentes importantes, salvar backup com timestamp em `.backups/` (ignorado pelo Git).
   - Registrar alterações relevantes no `CHANGELOG.md`.
   - **Nunca** commitar `.godot/`, `.backups/` ou `*.blend1`.

---

## 4. Armadilhas Conhecidas (Lições Já Resolvidas)
- **Facing da Isabela (`SK_Isabela.glb`):** A personagem olha para `+Z` em rest pose; na cena `player_isabela.tscn`, o nó visual `SK_Isabela` tem `rotation.y = PI` (`180°`) para alinhar com `-Z`.
- **Calibração do `WeaponSocket` (`SK_Isabela`):** Os ossos distais dos dedos (`RightMiddleProximal` / `RightMiddleDistal`) possuem deslocamento em relação à malha esfolada visível da mão direita. O encaixe correto no `RightHandAttachment` é **`Vector3(-0.096, 0.064, 0.100)`** (centróide real dos vértices da palma/dedos). Em testes de grip, medir os vértices esfolados (`SK_Isabela_Body`), não apenas a posição crua dos ossos dos dedos.
- **`BalanceDB._is_loaded`:** Verifica `_weapons_by_slot.size() >= 6 and _pickups_by_id.size() == 2`. Ao adicionar novas armas/slots, manter essa validação coerente.
- **`WeaponLoadout.select_slot(slot)`:** Retorna `false` quando `slot == _selected_slot`. Em testes que encadeiam `select_slot(x) and cycle_slot(...)`, verificar estado ou garantir que outro slot estava ativo antes.
- **Testes `SceneTree` Headless:** Qualquer erro antes de `quit(...)` ou retorno antecipado antes de `await` trava o `Godot --headless` indefinidamente. Sempre garantir chamada a `quit(0)` / `quit(1)` ao final da execução.
- **Blender `.blend` no GitHub:** `blend_sources/fase6_validation_scene.blend` tem ~117 MB (> limite de 100 MB do GitHub). Manter `*.blend` rastreados via **Git LFS** (`.gitattributes`).

---

## 5. Protocolo Obrigatório de Verificação
Antes de concluir qualquer alteração em scripts, cenas ou balanceamento:

1. **Rodar todas as 9 suítes headless** (Windows PowerShell — ajustar caminho do executável Godot 4.7.2 conforme ambiente):
```powershell
$godot = "D:\Godot\Godot_v4.7.2-stable_win64_console.exe"
$tests = @(
    'tests\test_balance_and_upgrades.gd',
    'tests\test_combat_core.gd',
    'tests\test_player_enemy_weapons.gd',
    'tests\test_spawner_projectiles_pickups.gd',
    'tests\test_hud_and_arena_loop.gd',
    'tests\test_playable_arena_e2e.gd',
    'tests\test_v2_camera_anims_fps.gd',
    'tests\test_gamepad_support.gd',
    'tests\test_jacket_and_weapon_grip.gd'
)
foreach ($t in $tests) {
    & $godot --headless --path . --script "res://$($t -replace '\\', '/')"
    if ($LASTEXITCODE -ne 0) { throw "Falha em $t (EXIT=$LASTEXITCODE)" }
}
```

2. **Conferir limite `< 300` linhas em `scripts/game/*.gd`:**
```powershell
Get-ChildItem scripts\game\*.gd | ForEach-Object {
    $c = (Get-Content $_.FullName).Count
    if ($c -ge 300) { throw "$($_.Name) excedeu 300 linhas ($c)" }
}
```

3. **Se alterar visuais/armas/poses/materiais:** Abrir ou renderizar `playable_arena.tscn` sem `--headless` para inspeção visual antes de aprovar.
