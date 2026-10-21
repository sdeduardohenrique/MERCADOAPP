# Guia de Configuração do Login com Apple (Sign in with Apple)

Este documento detalha **todo o passo a passo** para configurar a autenticação via Apple no Supabase, garantindo que o fluxo funcione corretamente tanto no iOS quanto no Android.

> ⚠️ **Importante**: O Login com Apple **exige configuração no Apple Developer Portal** e no **Painel do Supabase**. Sem isso, o fluxo falhará com erros como `invalid_grant`, `invalid_token` ou `identityToken is null`.

---

## 1. PRÉ-REQUISITOS

| Item | Obrigatório? | Observação |
|------|--------------|------------|
| Conta no **Apple Developer Program** ($99/ano) | ✅ Sim | Necessário para criar App IDs, Services IDs e chaves |
| Bundle ID do app iOS (ex: `com.seuapp.somaai`) | ✅ Sim | Deve ser único |
| URL de Callback do Supabase | ✅ Sim | Fornecida pelo Supabase |
| Projeto no Supabase | ✅ Sim | Auth > Providers > Apple |

---

## 2. APPLE DEVELOPER PORTAL (https://developer.apple.com/account)

### 2.1 Criar/Verificar App ID (iOS)

1. Acesse **Certificates, Identifiers & Profiles** → **Identifiers**
2. Clique em **+** → **App IDs**
2. **App ID Prefix**: Selecione seu **Team ID** (ex: `ABCD123456`)
3. **Bundle ID**: `Explicit` → digite o **Bundle ID do seu app iOS** (ex: `com.seuapp.somaai`)
   - ⚠️ Deve ser **exatamente** o mesmo do `CFBundleIdentifier` no `Info.plist` / `PRODUCT_BUNDLE_IDENTIFIER` no Xcode
4. **Capabilities**: Marque **Sign In with Apple**
5. Clique em **Continue** → **Register**

### 2.2 Criar Services ID (para Web/Android)

> **Obrigatório para Android** e para o Supabase validar o token.

1. Em **Identifiers**, clique em **+** → **Services IDs**
2. **Description**: `SomaAí Web Auth` (ou nome descritivo)
3. **Identifier**: `com.seuapp.somaai.web` (ex: `com.seuapp.somaai.service`)
   - ⚠️ **Este é o `Client ID` que vai no Supabase**
4. ✅ **Sign In with Apple** → **Configure**
   - **Primary App ID**: Selecione o App ID criado no passo 2.1
   - **Website URLs**:
     - **Domains**: `seudominio.com` (seu domínio de produção)
     - **Return URLs**: `https://SEU_PROJECT_REF.supabase.co/auth/v1/callback`
       - ⚠️ **EXATAMENTE esta URL** (fornecida pelo Supabase)
       - Para testes locais, adicione também: `http://localhost:3000/auth/callback`
5. **Save** → **Continue** → **Register**

### 2.3 Criar Chave Privada (Private Key / .p8)

> **Esta chave assina o JWT que o Supabase valida.**

1. Em **Keys**, clique em **+**
2. **Key Name**: `SomaAí Auth Key` (ou nome descritivo)
3. ✅ **Sign In with Apple** → **Configure**
   - Selecione o **App ID** do passo 2.1
4. **Save** → **Continue** → **Register**
5. ⚠️ **DOWNLOAD IMEDIATO**: Baixe o arquivo `.p8` (ex: `AuthKey_ABCD1234.p8`)
   - **SÓ PODE BAIXAR UMA VEZ!** Guarde em local seguro.
6. Anote o **Key ID** (ex: `ABCD1234`) — aparece na lista de chaves.

### 2.4 Obter Team ID

1. No canto superior direito do Developer Portal, clique no seu nome
2. **Membership Details** → **Team ID** (ex: `ABCD123456`)
   - ⚠️ Copie este valor — vai no Supabase.

---

## 3. SUPABASE DASHBOARD (https://supabase.com/dashboard)

### 3.1 Habilitar Provider Apple

1. Acesse seu projeto → **Authentication** → **Providers**
2. Encontre **Apple** → clique para editar
3. **Enable Apple provider**: ✅ **ON**

### 3.2 Preencher Credenciais

| Campo no Supabase | Valor | Origem |
|-------------------|-------|--------|
| **Bundle ID** | `com.seuapp.somaai` | App ID do iOS (passo 2.1) |
| **Team ID** | `ABCD123456` | Membership Details (passo 2.4) |
| **Services ID (Client ID)** | `com.seuapp.somaai.web` | Services ID Identifier (passo 2.2) |
| **Key ID** | `ABCD1234` | Chave privada .p8 (passo 2.3) |
| **Private Key** | *(cole o conteúdo do .p8)* | Arquivo `.p8` baixado (passo 2.3) |

**Como obter o conteúdo da Private Key:**
```bash
cat AuthKey_ABCD1234.p8
```
Cole **todo o conteúdo** (incluindo `-----BEGIN PRIVATE KEY-----` e `-----END PRIVATE KEY-----`).

### 3.3 Configurar Redirect URLs

Em **Authentication** → **URL Configuration**:

| Campo | Valor |
|-------|-------|
| **Site URL** | `https://seudominio.com` (ou `http://localhost:3000` para dev) |
| **Additional Redirect URLs** | <ul><li>`somaai://auth/callback`</li><li>`https://SEU_PROJECT_REF.supabase.co/auth/v1/callback`</li><li>`http://localhost:3000/auth/callback` (dev)</li></ul> |

> ⚠️ O esquema `somaai://` deve estar registrado no `AndroidManifest.xml` e `Info.plist`.

---

## 4. CONFIGURAÇÃO NO FLUTTER (App)

### 4.1 `pubspec.yaml` — Dependências

```yaml
dependencies:
  sign_in_with_apple: ^6.1.0
  supabase_flutter: ^2.3.4
```

> Rode `flutter pub get` após alterar.

### 4.2 iOS — `ios/Runner/Info.plist`

```xml
<!-- Sign in with Apple -->
<key>com.apple.developer.applesignin</key>
<array>
  <string>Default</string>
</array>

<!-- URL Schemes para deep link -->
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>somaai</string>
      <string>com.seuapp.somaai</string>
    </array>
  </dict>
</array>
```

### 4.3 iOS — Xcode (Signing & Capabilities)

1. Abra `ios/Runner.xcworkspace` no Xcode
2. **Runner** → **Signing & Capabilities**
3. ✅ **Sign In with Apple**
4. Verifique se o **Team** está correto
5. Build para device físico (Apple Sign-In **não funciona no simulador**)

### 4.4 Android — `android/app/src/main/AndroidManifest.xml`

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTop"
    ... >
    
    <!-- Deep link para auth callback -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="somaai" android:host="auth" android:pathPrefix="/callback" />
    </intent-filter>
    
    <meta-data android:name="io.flutter.embedding.android.NormalTheme" android:resource="@style/NormalTheme" />
    <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
    </intent-filter>
</activity>
```

### 4.5 Android — `android/app/build.gradle.kts`

```kotlin
android {
    defaultConfig {
        applicationId = "com.seuapp.somaai"  // Deve bater com o Bundle ID
        ...
    }
}
```

---

## 5. TESTES E DEBUG

### 5.1 Como testar o fluxo Apple

| Plataforma | Como testar |
|------------|-------------|
| **iOS (device físico)** | Build release/debug no Xcode → Testar botão Apple |
| **Android** | Build APK → Instalar no device → Testar (usa fluxo web OAuth) |
| **Simulador iOS** | ❌ **NÃO FUNCIONA** — Apple bloqueia no simulador |

### 5.2 Logs Esperados (Sucesso)

```
[AuthService] Starting Apple Sign-In flow...
[AuthService] Generated nonce (raw): 1700000000000X7fK3mN...
[AuthService] Generated nonce (sha256): a1b2c3d4e5f6...
[AuthService] Requesting Apple ID credential...
[AuthService] Received Apple credential:
[AuthService]   userIdentifier: 001234.abcdef1234567890
[AuthService]   email: usuario@exemplo.com
[AuthService]   givenName: João
[AuthService]   familyName: Silva
[AuthService]   identityToken: PRESENT (1234 chars)
[AuthService] Calling Supabase signInWithIdToken (Apple)...
[AuthService] Supabase response:
[AuthService]   user: abc123-user-id
[AuthService]   session: PRESENT
[AuthService] Apple login successful for user: abc123-user-id
```

### 5.3 Erros Comuns e Soluções

| Erro | Causa | Solução |
|------|-------|---------|
| `identityToken is null` | App ID sem Sign In with Apple habilitado | Verifique **Capabilities** no App ID |
| `invalid_grant` / `invalid_token` | Services ID / Key ID / Team ID / Private Key errados | Confira **TODOS** os 4 campos no Supabase |
| `redirect_uri_mismatch` | URL de callback não bate | Supabase Redirect URLs = Apple Services ID Return URLs |
| `SignInWithAppleAuthorizationException: cancelled` | Usuário cancelou | Tratar como cancelamento normal (não é erro) |
| `invalid_client` no Android | Services ID não configurado | Configure Services ID + Return URLs |
| `Apple ID credential request failed` | Simulador iOS | **Teste apenas em device físico** |

### 5.4 Debug no Código

Adicione logs temporários no `AuthService.signInWithApple()` (já inclusos na versão atual):

```dart
debugPrint('[AuthService] Starting Apple Sign-In flow...');
debugPrint('[AuthService] Generated nonce (raw): $rawNonce');
debugPrint('[AuthService] Generated nonce (sha256): $nonce');
// ...etc
```

Execute com:
```bash
flutter run --dart-define=FLUTTER_WEB_AUTO_DETECT=true
# ou simplesmente
flutter run
```

Filtre logs:
```bash
adb logcat | grep -i "authservice\|apple\|supabase"
# iOS:
xcrun simctl spawn booted log stream --predicate 'process == "Runner"' --level debug
```

---

## 6. CHECKLIST FINAL (✅ = OK)

### Apple Developer Portal
- [ ] App ID criado com Bundle ID correto + **Sign In with Apple** habilitado
- [ ] Services ID criado + **Sign In with Apple** configurado
- [ ] Services ID: **Primary App ID** vinculado ao App ID do iOS
- [ ] Services ID: **Return URLs** = `https://SEU_PROJECT_REF.supabase.co/auth/v1/callback`
- [ ] Private Key (.p8) criada, baixada e Key ID anotado
- [ ] Team ID obtido

### Supabase Dashboard
- [ ] Provider **Apple** habilitado
- [ ] **Bundle ID** = `com.seuapp.somaai`
- [ ] **Team ID** = `ABCD123456`
- [ ] **Services ID** = `com.seuapp.somaai.web`
- [ ] **Key ID** = `ABCD1234`
- [ ] **Private Key** = conteúdo completo do `.p8`
- [ ] Redirect URLs incluem `somaai://auth/callback` e `https://SEU_PROJECT_REF.supabase.co/auth/v1/callback`

### Flutter / Xcode / Android
- [ ] `sign_in_with_apple: ^6.1.0` no `pubspec.yaml`
- [ ] `Info.plist`: `com.apple.developer.applesignin` + `CFBundleURLSchemes` (`somaai`, `com.seuapp.somaai`)
- [ ] Xcode: **Sign In with Apple** capability habilitada + Team correto
- [ ] Android: `AndroidManifest.xml` com intent-filter `somaai://auth/callback`
- [ ] `applicationId` no Gradle = Bundle ID iOS

### Testes
- [ ] Build iOS no device físico → Login Apple funciona
- [ ] Build Android no device físico → Login Apple abre web view → funciona
- [ ] Logs mostram `identityToken: PRESENT` e `Supabase response: user: ...`
- [ ] Usuário redirecionado para `AppShell` após login

---

## 7. COMANDOS ÚTEIS

```bash
# Limpar e rebuild
flutter clean && flutter pub get && flutter build ios --release

# Ver logs no Android
adb logcat -s "AuthService" "Flutter" "Supabase"

# Ver SHA-1 do keystore (para Google, não Apple)
keytool -list -v -keystore android/keystore.jks -alias somaai

# iOS - abrir Xcode
open ios/Runner.xcworkspace
```

---

## 8. REFERÊNCIAS OFICIAIS

- [Supabase - Apple Auth](https://supabase.com/docs/guides/auth/social-login/auth-apple)
- [Apple - Sign in with Apple](https://developer.apple.com/sign-in-with-apple/get-started/)
- [Flutter - sign_in_with_apple](https://pub.dev/packages/sign_in_with_apple)
- [Supabase - OAuth Providers](https://supabase.com/docs/guides/auth/social-login)

---

## 9. CONTATO / SUPORTE

Se após seguir **TODOS** os passos o erro persistir:

1. Cole os logs completos do terminal (`flutter run` + `adb logcat`)
2. Verifique se o erro é `AuthException` (código + mensagem) ou `SignInWithAppleAuthorizationException`
3. Confira se o **Bundle ID** no Xcode **exatamente** igual ao do Apple Developer Portal

> **Dica**: 90% dos problemas de Apple Login são **configuração incorreta no Supabase** (Services ID, Key ID ou Private Key errados). Revise com calma cada campo.

---

**Última atualização**: Outubro 2026  
**Versão do guia**: 1.0  
**App**: SomaAí