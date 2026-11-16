# Design Detalhado dos 3 Bosses Rotativos — Trilha 3 (`BossSentinel`)

> Documento complementar ao [TRILHA_3_PLAN.md](TRILHA_3_PLAN.md) com a ficha completa de **identidade, leitura visual, fluxo de IA, movimentos, ataques, telegrafia e arquétipo de skin** para cada um dos 3 Bosses orbitais lançados pela `SM_Ship`.

---

## Boss 1 — Valkyrie Skull (`valkyrie_skull`)

### 1. Identidade & Leitura Visual em Arena
- **Aparição:** Onda **5** (*tier 1*) e depois em rotação nas ondas 20, 35...
- **Papel:** **Assalto Ágil / Rushdown** — pressiona o jogador com velocidade, esquivas reativas e ataques verticais em plataformas.
- **Visual-chave:** Guerreira ciborgue com **meia-máscara metálica de caveira**, olhos brancos brilhantes, cabelo preto com pontas vermelhas, armadura tática escura com ombreira de caveira, aura carmesim e **Garras Duplas energizadas**.
- **Referência T-Pose:** `docs/references/boss_char1_skull_cyborg_tpose.jpg` · **Asset alvo:** `res://assets/SK_Boss_Valkyrie/SK_Boss_Valkyrie.glb`

### 2. Comportamento & Fluxo de Combate (IA)
1. **Aproximação (`CHASE` — `Run_Predator`):**
   - Corrida baixa e agressiva de predadora, fechando distância rapidamente em zigue-zague leve para dificultar tiros lineares.
2. **Esquiva Reativa (`GUARD_OR_BLINK` — `Side_Step`):**
   - Se o jogador mantiver a mira travada nela por mais de **`1.0 s`** em linha de visão, dispara um *dash* lateral rápido (`Side_Step`) para quebrar a linha de tiro e reposicionar o ângulo de ataque.
   - **Contra-jogada do jogador (Fraqueza):** tem o menor pool de HP entre os 3 bosses (`-15%` equivalente no arquétipo ágil); armas de dispersão (**Shotgun**), **Explosivos de área** ou rajadas curtas após o *Side-Step* punem sua baixa resistência.
3. **Fase 2 — Enrage (`HP <= 50%`):**
   - Executa `Enrage_Roar` com aura térmica carmesim intensa ao redor das garras e cabelos/ombreira.
   - Ganha **`+25%` de velocidade de movimento**, chama a **salva orbital da `SM_Ship` (`4` cápsulas simultâneas)** e passa a disparar a **Rajada Térmica Carmesim** em **rajadas duplas (`burst_count = 2`)**.

### 3. Movimentos & Kit de Ataques

| Ataque / Ação | Animação (`.glb`) | Telegrafia (Leitura) | Execução & Impacto | Papel Tático |
| :--- | :--- | :--- | :--- | :--- |
| **Esquiva Lateral** | `Side_Step` | Breve agachamento + rastro carmesim nos olhos/ombros | *Dash* lateral veloz quando o jogador mira > `1.0 s` | Evita que o jogador derreta o Boss parado de longe |
| **Combo de Garras** | `Attack_Melee` | Cruza as garras brilhantes em vermelho antes do avanço | Combo melee rápido de **3 hits** com avanço curto | Pressiona combate próximo e pune recargas lentas |
| **Rajada Térmica Carmesim** | `Attack_Ranged` | Estende os braços concentrando faíscas térmicas carmesins | Dispara projéteis térmicos de média distância (`burst_count = 2` no Enrage) | Mantém pressão enquanto fecha distância |
| **Salto Predatório** | `Leap_Slam` | Dobra os joelhos com foco vertical e ignição carmesim | Salta direto até o topo das plataformas e crava as garras gerando impacto em área | **Anti-Cheese (`ArenaElevators`):** impede camping no alto das plataformas |

#### Sugestões extras para enriquecer o *moveset* na implementação *(além do mínimo do plano)*:
- **Recuperação pós-`Leap_Slam`:** janela curta (`~0.8 s`) com as garras cravadas no piso metálico antes de voltar ao `CHASE`, recompensando o jogador que usar *dash* para desviar do impacto.
- **Leitura sonora distinta:** zumbido agudo de lâmina térmica ao ativar `Attack_Melee`, estalo elétrico seco no `Side_Step` e rugido metálico agudo no `Enrage_Roar`.

### 4. Quando vira Skin Jogável (`valkyrie_skull`)
Ao derrotá-la na Onda 5, é desbloqueada como skin de mobilidade agressiva:
- **Buffs:** **`+18%` Velocidade** · **`-20%` Cooldown de Dash**
- **Debuffs (Equilíbrio):** **`-15%` HP Máx.** · **`-10%` Dano Base**

---

## Boss 2 — White Reaper (`white_reaper`)

### 1. Identidade & Leitura Visual em Arena
- **Aparição:** Onda **10** (*tier 2*) e depois em rotação nas ondas 25, 40...
- **Papel:** **Tanque Pesado / Juggernaut** — controla espaço pela pressão frontal, resistência a fogo comum e golpes sísmicos.
- **Visual-chave:** Androide biomecânico branco e preto, capacete branco liso sem rosto, cabos expostos no pescoço/abdômen (ponto fraco visual), **emblema de caveira vermelha no peito** (núcleo do canhão) e um **Montante Cibernético Pesado**.
- **Referência T-Pose:** `docs/references/boss_char2_white_android_tpose.jpg` · **Asset alvo:** `res://assets/SK_Boss_Reaper/SK_Boss_Reaper.glb`

### 2. Comportamento & Fluxo de Combate (IA)
1. **Aproximação (`CHASE` — `Walk_Heavy`):**
   - Marcha pesada e constante em direção ao jogador (passos cadenciados, som metálico/hidráulico marcante). Não faz *sidestep* nem corre; avança impondo presença.
2. **Postura Defensiva (`GUARD_OR_BLINK` — `Guard_Stance` — `1.5 s`):**
   - Ao receber fogo contínuo frontal, posiciona o montante largo na diagonal à frente do torso.
   - **Efeito:** reduz drasticamente o dano de armas comuns pela frente (faíscas ricocheteando na lâmina dão feedback imediato).
   - **Contra-jogada do jogador (Fraqueza):**
     - **Rocket / Explosivos** quebram a guarda e disparam **`Stagger_Core`** (abre janela clara de punição).
     - **Flanquear pelas costas / acertar os cabos expostos** ignora a proteção frontal e aplica dano crítico.
3. **Fase 2 — Enrage (`HP <= 50%`):**
   - Executa `Enrage_Roar` com aura emissiva vermelha no núcleo do peito e nos cabos.
   - Ganha **`+25%` de velocidade de movimento**, chama a **salva orbital da `SM_Ship` (`4` cápsulas simultâneas)** e passa a disparar o **Canhão de Peito** em **rajadas duplas (`burst_count = 2`)**.

### 3. Movimentos & Kit de Ataques

| Ataque / Ação | Animação (`.glb`) | Telegrafia (Leitura) | Execução & Impacto | Papel Tático |
| :--- | :--- | :--- | :--- | :--- |
| **Guarda Frontal** | `Guard_Stance` | Traz o montante para a frente do peito; brilho metálico/escudo | `1.5 s` reduzindo dano frontal comum | Força o jogador a usar Rocket/Explosivo ou flanquear |
| **Quebra de Postura** | `Stagger_Core` | Recuo pesado, cabos soltando faíscas, núcleo exposto | Fica vulnerável por ~`1.5–2.0 s` | Recompensa quem usa explosivos ou acerta as costas |
| **Golpe Sísmico** | `Sword_Slam` | Ergue o montante acima da cabeça (`WINDUP` lento e claro) | Bate a lâmina no chão e gera **onda de choque** radial/frontal | Pune quem fica parado no chão; obriga a pular ou usar *dash* (`iframes`) |
| **Canhão de Peito** | `Attack_Ranged` | A **caveira vermelha no peito** acende e concentra energia | Dispara feixe/projétil pesado em linha reta (`burst_count = 2` no Enrage) | **Anti-Cheese (`ArenaElevators`):** atinge o jogador mesmo em plataformas altas |

#### Sugestões extras para enriquecer o *moveset* na implementação *(além do mínimo do plano)*:
- **Varredura de Retaliação (`Cleave_Arc`):** logo após sair da `Guard_Stance`, um corte horizontal amplo (~`180°`) para punir quem ficou colado tentando rodear pelas costas.
- **Leitura sonora distinta:** servo hidráulico grave no `Walk_Heavy`, som metálico agudo de ricochete na `Guard_Stance`, e carregamento grave tipo capacitor antes do **Canhão de Peito**.

### 4. Quando vira Skin Jogável (`white_reaper`)
Ao derrotá-lo na Onda 10, é desbloqueado como skin de tanque blindado:
- **Buffs:** **`+35%` HP Máx.** · **`+20%` Dano Melee & Pesado**
- **Debuffs (Equilíbrio):** **`-18%` Velocidade** · **`+20%` Tempo de Recarga**

---

## Boss 3 — Anubis Phantom (`anubis_phantom`)

### 1. Identidade & Leitura Visual em Arena
- **Aparição:** Onda **15** (*tier 3*) e depois em rotação nas ondas 30, 45...
- **Papel:** **Cyber-Ninja Furtivo / Assassino de Precisão** — quebra a noção de distância com teleporte curto para o flanco/costas, saltos acrobáticos e projéteis em leque.
- **Visual-chave:** Androide cyber-ninja preto fosco com **elmo de chacal/Anubis**, olhos âmbar brilhantes, faixa preta esvoaçante na cintura e **Katana / Wakizashi Âmbar Dupla**.
- **Referência T-Pose:** `docs/references/boss_char3_anubis_ninja_tpose.jpg` · **Asset alvo:** `res://assets/SK_Boss_Anubis/SK_Boss_Anubis.glb`

### 2. Comportamento & Fluxo de Combate (IA)
1. **Aproximação (`CHASE` — `Ninja_Sprint`):**
   - Corrida furtiva inclinada para a frente com as duas lâminas âmbar recuadas, mantendo pressão rápida e imprevisível.
2. **Teleporte Tático (`GUARD_OR_BLINK` — `Shadow_Blink`):**
   - Antes de teleportar, exibe **brilho âmbar intenso nos olhos por `0.6 s`** (telegrafia justa e clara), desaparece em partículas digitais pretas e douradas e ressurge no **flanco ou nas costas** do jogador.
   - **Contra-jogada do jogador (Fraqueza):** é o boss mais frágil em resistência bruta (`-20%` equivalente em HP); acompanhar o som/brilho âmbar de `0.6 s`, virar a câmera rápido e acertar *headshots*/críticos logo após a materialização pune o avanço dele.
3. **Fase 2 — Enrage (`HP <= 50%`):**
   - Executa `Enrage_Roar` com rastro contínuo de energia âmbar nos olhos e lâminas.
   - Ganha **`+25%` de velocidade de movimento**, chama a **salva orbital da `SM_Ship` (`4` cápsulas simultâneas)** e passa a disparar o **Leque de `3` Lâminas de Energia** em **rajadas duplas (`burst_count = 2`)**.

### 3. Movimentos & Kit de Ataques

| Ataque / Ação | Animação (`.glb`) | Telegrafia (Leitura) | Execução & Impacto | Papel Tático |
| :--- | :--- | :--- | :--- | :--- |
| **Teleporte Sombrio** | `Shadow_Blink` | **Olhos âmbar brilham por `0.6 s`** + partículas digitais | Teleporte curto para o flanco ou costas do jogador | Quebra o kiting linear e exige atenção no **Mini-Radar** |
| **Corte Cruzado** | `Cross_Slash` | Cruza as duas katanas âmbar em `X` com faíscas douradas | Golpe duplo rápido logo após sair do `Shadow_Blink` | Pune quem demora para girar ou sair da zona de corte |
| **Leque de 3 Lâminas** | `Attack_Ranged` | Giro largo das duas katanas carregando arcos de energia âmbar | Dispara **leque horizontal de `3` lâminas de energia** (`burst_count = 2` no Enrage) | Cobre área lateral e força movimentação/salto |
| **Salto Acrobático** | `Acrobatic_Leap` | Agachamento rápido + impulso vertical ágil | Salta direto para o topo das plataformas elevatórias | **Anti-Cheese (`ArenaElevators`):** persegue o jogador em qualquer plataforma |

#### Sugestões extras para enriquecer o *moveset* na implementação *(além do mínimo do plano)*:
- **Sinal no Mini-Radar (`HUDRadar`):** durante os `0.6 s` de `Shadow_Blink`, piscar o diamante dourado do boss no radar para ajudar o jogador a antecipar a emboscada nas costas.
- **Leitura sonora distinta:** zumbido fino e agudo das lâminas de plasma no `Cross_Slash`, *whoosh* digital grave no `Shadow_Blink` e assobio cortante ao lançar o leque de `3` lâminas.

### 4. Quando vira Skin Jogável (`anubis_phantom`)
Ao derrotá-lo na Onda 15, é desbloqueado como skin de caçador de precisão (*glass cannon* crítico):
- **Buffs:** **`+15%` Chance Crítica** · **`+25%` Dano Crítico / Headshot**
- **Debuffs (Equilíbrio):** **`-20%` HP Máx.** · **`-15%` Capacidade de Munição/Bateria**
