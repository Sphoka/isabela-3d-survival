# Plano Técnico — Trilha 3 (Trilha C): Bosses Rotativos, Skins Desbloqueáveis com Arquétipos & Mini-Radar

> **Objetivo:** Especificação técnica completa para implementação posterior (por colaborador ou nova sessão de agente) dos 3 pilares de expansão de gameplay — **3 Bosses Rotativos com Chuva de Cápsulas**, **Skins Jogáveis Desbloqueáveis com Buffs/Debuffs de Equilíbrio** e **Mini-Radar Tático no HUD** — preservando **100% das invariantes de arquitetura e performance** já conquistadas.

---

## 0. Pré-condições & Restrições Obrigatórias (Não Quebrar!)

1. **Regra `< 300` linhas (enforced no GitHub Actions CI):**
   - Os arquivos abaixo estão colados no teto e **NÃO devem crescer**:
     - `player_animator.gd` (`299`), `weapon_manager.gd` (`297`), `enemy_droid.gd` (`296`), `hud_controller.gd` (`296`), `weapon_loadout.gd` (`293`), `arena_coordinator.gd` (`291`), `settings_modal_ui.gd` (`291`).
   - Toda lógica nova da Trilha 3 **deve nascer em módulos dedicados `< 240` linhas**, usando apenas hooks de 2–5 linhas nos coordenadores.
2. **Preservar Otimizações (`0361d86`):**
   - **Troca de armas `O(1)` (`WeaponPoolHelper`):** ao aplicar ou trocar a skin da jogadora no início da partida, re-vincular o `WeaponSocket` do novo rig **antes** do gameplay e chamar `_prewarm_pools()`.
   - **Zero alocações por quadro no HUD:** `HUDRadar` e `HUDBossBar` devem usar `_draw()` / `StyleBoxFlat` em cache e throttle (`0.05–0.08 s`), nunca `StyleBoxFlat.new()` ou `find_children()` dentro de `_process()`.
   - **Texturas novas:** importar com `compress/mode=2` (VRAM Compressed BPTC/S3TC) e `process/size_limit` `1024` ou `2048`.
3. **Proteção de Cenas/Assets Base:**
   - **Proibido alterar** `assets/SK_Isabela/SK_Isabela.glb`, `scenes/main_isabela_scene.tscn` e `scenes/test_fase1..5_*.tscn`.
4. **Data-Driven (`data/game_balance.json`):**
   - Todo valor numérico de Bosses, cápsulas orbitais, arquétipos (buffs/debuffs) e recompensas deve residir em `data/game_balance.json` e ser lido via `BalanceDB`.

---

## 1. Pilar 3.1 — 3 Bosses Rotativos a cada 5 Ondas (`SM_Ship` + `BossSentinel`)

### Visão Geral & Rotação
- Em ondas múltiplas de 5 (`wave % 5 == 0`), a Nave-Mãe `SM_Ship` lança um **Boss exclusivo** em rotação cíclica (`tier = wave / 5`):
  - **Onda 5 *(tier 1, e 20, 35...)*:** **Char 1 — "Valkyrie Skull"** (`docs/references/boss_char1_skull_cyborg_tpose.jpg`)
  - **Onda 10 *(tier 2, e 25, 40...)*:** **Char 2 — "White Reaper"** (`docs/references/boss_char2_white_android_tpose.jpg`)
  - **Onda 15 *(tier 3, e 30, 45...)*:** **Char 3 — "Anubis Phantom"** (`docs/references/boss_char3_anubis_ninja_tpose.jpg`)
- **Recompensa Pós-Boss (ao derrotar):**
  1. **1 draft de Upgrade com raridade mínima `"legendary"` garantida**;
  2. **Drop imediato de `1` `SM_Crate_Health` + `1` `SM_Crate_Ammo`** no ponto da derrota (respiro tático antes da próxima onda);
  3. **Desbloqueio permanente do personagem como Skin Jogável** (salvo em `user://unlocks.cfg`).

### Identidade, Armas & Animações Personalizadas por Boss

| Boss | Papel | Armas como Boss | Animações Obrigatórias (`.glb`) | Ações & Anti-Cheese (`ArenaElevators`) |
| :--- | :--- | :--- | :--- | :--- |
| **Char 1: Valkyrie Skull** | Assalto Ágil | **Garras Duplas** (combo melee 3 hits) + **Rajada Térmica Carmesim** (média distância) | `Idle`, `Run_Predator`, `Side_Step`, `Leap_Slam`, `Attack_Melee`, `Attack_Ranged`, `Enrage_Roar` | **Side-Step** ágil se jogador mirar > `1 s`; **Leap Slam** saltando direto até o topo das plataformas elevatórias |
| **Char 2: White Reaper** | Tanque Pesado | **Montante Cibernético Pesado** + **Canhão de Peito** | `Idle`, `Walk_Heavy`, `Guard_Stance`, `Sword_Slam`, `Attack_Ranged`, `Stagger_Core`, `Enrage_Roar` | **Guard Stance (`1.5 s`)** reduz dano frontal comum (fraco a **Rocket/Explosões** e acertos críticos nas costas/cabos); **Sword Slam** lança onda de choque no chão + **Canhão de Peito** atinge plataformas |
| **Char 3: Anubis Phantom** | Cyber-Ninja Furtivo | **Katana / Wakizashi Âmbar Dupla** + **Leque de `3` Lâminas de Energia** | `Idle`, `Ninja_Sprint`, `Shadow_Blink`, `Acrobatic_Leap`, `Cross_Slash`, `Attack_Ranged`, `Enrage_Roar` | **Shadow Blink** (`0.6 s` de brilho âmbar nos olhos → teleporte curto para flanco/costas); **Acrobatic Leap** salta direto para plataformas elevatórias |

### Mecânica Comum dos Bosses: 2 Fases + Chuva de Cápsulas da `SM_Ship`
- **Fase 1 (`HP > 50%`):** combate característico do Boss + solicitação periódica de **Chuva de Cápsulas** (`capsule_wave_cooldown_s = 11.0`, `capsules_per_rain = 2`).
- **Fase 2 (`HP <= 50%` — Enrage):**
  - Executa animação `Enrage_Roar` + aura emissiva;
  - `SM_Ship` dispara **salva orbital massiva (`enrage_salvo_count = 4` cápsulas simultâneas)**;
  - Boss ganha **`+25%` de velocidade de movimento** e alterna ataques ranged para **rajadas duplas (`burst_count = 2`)**.

### Contrato de Assets 3D (`.glb` Blender → Godot)
- Pastas alvo:
  - `res://assets/SK_Boss_Valkyrie/SK_Boss_Valkyrie.glb`
  - `res://assets/SK_Boss_Reaper/SK_Boss_Reaper.glb`
  - `res://assets/SK_Boss_Anubis/SK_Boss_Anubis.glb`
- **Padrão Blender:** `+Y Up`, frente em **`+Y`** (exporta `-Z` no Godot), pivô `(0,0,0)` nos pés, `Armature` compatível (ou `Skeleton3D` de 84 ossos se também for usado como skin jogável com `WeaponSocket`), texturas em `compress/mode=2` (`1024–2048 px`).
- Enquanto o `.glb` final de cada um ainda não estiver pronto, `boss_sentinel.tscn` usa fallback provisório parametrizado por `asset_path` em `data/game_balance.json`.

### Módulos Novos do Pilar 3.1

#### [NEW] `scenes/game/boss_sentinel.tscn` & `scripts/game/boss_sentinel.gd` (`< 240` linhas)
- Configura a ficha do Boss (`valkyrie_skull`, `white_reaper`, `anubis_phantom`) a partir de `BalanceDB.get_boss_cfg(boss_id, tier)`.
- Gerencia máquina de estados (`CHASE`, `GUARD_OR_BLINK`, `WINDUP`, `ATTACK`, `ENRAGE`) e emite: `hp_updated(current_hp, max_hp)`, `enraged()`, `capsule_rain_requested(count)`, `died(...)`.

#### [NEW] `scripts/game/orbital_drop_pod.gd` (`< 180` linhas)
- Spawna em altitude (`y = 26.0`), exibe anel pulsante no chão (`telegraph_s = 1.35 s`) respeitando `ArenaProps.is_position_clear()` e desce em queda rápida.
- **Impacto:** causa dano/knockback se o jogador estiver dentro de `2.4 m` (respeitando dash `iframes`) + explosão e SFX (`pod_impact`).
- **Cápsula Destrutível (`StaticBody3D`, grupo `"damageable_props"`, `HP = 90.0`):** fica `3.0 s` no chão antes de abrir:
  - Se **destruída a tempo**, explode sem liberar reforços e concede XP/munição bônus;
  - Se **não destruída em `3.0 s`**, abre liberando `1` droid (`droid_small` na Onda 5, `droid_spider` nas Ondas 10+).
- **Performance:** malha e material estáticos compartilhados (`cast_shadow = OFF` no anel de alerta).

#### [NEW] `scripts/game/hud_boss_bar.gd` (`< 120` linhas)
- Barra de HP fixa no topo do HUD (`visible = false` fora de ondas de Boss), exibe `"BOSS ORBITAL: <NOME> — ONDA X"` e muda para tema dourado/carmesim ao entrar em **Enrage**.

---

## 2. Pilar 3.2 — Skins Jogáveis Desbloqueáveis & Arquétipos (Buffs / Debuffs)

### Regra de Equilíbrio (Buff + Debuff por Trade-off)
- **Sem efeitos de DoT/Jamming complexos:** "Buffs e Debuffs" funcionam como **modificadores permanentes do arquétipo** da skin equipada para equilibrar velocidade, vida, dano, precisão e munição.

| Skin ID | Como Desbloquear | **Buffs (Vantagens)** | **Debuffs (Trade-offs)** |
| :--- | :--- | :--- | :--- |
| **`leeloo`** / **`isabela_jacket`** / **`isabela_top`** / **`isabela_lingerie`** | Liberadas no início | Equilibrada (`1.0×` todos os atributos) | Nenhum |
| **`valkyrie_skull`** *(Char 1)* | Derrotar Boss da **Onda 5** | **`+18%` Velocidade** · **`-20%` Cooldown de Dash** | **`-15%` HP Máx.** · **`-10%` Dano Base** |
| **`white_reaper`** *(Char 2)* | Derrotar Boss da **Onda 10** | **`+35%` HP Máx.** · **`+20%` Dano Melee & Pesado** | **`-18%` Velocidade** · **`+20%` Tempo de Recarga** |
| **`anubis_phantom`** *(Char 3)* | Derrotar Boss da **Onda 15** | **`+15%` Chance Crítica** · **`+25%` Dano Crítico / Headshot** | **`-20%` HP Máx.** · **`-15%` Capacidade de Munição/Bateria** |

- **Capacetes opcionais (`player_helmet`):** `"none"`, `"helmet_a"`, `"helmet_b"` (`SM_Helmet_A/B` via `BoneAttachment3D` no osso `Head`, compatível com as skins da Isabela).

### Arquitetura Proposta

#### [NEW] `scripts/game/player_skin_helper.gd` (`< 200` linhas)
- Gerencia:
  1. Instanciação do modelo da skin escolhida (ou alternância de visibilidade das submalhas `Jacket`/`Top`/`Lingerie` em `SK_Isabela.glb`, mantendo o arquivo `.glb` intacto);
  2. Acoplamento de capacete opcional no osso `Head`;
  3. Leitura e aplicação do bloco `"character_archetypes"` de `data/game_balance.json` sobre `PlayerController` (`max_hp`, `move_speed`, `dash_cooldown`) e `WeaponLoadout` (`damage_mult`, `reload_mult`, `crit_bonus`, `ammo_capacity_mult`).
- **Persistência & QA:** salvar desbloqueios em `user://unlocks.cfg` dentro de `SettingsManager` (com flag `unlock_all_for_test` para permitir que colaboradores testem todas as skins imediatamente sem precisar jogar até a Onda 15).

#### [MODIFY] `scripts/game/settings_manager.gd`, `scripts/game/main_menu_controller.gd`, `scripts/game/player_controller.gd`, `scripts/game/weapon_loadout.gd`
- Hooks mínimos (`2–5` linhas) para aplicar o arquétipo ativo no início da run e re-vincular `PlayerAnimator` + `WeaponPoolHelper` antes do combate.
- Seletor de Skin & Capacete no Menu Principal / aba de Customização exibindo status (`Desbloqueada` vs. `Derrote na Onda 5/10/15`) e resumo visual do **Buff + Debuff** da skin selecionada.

---

## 3. Pilar 3.3 — Mini-Radar Tático no HUD (`HUDRadar`)

#### [NEW] `scripts/game/hud_radar.gd` (`< 180` linhas)
- `Control` desenhado via `_draw()` (sem criar nós por inimigo), atualizado em throttle de `0.06 s` (`queue_redraw()`).
- **Transformação relativa ao jogador:** rotaciona `(entity.global_position - player.global_position)` por `-player_yaw` para manter a direção da câmera sempre voltada para **cima**, com alcance `RADAR_RANGE_M = 34.0` e cone sutil de FOV.
- **Legenda visual:**
  - `droid_small`: ponto laranja (`r = 3.0`)
  - `droid_tall`: ponto ciano (`r = 4.0`)
  - `droid_spider`: ponto roxo/magenta (`r = 4.0`)
  - `droid_sawbox`: ponto vermelho (`r = 4.5`)
  - `boss_sentinel`: diamante dourado pulsante (`r = 6.0`)
  - `orbital_drop_pod` (ativo): anel/ponto carmesim piscante (`r = 4.0`)
  - `explosive_barrels`: ponto âmbar discreto (`r = 2.2`)
- **Integração em `HUDController` (`+4` linhas):** instancia `HUDRadar`, adiciona ao `HUD` e chama `hud_radar.bind(player, CameraPivot)` em `HUDController.bind()`.

---

## 4. Plano de Testes (TDD Obrigatório para o Implementador)

Criar `tests/test_trilha_3_boss_skins_radar.gd` validando em `--headless`:
1. **Bosses & Chuva de Cápsulas:**
   - `WaveSpawner` spawna `valkyrie_skull` na Onda 5, `white_reaper` na Onda 10 e `anubis_phantom` na Onda 15;
   - Transição para Fase 2 (`Enrage`) aos `<= 50%` HP aumenta velocidade em `+25%` e solicita salva de `4` cápsulas;
   - Destruir `OrbitalDropPod` antes de `3.0 s` impede spawn de reforço; deixá-lo intacto por `3.0 s` libera `1` droid;
   - Derrotar Boss garante carta `"legendary"` em `UpgradeSystem`, dropa Vida + Munição e grava desbloqueio da skin.
2. **Skins & Arquétipos (Buff + Debuff):**
   - `PlayerSkinHelper` instancia todas as skins (`leeloo`, `isabela_*`, `valkyrie_skull`, `white_reaper`, `anubis_phantom`), preserva `WeaponPoolHelper.get_count() >= 7` e aplica exatamente os multiplicadores de HP/velocidade/dano/crítico/recarga/munição de `game_balance.json`.
   - `SettingsManager` bloqueia seleção de skin não desbloqueada em modo normal e respeita persistência em `user://unlocks.cfg`.
3. **HUD Radar & Boss Bar:**
   - `HUDRadar` calcula coordenadas rotacionadas por `yaw` dentro do raio do radar e `HUDBossBar` acompanha `hp_updated`, `enraged` e `died`.
4. **CI Verde:** rodar todas as **15+ suítes** `tests/test_*.gd` e checar `0` scripts `>= 300` linhas em `scripts/game/*.gd`.
