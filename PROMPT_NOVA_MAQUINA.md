# Prompt de Retomada — SomaAí (nova máquina)

> **Como usar:** cole o conteúdo deste arquivo no OpenCode da nova máquina. Ele contém o bootstrap completo do ambiente, a retomada do projeto e a instalação opcional da toolbox de agentes. Se você só quer buildar/rodar o SomaAí, execute as seções **2, 3, 7 e 8**; a seção **4** é opcional e pesa ~1,9 GB.

---

Você é o agente de continuidade do **SomaAí**, um app Flutter + Riverpod + Supabase de calculadora de carrinho inteligente, com scanner de etiquetas por câmera (ML Kit OCR/código de barras), entrada manual/voz, dashboard financeiro e comunidade de preços.

## 0. Objetivo desta retomada

Continuar o desenvolvimento a partir do estado atual, **sem refazer o que já está pronto**, sem inventar preços e sem apagar arquivos do usuário. Primeiro leia os documentos, valide o ambiente e só depois altere código.

## 1. Leitura obrigatória antes de agir

Leia, nesta ordem:

1. `PROJECT_STATUS.md` — fonte da verdade sobre arquitetura, funcionalidades, testes, métricas e roadmap.
2. `DIRECAO_DE_ARTE.md` — direção de arte, White Theme/Bento, acessibilidade e pt-BR.
3. `README.md` — visão geral e instruções do projeto.
4. `CLAUDE.md` e `.github/copilot-instructions.md` — convenções e regras para agentes.
5. `.cursor/rules/*.mdc` — regras específicas de Flutter usadas no projeto.
6. `.agents/skills/*/SKILL.md` — 27 skills curadas (Dart, Flutter, Supabase, testes, análise estática etc.).
7. `skills-lock.json` — manifesto das skills instaladas.
8. `pubspec.yaml` e `pubspec.lock` — dependências e versões.
9. `supabase/migrations/001_initial_schema.sql` e `002_purchases.sql` — schema do Supabase (inclui compras e total mensal).
10. `tools/apply_mlkit_patches.sh` e `tools/mlkit_patches/` — patches necessários aos plugins ML Kit.

Ao terminar a leitura, diga em poucas linhas o que entendeu e apresente um plano. Não peça para o usuário repetir o contexto.

---

# 2. Bootstrap da máquina

## 2.1 Ambiente de referência validado

Use estas versões como referência. Pequenas variações de patch podem funcionar, mas não troque o JDK 17 por Java 21/25 sem revalidar o build Android.

| Ferramenta | Versão validada |
|---|---|
| Sistema | Ubuntu 26.04.1 LTS (Linux x64) |
| Flutter | 3.47.7 stable |
| Dart | 3.13.5 |
| DevTools | 2.60.0 |
| JDK | Temurin/OpenJDK **17.0.12+7** |
| Gradle | wrapper **9.3.1-all** (não precisa de Gradle global) |
| Android build-tools | 36.0.0 |
| Android platform-tools | 37.0.1 |
| Android platforms | 29, 31, 34, 35 e 36 |
| Android NDK | 28.2.13676358 |
| Android CMake | 3.22.1 |
| Python | 3.14.4 |
| Node.js | 24.21.0 |
| npm | 11.19.0 |
| pnpm | 12.11.2 |
| OpenCode CLI | 2.0.32 |
| Git | 2.53.0 |
| Chrome | 154.0.8037.57 |
| Docker | 29.1.3 |
| ADB | 1.0.41 / platform-tools 37.0.1 |
| Dispositivo de teste | Redmi Note 11 `2201117SG`, Android 13 (API 33), serial de referência `6D4TQKXGONGAU8FE` |

O serial do aparelho muda de máquina para máquina; use `adb devices` para descobrir o novo.

## 2.2 Pacotes base do Linux

Em Ubuntu/Debian:

```bash
sudo apt update
sudo apt install -y \
  git curl wget unzip xz-utils zip \
  build-essential pkg-config \
  libglu1-mesa liblzma-dev \
  clang cmake ninja-build libgtk-3-dev mesa-utils \
  patch python3 python3-venv python3-pip
```

`clang`, `cmake`, `ninja-build`, `libgtk-3-dev` e `mesa-utils` são necessários para Flutter Linux desktop. Para build **Android**, os essenciais são Git, curl, unzip, xz, zip, `libglu1-mesa`, Python e JDK; os demais são opcionais. O `flutter doctor` desta máquina acusa falta desses pacotes de desktop, mas o build Android funciona.

## 2.3 Instalar o JDK 17

O Java padrão desta máquina é **25**, mas o projeto Android usa **17**. Não use o Java 25 para o build.

Opção A — instalar o Temurin 17.0.12+7 em `~/java`:

```bash
mkdir -p "$HOME/java"
cd "$HOME/java"
curl -fL -o jdk17.tar.gz \
  "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.12%2B7/OpenJDK17U-jdk_x64_linux_hotspot_17.0.12_7.tar.gz"
tar -xzf jdk17.tar.gz
export JAVA_HOME="$HOME/java/jdk-17.0.12+7"
export PATH="$JAVA_HOME/bin:$PATH"
java -version
```

Opção B — usar o pacote da distribuição:

```bash
sudo apt install -y openjdk-17-jdk
export JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
export PATH="$JAVA_HOME/bin:$PATH"
java -version
```

Coloque os `export` no `~/.bashrc` ou `~/.zshrc` para persistir.

## 2.4 Instalar o Flutter 3.47.7

```bash
git clone https://github.com/flutter/flutter.git -b stable "$HOME/flutter"
git -C "$HOME/flutter" checkout 3.47.7

export PATH="$HOME/flutter/bin:$PATH"
flutter --version
flutter config --android-sdk "$HOME/android-sdk"
flutter doctor -v
```

Se o clone não tiver a tag `3.47.7`, use o canal stable mais próximo e registre a diferença. O projeto exige Dart `>=3.4.0 <4.0.0` e Flutter `>=3.22.0`, mas o estado validado é o 3.47.7.

## 2.5 Instalar o Android SDK

Baixe o **Command-line Tools only** em <https://developer.android.com/studio#command-line-tools-only> e extraia para `~/android-sdk/cmdline-tools/latest`.

```bash
export ANDROID_HOME="$HOME/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

sdkmanager --sdk_root="$ANDROID_HOME" --install \
  "platform-tools" \
  "platforms;android-29" \
  "platforms;android-31" \
  "platforms;android-34" \
  "platforms;android-35" \
  "platforms;android-36" \
  "build-tools;36.0.0" \
  "ndk;28.2.13676358" \
  "cmake;3.22.1" \
  "cmdline-tools;latest"

yes | sdkmanager --sdk_root="$ANDROID_HOME" --licenses
```

Verificação:

```bash
sdkmanager --sdk_root="$ANDROID_HOME" --list_installed
adb version
```

`android/local.properties` é local, não versionado, e contém caminhos absolutos. O Flutter o gera/atualiza no primeiro build; se necessário, rode `flutter build apk` uma vez ou `flutter config --android-sdk "$ANDROID_HOME"`.

## 2.6 Instalar Python 3.14 e criar a venv

```bash
python3 --version
# Se não for 3.14, instale python3.14 e python3.14-venv pela distribuição.
# Se 3.14 não estiver disponível, use 3.12+ e registre a diferença.

cd <CAMINHO_DO_PROJETO>
python3.14 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
```

## 2.7 Instalar Node.js, npm, pnpm e OpenCode

Recomendado via nvm:

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
source "$HOME/.nvm/nvm.sh"
nvm install 24.21.0
nvm alias default 24.21.0
node --version
npm --version

npm install -g npm@11.19.0 pnpm@12.11.2 @opencode/cli@2.0.32
opencode --version
```

Opcional, se você usa o mesmo toolbox global:

```bash
npm install -g remotion@4.0.535
```

`claude` (Claude Code) não é necessário para o SomaAí; instale apenas se for usar.

## 2.8 Instalar Chrome, Docker, Git e ADB

```bash
# Git e ADB
sudo apt install -y git
sudo apt install -y android-tools-adb  # ou use o adb do Android SDK

# Chrome (necessário para Chrome DevTools MCP/Playwright)
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub \
  | sudo gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" \
  | sudo tee /etc/apt/sources.list.d/google-chrome.list
sudo apt update
sudo apt install -y google-chrome-stable

# Docker (usado por Strix/Firecrawl e outros tools)
sudo apt install -y docker.io docker-compose-v2
sudo usermod -aG docker "$USER"
# Faça logout/login para o grupo docker valer.
```

Verificação:

```bash
git --version
google-chrome --version
docker --version
adb version
```

## 2.9 GitHub CLI e Supabase CLI (opcionais)

Nesta máquina, `gh` e `supabase` **não estão instalados**. O MCP do Supabase é remoto e não exige a CLI. Se quiser usar a CLI para migrations:

```bash
# GitHub CLI (opcional; para push/PR)
sudo apt install -y gh
gh auth login

# Supabase CLI (opcional; para migrations/link)
npm install -g supabase
supabase --version
supabase login
supabase link --project-ref vvoqamnucengagpwwozt
```

---

# 3. Configurar o projeto SomaAí

## 3.1 Dependências Python do agente

```bash
cd <CAMINHO_DO_PROJETO>
source .venv/bin/activate
python -m pip install --upgrade pip
pip install -r requirements.txt
```

Observações:

- `requirements.txt` é o `pip freeze` do ambiente de ferramentas do agente (**122 pacotes**), não é dependência do app Flutter.
- Contém três dependências editáveis via Git: `firecrawl`, `graphify` e `strix`. Se estiver offline ou se essas linhas falharem, remova/comente apenas as linhas `-e git+...` e instale o restante. O app Flutter não depende delas.
- O ambiente de referência usa Python **3.14.4**.

## 3.2 Dependências Flutter

```bash
flutter pub get
```

Depois do `pub get`, aplique os patches dos plugins ML Kit:

```bash
bash tools/apply_mlkit_patches.sh
```

## 3.3 Patches do ML Kit — obrigatório

Os plugins `google_mlkit_*` 0.7.0/0.4.0 são antigos e precisam de ajustes para Android SDK 36:

- `google_mlkit_commons-0.4.0`
- `google_mlkit_text_recognition-0.7.0`
- `google_mlkit_barcode_scanning-0.7.0`

O script `tools/apply_mlkit_patches.sh`:

- adiciona `namespace` ao `android/build.gradle`;
- sobe `compileSdkVersion` para 36;
- remove o atributo legado `package=` do `AndroidManifest.xml`.

Execute **sempre** depois de `flutter pub get` e depois de `flutter pub cache repair`. O `pub cache repair` baixa os pacotes originais e desfaz os patches.

```bash
bash tools/apply_mlkit_patches.sh
```

Se os plugins forem atualizados para versões novas, não aplique às cegas: verifique se os patches ainda são necessários e ajuste os arquivos em `tools/mlkit_patches/`.

## 3.4 Supabase

```bash
cp .env.example .env
```

Preencha `.env` com `SUPABASE_URL` e `SUPABASE_ANON_KEY` do projeto. O project ref usado anteriormente é `vvoqamnucengagpwwozt`.

**Nunca** versione `.env`, keystores ou chaves. O código atual também tem uma chave `anon` hardcoded em `lib/core/constants/app_constants.dart`; ela não é `service_role`, mas o ideal é migrar para `.env`/`--dart-define` antes de tornar o repositório público.

O MCP remoto do Supabase usado no OpenCode é:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "supabase": {
      "type": "remote",
      "url": "https://mcp.supabase.com/mcp?project_ref=vvoqamnucengagpwwozt&features=docs%2Caccount%2Cdatabase%2Cdebugging%2Cdevelopment%2Cfunctions%2Cbranching",
      "enabled": true
    }
  }
}
```

Salve em `~/.config/opencode/opencode.jsonc`. Na primeira chamada, autentique no fluxo OAuth do Supabase/OpenCode. Não coloque access token no repositório.

## 3.5 Skills do projeto e skills globais

As skills curadas do projeto estão em `.agents/skills` (27 skills) e as regras em `.cursor/rules` (11 regras).

- Use a ferramenta de skills do OpenCode para carregar as skills relevantes.
- Se o OpenCode não descobrir a pasta do projeto, copie ou crie symlinks para `~/.config/opencode/skills`.
- O manifesto `skills-lock.json` lista o conjunto esperado.
- A máquina antiga também tem 25 skills globais em `~/.config/opencode/skills`; elas são uma cópia das skills de Dart/Flutter e podem ser recriadas a partir de `.agents/skills`.

Exemplo de sincronização:

```bash
mkdir -p "$HOME/.config/opencode/skills"
cp -a .agents/skills/. "$HOME/.config/opencode/skills/"
```

---

# 4. Toolbox opcional do agente (~1,9 GB)

Esta seção **não é necessária para buildar o SomaAí**. Ela replica os oito repositórios que existem em `HABILIDADES/tools` na máquina antiga. Esses repositórios são **ignorados pelo Git** e não vão no push.

## 4.1 Repositórios e commits de referência

| Repositório | URL | Commit de referência | Observação |
|---|---|---|---|
| agent-skills | `https://github.com/addyosmani/agent-skills.git` | `aeac41d4d005` | Fonte das skills; o conteúdo curado já está em `.agents/skills` |
| chrome-devtools-mcp | `https://github.com/ChromeDevTools/chrome-devtools-mcp.git` | `f874aeb96ae5` | MCP/CLI para Chrome; requer Node e Chrome |
| firecrawl | `https://github.com/firecrawl/firecrawl.git` | `bafad0bebcc8` | Plataforma de scraping; o SDK Python está no requirements |
| Glyph | `https://github.com/thu-coai/Glyph.git` | `61afa7f208e8` | Pesquisa de compressão visual; opcional e pesado |
| graphify | `https://github.com/Graphify-Labs/graphify.git` | `86c57be82046` | Grafo de conhecimento; o CLI está instalado no requirements |
| modelcontextprotocol | `https://github.com/perplexityai/modelcontextprotocol.git` | `6ba09f856ab8` | MCP da Perplexity; requer API key |
| playwright | `https://github.com/microsoft/playwright.git` | `88ed60ceef54` | Automação de browser; baixa navegadores |
| strix | `https://github.com/usestrix/strix.git` | `a0f8ea2cd379` | Pentest com agentes; opcional |

## 4.2 Clonar os repositórios

```bash
cd <CAMINHO_DO_PROJETO>
mkdir -p HABILIDADES/tools

git clone https://github.com/addyosmani/agent-skills.git HABILIDADES/tools/agent-skills
git clone https://github.com/ChromeDevTools/chrome-devtools-mcp.git HABILIDADES/tools/chrome-devtools-mcp
git clone https://github.com/firecrawl/firecrawl.git HABILIDADES/tools/firecrawl
git clone https://github.com/thu-coai/Glyph.git HABILIDADES/tools/Glyph
git clone https://github.com/Graphify-Labs/graphify.git HABILIDADES/tools/graphify
git clone https://github.com/perplexityai/modelcontextprotocol.git HABILIDADES/tools/modelcontextprotocol
git clone https://github.com/microsoft/playwright.git HABILIDADES/tools/playwright
git clone https://github.com/usestrix/strix.git HABILIDADES/tools/strix

git -C HABILIDADES/tools/agent-skills checkout aeac41d4d005
git -C HABILIDADES/tools/chrome-devtools-mcp checkout f874aeb96ae5
git -C HABILIDADES/tools/firecrawl checkout bafad0bebcc8
git -C HABILIDADES/tools/Glyph checkout 61afa7f208e8
git -C HABILIDADES/tools/graphify checkout 86c57be82046
git -C HABILIDADES/tools/modelcontextprotocol checkout 6ba09f856ab8
git -C HABILIDADES/tools/playwright checkout 88ed60ceef54
git -C HABILIDADES/tools/strix checkout a0f8ea2cd379
```

Se algum commit não existir no clone raso, use `git fetch --unshallow` ou o HEAD atual e registre a diferença.

## 4.3 Instalar cada ferramenta (opcional)

### agent-skills

Não é necessário instalar. O conteúdo útil já está em `.agents/skills`. O repositório serve para consultar documentação, comandos e novos padrões.

### chrome-devtools-mcp

Requer Node, npm e Chrome. Consulte o README do repositório; o uso típico é via `npx`/MCP:

```bash
cd HABILIDADES/tools/chrome-devtools-mcp
npm install
npm run build
# ou, sem clonar:
npx chrome-devtools-mcp@latest --help
```

### firecrawl

O SDK Python já é instalado pelo `requirements.txt` (`firecrawl_py`). O repositório completo é uma plataforma de scraping e pode exigir Docker/Redis; não é necessário para o app.

```bash
cd HABILIDADES/tools/firecrawl
# siga o README para subir a stack completa, se for usar.
```

### graphify

O CLI `graphify` é instalado pelo `requirements.txt`. O índice antigo fica em `~/.cache/graphify` (~12 MB) e **não** é versionado.

```bash
graphify --help
# Reindexe o projeto conforme o README/CLI, se for usar o grafo.
```

### Glyph

Ferramenta de pesquisa de compressão visual; opcional e pesada. Siga o README do repositório; pode exigir GPU/modelos externos.

```bash
cd HABILIDADES/tools/Glyph
# instale conforme o README (ambiente Python/ML próprio)
```

### modelcontextprotocol (Perplexity MCP)

Requer Node/npm e uma `PERPLEXITY_API_KEY`. Consulte o README; o servidor pode ser configurado via MCP remoto ou local. **Não** coloque a API key no Git.

### playwright

```bash
cd HABILIDADES/tools/playwright
npm install
npx playwright install --with-deps
```

Isso baixa Chromium/Firefox/WebKit e dependências do sistema; é pesado e opcional.

### strix

O pacote Python `strix_agent` é instalado pelo `requirements.txt`. O Strix pode usar Docker e modelos/API keys; consulte o README antes de rodar.

```bash
strix --help
```

## 4.4 Configuração do OpenCode

Além do MCP do Supabase em `~/.config/opencode/opencode.jsonc`, a máquina antiga usa:

- `@opencode/cli@2.0.32`;
- `pnpm@12.11.2`;
- plugin local `@opencode-ai/plugin@1.18.23` em `~/.config/opencode/package.json` (opcional);
- `cli.json` com preferências de UI (opcional).

Exemplo de `~/.config/opencode/package.json`:

```json
{
  "dependencies": {
    "@opencode-ai/plugin": "1.18.23"
  }
}
```

---

# 5. Android, dispositivo e build

## 5.1 Variáveis de ambiente

Adicione ao `~/.bashrc`/`~/.zshrc`:

```bash
export JAVA_HOME="$HOME/java/jdk-17.0.12+7"
export ANDROID_HOME="$HOME/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$HOME/flutter/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$JAVA_HOME/bin:$PATH"
```

Depois:

```bash
source ~/.bashrc
flutter doctor -v
adb devices -l
```

## 5.2 Regras udev para Xiaomi/Redmi (se necessário)

Se `adb devices` mostrar `no permissions`:

```bash
echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="2717", MODE="0666", GROUP="plugdev"' \
  | sudo tee /etc/udev/rules.d/51-android.rules
sudo udevadm control --reload-rules
sudo udevadm trigger
```

Ative “Depuração USB” no aparelho e aceite a impressão digital RSA.

## 5.3 Configuração Android que deve ser preservada

- `android/gradle.properties` é versionado e contém `android.enableR8.fullMode=false`.
- Ajuste `android.sdk.licenses.dir` para o caminho da nova máquina ou remova essa linha se `android.disableLicenseCheck=true` funcionar.
- **Não reative o R8 full mode** sem revalidar o APK release: `shared_preferences` 2.5+/jni quebra com `NoSuchMethodError`/`ClassNotFoundException`.
- `applicationId` atual: `com.example.mercado_app`.
- Versão atual: `1.0.0+2004`.
- A release usa assinatura de debug. Não distribua assim; trocar appId e keystore é pendente.
- O Gradle wrapper 9.3.1 está versionado; a primeira build baixa a distribuição.
- `android/local.properties` não é versionado e deve ser gerado localmente.

---

# 6. Validação

```bash
dart analyze lib test integration_test
flutter test
```

Estado esperado:

- `dart analyze` sem erros.
- **93 testes passando**.
- Principais testes: `test/price_parser_test.dart`, `test/label_confirmation_test.dart`,
  `test/scan_confirmation_sheet_test.dart`, `test/active_purchase_flow_test.dart`,
  `test/market_selection_test.dart`, `test/dashboard_period_provider_test.dart`,
  `test/community_offer_test.dart`, `test/community_screen_test.dart`,
  `test/cart_editor_flow_test.dart` e `test/purchase_budget_sheet_test.dart`.

Build release de referência:

```bash
flutter build apk --release --split-per-abi
adb devices
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

O APK ARM64 de referência tem cerca de **42,8 MB**. O preview da câmera aparece preto em `adb screencap` porque é uma `Texture`; isso não é bug visual. Para inspecionar bounds reais, use `uiautomator dump`.

---

# 7. Estado funcional que deve ser preservado

- Primeira tela após a splash é o **dashboard financeiro**, não a câmera nem lista vazia.
- Três abas: **Início**, **Comunidade** e **Perfil**, com estado preservado (`IndexedStack`), construídas apenas na primeira visita.
- Compra com ou sem mercado: sem mercado, fica só no histórico pessoal e não publica ofertas.
- Dashboard com filtros *Este mês*, *Últimos 3 meses*, *Este ano* e *Personalizado*.
- Comunidade com ofertas reais, cidade/raio 5/10/20 km, foto, endereço, distância e rotas Google Maps/Waze.
- Histórico persistente, detalhe de compra, entrada manual, folha de confirmação e finalização que salva no histórico.
- Carrinho com **edição pelo lápis** (nome, preço, tipo de cobrança, quantidade ou peso),
  **unidade × peso/kg**, **stepper inline** (1 un ou 100 g), **prova de prateleira**
  (miniatura 48×48 ao lado do nome que abre a foto da etiqueta em tela cheia) e
  **card de orçamento dinâmico** (Zona segura verde ≤75%, atenção amarelo 76–100%,
  estourado vermelho >100%, com `AnimatedContainer`).
- **Splash Screen + Auth Checker**: tela de abertura com fundo verde `#1DB954`, logo SVG animada
  (fade-in + scale-up 0.8→1.0), `CircularProgressIndicator` branco, timer mínimo 2500 ms;
  `BootstrapGate` verifica `SupabaseService.currentUser` e redireciona para `AppShell`
  (autenticado) ou `LoginScreen` (não autenticado, com opção "Continuar como visitante").
- **Autenticação Social + Passwordless**: `AuthService` centralizado com `AuthResult` sealed class;
  **Google OAuth** (`google_sign_in` → ID Token → `signInWithIdToken`), **Apple OAuth** (`sign_in_with_apple`
  com nonce SHA-256 → `signInWithIdToken`), **Telefone OTP SMS** (`signInWithOtp` + `verifyOTP`),
  tela `OTPVerificationScreen` (6 dígitos PIN, timer reenvio 60s), `PhoneLoginSheet` com máscara
  `(XX) XXXXX-XXXX`; `RegisterScreen` e `LoginScreen` atualizados com botões Google/Apple/Phone;
  dependências: `google_sign_in`, `sign_in_with_apple`, `pin_code_fields`; guia completa em `GUIA_AUTH_SOCIAL.md`
  (Supabase Providers, Google Cloud OAuth, Apple Services ID/Key, Twilio, Deep Links Android/iOS).
- Scanner com câmera em `ResolutionPreset.medium`, ~15 fps, throttle de **800–1000 ms**, `_isProcessing` descartando frames, ML Kit sem bloquear a UI e conversão YUV em `Isolate.run`.
- Validação estrita de preço: cifrão/padrão monetário, duas casas decimais, faixa **R$ 0,10–R$ 500,00**, rejeição de datas/EAN/porcentagens/pesos.
- Confirmação em **2 frames consecutivos** antes de sugerir o item; feedback “Aproxime da etiqueta de preço”, háptico forte e pausa para confirmação.
- `LabelScannerService` centraliza throttle, gate de confirmação, janela de 5 s e cooldown de 4 s.
- UI em **pt-BR**, acessível para idosos, com design White Theme/Bento.
- Código modular por feature em `lib/features/...` e serviços/utils em `lib/core/...`.

---

# 8. Próximos passos (não refazer o que já existe)

1. Validar OCR real com etiquetas impressas em diferentes iluminações e ângulos.
2. Corrigir a conversão `CameraImage → InputImage` para **NV21 real** (intercalar V/U) e medir ganho de leitura.
3. Trocar `applicationId` e criar keystore própria antes de distribuir.
4. Implementar entrada por voz (`speech_to_text`) e checkout fiscal.
5. Avaliar a remoção das 4 compras demo no primeiro arranque de produção.

---

# 9. Regras de trabalho

- Não invente preços, ofertas ou métricas. Se não houver dado real, use mock explicitamente identificado.
- Não afrouxe a validação de preço para “fazer funcionar”; falsos positivos são piores que uma leitura perdida.
- Preserve as três abas e o dashboard como primeira tela.
- Não apague arquivos do usuário sem confirmação.
- Não faça commit nem push sem autorização explícita.
- O caminho pode conter acento (`Público`); use `dart analyze lib test integration_test` em vez de comandos que dependem de caminho literal.
- Antes de qualquer mudança grande, rode os testes e o analyze; depois da mudança, rode novamente.
- Se encontrar divergência entre este prompt e `PROJECT_STATUS.md`, **o `PROJECT_STATUS.md` prevalece**; atualize-o ao final.
- Os patches do ML Kit são obrigatórios e não são opcionais.

---

# 10. Primeira resposta esperada

Responda com:

1. Confirmação de que leu os documentos e as skills.
2. Resumo do estado atual em até 10 linhas.
3. Plano de validação do ambiente (Python, Flutter, Android, Supabase, ML Kit).
4. Riscos ou bloqueios encontrados.
5. Pergunta sobre qual frente devo atacar primeiro, sem alterar código ainda.
