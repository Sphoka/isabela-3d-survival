# Plano Técnico — Trilha 3 (Trilha C): Expansão de Gameplay & Conteúdo

> **Objetivo:** Especificação técnica detalhada para implementação posterior (por colaborador ou nova sessão de agente) dos 3 pilares de expansão de gameplay — **Boss Orbital a cada 5 Ondas**, **Seletor de Visual/Roupas/Capacetes da Isabela** e **Mini-Radar Tático no HUD** — mantendo **100% das invariantes de arquitetura e performance** já conquistadas.

---

## 0. Pré-condições & Restrições Obrigatórias (Não Quebrar!)

1. **Regra `< 300` linhas (enforced no GitHub Actions CI):**
   - Os arquivos abaixo estão colados no teto e **NÃO devem crescer**:
     - `player_animator.gd` (`299`), `weapon_manager.gd` (`297`), `enemy_droid.gd` (`296`), `hud_controller.gd` (`296`), `weapon_loadout.gd` (`293`), `arena_coordinator.gd` (`291`), `settings_modal_ui.gd` (`291`).
   - Toda lógica nova da Trilha 3 **deve nascer em módulos dedicados `< 240` linhas**, usando apenas hooks de 2–5 linhas nos coordenadores.
2. **Preservar Otimizações (`0361d86`):**
   - **Troca de armas `O(1)` (`WeaponPoolHelper`):** se trocar a skin da jogadora no início da partida, re-vincular o `WeaponSocket` do novo rig **antes** do gameplay e chamar `_prewarm_pools()`.
   - **Zero alocações por quadro no HUD:** `HUDRadar` e `HUDBossBar` devem usar `_draw()` / `StyleBoxFlat` em cache e throttle (`0.05–0.08 s`), nunca `StyleBoxFlat.new()` ou `find_children()` dentro de `_process()`.
   - **Texturas novas:** importar com `compress/mode=2` (VRAM Compressed BPTC/S3TC) e `process/size_limit` `1024` ou `2048`.
3. **Proteção de Cenas/Assets Base:**
   - **Proibido alterar** `assets/SK_Isabela/SK_Isabela.glb`, `scenes/main_isabela_scene.tscn` e `scenes/test_fase1..5_*.tscn`.
4. **Data-Driven (`data/game_balance.json`):**
   - Todo valor numérico de Boss, ataque orbital, cooldowns e recompensas deve residir em `data/game_balance.json` e ser lido via `BalanceDB`.

---

## 1. Pilar 3.1 — Boss Orbital a cada 5 Ondas (`SM_Ship` + `BossSentinel`)

### Conceito de Gameplay
- Em ondas múltiplas de 5 (`wave % 5 == 0`: Onda 5, 10, 15...), a Nave-Mãe `SM_Ship` desce um **Boss Droide Comandante (`boss_sentinel`)** e passa a coordenar **ataques orbitais telegrafados**.
- Ao derrotar o Boss, o jogador recebe bônus alto de XP/score e **1 draft de Upgrade com raridade mínima `Lendário` garantida**.

### Arquitetura Proposta

#### [NEW] `scenes/game/boss_sentinel.tscn` & `scripts/game/boss_sentinel.gd` (`< 240` linhas)
- **Visual & Rig:** reaproveitar `SK_Droid_Tall.glb` escalado (`1.75x`) com material overlay/emissive carmesim-dourado e `CollisionShape3D` proporcional (`radius = 0.65`, `height = 3.4`, `collision_layer = 4`).
- **Fases de Combate:**
  - **Fase 1 (`HP > 50%`):** perseguição com canhão duplo de plasma (`ProjectileController`) + golpe pesado melee em curta distância.
  - **Fase 2 (`HP <= 50%` — Enrage):** aumenta velocidade em `+25%`, reduz cooldown de rajada e reduz intervalo do **Ataque Orbital da `SM_Ship`**.
- **Sinais:** `boss_spawned(boss_node, max_hp)`, `hp_updated(current_hp, max_hp)`, `died(...)` (compatível com `WaveSpawner` / `ArenaCoordinator`).

#### [NEW] `scripts/game/orbital_strike_vfx.gd` (`< 160` linhas)
- **Mecânica de Telegráfia:**
  1. Cria um anel marcador emissivo no chão (`y = 0.04`) na posição prevista do jogador (`radius = 3.8 m`), pulsando por `orbital_telegraph_s` (`1.4 s`).
  2. Após o telegrafamento, dispara um feixe vertical da altura da `SM_Ship` (`y = 24 -> 0`), toca SFX (`orbital_strike` via `AudioManager`), aplica dano em área (`45.0` base) no jogador caso ainda esteja dentro do raio (respeitando dash `iframes`), e spawna partículas de impacto reutilizando `DroidDestructionVFX.spawn_explosion_burst()`.
  - **Performance:** usar `CylinderMesh` / `StandardMaterial3D` estáticos compartilhados e `cast_shadow = OFF`.

#### [NEW] `scripts/game/hud_boss_bar.gd` (`< 120` linhas)
- Barra de HP estilizada no topo da tela (abaixo da barra de XP), oculta por padrão (`visible = false`), exibindo nome `"SENTINELA ORBITAL — ONDA X"` e `ProgressBar` carmesim-dourada.
- Conectada por `HUDController.bind()` apenas via sinais (`boss_spawned`, `boss.hp_updated`, `boss.died`) — zero polling no `_process()`.

#### [MODIFY] `data/game_balance.json`, `scripts/game/balance_db.gd`, `scripts/game/wave_spawner.gd`, `scripts/game/game_manager.gd`, `scripts/game/upgrade_system.gd`
- `game_balance.json`: adicionar seção `"boss"` (`base_hp: 1400.0`, `hp_scale_per_tier: 1.65`, `orbital_cooldown_s: 6.5`, `orbital_telegraph_s: 1.4`, `orbital_radius_m: 3.8`, `orbital_damage: 45.0`, `xp_reward: 260`, `score_reward: 1500`).
- `WaveSpawner`: em `wave % 5 == 0`, enfileirar `"boss_sentinel"` além da escolta reduzida; `GameManager` / `UpgradeSystem`: adicionar parâmetro opcional `min_rarity: String = ""` em `roll_choices(...)` para garantir pelo menos 1 carta `"legendary"` ao abater o Boss.

---

## 2. Pilar 3.2 — Seletor de Visual, Roupas & Capacetes da Isabela

### Assets Já Disponíveis no Repositório
- `res://assets/SK_Isabela/SK_Isabela_Leeloo.glb` (traje Leeloo laranja — padrão atual)
- `res://assets/SK_Isabela/SK_Isabela.glb` (contém malhas separadas: `SK_Isabela_Body`, `SK_Isabela_Hair`, `SK_Isabela_Jacket`, `SK_Isabela_Top`, `SK_Isabela_Lingerie`, preservando os mesmos **84 ossos** e `WeaponSocket`)
- `res://assets/SM_Helmet_A/SM_Helmet_A.glb` e `res://assets/SM_Helmet_B/SM_Helmet_B.glb`

### Arquitetura Proposta

#### [NEW] `scripts/game/player_skin_helper.gd` (`< 180` linhas)
- **Skins suportadas (`player_skin`):**
  1. `"leeloo"` → instancia `SK_Isabela_Leeloo.glb` (padrão)
  2. `"isabela_jacket"` → instancia `SK_Isabela.glb` com `Jacket + Top` visíveis (`Lingerie` oculta)
  3. `"isabela_top"` → instancia `SK_Isabela.glb` com `Top` visível (`Jacket` e `Lingerie` ocultas)
  4. `"isabela_lingerie"` → instancia `SK_Isabela.glb` com `Lingerie` visível (`Jacket` e `Top` ocultas)
- **Capacetes suportados (`player_helmet`):** `"none"`, `"helmet_a"`, `"helmet_b"`
  - Anexados dinamicamente via `BoneAttachment3D` (`bone_name = "Head"`) no `Skeleton3D` ativo, com `cast_shadow = OFF` opcional ou sombra leve e offset calibrado por enum.
- **Contrato crítico com `PlayerController` / `WeaponManager`:**
  - Aplicado em `PlayerController._ready()` **antes** de `PlayerAnimator.bind_isabela(...)` e `WeaponManager.set_weapon_socket(...)`, garantindo que o `WeaponPoolHelper` pré-aqueça todas as 7 armas no `WeaponSocket` correto da skin escolhida.

#### [MODIFY] `scripts/game/settings_manager.gd` & `scripts/game/settings_modal_ui.gd` (ou painel no `MainMenuController`)
- Persistir `"player_skin"` e `"player_helmet"` em `user://settings.cfg` (`DEFAULTS`: `"leeloo"` / `"none"`).
- Adicionar seletores `OptionButton` no menu (em `Configurações` ou card dedicado no `MainMenu`) com aviso claro de que a troca entra em vigor ao iniciar/reiniciar a partida.

---

## 3. Pilar 3.3 — Mini-Radar Tático no HUD (`HUDRadar`)

### Arquitetura Proposta

#### [NEW] `scripts/game/hud_radar.gd` (`< 180` linhas)
- **Renderização eficiente (`Control._draw()`):**
  - Círculo translúcido sci-fi (`128 × 128 px`, canto superior esquerdo ou direito abaixo do HUD de abates) com anéis concêntricos e cone frontal de FOV (destacando a direção da câmera no modo FPS e TPS).
  - Atualiza apenas a cada `0.06 s` (`_accum += delta; if _accum >= 0.06: queue_redraw()`), evitando redesenho em todos os quadros.
  - **Cálculo relativo ao jogador:** transforma `(enemy.global_position - player.global_position)` pelo `-player_yaw` para que "frente" seja sempre **para cima no radar**, limitado ao alcance `RADAR_RANGE_M = 34.0`.
  - **Código visual dos blips:**
    - `droid_small`: ponto laranja (`r = 3.0`)
    - `droid_tall`: ponto ciano (`r = 4.0`)
    - `droid_spider`: ponto roxo/magenta (`r = 4.0`)
    - `droid_sawbox`: ponto vermelho (`r = 4.5`)
    - `boss_sentinel`: diamante/círculo dourado pulsante (`r = 6.0`)
    - `explosive_barrels` (ativos): pequeno X/ponto âmbar (`r = 2.2`)
- **Integração em `HUDController` (`+4` linhas):**
  - Instanciar `HUDRadar`, adicionar como filho do `HUD` e passar `player` + `CameraPivot` em `HUDController.bind()`.

---

## 4. Plano de Testes (TDD Obrigatório para o Implementador)

Criar `tests/test_trilha_3_boss_skins_radar.gd` validando em `--headless`:
1. **Boss & Orbital Strike:** `WaveSpawner` em Onda 5 spawna `boss_sentinel`, `BossSentinel` entra em Fase 2 abaixo de 50% HP, `OrbitalStrikeVFX` aplica dano após telegrafamento (respeitando dash iframes), e `UpgradeSystem` garante carta `legendary` na recompensa.
2. **Skins & Capacetes:** `PlayerSkinHelper` instancia cada uma das 4 skins (`leeloo`, `isabela_jacket`, `isabela_top`, `isabela_lingerie`) e anexa `SM_Helmet_A`/`SM_Helmet_B` no osso `Head`, preservando `84` ossos e `WeaponPoolHelper.get_count() >= 7`.
3. **HUD Radar & Boss Bar:** `HUDRadar` calcula posições relativas rotacionadas pelo `yaw` dentro de `[0..radar_radius]` e `HUDBossBar` acompanha `hp_updated` e oculta ao morrer.
4. **CI Verde:** rodar todas as **15+ suítes** `tests/test_*.gd` e checar `0` scripts `>= 300` linhas em `scripts/game/*.gd`.
