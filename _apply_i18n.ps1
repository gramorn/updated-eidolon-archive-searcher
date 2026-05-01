# Script to reimplement i18n in index.html and atualizar_eidolons.ps1
# Run once from the project directory

$ErrorActionPreference = "Stop"

# ── PHASE 1: index.html ─────────────────────────────────────────────────────

$html = Get-Content "index.html" -Raw -Encoding UTF8

# 1a. CSS: add lang-selector styles before .useful-links-btn block
$langCss = @'
      .lang-selector {
        position: relative;
        display: flex;
        align-items: center;
        gap: 2px;
      }
      .lang-btn {
        background: none;
        border: 1px solid transparent;
        border-radius: 6px;
        cursor: pointer;
        padding: 3px 5px;
        line-height: 1;
        display: none;
        align-items: center;
        transition:
          border-color 0.15s,
          background 0.15s;
      }
      .lang-btn img {
        width: 22px;
        height: 15px;
        object-fit: cover;
        border-radius: 2px;
        display: block;
      }
      .lang-btn.active {
        display: inline-flex;
        border-color: var(--accent);
      }
      .lang-selector.open .lang-btn {
        display: inline-flex;
      }
      .lang-btn:hover {
        border-color: var(--line);
        background: var(--chip-bg);
      }
      .lang-btn.active:hover {
        border-color: var(--accent);
      }

'@

$html = $html -replace '(\s+)(\.useful-links-btn \{)', "`n$langCss      `$2"

# 1b. HTML: add lang-selector before the themeToggle button
$langHtml = @'
            <div class="lang-selector" role="group" aria-label="Language">
              <button
                class="lang-btn active"
                data-lang="en"
                title="English"
                type="button"
              >
                <img
                  src="https://flagcdn.com/20x15/us.png"
                  alt="English"
                  width="20"
                  height="15"
                />
              </button>
              <button
                class="lang-btn"
                data-lang="pt"
                title="Português (Brasil)"
                type="button"
              >
                <img
                  src="https://flagcdn.com/20x15/br.png"
                  alt="Português"
                  width="20"
                  height="15"
                />
              </button>
              <button
                class="lang-btn"
                data-lang="es"
                title="Español"
                type="button"
              >
                <img
                  src="https://flagcdn.com/20x15/es.png"
                  alt="Español"
                  width="20"
                  height="15"
                />
              </button>
              <button
                class="lang-btn"
                data-lang="de"
                title="Deutsch"
                type="button"
              >
                <img
                  src="https://flagcdn.com/20x15/de.png"
                  alt="Deutsch"
                  width="20"
                  height="15"
                />
              </button>
              <button
                class="lang-btn"
                data-lang="fr"
                title="Français"
                type="button"
              >
                <img
                  src="https://flagcdn.com/20x15/fr.png"
                  alt="Français"
                  width="20"
                  height="15"
                />
              </button>
            </div>

'@

$html = $html -replace '(\s+)(<button\r?\n\s+id="themeToggle")', "`n$langHtml            <button`r`n              id=`"themeToggle`""

# 1c. data-i18n on nav toggle buttons
$html = $html -replace '(<summary class="info-menu-toggle" aria-label="Open info menu">)\s*Guides ▾\s*(</summary>)', '<summary class="info-menu-toggle" aria-label="Open info menu" data-i18n="nav_guides">Guides ▾</summary>'
$html = $html -replace '(<summary\s[^>]*aria-label="Open class guides menu"[^>]*>)\s*Class Guides ▾\s*(</summary>)', '<summary class="info-menu-toggle" aria-label="Open class guides menu" data-i18n="nav_class_guides">Class Guides ▾</summary>'

# 1d. data-i18n on search input placeholder
$html = $html -replace '(id="q"\s+class="search"\s+placeholder=")Search by Eidolon, combo or bonus\.\.\."', '$1Search by Eidolon, combo or bonus..." data-i18n-placeholder="search_placeholder"'

# 1e. Modal h3 titles
$html = $html -replace '<h3 id="luckyPackTitle">Eidolon Lucky Packs</h3>', '<h3 id="luckyPackTitle" data-i18n="modal_lucky_pack_title">Eidolon Lucky Packs</h3>'
$html = $html -replace '<h3 id="wishCoinTitle">Eidolon Wish Coins</h3>', '<h3 id="wishCoinTitle" data-i18n="modal_wish_coin_title">Eidolon Wish Coins</h3>'
$html = $html -replace '<h3 id="limitBreakTitle">Card Breakthrough Devices</h3>', '<h3 id="limitBreakTitle" data-i18n="modal_limit_break_title">Card Breakthrough Devices</h3>'
$html = $html -replace '<h3 id="levelingGuideTitle">Eidolon Leveling</h3>', '<h3 id="levelingGuideTitle" data-i18n="modal_leveling_title">Eidolon Leveling</h3>'
$html = $html -replace '<h3 id="gearGuideTitle">Gear Guide</h3>', '<h3 id="gearGuideTitle" data-i18n="modal_gear_title">Gear Guide</h3>'
$html = $html -replace '<h3 id="boostGuideTitle">Boost your damage</h3>', '<h3 id="boostGuideTitle" data-i18n="modal_boost_title">Boost your damage</h3>'
$html = $html -replace '<h3 id="dungeonGuideTitle">Eidolon Spawn Location</h3>', '<h3 id="dungeonGuideTitle" data-i18n="modal_dungeon_title">Eidolon Spawn Location</h3>'
$html = $html -replace '<h3 id="bestEidolonsTitle">Best Eidolons</h3>', '<h3 id="bestEidolonsTitle" data-i18n="modal_best_eidolons_title">Best Eidolons</h3>'
$html = $html -replace '<h3 id="usefulLinksTitle">Useful links</h3>', '<h3 id="usefulLinksTitle" data-i18n="modal_useful_links_title">Useful links</h3>'
$html = $html -replace '<h3 id="classGuideTitle">Class Guides</h3>', '<h3 id="classGuideTitle" data-i18n="modal_class_guide_title">Class Guides</h3>'

# 1f. JS: add TRANSLATIONS + applyLang + lang selector handler + init before </script>
$jsI18n = @'

      const TRANSLATIONS = {
        en: {
          nav_guides: "Guides ▾",
          nav_class_guides: "Class Guides ▾",
          btn_what_is: "What is",
          btn_eidolon_leveling: "Eidolon Leveling",
          btn_gear_guide: "Gear Guide",
          btn_boost_damage: "Boost your damage",
          btn_spawn_location: "Eidolon Spawn Location",
          btn_best_eidolons: "Best Eidolons",
          btn_useful_links: "Useful links",
          btn_close: "Close",
          search_placeholder: "Search by Eidolon, combo or bonus...",
          modal_best_eidolons_title: "Best Eidolons",
          modal_best_eidolons_warning_label: "Outdated list:",
          modal_best_eidolons_warning_text:
            " this information is from July 2024 and may no longer reflect the current best choices.",
          modal_best_eidolons_legend: "= Great with Eidolon Symbol",
          modal_best_eidolons_footer:
            "I do not know who should be credited for this information. If this is your information and you want credit, feel free to contact me on Discord.",
          section_universal: "Universal Eidolons",
          section_dark: "Dark Eidolons",
          section_holy: "Holy Eidolons",
          section_flame: "Flame Eidolons",
          section_storm: "Storm Eidolons",
          section_ice: "Ice Eidolons",
          section_lightning: "Lightning Eidolons",
          section_physical: "Physical Eidolons",
          modal_useful_links_title: "Useful links",
          modal_useful_links_intro: "Community guides and resources.",
          modal_class_guide_title: "Class Guides",
          modal_class_guide_intro:
            "This menu is ready for class-by-class Aura Kingdom guides.",
          modal_lucky_pack_title: "Eidolon Lucky Packs",
          modal_lucky_pack_p1:
            "Eidolon Lucky Packs are used at the Eidolon Den in your house to level up intimacy.",
          modal_lucky_pack_p2:
            "The basic stats gained by intimacy leveling are applied to your character:",
          modal_lucky_pack_p3:
            "Because of this, all Eidolons should be leveled to at least intimacy level 8. It usually takes about 280 Eidolon Lucky Packs to go from level 1 to 8. Level 10 is optional.",
          modal_wish_coin_title: "Eidolon Wish Coins",
          modal_wish_coin_p1:
            "Wish Coins are used to fulfill an Eidolon's wish without needing to gather what they ask for. They are a shortcut to fulfill wishes.",
          modal_wish_coin_p2:
            "All stats gained this way are applied to your character.",
          modal_wish_coin_cost: "Wish Coin cost per wish level:",
          modal_wish_coin_outro:
            "All Eidolons should have their wishes fulfilled. This is one of the greatest sources of raw stats.",
          modal_limit_break_title: "Card Breakthrough Devices",
          modal_limit_break_p1:
            "Card Breakthrough Devices are used to increase the breakthrough level of a card from 1 to 10.",
          modal_limit_break_p2:
            "Reaching level 10 unlocks the card's <strong>Status Bonus</strong>, applied permanently to your character.",
          modal_limit_break_tier: "Device tier required per level:",
          modal_limit_break_t1: "Levels 1–3: Basic Card Breakthrough Device",
          modal_limit_break_t2:
            "Levels 4–7: Intermediate Card Breakthrough Device",
          modal_limit_break_t3:
            "Levels 7–10: Advanced Card Breakthrough Device",
          modal_limit_break_outro:
            "Prioritize reaching level 10 on cards with the strongest Status Bonuses for your build.",
          modal_leveling_title: "Eidolon Leveling",
          modal_leveling_p1:
            "To level an Eidolon from level 25 to 80, you can use the crystals below:",
          modal_skill_leveling_title: "Eidolon Skill Leveling (Mana Starstone)",
          modal_skill_leveling_p:
            "Leveling the skills of your main Eidolons is very important, because their skills gain stronger and additional buffs/debuffs.",
          modal_skill_leveling_total: "Total Mana Starstone needed: 6700",
          modal_gear_title: "Gear Guide",
          modal_gear_intro:
            "This section covers practical crafting priorities for your equipment.",
          gear_crafting_notes: "Crafting Notes",
          gear_weapon_progression: "Weapon Progression by Level",
          gear_weapon_core: "Weapon Core Options",
          gear_armor_core: "Armor / Trophy / Accessories Core Options",
          gear_mount_buff: "Mount Buff",
          gear_weapon_stone: "Weapon Secret Stone",
          gear_armor_stone: "Armor Secret Stone",
          gear_armor_stone_reroll: "Best Stats to Aim For (Rerolling)",
          gear_costume: "Costume",
          gear_crafting_li1:
            "Your weapon should use your class element because it deals 20% more elemental damage.",
          gear_crafting_li2:
            "Your armor element applies only on the chest piece and gives extra defense against that element. Dark element armor is generally preferred.",
          gear_crafting_li3:
            "Try to craft at least 120%+ quality on equipment. It is less important on armor, but high weapon quality increases damage noticeably.",
          gear_crafting_li4:
            "The quality cap is 130% for Orange equipment and 140% for Gold equipment.",
          gear_wp_note:
            "The strongest current weapons are farmed in Abyss II for each element. They are the best choices at Lv95, S15, and S35, so after Lv95 you generally do not need other weapon lines.",
          gear_wp_li1:
            "<strong>Below Lv95:</strong> Use reward weapons from Aura and Advanced Gaia (one from Lv1-40 and one from Lv40-75). They can carry you comfortably until Lv95.",
          gear_wp_li2:
            "<strong>Lv95:</strong> Craft the Abyss II weapon for your element: Hebe (Ice), Cerberus (Fire), Izanami (Dark), Michaela (Holy), Demeter (Storm), Hermes (Lightning). For physical builds, pick the weapon that gives the best boost to your main skills. If you do not want Abyss II yet, use Lv95 gold with your element or craft Lv90 orange with your preferred core.",
          gear_wp_li3:
            "<strong>S5:</strong> If you still do not have a Lv95 option, craft your Abyss II element weapon or use an S5 gold weapon with your element.",
          gear_wp_li4:
            "<strong>S10:</strong> The Lv95 Abyss II weapon is still good here. If you really want to change, craft the S10 orange weapon.",
          gear_wp_li5:
            "<strong>S15:</strong> Craft the S15 Abyss II weapon for your element. This is your best weapon line until S35.",
          gear_wp_li6:
            "<strong>S35:</strong> You can switch to S35 gold for your element, but it is optional. The best weapon is still Abyss II S35 of your element; S35 Abyss II is difficult to farm, so swap when you are strong enough and can farm it consistently.",
          gear_wc_li1: "<strong>Destroyer:</strong> 10% DEF Shred.",
          gear_wc_li2:
            "<strong>Nocturnal:</strong> 3% Absorb DMG to HP. This is nerfed in some dungeons.",
          gear_wc_li3: "<strong>Deadly:</strong> 15% CRIT DMG.",
          gear_wc_li4: "<strong>Restorer (Bard Only):</strong> 10% Heal.",
          gear_ac_li1: "<strong>Imperial:</strong> 3% Move SPD.",
          gear_ac_li2: "<strong>Blessed:</strong> 5% EXP Gain.",
          gear_ac_li3: "<strong>Bestial:</strong> 1% DMG + 1% HP.",
          gear_ac_li4: "<strong>Spiky:</strong> 1% DMG + 1% DEF.",
          gear_mb_li1: "40% bonus to your class element skill damage.",
          gear_ws_note: "Always get the secret stone for your class skill.",
          gear_ws_li1:
            "<strong>Piercing Secret Stone</strong> \u2014 Best in slot, but expensive.",
          gear_ws_li2:
            "<strong>Lava Secret Stone</strong> \u2014 Cheaper than Piercing, and can be farmed in Pyroclastic Purgatory.",
          gear_ws_li3:
            "<strong>Orange Class Master Stone</strong> \u2014 Use as a placeholder before getting Lava or better.",
          gear_as_note1:
            "Purchase them at your class Master in Navea. They will be orange \u2014 don't worry about the stats. Level them to 70, then upgrade to purple to add one more stat, and they are ready to reroll.",
          gear_as_li1: "<strong>Detail-DMG</strong> (or DMG): +5 / +4 / +3",
          gear_as_li2: "<strong>CRIT DMG:</strong> +10 / +8 / +6",
          gear_as_note2:
            "Always aim for <strong>Detail-DMG +5%</strong> or at least <strong>DMG +4%</strong>. The most common strategy is to get <strong>Detail-DMG +5</strong> on the last line, then use a <strong>DMG + Something reroll potion</strong> to aim for double Detail-DMG on the stone.",
          gear_as_note3:
            "With enough economy, you can push further and get a stone with <strong>three damage stats</strong> \u2014 for example: <em>The DMG caused is increased by 6% / DMG +3% / Detail-DMG +5%</em>.",
          gear_costume_note:
            "<strong>Important:</strong> Always apply a <strong>Premium / Super Premium Card</strong> to the blue card bought from the Encyclopedia first, then use that blue card with enchants on your costume.",
          gear_costume_h5_head: "Headpiece - 12% DMG To Bosses",
          gear_costume_head_li1: "Add 10% Boss DMG Enchant.",
          gear_costume_head_li2: "Option A: Add 4% HP + 2% EVA Super Enchant.",
          gear_costume_head_li3: "Option B: Add 4% HP + 4% HEAL Super Enchant.",
          gear_costume_h5_body: "Body - 20% CRIT DMG To Bosses",
          gear_costume_body_li1: "Add 25% Boss CRIT DMG Enchant.",
          gear_costume_body_li2: "Add 4% DMG + 2% CRIT Super Enchant.",
          gear_costume_h5_face:
            "Face - Pick What You Need Most (7% DMG / 7% SPD / 7% CRIT)",
          gear_costume_face_li1: "Add Class Enchant.",
          gear_costume_face_li2:
            "Option A: Add 4% DMG + 2% CRIT Super Enchant.",
          gear_costume_face_li3:
            "Option B: Add 4% DMG + Reduce 4% DMG Taken Super Enchant.",
          gear_costume_h5_back:
            "Back - 8% Move SPD Priority. Otherwise Pick What You Need Most (7% DMG / 7% SPD / 7% CRIT)",
          gear_costume_back_li1: "Add Move SPD Enchant.",
          gear_costume_back_li2: "Add 4% DMG + 4% HP Super Enchant.",
          gear_costume_h5_weapon: "Weapon - 12% Element Skill DMG",
          gear_costume_weapon_li1: "Add Class Enchant.",
          gear_costume_weapon_li2: "Add 4% DMG + 2% CRIT Super Enchant.",
          modal_boost_title: "Boost your damage",
          modal_boost_intro:
            "This guide focuses on practical ways to increase your overall damage output.",
          boost_back_strike: "Back Strike",
          boost_back_strike_p1:
            "Back Strike means attacking enemies from behind. Doing this grants <strong>50% amplified damage</strong>.",
          boost_back_strike_p2:
            "Whenever possible, reposition to stay behind the target and maintain this bonus.",
          boost_jump_casting: "Jump Casting",
          boost_jump_p1:
            "Jump Casting is a combat mechanic where you jump and then cast your skills. This helps cancel or shorten many animations that would normally lock you in place.",
          boost_jump_p2:
            "It also weaves basic attacks between skills, which increases your total damage output over time.",
          boost_amp_sources: "Amplified Damage Sources",
          boost_amp_intro:
            "Reference list of common sources that can raise your amplified damage in combat.",
          modal_dungeon_title: "Eidolon Spawn Location",
          modal_dungeon_note:
            "<strong>Note:</strong> Eidolons not listed here may be obtained from the Loyalty Points shop, by buying from other players, through the Auction House, by playing Paragon, or from in-game events.",
        },
        pt: {
          nav_guides: "Guias ▾",
          nav_class_guides: "Guias de Classe ▾",
          btn_what_is: "O que é",
          btn_eidolon_leveling: "Nivelar Eidolon",
          btn_gear_guide: "Guia de Equipamento",
          btn_boost_damage: "Aumente seu dano",
          btn_spawn_location: "Local de Aparição do Eidolon",
          btn_best_eidolons: "Melhores Eidolons",
          btn_useful_links: "Links úteis",
          btn_close: "Fechar",
          search_placeholder: "Buscar por Eidolon, combo ou bônus...",
          modal_best_eidolons_title: "Melhores Eidolons",
          modal_best_eidolons_warning_label: "Lista desatualizada:",
          modal_best_eidolons_warning_text:
            " estas informações são de julho de 2024 e podem não refletir mais as melhores escolhas atuais.",
          modal_best_eidolons_legend: "= Ótimo com Símbolo de Eidolon",
          modal_best_eidolons_footer:
            "Não sei a quem creditar esta informação. Se for sua e quiser crédito, entre em contato comigo no Discord.",
          section_universal: "Eidolons Universais",
          section_dark: "Eidolons das Trevas",
          section_holy: "Eidolons Sagrados",
          section_flame: "Eidolons de Fogo",
          section_storm: "Eidolons de Tempestade",
          section_ice: "Eidolons de Gelo",
          section_lightning: "Eidolons de Raio",
          section_physical: "Eidolons Físicos",
          modal_useful_links_title: "Links úteis",
          modal_useful_links_intro: "Guias e recursos da comunidade.",
          modal_class_guide_title: "Guias de Classe",
          modal_class_guide_intro:
            "Este menu está pronto para guias por classe do Aura Kingdom.",
          modal_lucky_pack_title: "Lucky Packs de Eidolon",
          modal_lucky_pack_p1:
            "Os Lucky Packs de Eidolon são usados no Covil do Eidolon em sua casa para aumentar a intimidade.",
          modal_lucky_pack_p2:
            "Os atributos básicos obtidos ao aumentar a intimidade são aplicados ao seu personagem:",
          modal_lucky_pack_p3:
            "Por isso, todos os Eidolons devem ser levados ao nível 8 de intimidade. Geralmente são necessários cerca de 280 Lucky Packs para ir do nível 1 ao 8. O nível 10 é opcional.",
          modal_wish_coin_title: "Moedas de Desejo de Eidolon",
          modal_wish_coin_p1:
            "As Moedas de Desejo são usadas para cumprir o desejo de um Eidolon sem precisar reunir os itens solicitados. São um atalho para cumprir desejos.",
          modal_wish_coin_p2:
            "Todos os atributos obtidos dessa forma são aplicados ao seu personagem.",
          modal_wish_coin_cost: "Custo de Moedas de Desejo por nível:",
          modal_wish_coin_outro:
            "Todos os Eidolons devem ter seus desejos cumpridos. Esta é uma das maiores fontes de atributos.",
          modal_limit_break_title: "Dispositivos de Avanço de Carta",
          modal_limit_break_p1:
            "Os Dispositivos de Avanço de Carta são usados para aumentar o nível de avanço de uma carta de 1 a 10.",
          modal_limit_break_p2:
            "Chegar ao nível 10 desbloqueia o <strong>Bônus de Status</strong> da carta, aplicado permanentemente ao seu personagem.",
          modal_limit_break_tier: "Tier do dispositivo necessário por nível:",
          modal_limit_break_t1: "Níveis 1–3: Dispositivo de Avanço Básico",
          modal_limit_break_t2:
            "Níveis 4–7: Dispositivo de Avanço Intermediário",
          modal_limit_break_t3: "Níveis 7–10: Dispositivo de Avanço Avançado",
          modal_limit_break_outro:
            "Priorize chegar ao nível 10 nas cartas com os Bônus de Status mais fortes para sua build.",
          modal_leveling_title: "Nivelamento de Eidolon",
          modal_leveling_p1:
            "Para nivelar um Eidolon do nível 25 ao 80, você pode usar os cristais abaixo:",
          modal_skill_leveling_title:
            "Nivelamento de Habilidades do Eidolon (Mana Starstone)",
          modal_skill_leveling_p:
            "Nivelar as habilidades dos seus Eidolons principais é muito importante, pois elas ficam mais fortes e ganham buffs/debuffs adicionais.",
          modal_skill_leveling_total:
            "Total de Mana Starstone necessário: 6700",
          modal_gear_title: "Guia de Equipamento",
          modal_gear_intro:
            "Esta seção cobre as prioridades práticas de criação do seu equipamento.",
          gear_crafting_notes: "Notas de Criação",
          gear_weapon_progression: "Progressão de Armas por Nível",
          gear_weapon_core: "Opções de Núcleo de Arma",
          gear_armor_core: "Opções de Núcleo de Armadura / Troféu / Acessórios",
          gear_mount_buff: "Buff de Montaria",
          gear_weapon_stone: "Pedra Secreta de Arma",
          gear_armor_stone: "Pedra Secreta de Armadura",
          gear_armor_stone_reroll: "Melhores Atributos a Buscar (Reroll)",
          gear_costume: "Fantasia",
          gear_crafting_li1:
            "Sua arma deve usar o elemento da sua classe pois causa 20% mais dano elemental.",
          gear_crafting_li2:
            "O elemento da armadura se aplica apenas na peça do peito e dá defesa extra contra aquele elemento. Armadura de elemento Escuridão é geralmente preferida.",
          gear_crafting_li3:
            "Tente craftar equipamentos com pelo menos 120%+ de qualidade. É menos importante na armadura, mas uma alta qualidade de arma aumenta o dano notavelmente.",
          gear_crafting_li4:
            "O limite de qualidade é 130% para equipamentos Laranja e 140% para equipamentos Ouro.",
          gear_wp_note:
            "As armas mais fortes atualmente são farmadas no Abyss II para cada elemento. Elas são as melhores escolhas no Lv95, S15 e S35, então após o Lv95 você geralmente não precisa de outras linhas de armas.",
          gear_wp_li1:
            "<strong>Abaixo do Lv95:</strong> Use armas de recompensa do Aura e do Gaia Avançado (uma do Lv1-40 e outra do Lv40-75). Elas podem te carregar confortavelmente até o Lv95.",
          gear_wp_li2:
            "<strong>Lv95:</strong> Crafta a arma do Abyss II para o seu elemento: Hebe (Gelo), Cerberus (Fogo), Izanami (Escuridão), Michaela (Sagrado), Demeter (Tempestade), Hermes (Raio). Para builds físicas, escolha a arma que dá o melhor boost às suas habilidades principais. Se não quiser Abyss II ainda, use ouro Lv95 com seu elemento ou crafta laranja Lv90 com o núcleo preferido.",
          gear_wp_li3:
            "<strong>S5:</strong> Se ainda não tiver opção Lv95, crafta a arma de elemento do Abyss II ou use uma arma ouro S5 com seu elemento.",
          gear_wp_li4:
            "<strong>S10:</strong> A arma Abyss II Lv95 ainda é boa aqui. Se realmente quiser mudar, crafta a arma laranja S10.",
          gear_wp_li5:
            "<strong>S15:</strong> Crafta a arma Abyss II S15 para o seu elemento. Esta é sua melhor linha de arma até o S35.",
          gear_wp_li6:
            "<strong>S35:</strong> Você pode trocar para ouro S35 do seu elemento, mas é opcional. A melhor arma ainda é o Abyss II S35 do seu elemento; o Abyss II S35 é difícil de farmar, então troque quando estiver forte o suficiente e conseguir farmar consistentemente.",
          gear_wc_li1:
            "<strong>Destruidor:</strong> 10% de redução de DEF.",
          gear_wc_li2:
            "<strong>Noturno:</strong> 3% de absorção de dano para HP. Isso é limitado em algumas masmorras.",
          gear_wc_li3: "<strong>Mortal:</strong> 15% de CRIT DMG.",
          gear_wc_li4:
            "<strong>Restaurador (Apenas Bardo):</strong> 10% de Cura.",
          gear_ac_li1:
            "<strong>Imperial:</strong> 3% de Velocidade de Movimento.",
          gear_ac_li2: "<strong>Abençoado:</strong> 5% de Ganho de EXP.",
          gear_ac_li3: "<strong>Bestial:</strong> 1% DMG + 1% HP.",
          gear_ac_li4: "<strong>Espinhoso:</strong> 1% DMG + 1% DEF.",
          gear_mb_li1:
            "40% de bônus no dano de habilidade do elemento da sua classe.",
          gear_ws_note:
            "Sempre pegue a pedra secreta para a habilidade da sua classe.",
          gear_ws_li1:
            "<strong>Pedra Secreta Perfurante</strong> \u2014 Melhor no slot, mas cara.",
          gear_ws_li2:
            "<strong>Pedra Secreta de Lava</strong> \u2014 Mais barata que a Perfurante e pode ser farmada no Purgatório Piroclástico.",
          gear_ws_li3:
            "<strong>Pedra Mestre de Classe Laranja</strong> \u2014 Use como substituta antes de conseguir Lava ou melhor.",
          gear_as_note1:
            "Compre no Mestre da sua classe em Navea. Serão laranjas \u2014 não se preocupe com os atributos. Suba para o nível 70, depois evolua para roxo para adicionar mais um atributo, e estarão prontas para reroll.",
          gear_as_li1: "<strong>Detail-DMG</strong> (ou DMG): +5 / +4 / +3",
          gear_as_li2: "<strong>CRIT DMG:</strong> +10 / +8 / +6",
          gear_as_note2:
            "Sempre mire em <strong>Detail-DMG +5%</strong> ou pelo menos <strong>DMG +4%</strong>. A estratégia mais comum é conseguir <strong>Detail-DMG +5</strong> na última linha, depois usar uma <strong>poção de reroll DMG + Algo</strong> para ter Detail-DMG duplo na pedra.",
          gear_as_note3:
            "Com economia suficiente, você pode ir mais longe e conseguir uma pedra com <strong>três atributos de dano</strong> \u2014 por exemplo: <em>O DMG causado aumenta em 6% / DMG +3% / Detail-DMG +5%</em>.",
          gear_costume_note:
            "<strong>Importante:</strong> Sempre aplique um <strong>Card Premium / Super Premium</strong> no card azul comprado da Enciclopédia primeiro, depois use esse card azul com encantamentos na sua fantasia.",
          gear_costume_h5_head: "Capacete - 12% de DMG para Chefes",
          gear_costume_head_li1:
            "Adicione Encantamento de 10% de DMG para Chefes.",
          gear_costume_head_li2:
            "Opção A: Adicione Super Encantamento de 4% HP + 2% EVA.",
          gear_costume_head_li3:
            "Opção B: Adicione Super Encantamento de 4% HP + 4% HEAL.",
          gear_costume_h5_body: "Corpo - 20% de CRIT DMG para Chefes",
          gear_costume_body_li1:
            "Adicione Encantamento de 25% de CRIT DMG para Chefes.",
          gear_costume_body_li2:
            "Adicione Super Encantamento de 4% DMG + 2% CRIT.",
          gear_costume_h5_face:
            "Rosto - Escolha o que Mais Precisa (7% DMG / 7% SPD / 7% CRIT)",
          gear_costume_face_li1: "Adicione Encantamento de Classe.",
          gear_costume_face_li2:
            "Opção A: Adicione Super Encantamento de 4% DMG + 2% CRIT.",
          gear_costume_face_li3:
            "Opção B: Adicione Super Encantamento de 4% DMG + Reduzir 4% DMG Recebido.",
          gear_costume_h5_back:
            "Costas - Prioridade de 8% Velocidade de Movimento. Caso contrário, Escolha o que Mais Precisa (7% DMG / 7% SPD / 7% CRIT)",
          gear_costume_back_li1:
            "Adicione Encantamento de Velocidade de Movimento.",
          gear_costume_back_li2:
            "Adicione Super Encantamento de 4% DMG + 4% HP.",
          gear_costume_h5_weapon: "Arma - 12% de DMG de Habilidade Elemental",
          gear_costume_weapon_li1: "Adicione Encantamento de Classe.",
          gear_costume_weapon_li2:
            "Adicione Super Encantamento de 4% DMG + 2% CRIT.",
          modal_boost_title: "Aumente seu dano",
          modal_boost_intro:
            "Este guia foca em maneiras práticas de aumentar seu dano geral.",
          boost_back_strike: "Ataque Pelas Costas",
          boost_back_strike_p1:
            "Ataque Pelas Costas significa atacar inimigos por trás. Isso concede 50% de dano amplificado.",
          boost_back_strike_p2:
            "Sempre que possível, reposicione-se para ficar atrás do alvo e manter esse bônus.",
          boost_jump_casting: "Conjuração em Salto",
          boost_jump_p1:
            "Conjuração em Salto é uma mecânica de combate onde você pula e depois usa suas habilidades. Isso ajuda a cancelar ou encurtar muitas animações que normalmente te imobilizariam.",
          boost_jump_p2:
            "Também intercala ataques básicos entre habilidades, aumentando seu dano total ao longo do tempo.",
          boost_amp_sources: "Fontes de Dano Amplificado",
          boost_amp_intro:
            "Lista de referência de fontes comuns que podem aumentar seu dano amplificado em combate.",
          modal_dungeon_title: "Local de Aparição do Eidolon",
          modal_dungeon_note:
            "<strong>Nota:</strong> Eidolons não listados aqui podem ser obtidos na loja de Pontos de Lealdade, comprando de outros jogadores, pelo Mercado, jogando Paragon ou em eventos do jogo.",
        },
        es: {
          nav_guides: "Guías ▾",
          nav_class_guides: "Guías de Clase ▾",
          btn_what_is: "¿Qué es",
          btn_eidolon_leveling: "Nivelar Eidolon",
          btn_gear_guide: "Guía de Equipo",
          btn_boost_damage: "Aumenta tu daño",
          btn_spawn_location: "Ubicación de Aparición",
          btn_best_eidolons: "Mejores Eidolons",
          btn_useful_links: "Enlaces útiles",
          btn_close: "Cerrar",
          search_placeholder: "Buscar por Eidolon, combo o bonificación...",
          modal_best_eidolons_title: "Mejores Eidolons",
          modal_best_eidolons_warning_label: "Lista desactualizada:",
          modal_best_eidolons_warning_text:
            " esta información es de julio de 2024 y puede no reflejar las mejores opciones actuales.",
          modal_best_eidolons_legend: "= Excelente con Símbolo de Eidolon",
          modal_best_eidolons_footer:
            "No sé a quién acreditar esta información. Si es tuya y quieres crédito, contáctame en Discord.",
          section_universal: "Eidolons Universales",
          section_dark: "Eidolons Oscuros",
          section_holy: "Eidolons Sagrados",
          section_flame: "Eidolons de Fuego",
          section_storm: "Eidolons de Tormenta",
          section_ice: "Eidolons de Hielo",
          section_lightning: "Eidolons de Rayo",
          section_physical: "Eidolons Físicos",
          modal_useful_links_title: "Enlaces útiles",
          modal_useful_links_intro: "Guías y recursos de la comunidad.",
          modal_class_guide_title: "Guías de Clase",
          modal_class_guide_intro:
            "Este menú está listo para guías de clase de Aura Kingdom.",
          modal_lucky_pack_title: "Paquetes de Suerte de Eidolon",
          modal_lucky_pack_p1:
            "Los Paquetes de Suerte de Eidolon se usan en la Guarida del Eidolon en tu casa para subir la intimidad.",
          modal_lucky_pack_p2:
            "Los atributos básicos obtenidos al subir la intimidad se aplican a tu personaje:",
          modal_lucky_pack_p3:
            "Por eso, todos los Eidolons deben llegar al nivel 8 de intimidad. Generalmente se necesitan unos 280 paquetes para ir del nivel 1 al 8. El nivel 10 es opcional.",
          modal_wish_coin_title: "Monedas de Deseo de Eidolon",
          modal_wish_coin_p1:
            "Las Monedas de Deseo se usan para cumplir el deseo de un Eidolon sin necesitar reunir los objetos pedidos.",
          modal_wish_coin_p2:
            "Todos los atributos obtenidos así se aplican a tu personaje.",
          modal_wish_coin_cost: "Costo de Monedas de Deseo por nivel:",
          modal_wish_coin_outro:
            "Todos los Eidolons deben tener sus deseos cumplidos. Es una de las mayores fuentes de atributos.",
          modal_limit_break_title: "Dispositivos de Avance de Carta",
          modal_limit_break_p1:
            "Los Dispositivos de Avance de Carta se usan para aumentar el nivel de avance de una carta del 1 al 10.",
          modal_limit_break_p2:
            "Llegar al nivel 10 desbloquea el <strong>Bono de Estado</strong> de la carta, aplicado permanentemente a tu personaje.",
          modal_limit_break_tier: "Nivel de dispositivo requerido por nivel:",
          modal_limit_break_t1: "Niveles 1–3: Dispositivo de Avance Básico",
          modal_limit_break_t2: "Niveles 4–7: Dispositivo de Avance Intermedio",
          modal_limit_break_t3: "Niveles 7–10: Dispositivo de Avance Avanzado",
          modal_limit_break_outro:
            "Prioriza llegar al nivel 10 en las cartas con los Bonos de Estado más fuertes para tu build.",
          modal_leveling_title: "Nivelación de Eidolon",
          modal_leveling_p1:
            "Para nivelar un Eidolon del nivel 25 al 80, puedes usar los cristales a continuación:",
          modal_skill_leveling_title:
            "Nivelación de Habilidades del Eidolon (Mana Starstone)",
          modal_skill_leveling_p:
            "Nivelar las habilidades de tus Eidolons principales es muy importante, ya que sus habilidades se vuelven más fuertes y ganan buffs/debuffs adicionales.",
          modal_skill_leveling_total: "Total de Mana Starstone necesario: 6700",
          modal_gear_title: "Guía de Equipo",
          modal_gear_intro:
            "Esta sección cubre las prioridades prácticas de fabricación de tu equipo.",
          gear_crafting_notes: "Notas de Fabricación",
          gear_weapon_progression: "Progresión de Armas por Nivel",
          gear_weapon_core: "Opciones de Núcleo de Arma",
          gear_armor_core:
            "Opciones de Núcleo de Armadura / Trofeo / Accesorios",
          gear_mount_buff: "Buff de Montura",
          gear_weapon_stone: "Piedra Secreta de Arma",
          gear_armor_stone: "Piedra Secreta de Armadura",
          gear_armor_stone_reroll: "Mejores Atributos a Buscar (Reroll)",
          gear_costume: "Disfraz",
          gear_crafting_li1:
            "Tu arma debe usar el elemento de tu clase porque causa un 20% más de daño elemental.",
          gear_crafting_li2:
            "El elemento de la armadura solo se aplica en la pieza de pecho y da defensa extra contra ese elemento. La armadura de elemento Oscuridad es generalmente preferida.",
          gear_crafting_li3:
            "Intenta fabricar equipamiento con al menos 120%+ de calidad. Es menos importante en la armadura, pero una alta calidad de arma aumenta el daño notablemente.",
          gear_crafting_li4:
            "El límite de calidad es 130% para equipo Naranja y 140% para equipo Dorado.",
          gear_wp_note:
            "Las armas más fuertes actualmente se farmean en Abyss II para cada elemento. Son las mejores opciones en Lv95, S15 y S35, así que después del Lv95 generalmente no necesitas otras líneas de armas.",
          gear_wp_li1:
            "<strong>Bajo Lv95:</strong> Usa armas de recompensa de Aura y Gaia Avanzado (una de Lv1-40 y una de Lv40-75). Pueden llevarte cómodamente hasta Lv95.",
          gear_wp_li2:
            "<strong>Lv95:</strong> Fabrica el arma de Abyss II para tu elemento: Hebe (Hielo), Cerberus (Fuego), Izanami (Oscuridad), Michaela (Sagrado), Demeter (Tormenta), Hermes (Rayo). Para builds físicas, elige el arma que dé el mejor boost a tus habilidades principales. Si aún no quieres Abyss II, usa oro Lv95 con tu elemento o fabrica naranja Lv90 con tu núcleo preferido.",
          gear_wp_li3:
            "<strong>S5:</strong> Si aún no tienes opción Lv95, fabrica el arma de elemento Abyss II o usa un arma de oro S5 con tu elemento.",
          gear_wp_li4:
            "<strong>S10:</strong> El arma Abyss II Lv95 sigue siendo buena aquí. Si realmente quieres cambiar, fabrica el arma naranja S10.",
          gear_wp_li5:
            "<strong>S15:</strong> Fabrica el arma Abyss II S15 para tu elemento. Esta es tu mejor línea de arma hasta S35.",
          gear_wp_li6:
            "<strong>S35:</strong> Puedes cambiar a oro S35 para tu elemento, pero es opcional. El mejor arma sigue siendo Abyss II S35 de tu elemento; S35 Abyss II es difícil de farmear, así que cambia cuando seas lo suficientemente fuerte y puedas farmearlo consistentemente.",
          gear_wc_li1: "<strong>Destructor:</strong> 10% de reducción de DEF.",
          gear_wc_li2:
            "<strong>Nocturno:</strong> 3% de absorción de daño a HP. Esto está reducido en algunas mazmorras.",
          gear_wc_li3: "<strong>Mortal:</strong> 15% de CRIT DMG.",
          gear_wc_li4:
            "<strong>Restaurador (Solo Bardo):</strong> 10% de Curación.",
          gear_ac_li1:
            "<strong>Imperial:</strong> 3% de Velocidad de Movimiento.",
          gear_ac_li2: "<strong>Bendecido:</strong> 5% de Ganancia de EXP.",
          gear_ac_li3: "<strong>Bestial:</strong> 1% DMG + 1% HP.",
          gear_ac_li4: "<strong>Espinoso:</strong> 1% DMG + 1% DEF.",
          gear_mb_li1:
            "40% de bonificación al daño de habilidad del elemento de tu clase.",
          gear_ws_note:
            "Siempre consigue la piedra secreta para la habilidad de tu clase.",
          gear_ws_li1:
            "<strong>Piedra Secreta Perforante</strong> — La mejor en slot, pero cara.",
          gear_ws_li2:
            "<strong>Piedra Secreta de Lava</strong> — Más barata que la Perforante y puede farmearse en el Purgatorio Piroclástico.",
          gear_ws_li3:
            "<strong>Piedra Maestra de Clase Naranja</strong> — Úsala como sustituta antes de conseguir Lava o mejor.",
          gear_as_note1:
            "Cómpralas en el Maestro de tu clase en Navea. Serán naranjas — no te preocupes por los atributos. Súbelas al nivel 70, luego mejóralas a morado para añadir un atributo más, y estarán listas para reroll.",
          gear_as_li1: "<strong>Detail-DMG</strong> (o DMG): +5 / +4 / +3",
          gear_as_li2: "<strong>CRIT DMG:</strong> +10 / +8 / +6",
          gear_as_note2:
            "Siempre apunta a <strong>Detail-DMG +5%</strong> o al menos <strong>DMG +4%</strong>. La estrategia más común es conseguir <strong>Detail-DMG +5</strong> en la última línea, luego usar una <strong>poción de reroll DMG + Algo</strong> para apuntar a doble Detail-DMG en la piedra.",
          gear_as_note3:
            "Con suficiente economía, puedes ir más lejos y conseguir una piedra con <strong>tres estadísticas de daño</strong> — por ejemplo: <em>El DMG causado aumenta en 6% / DMG +3% / Detail-DMG +5%</em>.",
          gear_costume_note:
            "<strong>Importante:</strong> Siempre aplica una <strong>Carta Premium / Super Premium</strong> a la carta azul comprada de la Enciclopedia primero, luego usa esa carta azul con encantamientos en tu disfraz.",
          gear_costume_h5_head: "Cabeza - 12% DMG a Jefes",
          gear_costume_head_li1: "Añade Encantamiento de 10% DMG a Jefes.",
          gear_costume_head_li2:
            "Opción A: Añade Super Encantamiento de 4% HP + 2% EVA.",
          gear_costume_head_li3:
            "Opción B: Añade Super Encantamiento de 4% HP + 4% HEAL.",
          gear_costume_h5_body: "Cuerpo - 20% CRIT DMG a Jefes",
          gear_costume_body_li1: "Añade Encantamiento de 25% CRIT DMG a Jefes.",
          gear_costume_body_li2:
            "Añade Super Encantamiento de 4% DMG + 2% CRIT.",
          gear_costume_h5_face:
            "Cara - Elige lo que Más Necesites (7% DMG / 7% SPD / 7% CRIT)",
          gear_costume_face_li1: "Añade Encantamiento de Clase.",
          gear_costume_face_li2:
            "Opción A: Añade Super Encantamiento de 4% DMG + 2% CRIT.",
          gear_costume_face_li3:
            "Opción B: Añade Super Encantamiento de 4% DMG + Reducir 4% DMG Recibido.",
          gear_costume_h5_back:
            "Espalda - Prioridad de 8% Velocidad de Movimiento. De lo contrario, Elige lo que Más Necesites (7% DMG / 7% SPD / 7% CRIT)",
          gear_costume_back_li1:
            "Añade Encantamiento de Velocidad de Movimiento.",
          gear_costume_back_li2: "Añade Super Encantamiento de 4% DMG + 4% HP.",
          gear_costume_h5_weapon: "Arma - 12% DMG de Habilidad Elemental",
          gear_costume_weapon_li1: "Añade Encantamiento de Clase.",
          gear_costume_weapon_li2:
            "Añade Super Encantamiento de 4% DMG + 2% CRIT.",
          modal_boost_title: "Aumenta tu daño",
          modal_boost_intro:
            "Esta guía se enfoca en formas prácticas de aumentar tu daño general.",
          boost_back_strike: "Golpe por la Espalda",
          boost_back_strike_p1:
            "Golpe por la Espalda significa atacar enemigos por detrás. Hacer esto otorga un 50% de daño amplificado.",
          boost_back_strike_p2:
            "Siempre que sea posible, reposiciónate para estar detrás del objetivo y mantener este bonus.",
          boost_jump_casting: "Lanzamiento en Salto",
          boost_jump_p1:
            "El Lanzamiento en Salto es una mecánica de combate en la que saltas y luego lanzas tus habilidades. Esto ayuda a cancelar o acortar muchas animaciones que normalmente te detendrían.",
          boost_jump_p2:
            "También intercala ataques básicos entre habilidades, lo que aumenta tu daño total con el tiempo.",
          boost_amp_sources: "Fuentes de Daño Amplificado",
          boost_amp_intro:
            "Lista de referencia de fuentes comunes que pueden aumentar tu daño amplificado en combate.",
          modal_dungeon_title: "Ubicación de Aparición del Eidolon",
          modal_dungeon_note:
            "<strong>Nota:</strong> Los Eidolons no listados aquí pueden obtenerse en la tienda de Puntos de Lealtad, comprando a otros jugadores, por la Casa de Subastas, jugando Paragon o en eventos del juego.",
        },
        de: {
          nav_guides: "Guides ▾",
          nav_class_guides: "Klassen-Guides ▾",
          btn_what_is: "Was ist",
          btn_eidolon_leveling: "Eidolon leveln",
          btn_gear_guide: "Ausrüstungs-Guide",
          btn_boost_damage: "Schaden erhöhen",
          btn_spawn_location: "Eidolon-Fundorte",
          btn_best_eidolons: "Beste Eidolons",
          btn_useful_links: "Nützliche Links",
          btn_close: "Schließen",
          search_placeholder: "Nach Eidolon, Kombination oder Bonus suchen...",
          modal_best_eidolons_title: "Beste Eidolons",
          modal_best_eidolons_warning_label: "Veraltete Liste:",
          modal_best_eidolons_warning_text:
            " Diese Informationen stammen aus Juli 2024 und spiegeln möglicherweise nicht mehr die aktuell besten Optionen wider.",
          modal_best_eidolons_legend: "= Hervorragend mit Eidolon-Symbol",
          modal_best_eidolons_footer:
            "Ich weiß nicht, wem diese Information zugeschrieben werden sollte. Falls es deine ist und du eine Erwähnung möchtest, kontaktiere mich auf Discord.",
          section_universal: "Universelle Eidolons",
          section_dark: "Dunkle Eidolons",
          section_holy: "Heilige Eidolons",
          section_flame: "Flammen-Eidolons",
          section_storm: "Sturm-Eidolons",
          section_ice: "Eis-Eidolons",
          section_lightning: "Blitz-Eidolons",
          section_physical: "Physische Eidolons",
          modal_useful_links_title: "Nützliche Links",
          modal_useful_links_intro: "Community-Guides und Ressourcen.",
          modal_class_guide_title: "Klassen-Guides",
          modal_class_guide_intro:
            "Dieses Menü ist bereit für klassenspezifische Aura Kingdom Guides.",
          modal_lucky_pack_title: "Eidolon-Glückspakete",
          modal_lucky_pack_p1:
            "Eidolon-Glückspakete werden im Eidolon-Hort in deinem Haus verwendet, um Intimität zu steigern.",
          modal_lucky_pack_p2:
            "Die durch Intimität gewonnenen Basiswerte werden auf deinen Charakter angewendet:",
          modal_lucky_pack_p3:
            "Deshalb sollten alle Eidolons mindestens auf Intimitätslevel 8 gebracht werden. Es dauert etwa 280 Pakete, um von Level 1 auf 8 zu kommen. Level 10 ist optional.",
          modal_wish_coin_title: "Eidolon-Wunschmünzen",
          modal_wish_coin_p1:
            "Wunschmünzen werden verwendet, um den Wunsch eines Eidolons zu erfüllen, ohne die geforderten Gegenstände sammeln zu müssen.",
          modal_wish_coin_p2:
            "Alle so gewonnenen Werte werden auf deinen Charakter angewendet.",
          modal_wish_coin_cost: "Kosten der Wunschmünzen pro Wunschstufe:",
          modal_wish_coin_outro:
            "Alle Eidolons sollten ihre Wünsche erfüllt haben. Das ist eine der größten Quellen für Rohwerte.",
          modal_limit_break_title: "Karten-Durchbruchgeräte",
          modal_limit_break_p1:
            "Karten-Durchbruchgeräte werden verwendet, um den Durchbruchlevel einer Karte von 1 auf 10 zu erhöhen.",
          modal_limit_break_p2:
            "Level 10 zu erreichen schaltet den <strong>Statusbonus</strong> der Karte frei, der dauerhaft auf deinen Charakter angewendet wird.",
          modal_limit_break_tier: "Benötigte Gerätestufe pro Level:",
          modal_limit_break_t1: "Level 1–3: Einfaches Durchbruchgerät",
          modal_limit_break_t2: "Level 4–7: Mittleres Durchbruchgerät",
          modal_limit_break_t3: "Level 7–10: Fortgeschrittenes Durchbruchgerät",
          modal_limit_break_outro:
            "Priorisiere das Erreichen von Level 10 bei Karten mit den stärksten Statusboni für deinen Build.",
          modal_leveling_title: "Eidolon leveln",
          modal_leveling_p1:
            "Um ein Eidolon von Level 25 auf 80 zu bringen, kannst du folgende Kristalle verwenden:",
          modal_skill_leveling_title:
            "Eidolon-Fähigkeiten leveln (Mana Starstone)",
          modal_skill_leveling_p:
            "Das Leveln der Fähigkeiten deiner Haupt-Eidolons ist sehr wichtig, da sie stärker werden und zusätzliche Buffs/Debuffs erhalten.",
          modal_skill_leveling_total: "Benötigte Mana Starstones gesamt: 6700",
          modal_gear_title: "Ausrüstungs-Guide",
          modal_gear_intro:
            "Dieser Abschnitt behandelt praktische Herstellungsprioritäten für deine Ausrüstung.",
          gear_crafting_notes: "Handwerkshinweise",
          gear_weapon_progression: "Waffenprogression nach Level",
          gear_weapon_core: "Waffenkern-Optionen",
          gear_armor_core: "Rüstungs- / Trophäen- / Zubehör-Kern-Optionen",
          gear_mount_buff: "Reittier-Buff",
          gear_weapon_stone: "Waffen-Geheimstein",
          gear_armor_stone: "Rüstungs-Geheimstein",
          gear_armor_stone_reroll: "Beste Werte für Reroll",
          gear_costume: "Kostüm",
          gear_crafting_li1:
            "Deine Waffe sollte dein Klassenelement verwenden, da sie 20% mehr Elementarschaden verursacht.",
          gear_crafting_li2:
            "Das Rüstungselement gilt nur für das Brustteil und gibt zusätzliche Verteidigung gegen dieses Element. Dunkel-Element-Rüstung wird generell bevorzugt.",
          gear_crafting_li3:
            "Versuche, Ausrüstung mit mindestens 120%+ Qualität herzustellen. Bei Rüstungen ist es weniger wichtig, aber hohe Waffenqualität erhöht den Schaden deutlich.",
          gear_crafting_li4:
            "Die Qualitätsgrenze beträgt 130% für Orange-Ausrüstung und 140% für Gold-Ausrüstung.",
          gear_wp_note:
            "Die stärksten aktuellen Waffen werden in Abyss II für jedes Element gefarmt. Sie sind die besten Optionen bei Lv95, S15 und S35, daher benötigst du nach Lv95 generell keine anderen Waffenlinien.",
          gear_wp_li1:
            "<strong>Unter Lv95:</strong> Verwende Belohnungswaffen aus Aura und Advanced Gaia (eine von Lv1-40 und eine von Lv40-75). Sie können dich komfortabel bis Lv95 tragen.",
          gear_wp_li2:
            "<strong>Lv95:</strong> Stelle die Abyss-II-Waffe für dein Element her: Hebe (Eis), Cerberus (Feuer), Izanami (Dunkel), Michaela (Heilig), Demeter (Sturm), Hermes (Blitz). Wähle für physische Builds die Waffe, die deinen Hauptfähigkeiten den besten Boost gibt. Wenn du Abyss II noch nicht möchtest, verwende Lv95 Gold mit deinem Element oder stelle Lv90 Orange mit deinem bevorzugten Kern her.",
          gear_wp_li3:
            "<strong>S5:</strong> Wenn du noch keine Lv95-Option hast, stelle die Abyss-II-Elementwaffe her oder verwende eine S5-Gold-Waffe mit deinem Element.",
          gear_wp_li4:
            "<strong>S10:</strong> Die Lv95-Abyss-II-Waffe ist hier noch gut. Wenn du wirklich wechseln möchtest, stelle die S10-Orange-Waffe her.",
          gear_wp_li5:
            "<strong>S15:</strong> Stelle die S15-Abyss-II-Waffe für dein Element her. Dies ist deine beste Waffenlinie bis S35.",
          gear_wp_li6:
            "<strong>S35:</strong> Du kannst auf S35 Gold für dein Element wechseln, aber es ist optional. Die beste Waffe ist immer noch Abyss II S35 deines Elements; S35 Abyss II ist schwer zu farmen, also wechsle, wenn du stark genug bist und es konsistent farmen kannst.",
          gear_wc_li1: "<strong>Vernichter:</strong> 10% DEF-Reduzierung.",
          gear_wc_li2:
            "<strong>Nachtaktiv:</strong> 3% Schadensabsorption zu HP. Dies wird in einigen Dungeons geschwächt.",
          gear_wc_li3: "<strong>Tödlich:</strong> 15% CRIT DMG.",
          gear_wc_li4:
            "<strong>Restaurierer (Nur Barde):</strong> 10% Heilung.",
          gear_ac_li1:
            "<strong>Imperial:</strong> 3% Bewegungsgeschwindigkeit.",
          gear_ac_li2: "<strong>Gesegnet:</strong> 5% EXP-Gewinn.",
          gear_ac_li3: "<strong>Bestialisch:</strong> 1% DMG + 1% HP.",
          gear_ac_li4: "<strong>Stachelig:</strong> 1% DMG + 1% DEF.",
          gear_mb_li1:
            "40% Bonus auf den Elementarfähigkeitsschaden deiner Klasse.",
          gear_ws_note:
            "Hole immer den Geheimstein für deine Klassenfähigkeit.",
          gear_ws_li1:
            "<strong>Durchdringender Geheimstein</strong> — Bestes im Slot, aber teuer.",
          gear_ws_li2:
            "<strong>Lava-Geheimstein</strong> — Günstiger als Durchdringend und kann im Pyroclastic Purgatory gefarmt werden.",
          gear_ws_li3:
            "<strong>Oranger Klassen-Meister-Stein</strong> — Als Platzhalter verwenden, bis Lava oder besser verfügbar ist.",
          gear_as_note1:
            "Kaufe sie beim Klassenmeister in Navea. Sie werden Orange sein — mach dir keine Sorgen um die Werte. Bringe sie auf Level 70, dann verbessere sie auf Lila, um einen weiteren Wert hinzuzufügen, und sie sind bereit zum Reroll.",
          gear_as_li1: "<strong>Detail-DMG</strong> (oder DMG): +5 / +4 / +3",
          gear_as_li2: "<strong>CRIT DMG:</strong> +10 / +8 / +6",
          gear_as_note2:
            "Ziele immer auf <strong>Detail-DMG +5%</strong> oder mindestens <strong>DMG +4%</strong>. Die häufigste Strategie ist, <strong>Detail-DMG +5</strong> in der letzten Zeile zu erhalten, dann einen <strong>DMG + Irgendetwas Reroll-Trank</strong> zu verwenden, um doppeltes Detail-DMG auf dem Stein zu erzielen.",
          gear_as_note3:
            "Mit genug Ressourcen kannst du noch weiter gehen und einen Stein mit <strong>drei Schadenswerten</strong> erhalten — zum Beispiel: <em>Der verursachte DMG wird um 6% erhöht / DMG +3% / Detail-DMG +5%</em>.",
          gear_costume_note:
            "<strong>Wichtig:</strong> Wende zuerst immer eine <strong>Premium / Super Premium Karte</strong> auf die blaue Karte aus der Enzyklopädie an, dann verwende diese blaue Karte mit Verzauberungen auf deinem Kostüm.",
          gear_costume_h5_head: "Kopfstück - 12% DMG gegen Bosse",
          gear_costume_head_li1: "Füge eine 10% Boss-DMG-Verzauberung hinzu.",
          gear_costume_head_li2:
            "Option A: Füge eine Super-Verzauberung mit 4% HP + 2% EVA hinzu.",
          gear_costume_head_li3:
            "Option B: Füge eine Super-Verzauberung mit 4% HP + 4% HEAL hinzu.",
          gear_costume_h5_body: "Körper - 20% CRIT DMG gegen Bosse",
          gear_costume_body_li1:
            "Füge eine 25% Boss-CRIT-DMG-Verzauberung hinzu.",
          gear_costume_body_li2:
            "Füge eine Super-Verzauberung mit 4% DMG + 2% CRIT hinzu.",
          gear_costume_h5_face:
            "Gesicht - Wähle, was du am meisten brauchst (7% DMG / 7% SPD / 7% CRIT)",
          gear_costume_face_li1: "Füge eine Klassenverzauberung hinzu.",
          gear_costume_face_li2:
            "Option A: Füge eine Super-Verzauberung mit 4% DMG + 2% CRIT hinzu.",
          gear_costume_face_li3:
            "Option B: Füge eine Super-Verzauberung mit 4% DMG + Reduziere 4% erlittenen DMG hinzu.",
          gear_costume_h5_back:
            "Rücken - Priorität auf 8% Bewegungsgeschwindigkeit. Ansonsten wähle, was du am meisten brauchst (7% DMG / 7% SPD / 7% CRIT)",
          gear_costume_back_li1:
            "Füge eine Bewegungsgeschwindigkeits-Verzauberung hinzu.",
          gear_costume_back_li2:
            "Füge eine Super-Verzauberung mit 4% DMG + 4% HP hinzu.",
          gear_costume_h5_weapon: "Waffe - 12% Elementarfähigkeits-DMG",
          gear_costume_weapon_li1: "Füge eine Klassenverzauberung hinzu.",
          gear_costume_weapon_li2:
            "Füge eine Super-Verzauberung mit 4% DMG + 2% CRIT hinzu.",
          modal_boost_title: "Schaden erhöhen",
          modal_boost_intro:
            "Dieser Guide konzentriert sich auf praktische Wege, deinen Gesamtschaden zu steigern.",
          boost_back_strike: "Rückenangriff",
          boost_back_strike_p1:
            "Rückenangriff bedeutet, Feinde von hinten anzugreifen. Dadurch erhältst du 50% verstärkten Schaden.",
          boost_back_strike_p2:
            "Positioniere dich wann immer möglich hinter dem Ziel, um diesen Bonus aufrechtzuerhalten.",
          boost_jump_casting: "Sprungwirken",
          boost_jump_p1:
            "Sprungwirken ist eine Kampfmechanik, bei der du springst und dann deine Fähigkeiten einsetzt. Dies hilft, viele Animationen zu unterbrechen oder zu verkürzen, die dich normalerweise festhalten würden.",
          boost_jump_p2:
            "Es verwebt auch normale Angriffe zwischen Fähigkeiten, was deinen Gesamtschaden über die Zeit erhöht.",
          boost_amp_sources: "Quellen für verstärkten Schaden",
          boost_amp_intro:
            "Referenzliste gängiger Quellen, die deinen verstärkten Schaden im Kampf erhöhen können.",
          modal_dungeon_title: "Eidolon-Fundorte",
          modal_dungeon_note:
            "<strong>Hinweis:</strong> Eidolons, die hier nicht aufgeführt sind, können im Treue-Punkte-Shop, durch den Kauf von anderen Spielern, über das Auktionshaus, durch Paragon oder bei In-Game-Events erhalten werden.",
        },
        fr: {
          nav_guides: "Guides ▾",
          nav_class_guides: "Guides de Classe ▾",
          btn_what_is: "Qu'est-ce que",
          btn_eidolon_leveling: "Monter en niveau l'Eidolon",
          btn_gear_guide: "Guide d'Équipement",
          btn_boost_damage: "Augmenter vos dégâts",
          btn_spawn_location: "Emplacements d'Apparition",
          btn_best_eidolons: "Meilleurs Eidolons",
          btn_useful_links: "Liens utiles",
          btn_close: "Fermer",
          search_placeholder: "Rechercher par Eidolon, combo ou bonus...",
          modal_best_eidolons_title: "Meilleurs Eidolons",
          modal_best_eidolons_warning_label: "Liste obsolète :",
          modal_best_eidolons_warning_text:
            " ces informations datent de juillet 2024 et peuvent ne plus refléter les meilleurs choix actuels.",
          modal_best_eidolons_legend: "= Excellent avec le Symbole d'Eidolon",
          modal_best_eidolons_footer:
            "Je ne sais pas à qui attribuer ces informations. Si c'est le vôtre et que vous souhaitez une mention, contactez-moi sur Discord.",
          section_universal: "Eidolons Universels",
          section_dark: "Eidolons des Ténèbres",
          section_holy: "Eidolons Sacrés",
          section_flame: "Eidolons de Feu",
          section_storm: "Eidolons de Tempête",
          section_ice: "Eidolons de Glace",
          section_lightning: "Eidolons de Foudre",
          section_physical: "Eidolons Physiques",
          modal_useful_links_title: "Liens utiles",
          modal_useful_links_intro: "Guides et ressources communautaires.",
          modal_class_guide_title: "Guides de Classe",
          modal_class_guide_intro:
            "Ce menu est prêt pour des guides par classe d'Aura Kingdom.",
          modal_lucky_pack_title: "Packs Chanceux d'Eidolon",
          modal_lucky_pack_p1:
            "Les Packs Chanceux d'Eidolon sont utilisés dans la Tanière de l'Eidolon dans votre maison pour augmenter l'intimité.",
          modal_lucky_pack_p2:
            "Les statistiques de base obtenues en montant l'intimité sont appliquées à votre personnage :",
          modal_lucky_pack_p3:
            "C'est pourquoi tous les Eidolons devraient atteindre au moins le niveau 8 d'intimité. Il faut environ 280 packs pour passer du niveau 1 au niveau 8. Le niveau 10 est optionnel.",
          modal_wish_coin_title: "Pièces de Souhait d'Eidolon",
          modal_wish_coin_p1:
            "Les Pièces de Souhait sont utilisées pour exaucer le vœu d'un Eidolon sans avoir besoin de rassembler les objets demandés.",
          modal_wish_coin_p2:
            "Toutes les statistiques ainsi obtenues sont appliquées à votre personnage.",
          modal_wish_coin_cost: "Coût en Pièces de Souhait par niveau de vœu :",
          modal_wish_coin_outro:
            "Tous les Eidolons devraient avoir leurs vœux exaucés. C'est l'une des plus grandes sources de statistiques brutes.",
          modal_limit_break_title: "Dispositifs de Percée de Carte",
          modal_limit_break_p1:
            "Les Dispositifs de Percée de Carte sont utilisés pour augmenter le niveau de percée d'une carte de 1 à 10.",
          modal_limit_break_p2:
            "Atteindre le niveau 10 débloque le <strong>Bonus de Statut</strong> de la carte, appliqué définitivement à votre personnage.",
          modal_limit_break_tier: "Niveau de dispositif requis par niveau :",
          modal_limit_break_t1: "Niveaux 1–3 : Dispositif de Percée Basique",
          modal_limit_break_t2:
            "Niveaux 4–7 : Dispositif de Percée Intermédiaire",
          modal_limit_break_t3: "Niveaux 7–10 : Dispositif de Percée Avancé",
          modal_limit_break_outro:
            "Privilégiez le niveau 10 sur les cartes avec les Bonus de Statut les plus puissants pour votre build.",
          modal_leveling_title: "Montée en Niveau de l'Eidolon",
          modal_leveling_p1:
            "Pour monter un Eidolon du niveau 25 au niveau 80, vous pouvez utiliser les cristaux ci-dessous :",
          modal_skill_leveling_title:
            "Montée en Niveau des Compétences (Mana Starstone)",
          modal_skill_leveling_p:
            "Monter en niveau les compétences de vos Eidolons principaux est très important, car leurs compétences deviennent plus puissantes et gagnent des buffs/debuffs supplémentaires.",
          modal_skill_leveling_total:
            "Total de Mana Starstone nécessaire : 6700",
          modal_gear_title: "Guide d'Équipement",
          modal_gear_intro:
            "Cette section couvre les priorités pratiques de fabrication de votre équipement.",
          gear_crafting_notes: "Notes de Fabrication",
          gear_weapon_progression: "Progression des Armes par Niveau",
          gear_weapon_core: "Options de Noyau d'Arme",
          gear_armor_core: "Options de Noyau d'Armure / Trophée / Accessoires",
          gear_mount_buff: "Bonus de Monture",
          gear_weapon_stone: "Pierre Secrète d'Arme",
          gear_armor_stone: "Pierre Secrète d'Armure",
          gear_armor_stone_reroll: "Meilleures Statistiques à Viser (Reroll)",
          gear_costume: "Costume",
          gear_crafting_li1:
            "Votre arme doit utiliser l'élément de votre classe car elle inflige 20% de dégâts élémentaires supplémentaires.",
          gear_crafting_li2:
            "L'élément de l'armure s'applique uniquement sur la pièce de poitrine et offre une défense supplémentaire contre cet élément. L'armure de l'élément Ténèbres est généralement préférée.",
          gear_crafting_li3:
            "Essayez de fabriquer des équipements avec au moins 120%+ de qualité. C'est moins important pour l'armure, mais une haute qualité d'arme augmente les dégâts notablement.",
          gear_crafting_li4:
            "Le plafond de qualité est de 130% pour l'équipement Orange et de 140% pour l'équipement Or.",
          gear_wp_note:
            "Les armes actuelles les plus puissantes se farment dans Abyss II pour chaque élément. Elles sont les meilleurs choix à Lv95, S15 et S35, donc après Lv95 vous n'avez généralement pas besoin d'autres lignes d'armes.",
          gear_wp_li1:
            "<strong>En dessous de Lv95 :</strong> Utilisez les armes de récompense d'Aura et de Gaia Avancé (une de Lv1-40 et une de Lv40-75). Elles peuvent vous porter confortablement jusqu'à Lv95.",
          gear_wp_li2:
            "<strong>Lv95 :</strong> Fabriquez l'arme Abyss II pour votre élément : Hebe (Glace), Cerberus (Feu), Izanami (Ténèbres), Michaela (Saint), Demeter (Tempête), Hermes (Foudre). Pour les builds physiques, choisissez l'arme qui offre le meilleur boost à vos compétences principales. Si vous ne voulez pas encore Abyss II, utilisez l'or Lv95 avec votre élément ou fabriquez l'orange Lv90 avec votre noyau préféré.",
          gear_wp_li3:
            "<strong>S5 :</strong> Si vous n'avez toujours pas d'option Lv95, fabriquez l'arme élémentaire Abyss II ou utilisez une arme en or S5 avec votre élément.",
          gear_wp_li4:
            "<strong>S10 :</strong> L'arme Abyss II Lv95 est toujours bonne ici. Si vous voulez vraiment changer, fabriquez l'arme orange S10.",
          gear_wp_li5:
            "<strong>S15 :</strong> Fabriquez l'arme Abyss II S15 pour votre élément. C'est votre meilleure ligne d'arme jusqu'à S35.",
          gear_wp_li6:
            "<strong>S35 :</strong> Vous pouvez passer à l'or S35 pour votre élément, mais c'est optionnel. La meilleure arme est toujours Abyss II S35 de votre élément ; S35 Abyss II est difficile à farmer, alors changez quand vous êtes assez fort et pouvez le farmer régulièrement.",
          gear_wc_li1:
            "<strong>Destructeur :</strong> 10% de réduction de DEF.",
          gear_wc_li2:
            "<strong>Nocturne :</strong> 3% d'absorption de dégâts en HP. Ceci est réduit dans certains donjons.",
          gear_wc_li3: "<strong>Mortel :</strong> 15% de CRIT DMG.",
          gear_wc_li4:
            "<strong>Restaurateur (Barde uniquement) :</strong> 10% de Soin.",
          gear_ac_li1:
            "<strong>Impérial :</strong> 3% de Vitesse de Déplacement.",
          gear_ac_li2: "<strong>Béni :</strong> 5% de Gain d'EXP.",
          gear_ac_li3: "<strong>Bestial :</strong> 1% DMG + 1% HP.",
          gear_ac_li4: "<strong>Épineux :</strong> 1% DMG + 1% DEF.",
          gear_mb_li1:
            "40% de bonus aux dégâts de compétence élémentaire de votre classe.",
          gear_ws_note:
            "Obtenez toujours la pierre secrète pour la compétence de votre classe.",
          gear_ws_li1:
            "<strong>Pierre Secrète Perçante</strong> — La meilleure dans son emplacement, mais chère.",
          gear_ws_li2:
            "<strong>Pierre Secrète de Lave</strong> — Moins chère que la Perçante et peut être farmée dans le Purgatoire Pyroclastique.",
          gear_ws_li3:
            "<strong>Pierre Maître de Classe Orange</strong> — À utiliser comme remplaçante avant d'obtenir Lave ou mieux.",
          gear_as_note1:
            "Achetez-les chez le Maître de votre classe à Navea. Elles seront orange — ne vous inquiétez pas des statistiques. Montez-les au niveau 70, puis améliorez-les en violet pour ajouter une statistique supplémentaire, et elles seront prêtes pour le reroll.",
          gear_as_li1: "<strong>Detail-DMG</strong> (ou DMG) : +5 / +4 / +3",
          gear_as_li2: "<strong>CRIT DMG :</strong> +10 / +8 / +6",
          gear_as_note2:
            "Visez toujours <strong>Detail-DMG +5%</strong> ou au moins <strong>DMG +4%</strong>. La stratégie la plus courante est d'obtenir <strong>Detail-DMG +5</strong> sur la dernière ligne, puis d'utiliser une <strong>potion de reroll DMG + Quelque chose</strong> pour viser le double Detail-DMG sur la pierre.",
          gear_as_note3:
            "Avec assez d'économie, vous pouvez aller plus loin et obtenir une pierre avec <strong>trois statistiques de dégâts</strong> — par exemple : <em>Les DMG causés augmentent de 6% / DMG +3% / Detail-DMG +5%</em>.",
          gear_costume_note:
            "<strong>Important :</strong> Appliquez toujours une <strong>Carte Premium / Super Premium</strong> à la carte bleue achetée dans l'Encyclopédie d'abord, puis utilisez cette carte bleue avec des enchantements sur votre costume.",
          gear_costume_h5_head: "Coiffe - 12% DMG contre les Boss",
          gear_costume_head_li1:
            "Ajoutez un Enchantement de 10% DMG contre les Boss.",
          gear_costume_head_li2:
            "Option A : Ajoutez un Super Enchantement de 4% HP + 2% EVA.",
          gear_costume_head_li3:
            "Option B : Ajoutez un Super Enchantement de 4% HP + 4% HEAL.",
          gear_costume_h5_body: "Corps - 20% CRIT DMG contre les Boss",
          gear_costume_body_li1:
            "Ajoutez un Enchantement de 25% CRIT DMG contre les Boss.",
          gear_costume_body_li2:
            "Ajoutez un Super Enchantement de 4% DMG + 2% CRIT.",
          gear_costume_h5_face:
            "Visage - Choisissez ce dont vous avez le plus besoin (7% DMG / 7% SPD / 7% CRIT)",
          gear_costume_face_li1: "Ajoutez un Enchantement de Classe.",
          gear_costume_face_li2:
            "Option A : Ajoutez un Super Enchantement de 4% DMG + 2% CRIT.",
          gear_costume_face_li3:
            "Option B : Ajoutez un Super Enchantement de 4% DMG + Réduire 4% DMG reçus.",
          gear_costume_h5_back:
            "Dos - Priorité à 8% Vitesse de Déplacement. Sinon, Choisissez ce dont vous avez le plus besoin (7% DMG / 7% SPD / 7% CRIT)",
          gear_costume_back_li1:
            "Ajoutez un Enchantement de Vitesse de Déplacement.",
          gear_costume_back_li2:
            "Ajoutez un Super Enchantement de 4% DMG + 4% HP.",
          gear_costume_h5_weapon: "Arme - 12% DMG de Compétence Élémentaire",
          gear_costume_weapon_li1: "Ajoutez un Enchantement de Classe.",
          gear_costume_weapon_li2:
            "Ajoutez un Super Enchantement de 4% DMG + 2% CRIT.",
          modal_boost_title: "Augmenter vos dégâts",
          modal_boost_intro:
            "Ce guide se concentre sur les moyens pratiques d'augmenter vos dégâts globaux.",
          boost_back_strike: "Frappe dans le Dos",
          boost_back_strike_p1:
            "La Frappe dans le Dos consiste à attaquer les ennemis par derrière. Cela accorde <strong>50% de dégâts amplifiés</strong>.",
          boost_back_strike_p2:
            "Chaque fois que possible, repositionnez-vous pour rester derrière la cible et maintenir ce bonus.",
          boost_jump_casting: "Lancement en Saut",
          boost_jump_p1:
            "Le Lancement en Saut est une mécanique de combat où vous sautez puis lancez vos compétences. Cela aide à annuler ou raccourcir de nombreuses animations qui vous immobiliseraient normalement.",
          boost_jump_p2:
            "Il intercale également des attaques de base entre les compétences, ce qui augmente vos dégâts totaux au fil du temps.",
          boost_amp_sources: "Sources de Dégâts Amplifiés",
          boost_amp_intro:
            "Liste de référence des sources courantes pouvant augmenter vos dégâts amplifiés en combat.",
          modal_dungeon_title: "Emplacements d'Apparition des Eidolons",
          modal_dungeon_note:
            "<strong>Note :</strong> Les Eidolons non listés ici peuvent être obtenus dans la boutique de Points de Fidélité, en achetant à d'autres joueurs, via la Maison des Ventes, en jouant à Paragon ou lors d'événements en jeu.",
        },
      };

      function applyLang(lang) {
        const t = TRANSLATIONS[lang] || TRANSLATIONS.en;
        document.querySelectorAll("[data-i18n]").forEach((el) => {
          const key = el.getAttribute("data-i18n");
          if (t[key] !== undefined) el.textContent = t[key];
        });
        document.querySelectorAll("[data-i18n-html]").forEach((el) => {
          const key = el.getAttribute("data-i18n-html");
          if (t[key] !== undefined) el.innerHTML = t[key];
        });
        document.querySelectorAll("[data-i18n-placeholder]").forEach((el) => {
          const key = el.getAttribute("data-i18n-placeholder");
          if (t[key] !== undefined) el.setAttribute("placeholder", t[key]);
        });
        document.querySelectorAll(".lang-btn").forEach((btn) => {
          const isActive = btn.getAttribute("data-lang") === lang;
          btn.classList.toggle("active", isActive);
        });
        localStorage.setItem("eidolonLang", lang);
      }

      // Mutual exclusion for details menus
      const infoMenus = Array.from(document.querySelectorAll(".info-menu"));
      infoMenus.forEach((menu) => {
        menu.addEventListener("toggle", () => {
          if (menu.open) {
            infoMenus.forEach((other) => {
              if (other !== menu && other.open) other.open = false;
            });
          }
        });
      });

      // Lang selector
      const langSelector = document.querySelector(".lang-selector");
      langSelector.querySelectorAll(".lang-btn").forEach((btn) => {
        btn.addEventListener("click", (e) => {
          e.stopPropagation();
          if (!langSelector.classList.contains("open")) {
            langSelector.classList.add("open");
          } else {
            applyLang(btn.getAttribute("data-lang"));
            langSelector.classList.remove("open");
          }
        });
      });
      document.addEventListener("click", (e) => {
        if (!langSelector.contains(e.target)) {
          langSelector.classList.remove("open");
        }
      });

      applyLang(localStorage.getItem("eidolonLang") || "en");
'@

# Insert JS before the closing </script> tag (which is right before </body>)
$html = $html -replace '(      q\.addEventListener\("input")', "$jsI18n`n`n      `$1"

Set-Content "index.html" $html -Encoding UTF8 -NoNewline
Write-Output "✅ index.html updated"
