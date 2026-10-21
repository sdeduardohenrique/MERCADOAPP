# SomaAí — Project Status & Architecture

**Last Updated:** October 20, 2026  
**Status:** ✅ APK release ARM64 (39,5 MB) instalado no Redmi Note 11 — fluxo completo validado (entrada manual → carrinho → finalizar → histórico → Dashboard), 3 abas, R8 e câmera estáveis

---

## 📋 Project Overview

**SomaAí** — assistente de compras de supermercado com:

- Leitura de etiquetas de preço por câmera (OCR + código de barras)
- Carrinho em tempo real com total automático
- Rede de comparação de preços da comunidade (estilo Waze/Cuponomia)
- Backend Supabase com geolocalização (PostGIS)

---

## 🏗️ Arquitetura

### Stack

| Camada | Tecnologia | Versão |
|--------|------------|--------|
| Frontend | Flutter (canal stable, em `~/flutter`) | 3.47.7 |
| Estado | Riverpod | 2.6.x |
| Backend | Supabase (PostgreSQL + Realtime + Storage) | — |
| Câmera | `camera` | 0.10.x |
| OCR | `google_mlkit_text_recognition` | 0.7.0 |
| Código de barras | `google_mlkit_barcode_scanning` | 0.7.0 |
| Scanner alternativo | `mobile_scanner` | 5.x |
| Localização | `geolocator` + `permission_handler` | 11.1.0 / 11.x |
| Offline (planejado) | Drift/SQLite | 2.x |
| Animações | `flutter_animate` | 4.x |

> ⚠️ O pacote guarda-chuva `google_ml_kit` foi **removido**. Ele arrastava 11 módulos
> não usados (tradução, face, pose, digital ink, etc.), inflando o APK de 37 MB para 186 MB
> em debug. Agora só OCR + barcode são incluídos.

### Estrutura

```
lib/
├── main.dart                           # runApp imediato + BootstrapGate + handlers globais
├── core/
│   ├── bootstrap/app_bootstrap.dart    # Supabase init não-bloqueante (timeout 8s, offline-safe)
│   ├── constants/app_constants.dart    # URL + anon key do Supabase
│   ├── theme/app_theme.dart            # Design system White Theme / Bento (light/dark)
│   ├── models/
│   │   ├── cart_item.dart              # CartItem, ParsedOcrItem, ScanSource
│   │   ├── community_price.dart        # CommunityPriceAlert, Store, Product
│   │   └── purchase.dart               # Purchase + PurchaseItem (histórico local)
│   ├── services/
│   │   ├── camera_service.dart         # CameraController + streaming
│   │   ├── ml_kit_service.dart         # OCR + barcode (TextRecognizer/BarcodeScanner)
│   │   ├── price_validation_service.dart
│   │   ├── location_service.dart       # GPS + permission_handler
│   │   └── supabase_service.dart
│   ├── utils/
│   │   ├── price_parser.dart           # parser de etiquetas pt-BR
│   │   ├── ean_validator.dart          # EAN-8/13, UPC-A/E
│   │   ├── text_normalizer.dart        # normalização de texto pt-BR
│   │   └── formatters.dart             # moeda pt-BR + datas relativas (sem locale init)
│   └── widgets/somaai_logo.dart        # marca (cesta + selo de soma) e wordmark
├── features/
│   ├── providers.dart                  # barrel de providers (caminhos corrigidos)
│   ├── splash/presentation/splash_screen.dart  # splash nativa (sem fontes de rede)
│   ├── shell/presentation/app_shell.dart       # BottomNavigationBar + IndexedStack (3 abas)
│   ├── home/
│   │   ├── data/demo_purchases.dart    # histórico de demonstração (primeiro arranque)
│   │   └── presentation/
│   │       ├── home_dashboard_screen.dart      # Dashboard (CTA + Bento + últimas compras)
│   │       ├── purchase_history_screen.dart    # histórico completo + detalhe
│   │       └── providers/purchase_history_provider.dart  # persistência local + derived providers
│   ├── community/presentation/community_screen.dart  # radar de ofertas (mock estruturado)
│   ├── profile/presentation/profile_screen.dart      # perfil, stats, preferências
│   ├── scanner/
│   │   ├── domain/usecases/process_frame_use_case.dart
│   │   └── presentation/
│   │       ├── scanner_screen.dart     # câmera + painel de saldo glass + finalizar compra
│   │       ├── providers/scanner_provider.dart
│   │       └── widgets/ (camera_preview, bottom_sheet_cart)
│   ├── cart/presentation/providers/cart_provider.dart
│   └── community_alerts/
│       ├── presentation/providers/alert_preferences_provider.dart
│       └── presentation/widgets/price_alert_banner.dart
```

---

## 🗄️ Banco de Dados (Supabase)

Projeto: `vvoqamnucengagpwwozt` — `https://vvoqamnucengagpwwozt.supabase.co`

### Tabelas

| Tabela | Função | Destaques |
|--------|--------|-----------|
| `profiles` | Perfis de usuário | trust_score, total_scans |
| `stores` | Supermercados | geography(Point) PostGIS, rede |
| `products` | Catálogo | EAN único, busca full-text pt-BR |
| `community_prices` | Preços colaborativos | TTL 72h, unit_price, confirmações/disputas |
| `price_confirmations` | Validações | triggers de contagem |

### RPCs

- `find_stores_nearby(lat, lon, radius_km, limit)`
- `find_better_prices_nearby(ean, lat, lon, current_price, radius_km, limit)`
- `refresh_best_prices()`
- `expire_old_prices()`

### Observações de schema

- Triggers substituíram colunas geradas (erro `generation expression is not immutable`).
- Sem índices parciais com `now()` (erro de função não IMMUTABLE).
- RLS ativo; leitura pública de preços ativos; escrita apenas do próprio usuário.

---

## 🔧 Ambiente de Build

| Item | Caminho / Versão |
|------|------------------|
| Flutter | `~/flutter` (3.47.7) — **não usar o snap** |
| Java | `~/java/jdk-17.0.12+7` (o Java do sistema é 25 e quebra o AGP) |
| Android SDK | `~/android-sdk` (não usar `/usr/lib/android-sdk`) |
| Build-Tools | 36.0.0 (instalado em `build-tools/36.0.0-2`) |
| Platform | android-36 (em `platforms/android-36-2`) |
| NDK | **28.2.13676358 (r28c) — instalado de verdade via sdkmanager** |
| CMake | 3.22.1 |
| Gradle/AGP | via Flutter plugin (Java 17) |

### Comando de build

```bash
export JAVA_HOME=$HOME/java/jdk-17.0.12+7
export PATH=$JAVA_HOME/bin:$HOME/flutter/bin:$HOME/android-sdk/platform-tools:$PATH
export ANDROID_HOME=$HOME/android-sdk
export ANDROID_SDK_ROOT=$HOME/android-sdk

# Release ARM64 (recomendado para sideload)
flutter build apk --release --split-per-abi

# Debug (para depuração)
flutter build apk --debug --split-per-abi
```

### ⚠️ Patches em `~/.pub-cache` (não versionados)

Os plugins ML Kit publicados são antigos e incompatíveis com o AGP atual. Foram aplicados:

1. Removido `package="..."` de `google_mlkit_*/android/src/main/AndroidManifest.xml`
   (o AGP novo rejeita namespace no manifest).
2. `compileSdkVersion` alterado para **36** em `google_mlkit_*/android/build.gradle`
   (as dependências exigem API ≥ 33).

> `flutter pub cache repair` ou uma máquina nova **desfazem** esses patches.
> Se o build voltar a falhar com `Incorrect package=` ou `compileSdk 31`, reaplique.

### Skills de IA (Dart/Flutter oficiais)

Instaladas globalmente em `~/.config/opencode/skills/` (25 skills, versão oficial
do commit `6e59065` de 2026-10-19):

- **15 Dart**: `dart-add-unit-test`, `dart-build-cli-app`, `dart-collect-coverage`,
  `dart-fix-runtime-errors`, `dart-generate-test-mocks`,
  `dart-migrate-to-checks-package`, `dart-resolve-package-conflicts`,
  `dart-run-static-analysis`, `dart-setup-ffi-assets`, `dart-use-doc-examples`,
  `dart-use-ffigen`, `dart-use-path-package`, `dart-use-pattern-matching`,
  `dart-use-primary-constructors`, `dart-write-documentation`
- **10 Flutter**: `flutter-add-integration-test`, `flutter-add-widget-preview`,
  `flutter-add-widget-test`, `flutter-apply-architecture-best-practices`,
  `flutter-build-responsive-layout`, `flutter-fix-layout-issues`,
  `flutter-implement-json-serialization`, `flutter-setup-declarative-routing`,
  `flutter-setup-localization`, `flutter-use-http-package`

Cópia idêntica também em `.agents/skills/` (projeto). Repositórios oficiais:
`github.com/flutter/skills` e `github.com/dart-lang/skills`.
Atualizar com `npx skills add flutter/skills --skill '*' --agent universal`.

### Proguard

`android/app/proguard-rules.pro` contém `-dontwarn` para:

- classes de OCR de chinês/devanagari/japonês/coreano (não usadas — só Latin);
- `com.google.android.play.core.**` (split install do Play Store, não usado).

---

## 📱 APK Gerado

| Artefato | Caminho | Tamanho |
|----------|---------|---------|
| **Release ARM64** (usar este) | `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` | **39,5 MB** |
| Release ARMv7 | `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk` | 31,8 MB |
| Release x86_64 (emulador) | `build/app/outputs/flutter-apk/app-x86_64-release.apk` | 43,0 MB |
| Cópia na raiz do projeto | `somaai-arm64-release.apk` | 39,5 MB |
| Cópia no celular | `/sdcard/Download/somaai-arm64-release.apk` | 39,5 MB |
| Debug ARM64 | `build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk` | 186 MB |
| Debug universal | `build/app/outputs/flutter-apk/app-debug.apk` | 372 MB |

Assinatura: chave **debug** (suficiente para testes; trocar antes de publicar).
Label exibido no Android: **SomaAí** (`applicationId` ainda é `com.example.mercado_app`).

### Instalação no Redmi Note 11 (`6D4TQKXGONGAU8FE`)

✅ **Instalação via ADB validada em 20/10/2026** (depois de habilitar
“Instalar via USB” no MIUI). O app abriu sem `FATAL EXCEPTION` e os logs
mostraram `[SomaAí] Supabase inicializado com sucesso.`

```bash
adb -s 6D4TQKXGONGAU8FE install -r somaai-arm64-release.apk
```

Fallback manual (se o MIUI voltar a bloquear): abrir “Arquivos/Gerenciador” →
Downloads → `somaai-arm64-release.apk` → Instalar.

Diagnóstico automático: `./tools/diagnose_somaai.sh` (instala, abre e filtra o logcat).

---

### Validação ponta a ponta (20/10/2026)

Fluxo executado no Redmi Note 11 (`1080×2400`, Android 13), com dados de demonstração zerados:

1. Dashboard (4 compras demo, R$ 332,52) → **Iniciar nova compra** → scanner.
2. **Manual** → “Leite” + R$ 4,49 → adicionar (carrinho 1 item, saldo R$ 4,49).
3. **Finalizar compra** → mercado “Supermercado” → salvar.
4. Dashboard atualizado para R$ 337,01 / 5 compras e a compra no topo de “Últimas compras”.
5. Histórico e detalhe exibem o item, a quantidade e o total corretos.
6. Repetição com “Cafe” + R$ 9,90 confirmou o diálogo no singular **“1 item”**, sem teclado
   automático nem handle de seleção sobre o campo do mercado.
7. `adb logcat` sem ocorrências de `startImageStream was called while a camera was streaming`
   durante 10 s de câmera aberta.
8. `pm clear` no final: o app volta ao estado limpo com as 4 compras demo.

---

### Scanner: performance e anti-falsos positivos (20/10/2026)

**Câmera e processamento**

- `CameraController` em `ResolutionPreset.medium`, `fps: 15` e `yuv420`.
- Timer de captura em **900 ms** (antes 500 ms), com descarte imediato de frames
  enquanto `_isProcessing` ou `_isStreaming` estiverem ativos.
- Um único frame em voo por vez; timeout de 2 s reinicia o stream se o aparelho parar
  de entregar imagens.
- Fusão dos planos YUV movida para `Isolate.run` com `Uint8List` pré-alocado, fora da
  thread da UI. A chamada nativa do ML Kit continua assíncrona.
- `LabelScannerService` (`lib/features/scanner/domain/label_scanner_service.dart`)
  centraliza throttle, confirmação e cooldown.

**Validação do preço**

- `PriceParser` só aceita valor com **duas casas decimais** e:
  - `R$ 12,90` (cifrão explícito), ou
  - número isolado na linha (`12,90`, `12,90 un`), ou
  - palavra-chave imediatamente antes (`POR`, `PREÇO`, `VALOR`, `CADA`, `A PARTIR DE`).
- Faixa de sanidade: **R$ 0,10 a R$ 500,00**; zero, negativos e valores acima do teto
  são descartados.
- Datas (`12/10/2026`), EAN (8–14 dígitos), porcentagens (`10%`) e pesos/volumes
  (`500 g`, `1,5 kg`, `2 un`) são ignorados como preço.
- Promoções `2x 4,99` / `3 por 10,00` calculam o unitário e preservam a quantidade;
  “De R$ 29,90 por R$ 24,90” prefere o valor depois de “por”.
- Nome do produto é separado do preço mesmo quando o OCR junta tudo na mesma linha
  (`Leite Integral R$ 4,49` → `Leite Integral`).

**Confirmação e feedback**

- O mesmo valor precisa aparecer em **2 frames consecutivos** (janela de 5 s;
  nomes/EAN ajudam a identidade). Um valor diferente reinicia a contagem.
- Após confirmar: vibração forte (`HapticFeedback.heavyImpact`), pulso verde e o
  scanner é **pausado** com a folha “Leitura confirmada” (nome, preço, unidade).
- “Adicionar ao carrinho” salva o item; “Escanear de novo” descarta e retoma.
  Cooldown de 4 s evita duplicar o mesmo produto ao baixar o celular.
- Mensagem discreta sob a moldura: “Aproxime da etiqueta de preço”; ao ler um
  candidato, mostra o valor e a moldura fica âmbar.

**Testes adicionados**

- `test/price_parser_test.dart`: 18 casos (formatos, limites, datas, EAN, peso,
  promoções, nome na mesma linha).
- `test/label_confirmation_test.dart`: 7 casos do throttle de 800 ms e do gate de
  2 frames, janela, EAN e normalização de acentos.
- `test/scan_confirmation_sheet_test.dart`: valida a folha de confirmação e as ações.
- Suíte completa: **37 testes** passando; `dart analyze` sem erros.

**Validação no Redmi Note 11**

- Scanner aberto por 25 s: **0** ocorrências de
  `startImageStream was called while a camera was streaming`, sem `FATAL EXCEPTION`
  ou `E/flutter`.
- CPU do processo entre ~3% e 7% nas amostras; memória residente ~356–368 MB.
- Mensagem “Aproxime da etiqueta de preço” visível sob a moldura (corrigido o clipping
  e a animação que deixava o texto com opacidade 0).
- Entrada manual segue abrindo e funcionando.

**Limitação conhecida:** a conversão atual ainda concatena os planos YUV; o próximo
passo é montar NV21 corretamente (intercalar V/U) para melhorar a taxa de leitura sem
mexer no throttle.

---

## ✅ Estado Atual da Compilação

### Concluído

- [x] Estrutura do projeto e todos os arquivos Dart
- [x] Schema Supabase aplicado (tabelas, MV, RPCs, RLS)
- [x] `flutter pub get` e `dart analyze` sem **erros** (0 errors; ~70 warnings/infos)
- [x] Build do APK debug e release
- [x] **Correção do erro de sintaxe em `scanner_screen.dart`**
      (faltava o `)` que fecha o `Scaffold` do estado de loading — linha 207 usava `);`)
- [x] `camera_service.dart`: import de `dart:ui` para `Size`
- [x] `features/providers.dart`: exports apontando para os caminhos reais
- [x] Manifest: permissões `CAMERA`, `ACCESS_FINE/COARSE_LOCATION`, `INTERNET`
- [x] `main.dart`: delegates de localização (`GlobalMaterial/Widgets/Cupertino`) + `pt_BR`/`en`
- [x] `pubspec.yaml`: removida declaração de fontes inexistentes (`assets/fonts/*.ttf`)
- [x] ML Kit migrado para pacotes específicos (OCR + barcode)
- [x] NDK 28.2.13676358 instalado corretamente (antes era uma pasta falsa)
- [x] Proguard rules para R8
- [x] Permissão de câmera solicitada em runtime + tela de erro com “Abrir configurações”
- [x] **Rename para SomaAí**: label Android, `CFBundleDisplayName`/`CFBundleName`, `app_constants.appName`,
      `MaterialApp.title`, `pubspec name: soma_ai` e imports dos testes
- [x] **Boot não-bloqueante**: `runApp` imediato + `BootstrapGate` + `AppBootstrap` com timeout de 8s
- [x] **Handlers globais**: `FlutterError.onError`, `PlatformDispatcher.onError` e `ErrorWidget.builder`
- [x] **Modo offline**: `PriceValidationService`/`SupabaseService` não tocam em `Supabase.instance` sem init
- [x] **ProGuard/R8 ampliado**: Flutter, MethodChannel handlers, ML Kit, GMS, Supabase, JNI e anotações
- [x] **Launch theme verde** (`@color/launch_background`) — elimina o flash preto do modo escuro
- [x] **Câmera resiliente**: timeout de 15s, botão “Tentar novamente”, `dispose` seguro
- [x] Testes: **37 testes** passando (splash, fallback do `BootstrapGate`, Dashboard,
      troca de aba, modelo `Purchase`, formatadores, parser de preços, gate de
      confirmação em 2 frames e folha de confirmação do scanner)
- [x] Script `tools/diagnose_somaai.sh` para captura de logs no aparelho
- [x] **Dashboard financeiro** como tela inicial (não abre mais a câmera direto)
- [x] **3 abas** (`Início`, `Comunidade`, `Perfil`) com `IndexedStack` (estado preservado)
- [x] **Histórico persistente** em `SharedPreferences` (`Purchase`/`PurchaseItem`)
- [x] **Finalizar compra** no scanner: pergunta o mercado, salva no histórico e volta
- [x] **Painel de saldo glassmorphism** no scanner + ações Voz/Manual/Carrinho
- [x] **Design system White Theme / Bento** (creme `#FBFBF7`, esmeralda, cantos 28–34)
- [x] Logotipo em código (cesta + selo “+”) e splash atualizada
- [x] **Entrada manual de item** no scanner (nome, preço com vírgula/ponto, quantidade)
- [x] **Fluxo ponta a ponta validado no aparelho**: item manual → carrinho → Finalizar compra →
      escolha do mercado → compra persistida → Dashboard e histórico atualizados no mesmo instante
- [x] **Ciclo de vida dos controllers** da folha manual: descarte só depois de fechar a folha
      (antes, um `Future.delayed` de 2 s os descartava com a folha ainda aberta e bloqueava a digitação)
- [x] **Stream da câmera protegido** por `_isStreaming`: sem `startImageStream` concorrente
      (eliminado o erro repetido “a camera has started streaming images”)
- [x] Diálogo de finalização sem autofocus no campo do mercado (sem teclado/handle por cima)
      e contagem no singular (“1 item”)

### 🐞 Diagnóstico da tela preta (release)

**Causa raiz provável:** o `main()` antigo fazia `await Supabase.initialize(...)` **antes** de
`runApp`. Qualquer falha/travamento nessa chamada (ex.: `SharedPreferences`/JNI ou plugin
removido pelo R8 no release) impedia o Flutter de desenhar o primeiro frame. Como o
`LaunchTheme` do modo escuro usava `?android:colorBackground` (preto), o resultado era uma
tela totalmente preta.

**Correções aplicadas (defesa em profundidade):**

| Camada | Correção |
|--------|----------|
| Inicialização | `runApp` acontece antes de qualquer `await`; Supabase inicializa no `BootstrapGate` |
| Falha de rede/plugin | `AppBootstrap` captura tudo e libera a UI em modo offline (timeout 8s) |
| Renderização | `ErrorWidget.builder` mostra tela legível em vez de caixa preta/cinza |
| ProGuard/R8 | keeps explícitos para Flutter, handlers de plugin, ML Kit, GMS, Supabase e JNI |
| Splash nativa | `launch_background` agora é verde da marca, nunca preto |
| Câmera | timeout de 15s + botão “Tentar novamente” (não fica preso em “Inicializando”) |
| Serviços | `PriceValidationService` só acessa Supabase quando online; `SupabaseService.isReady` |

**Como confirmar no aparelho:** instalar o APK e rodar `./tools/diagnose_somaai.sh`.
Os logs do app aparecem com o prefixo `[SomaAí]` (ex.: `Supabase indisponível — seguindo em modo offline`).

### Limitações conhecidas (não bloqueiam o APK)

- [ ] Conversão `CameraImage` → `InputImage` é ingênua (concatena planos como NV21);
      OCR pode ter qualidade ruim em alguns aparelhos. Próximo passo: usar
      `InputImageConverter`/`nv21` correto por plataforma.
- [ ] Entrada por voz ainda é stub (“Em desenvolvimento”); a entrada manual por teclado já funciona
- [ ] Tela de checkout fiscal não implementada
- [ ] Fila offline (Drift) não implementada
- [ ] `flutter analyze` (LSP) quebra com o caminho acentuado `Público`;
      usar `dart analyze lib` no terminal

---

## 🎨 Redesign — Dashboard & Identidade Visual (Out/2026)

### Nova navegação

`main.dart` → `BootstrapGate` → `AppShell` (3 abas com `IndexedStack`):

| Aba | Ficheiro | Conteúdo |
|-----|----------|----------|
| Início | `home_dashboard_screen.dart` | Saudação, CTA “Iniciar nova compra”, Bento de gastos/economia, últimas compras |
| Comunidade | `community_screen.dart` | Radar de ofertas com filtros (recentes, descontos, perto de mim) |
| Perfil | `profile_screen.dart` | Estatísticas, mercados favoritos, preferências e limpar histórico |

A câmera abre apenas por `Navigator.push` a partir do CTA.

### Dados

- `Purchase` / `PurchaseItem` (`lib/core/models/purchase.dart`).
- `PurchaseHistoryNotifier` persiste JSON em `SharedPreferences`
  (`somaai.purchase_history.v1`).
- No primeiro arranque semeia 4 compras de demonstração
  (`demo_purchases.dart`); “Limpar histórico” no Perfil remove tudo.
- Providers derivados: `monthlySpendingProvider`, `monthlySavingsProvider`,
  `recentPurchasesProvider`, `lifetimeSpendingProvider`, `lifetimeSavingsProvider`.
- A economia de uma compra é a soma dos `CommunityPriceAlert.savings` vistos
  durante a sessão de scanner (uma vez por EAN).

### Scanner

- Painel inferior em vidro fosco (`BackdropFilter` + branco 90%) com “SALDO TOTAL”
  em verde grande, contagem de itens e ações Voz / Manual / Carrinho.
- Barra superior: fechar, wordmark, alertas e lanterna.
- “Finalizar compra” → diálogo com total, campo “Onde você comprou?” e atalhos
  (Extra, Assaí, Carrefour, Pão de Açúcar) → salva e volta ao Dashboard.

### Design tokens

| Token | Valor |
|-------|-------|
| Fundo | `#FBFBF7` |
| Esmeralda | `#0E9F6E` / `#12B76A` |
| Verde escuro | `#07603F` |
| Lima (destaque) | `#C8F169` |
| Âmbar (alertas) | `#F5A524` |
| Tinta | `#101828` |
| Texto secundário | `#667085` |
| Raios | 14 / 20 / 28 / 34 |
| Tipografia | Plus Jakarta Sans (google_fonts) |

### Direção de arte

- **Logotipo:** cesta branca sobre quadrado esmeralda arredondado + selo lima
  com “+”. Lê-se “somar compras” numa só forma; funciona a 22 px e a 96 px.
- **Splash:** gradiente esmeralda, cartão branco com o símbolo, wordmark branco
  e a promessa “Sem sustos no caixa.”; carregamento em lima.
- **Dashboard:** CTA em gradiente com círculos orgânicos, cartões Bento brancos,
  números grandes e um teaser âmbar do radar.
- **Comunidade:** cartões brancos com preço grande em esmeralda, preço antigo
  riscado, selo de desconto em lima e confirmação por polegar.
- **Glassmorphism:** usado só nos painéis flutuantes sobre a câmera.

---

## 🎯 Fase 1 — MVP Core

| Tarefa | Status |
|--------|--------|
| Câmera + OCR + Barcode | ✅ compila e builda (qualidade de OCR a calibrar) |
| Carrinho em tempo real | ✅ implementado |
| Sync Supabase | ✅ schema + serviços prontos |
| APK de teste | ✅ release ARM64 39,5 MB |

---

## 🗺️ Roadmap

### Fase 2 — Comunidade (2–3 semanas)
- Validar RPC de comparação de preços em dispositivo real
- Cadastro de lojas com geolocalização
- Alertas com toggle (já há UI)
- Frescor de 72h (TTL)

### Fase 3 — UX (2 semanas)
- Entrada por voz (`speech_to_text`)
- ✅ Formulário de entrada manual (concluído em 20/10/2026)
- Offline-first (Drift/SQLite + fila)
- Sync em background

### Fase 4 — Gamificação (2–3 semanas)
- Trust score, badges, leaderboards
- Push notifications

### Fase 5 — Escala
- Modelo ML customizado para etiquetas BR
- Edge Functions para OCR server-side
- Multi-região

---

## 🐛 Correções aplicadas (histórico)

| Problema | Correção |
|----------|----------|
| `Can't find ')' to match '('` em `scanner_screen.dart:185` | Faltava `)` do `Scaffold`; `);` na linha 207 fechava só o `Container` |
| `Undefined class 'Size'` | `import 'dart:ui' show Size;` em `camera_service.dart` |
| URI inexistente em `features/providers.dart` | Exports para `cart/...`, `community_alerts/...`, `scanner/...` |
| Asset `assets/fonts/Inter-*.ttf` ausente | Removido bloco `fonts:` (usa `google_fonts`) |
| `Incorrect package=` nos plugins ML Kit | Removido atributo `package` dos manifests em pub-cache |
| `requires compileSdk 33+` | `compileSdkVersion 36` nos `build.gradle` dos plugins |
| CMake `Could not find toolchain file` | NDK 28.2.13676358 reinstalado via `sdkmanager` |
| R8 missing classes (OCR asiático / Play Core) | `android/app/proguard-rules.pro` com `-dontwarn` |
| `BarcodeFormat.upcA` / `upcE` | Enum correto: `upca` / `upce` |
| `InputImage.fromCameraImage` inexistente | `_cameraImageToInputImage` + `InputImage.fromBytes` |
| `WriteBuffer` | `Uint8List.fromList` |
| `Math.min` | `min` de `dart:math` |
| `Icons.checkout` | `Icons.shopping_cart_checkout` |
| locale `pt_BR` sem delegate | `flutter_localizations` + delegates globais |
| Tela preta no release | `runApp` imediato + `BootstrapGate`/`AppBootstrap` com timeout e fallback offline |
| Erro de renderização invisível | `FlutterError.onError`, `PlatformDispatcher.onError`, `ErrorWidget.builder` |
| Flash preto do launch theme | `launch_background` = `@color/launch_background` (`#07603F`) |
| app “preso” em “Inicializando câmera” | timeout de 15s + botão “Tentar novamente” |
| `LateInitializationError` no `dispose` | serviços de scanner agora nullable + dispose seguro |
| `NoSuchMethodError` no `shared_preferences` (release) | R8 renomeava `kotlin.coroutines.Continuation` na assinatura JNI; `includedescriptorclasses` + keeps de `kotlin.*` e `android.enableR8.fullMode=false` |
| `ClassNotFoundException: kotlin/Result` (release) | `-keep class kotlin.Result { *; }` + `kotlinx.coroutines.**`; validação no aparelho sem exceções |
| `INSTALL_FAILED_VERSION_DOWNGRADE` | `version` do pubspec passou para `1.0.0+2002` (aparelho tinha 2001) |

---

## 📝 Próximos passos imediatos

1. Trocar `applicationId` (`com.example.mercado_app`) e gerar keystore própria
   antes de qualquer distribuição; remover a assinatura debug.
2. Implementar entrada por voz (`speech_to_text`) e o checkout fiscal.
3. Substituir as ofertas mock da Comunidade pela RPC/PostGIS do Supabase.
4. Corrigir a conversão `CameraImage → InputImage` (NV21 por plataforma) para
   melhorar o OCR de etiquetas reais; a entrada manual cobre os testes até lá.
5. Avaliar a remoção dos dados demo no primeiro arranque de produção
   (`PurchaseHistoryNotifier` semeia 4 compras apenas quando o storage está vazio).

---

## 📊 Métricas

- Build release ARM64: ~20–60 s (cache quente, split-per-abi)
- APK release ARM64: **39,5 MB**
- APK debug ARM64: 186 MB (kernel JIT + libs debug)
- Testes: **36 passando** (`flutter test`)
- Análise estática: 0 erros (`dart analyze lib test integration_test`)
- Preview: 15 fps; processamento: **1 frame a cada 900 ms**, um por vez
- Scanner no aparelho: ~3–7% de CPU e ~356–368 MB de memória residente
- Fila offline planejada: até 100 scans

---

*Atualizar este documento a cada marco relevante.*
