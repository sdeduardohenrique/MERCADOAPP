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
   *O hash esperado do último commit inclui `83baba6` (integração híbrida TomTom v3 + PostGIS) e o commit dos 4 pilares de localização/visitante. Confira `git log -3 --oneline`.*
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
2. Execute a suíte completa de testes (110 testes automatizados):
   ```bash
   flutter test
   ```
   *Todos os 110 testes devem passar sem falhas.*

---

## 4. Compilação de APK Release (Ferramenta Automatizada)

Para gerar o APK release otimizado para ARM64 com as chaves injetadas via `--dart-define` lidas do `.env`:

1. Execute o script automatizado de build:
   ```bash
   ./tools/build_apk.sh
   ```
2. O artefato gerado será `somaai-arm64-release.apk` (tamanho esperado: ~42.7 MB).

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

---

## 6. Próximos Passos Imediatos para a Nova Máquina

Assim que o ambiente estiver validado e os testes passarem, pergunte ao usuário qual das seguintes frentes pendentes ele deseja atacar:
1. **Pilar de Localização Global (`location_provider`):** Isolamento de alta precisão com `Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best)` e logs de auditoria de coordenadas.
2. **Controle Dinâmico de Raio:** Adição de ChoiceChips (1 km, 3 km, 5 km, 10 km) na UI de busca manual e repasse do parâmetro de raio para a TomTom.
3. **Modo Visitante 100% Offline:** Dialog de boas-vindas pedindo apelido e isolamento estrito de compras/carrinho no storage local (sem comunicação com o Supabase).
4. **Bloqueio da Comunidade para Visitantes:** Tela de bloqueio (Empty State com ícone de cadeado e CTA de cadastro) na aba Comunidade.
5. **Consolidação de RLS de Isolamento:** Execução dos scripts de hardening em `tools/rls_isolation.sql`.

Aguarde o comando do usuário.
