# SomaAí — Direção de Arte e UX

**Versão:** 1.0 · Outubro/2026  
**Princípio:** *Sem sustos no caixa.* Uma marca calorosa, números grandes e decisões óbvias.

---

## 1. Marca e logotipo

### Conceito
“SomaAí” é somar + aí: a soma que acontece no lugar onde a pessoa está. O símbolo é uma **cesta orgânica** (curvas generosas, alça assimétrica) com um **selo “+”** no canto superior direito. A cesta representa a compra; o selo, a economia que se acumula. Nada de carrinho de supermercado genérico.

### Construção
- Símbolo em quadrado arredondado (raio 30%): fundo esmeralda `#0E9F6E`, cesta em creme `#FBFBF7`, selo “+” em lima `#C8F169` com “+” em verde escuro `#07603F`.
- Wordmark “SomaAí” em **Plus Jakarta Sans ExtraBold**, com o acento do “í” transformado em uma **moeda/etiqueta lima** levemente inclinada.
- Área de respiro: altura do “S” em todos os lados. Tamanho mínimo digital: 24 px de altura do símbolo.
- Versões: principal (símbolo + wordmark), horizontal, só símbolo (app icon/favicon) e monocromática (verde escuro sobre creme ou creme sobre verde).
- App icon adaptativo: fundo esmeralda, cesta creme no centro seguro (66%), sem wordmark.

### Paleta (proporção 60/25/10/4/1)
| Token | Hex | Uso |
|---|---|---|
| Creme | `#FBFBF7` | Fundo dominante, respiro |
| Branco | `#FFFFFF` | Cartões, campos, superfícies |
| Esmeralda | `#0E9F6E` | Ações primárias, confirmação |
| Esmeralda claro | `#12B76A` | Estados hover/ativos, gráficos |
| Verde escuro | `#07603F` | Texto de marca, títulos, números |
| Lima | `#C8F169` | Economia, conquistas, selo “+” |
| Âmbar | `#F5A524` | Ofertas, atenção, alerta gentil |
| Tinta | `#101828` | Texto principal |
| Cinza | `#667085` | Texto secundário |
| Linha | `#EAECF0` | Bordas e divisores |

**Regra:** lima nunca recebe texto branco; esmeralda escuro sobre creme tem contraste > 7:1.

### Tipografia
**Plus Jakarta Sans** (Google Fonts). Geométrica, humanista, amigável — não infantil.
- Display: 32–40 / 1.1 · w800
- Título: 22–24 / 1.25 · w700
- Corpo: 15–16 / 1.45 · w500
- Rótulo: 11 / 1.2 · w700 · tracking 0.8–1.2
- Preços: 40–48 / 1.0 · w800 · **numerais tabulares**
- Botões: 16 / 1.0 · w700

### Tom de voz
Curto, direto e acolhedor. “Vamos somar as compras?”, “Sem sustos no caixa.”, “Achamos mais barato pertinho de você.” Sem jargão financeiro, sem culpa, sem urgência falsa.

---

## 2. Splash

- Fundo verde escuro `#07603F` de ponta a ponta (igual ao `launch_background` nativo, para não haver flash).
- Brilho radial lima muito sutil no centro (8% de opacidade), como um sol de mercado aberto.
- Composição vertical: símbolo em tile creme (96×96, raio 30), wordmark branco, tagline “Sem sustos no caixa.” em creme 70%.
- Movimento: símbolo entra com escala 0.92 → 1 e fade em 500 ms; wordmark sobe 8 px e aparece em 300 ms; tagline entra por último. Nada de loop.
- Duração total ~1,2 s; com “reduzir movimento”, apenas fade de 200 ms.
- Sai com fade para o Dashboard; nunca mostra spinner na splash.

---

## 3. Dashboard (tela inicial)

- Fundo creme; saudação “Olá, Eduardo! 👋” em verde escuro + subtítulo “Sem sustos no caixa.”
- **Hero card** esmeralda com círculos orgânicos mais claros, rótulo “NOVA COMPRA”, título “Vamos somar as compras?” e CTA branco “Iniciar nova compra” com ícone de câmera.
- **Bento:** cartão branco “Gastos em Outubro” com número 40 px; cartão verde-menta “Você economizou” com lima e número esmeralda.
- **Últimas compras:** cartões brancos, ícone de loja em tile menta, nome, “Ontem • 12 itens”, valor à direita e economia em verde. “Ver todas →” em esmeralda.
- Tudo em 20 px de margem, 12 px de gutter, cartões com raio 28–34 e sombra quase invisível (0 8 24, 4%).
- Alvos de toque ≥ 48 px; nenhum texto abaixo de 11 px.

---

## 4. Scanner com vidro fosco

### Estrutura
1. **Câmera em tela cheia**, sem moldura branca.
2. **Topo:** gradiente preto 45% → transparente; botão fechar circular, chip com logo + “SomaAí”, lanterna e alertas em vidro escuro.
3. **Janela de leitura:** retângulo 16:10 com cantos raio 28, contorno branco 70% de 2 px; linha de varredura lima de 2 px com glow, subindo e descendo em 1,8 s. Texto de apoio: “Aponte para a etiqueta”.
4. **Painel inferior em vidro:** blur 28, branco 78%, borda branca 60% de 1 px, raio 34 no topo, sombra verde 18%. Sobre cenas muito claras, um tint esmeralda de 6% garante leitura.
   - Rótulo “SALDO TOTAL” em 11 px, tracking 1.2, cinza-esmeralda.
   - Valor 44 px, w800, verde escuro, numerais tabulares.
   - Pill “1 item” em lima tint com cesta.
   - Três ações em tiles brancos de 56 px (Voz, Manual, Carrinho), ícones de 22 px; o carrinho mostra badge esmeralda com a quantidade.
   - CTA “Finalizar compra” em verde escuro, 56 px, ícone de check.
5. **Feedback de leitura:** flash lima de 120 ms na janela, haptic leve, toast “Leite • R$ 4,49” e o valor sobe com contagem animada de 200 ms.

### Acessibilidade
- Fallback sólido (sem blur) quando o aparelho não suporta ou com “reduzir transparência”.
- Contraste do valor e dos botões independente da imagem da câmera.
- Textos de estado anunciados por leitor de tela; a linha de varredura pausa com movimento reduzido.
- Modo escuro do sistema não altera o scanner: o vidro é sempre escuro no topo e claro no painel.

---

## 5. Pop-up de oferta da comunidade

Um cartão que **sobe por cima do scanner**, sem interromper a compra.

- Largura: tela − 32 px; raio 24; fundo âmbar tint `#FFF6E5`; borda âmbar 25%; barra de 4 px âmbar à esquerda.
- Cabeçalho: ícone de loja + “Achamos mais barato” (11 px, w700, âmbar escuro) e botão “×”.
- Produto em 15 px w700; comparação lado a lado:
  - “Aqui: R$ 9,90” com preço antigo riscado em cinza;
  - “No Assaí: R$ 7,49” em 24 px w800 verde escuro.
- Pill lima “− R$ 2,41” + meta “1,2 km • há 2 h”.
- Ações: “Ver oferta” (esmeralda, 48 px) e “Agora não” (texto).
- Auto-dismiss em 8 s com uma hairline de progresso; arrastar para baixo fecha. **Uma oferta por EAN por sessão** — nada de repetir.
- Entrada: slide-up 24 px + fade em 240 ms; saída em 180 ms. Leitor de tela anuncia “Oferta mais barata encontrada” em live region.
- Sem contagem regressiva agressiva, sem “últimas unidades”. A economia é o herói.

---

## 6. Tela “Meu Carrinho”

- Modal de altura 92% ou rota própria; fundo creme; topo com “Meu carrinho”, “3 itens” e “Limpar” (vermelho suave, com confirmação).
- Lista de cartões brancos:
  - nome do produto + selo de origem (“Câmera” ou “Manual”);
  - preço unitário em cinza;
  - stepper − quantidade + em tiles de 44 px;
  - subtotal à direita em verde escuro, numerais tabulares.
- Resumo fixo no rodapé: “Subtotal”, “Economia da sessão” em lima, “Total” em 24 px e CTA “Finalizar compra”.
- Estado vazio: ilustração de cesta com folha, título “Seu carrinho está vazio” e botão “Escanear etiqueta”.
- Deslizar para excluir com confirmação; haptic ao mudar quantidade; textos no singular/plural corretos (“1 item” / “2 itens”).

---

## 7. Movimento e acessibilidade

| Elemento | Duração | Curva |
|---|---|---|
| Toque/ripple | 120 ms | easeOut |
| Troca de aba | 180 ms | easeOutCubic |
| Bottom sheet | 240 ms | easeOutCubic |
| Pop-up de oferta | 240 ms (entrada) / 180 ms (saída) | easeOutCubic |
| Contagem do saldo | 200 ms | easeOut |

- Haptics: leve ao ler item, médio ao finalizar, nunca em loop.
- “Reduzir movimento”: desliga linha de varredura, contagens e slides; mantém fades curtos.
- Fonte do sistema até 130% sem truncar; números e botões crescem juntos.
- Contraste AA em todos os textos; informação nunca só por cor (ícone + texto).
- Alvos ≥ 48×48; espaçamento mínimo de 8 px entre ações.
- Instruções em voz ativa: “Toque em Manual para digitar o produto”, “Confirme o mercado”.
- Nenhuma ação destrutiva sem confirmação; nenhuma armadilha de rolagem.

---

## 8. Tokens de handoff

- **Raios:** 14 (chips), 20 (campos/ações), 28 (cartões), 34 (sheets/painel).
- **Espaçamento:** 4 / 8 / 12 / 16 / 20 / 24 / 32.
- **Sombra:** `0 8 24 rgba(16,24,40,0.06)`; elevação do painel `0 18 40 rgba(7,96,63,0.18)`.
- **Vidro:** blur 28; fundo `rgba(255,255,255,0.78)`; borda `rgba(255,255,255,0.60)`; tint esmeralda 6% quando necessário.
- **Ícones:** traço 2 px, cantos arredondados, estilo duotone nos ativos.
- **Grid:** 8 pt; margem 20; gutter 12.

> A implementação atual já usa estes tokens em `lib/core/theme/app_theme.dart` e no logotipo em `lib/core/widgets/somaai_logo.dart`.
