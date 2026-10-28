# 🚀 Prompt de Retomada Automática — SomaAí (Cross-Machine Continuity)

> **Instrução para a nova máquina:** Cole este texto integralmente no OpenCode logo após clonar o repositório ou abrir a pasta do projeto. Este documento contém o manifesto completo para configurar o ambiente, compilar o APK, restaurar o estado exato e continuar o desenvolvimento sem perda de contexto.

---

## 🛑 Instrução Inicial ao Agente

Você é o Arquiteto de Sistemas Sênior e Engenheiro Mobile responsável pelo **SomaAí** (Flutter + Riverpod + Supabase + TomTom Places). O seu objetivo **não é recriar o projeto**, mas sim **retomar o desenvolvimento exatamente de onde parou**, garantindo que o build funcione na primeira tentativa.

Execute as etapas abaixo em ordem estrita antes de aceitar qualquer modificação ou interagir com o usuário:

---

## 1. Verificação do Estado Atual & Repositório

1. Valide o diretório de trabalho atual: `/home/supervisoreduardoalves/Público/MERCADOAPP` (ou equivalente na máquina nova).
2. Verifique o último commit executado no repositório local:
   ```bash
   git log -1 --oneline
   ```
   *O último commit em `origin/main` é `802b450`. O módulo Minhas Listas 2.0 (4 abas, múltiplas listas, setores, checklist ativo e sync Supabase), o recibo compartilhável e o onboarding de mercado/orçamento estão no commit local mais recente, ainda não enviado ao `origin`. Confira `git log -3 --oneline` e `git status`.*
3. Leia integralmente o arquivo `PROJECT_STATUS.md` na raiz para absorver o histórico arquitetural, métricas e pendências.

---

## 2. Configuração de Ambiente & Dependências (`pubspec.yaml`)

1. Restaure as dependências do projeto Flutter:
   ```bash
   flutter pub get
   ```
2. Verifique se o arquivo `.env` existe na raiz do projeto (ele não é versionado por segurança). Se não existir, crie-o a partir do `.env.example`:
   ```bash
   cp .env.example .env
   ```
   *(Nota: A chave da TomTom `TOMTOM_API_KEY` e o Google Web Client ID devem ser injetados pelo usuário ou preenchidos no `.env` para testes reais no dispositivo).*

---

## 3. Validação Estática e Testes Automatizados

Antes de compilar qualquer binário ou tocar em código, garanta que a suíte de testes e o linter estejam 100% verdes:

1. Execute a análise estática para garantir zero erros ou warnings:
   ```bash
   dart analyze lib test
   ```
2. Execute a suíte completa de testes (153 testes automatizados):
   ```bash
   flutter test
   ```
   *Todos os 153 testes devem passar sem falhas.*

---

## 4. Compilação de APK Release (Ferramenta Automatizada)

Para gerar o APK release otimizado para ARM64 com as chaves injetadas via `--dart-define` lidas do `.env`:

1. Execute o script automatizado de build:
   ```bash
   ./tools/build_apk.sh
   ```
2. O artefato gerado será `somaai-arm64-release.apk` (tamanho esperado: ~43.2 MB, versão `1.0.0+2005`).
   SHA-256 do build atual: `73d97ec2840d47f78e72951183f1d7b57a3906fec46ac8c84637a1f20f0d9d85`.

---

## 5. Resumo do Estado Arquitetural Atual (Contexto)

- **Módulo de Mercados Híbrido:**
  - Consulta inicial PostGIS (raio de 100 m) com sugestão exata ("Identificamos que você está no [mercado]").
  - Fallback TomTom Places Search API v3 (Orbis) acionado apenas quando a base interna está vazia no raio especificado.
  - Upsert silencioso via RPC `upsert_mercado_by_external_id` (migration `007_mercados_tomtom.sql` já aplicada no Supabase remoto).
  - Selo visual "TomTom" nos tiles da listagem e deduplicação por ID externo.
- **Autenticação & Sessão:**
  - Suporte a Email/Senha e Google OAuth (com `serverClientId` configurado).
  - Aba Perfil com botão de Sair ("Sair da conta") que executa `SupabaseService.signOut()` e invalida/reseta todos os providers do Riverpod (`purchaseHistoryProvider`, `cartProvider`, `userProfileProvider`, etc.).
  - Remoção completa de dados demo estáticos (o histórico começa limpo com persistência local em SharedPreferences).
- **Perfil Editável (nome + avatar):**
  - Lápis/card do Perfil abre `EditProfileSheet` (BottomSheet arredondado) com nome pré-preenchido, avatar com câmera, e-mail somente leitura e botões Cancelar/Salvar.
  - `ProfileController.updateProfile()` grava `profiles.display_name` + metadados `full_name`, faz upload da foto no bucket `avatars` (`{user_id}/...`) e invalida `userProfileProvider` — card e saudação do Dashboard atualizam na hora.
  - Migration `008_profile_avatars.sql` aplicada no remoto: backfill de perfis, trigger `handle_new_user`, policy de INSERT e bucket `avatars` com isolamento por usuário.
- **Hub de Ferramentas da Nova Compra:**
  - Barra inferior enxuta (somente “Ler Etiquetas (Câmera)” e “Finalizar Compra”) e FAB verde “+” abrindo o BottomSheet “Ferramentas de Compra” (Manual, Voz, Calculadora de Promoções e Comparador de Custo).
  - `PromotionCalculatorModal` cobre Atacado (quantidade mínima + preço promocional) e Leve X/Pague Y (preço unitário rateado), com total e economia em tempo real.
  - `UnitCostComparatorModal` converte g/kg e ml/L, destaca a embalagem “Mais Econômico!” e adiciona o vencedor ao `cartProvider`; a matemática pura vive em `domain/purchase_tools.dart` e tem 13 testes em `test/purchase_tools_test.dart`.
- **Minhas Listas 2.0 (múltiplas listas + checklist ativo):**
  - `AppShell` com 4 abas (`Início`, `Minhas Listas`, `Comunidade`, `Perfil`); o atalho compacto do Dashboard abre a aba de listas via `shellTabProvider`.
  - `ShoppingListsScreen`/`ShoppingListDetailScreen`: múltiplas listas por ocasião, ícone personalizável, progresso, contador “X de Y itens” e estimativa; itens agrupados por Hortifrúti, Açougue & Peixaria, Laticínios & Frios, Limpeza & Lavanderia, Mercearia & Mantimentos, Padaria & Matinais e Outros, com quantidade/unidade, preço opcional e riscado animado.
  - “Iniciar Compra no Mercado” usa o mesmo onboarding da Home (`prepareNewPurchase`): pergunta primeiro o mercado/GPS e depois o orçamento; fechar a seleção de mercado cancela o início. Depois define a lista ativa; `ActiveShoppingListBar` expansível no topo da compra mostra “Lista: … (X/Y itens no carrinho)” e os pendentes. `CartNotifier.addItem` chama `markBoughtMatching`; limpar o carrinho/finalizar limpa a lista ativa.
  - Visitante em `SharedPreferences` (`somaai.shopping_lists.v2.guest`, com migração da lista antiga); autenticado em cache local + `listas_compras`/`itens_lista` (migration `010`, RLS por `user_id`, triggers e índices). A tabela `pre_shopping_list_items` é mantida apenas como legado e não é mais usada pelo app.
  - `PurchaseShareService.buildMessage` gera o template WhatsApp exato; `share_plus 13.3.1` abre o share sheet. Botão “Compartilhar Resumo” na `PurchaseSuccessScreen` e em `PurchaseDetailScreen`.
  - `_finishPurchase` soma `_sessionSavings` + `rawOcrData['savings']` das calculadoras de promoção.
  - 16 testes em `test/shopping_lists_test.dart`; suíte total em **153**.

---

## 6. Próximos Passos Imediatos para a Nova Máquina

Assim que o ambiente estiver validado e os testes passarem, pergunte ao usuário qual das seguintes frentes pendentes ele deseja atacar:
1. **Consolidação de RLS de Isolamento:** Execução dos scripts de hardening em `tools/rls_isolation.sql`.
2. **Chave TomTom & Atribuição:** Restringir a chave no painel/Edge Function e adicionar "Powered by TomTom".
3. **Publicação:** Gerar keystore própria e preparar a Play Store (o `applicationId` já é `com.somaaiapp`).
4. **Novas frentes:** entrada por voz (`speech_to_text`) e checkout fiscal.

> **Já concluído:** os 4 pilares de localização/visitante, a edição de perfil (nome + avatar), o hub de ferramentas da Nova Compra (Calculadora de Promoções + Comparador de Custo) e o módulo **Minhas Listas 2.0** (4 abas, múltiplas listas por setor, checklist ativo com mini-barra, auto-riscar e sync Supabase) + recibo compartilhável estão implementados, testados (**153 testes**) e validados no Redmi Note 11.

Aguarde o comando do usuário.
