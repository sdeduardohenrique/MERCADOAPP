# Guia de Configuração de Autenticação Social e OTP — SomaAí

Este documento detalha **passo a passo** o que você deve configurar no **Supabase**, **Google Cloud Console** e **Apple Developer** para habilitar:

- ✅ Login com **Google** (OAuth 2.0 / OpenID Connect)
- ✅ Login com **Apple** (Sign in with Apple)
- ✅ Autenticação por **Telefone (OTP SMS)**

> ⚠️ **Importante**: A IA **não tem acesso** aos seus painéis. Você deve executar estes passos manualmente.

---

## 1️⃣ CONFIGURAÇÃO NO SUPABASE

### 1.1 Habilitar Provedores de Autenticação

1. Acesse o painel do Supabase: https://supabase.com/dashboard/project/**SEU_PROJECT_REF**/auth/providers
2. Para cada provedor abaixo, clique em **Enable** e preencha os campos:

#### 🔵 Google
| Campo | Valor |
|-------|-------|
| **Enabled** | ✅ Sim |
| **Client ID** | `SEU_GOOGLE_CLIENT_ID.apps.googleusercontent.com` (veja seção 2) |
| **Client Secret** | `SEU_GOOGLE_CLIENT_SECRET` (veja seção 2) |
| **Redirect URL** | `https://SEU_PROJECT_REF.supabase.co/auth/v1/callback` |
| **Scopes** | `openid email profile` |
| **Skip nonce check** | ❌ Não (mantenha seguro) |

#### 🍎 Apple
| Campo | Valor |
|-------|-------|
| **Enabled** | ✅ Sim |
| **Client ID (Services ID)** | `com.seudominio.somaai` (veja seção 3) |
| **Team ID** | `SEU_TEAM_ID` (Apple Developer) |
| **Key ID** | `SUA_KEY_ID` (veja seção 3) |
| **Private Key** | `-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----` (veja seção 3) |
| **Redirect URL** | `https://SEU_PROJECT_REF.supabase.co/auth/v1/callback` |

#### 📱 Phone (OTP SMS)
| Campo | Valor |
|-------|-------|
| **Enabled** | ✅ Sim |
| **Provider** | `Twilio` (padrão do Supabase) ou `Custom` |
| **Twilio Account SID** | `ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` |
| **Twilio Auth Token** | `your_auth_token` |
| **Twilio Phone Number** | `+15551234567` (formato E.164) |
| **OTP Expiry** | `600` (segundos = 10 min) |
| **Rate Limit** | `3` requisições por hora por IP/telefone |

> 💡 **Dica**: Se não quiser usar Twilio, use um provedor customizado (ex: Zenvia, TotalVoice, Vonage) configurando uma **Edge Function** no Supabase que recebe o webhook e chama `supabase.auth.admin.generateLink()`.

---

### 1.2 Configurar URL de Redirecionamento (Deep Link)

No painel **Authentication > URL Configuration**:

| Campo | Valor |
|-------|-------|
| **Site URL** | `https://seudominio.com` (ou `http://localhost:3000` para dev) |
| **Redirect URLs** (adicionar todas): |
| | `somaai://auth/callback` |
| | `somaai://reset-password` |
| | `https://SEU_PROJECT_REF.supabase.co/auth/v1/callback` |
| | `http://localhost:3000/auth/callback` (dev web) |

> ⚠️ O esquema `somaai://` deve ser registrado no **Android** (`AndroidManifest.xml`) e **iOS** (`Info.plist`).

---

### 1.3 Configurar SMTP (Email de Confirmação / Recuperação)

Em **Authentication > SMTP Settings**:

| Campo | Valor |
|-------|-------|
| **Enable custom SMTP** | ✅ Sim |
| **Host** | `smtp.resend.com` (ou SendGrid, Mailgun, AWS SES) |
| **Port** | `587` (TLS) ou `465` (SSL) |
| **User** | `resend` (ou seu user SMTP) |
| **Password** | `re_xxxxxxxxxxxxx` (sua API key) |
| **Sender email** | `noreply@seudominio.com` |
| **Sender name** | `SomaAí` |

> 💡 Teste enviando um email de recuperação de senha pelo painel.

---

## 2️⃣ GOOGLE CLOUD CONSOLE (Login com Google)

### 2.1 Criar Projeto / Selecionar Projeto

1. Acesse: https://console.cloud.google.com/
2. Crie um novo projeto ou selecione existente: **SomaAí Auth**

### 2.2 Configurar OAuth Consent Screen

1. **APIs & Services > OAuth consent screen**
2. **User Type**: External
3. Preencha:
   - **App name**: `SomaAí`
   - **User support email**: `seu@email.com`
   - **Developer contact**: `seu@email.com`
   - **Authorized domains**: `seudominio.com`, `supabase.co`
4. **Scopes**: Adicione `openid`, `email`, `profile`
5. **Test users**: Adicione seu email para testes (enquanto em "Testing")

### 2.3 Criar Credenciais OAuth 2.0

1. **APIs & Services > Credentials > Create Credentials > OAuth client ID**
2. **Application type**: **Web application** (para Supabase)
   - **Name**: `SomaAí Web (Supabase)`
   - **Authorized redirect URIs**:
     - `https://SEU_PROJECT_REF.supabase.co/auth/v1/callback`
   - Salve → Copie **Client ID** e **Client Secret** → Cole no Supabase (seção 1.1)

3. Crie **outro** OAuth client ID para **Android**:
   - **Application type**: Android
   - **Name**: `SomaAí Android`
   - **Package name**: `com.example.mercado_app` (seu `applicationId`)
   - **SHA-1 certificate fingerprint**: (veja abaixo como gerar)

4. Crie **outro** para **iOS**:
   - **Application type**: iOS
   - **Name**: `SomaAí iOS`
   - **Bundle ID**: `com.example.mercadoApp` (seu `PRODUCT_BUNDLE_IDENTIFIER`)

---

### 2.4 Gerar SHA-1 (Android)

**Debug (desenvolvimento):**
```bash
# Linux/macOS
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# Windows
keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android
```

**Release (produção):**
```bash
keytool -list -v -keystore caminho/para/seu/keystore.jks -alias seu_alias
```
> Copie o **SHA-1** e cole no Google Cloud Console (credencial Android).

---

### 2.5 Configurar `google-services.json` (Android)

1. No Firebase Console (ou Google Cloud), baixe o `google-services.json` do app Android.
2. Coloque em: `android/app/google-services.json`
3. No `android/build.gradle.kts` (ou `.gradle`), certifique-se que tem:
   ```kotlin
   id("com.google.gms.google-services") version "4.4.1" apply false
   ```
4. No `android/app/build.gradle.kts`:
   ```kotlin
   plugins { id("com.google.gms.google-services") }
   ```

---

### 2.6 Configurar `GoogleService-Info.plist` (iOS)

1. Baixe do Firebase/Google Cloud o `GoogleService-Info.plist` do app iOS.
2. No Xcode: arraste para `Runner/Runner/` (marque "Copy items if needed").
3. No `Info.plist`, adicione `URL Types`:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleURLSchemes</key>
       <array>
         <string>com.googleusercontent.apps.SEU_CLIENT_ID_INVERTIDO</string>
         <!-- Ex: com.googleusercontent.apps.123456789-abcdefghijklmnop -->
       </array>
     </dict>
   </array>
   ```

---

## 3️⃣ APPLE DEVELOPER (Sign in with Apple)

### 3.1 Configurar App ID

1. Acesse: https://developer.apple.com/account/resources/identifiers/list
2. Selecione seu App ID (`com.example.mercadoApp`)
3. Habilite **Sign In with Apple** → **Edit** → **Enable as a primary App ID**

### 3.2 Criar Services ID (para Web/Supabase)

1. **Identifiers > + > Services IDs**
2. **Description**: `SomaAí Web Auth`
3. **Identifier**: `com.seudominio.somaai` (ex: `com.somaai.app`)
4. ✅ **Sign In with Apple** → **Configure**
   - **Primary App ID**: selecione seu App ID
   - **Website URLs**:
     - **Domain**: `seudominio.com`
     - **Return URLs**: `https://SEU_PROJECT_REF.supabase.co/auth/v1/callback`
5. Salve → **Identifier** = `Client ID` para o Supabase (seção 1.1)

### 3.3 Criar Chave Privada (Key)

1. **Keys > + > Sign In with Apple**
2. **Key Name**: `SomaAí Auth Key`
3. Baixe o arquivo `.p8` (**só pode baixar uma vez!**) → Guarde seguro.
4. Anote o **Key ID** (ex: `ABC123XYZ`) → Cole no Supabase.

### 3.4 Obter Team ID

1. **Account > Membership** → **Team ID** (ex: `ABCD123456`) → Cole no Supabase.

### 3.5 Configurar no Xcode (iOS)

1. No Xcode: **Signing & Capabilities > + Capability > Sign In with Apple**
2. Verifique se o **Team** está correto.
3. No `Info.plist`, adicione:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleURLSchemes</key>
       <array>
         <string>com.seudominio.somaai</string>
       </array>
     </dict>
   </array>
   ```

---

## 4️⃣ CONFIGURAÇÃO NO FLUTTER (APP)

### 4.1 Android — `android/app/src/main/AndroidManifest.xml`

Adicione dentro de `<manifest>`:

```xml
<!-- Permissão para internet (já costuma existir) -->
<uses-permission android:name="android.permission.INTERNET" />

<!-- Intent filter para deep link somaai:// -->
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTop"
    android:theme="@style/LaunchTheme"
    android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
    android:hardwareAccelerated="true"
    android:windowSoftInputMode="adjustResize">

    <!-- Deep link para auth callback -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="somaai" android:host="auth" android:pathPrefix="/callback" />
    </intent-filter>

    <!-- Deep link para reset password -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="somaai" android:host="reset-password" />
    </intent-filter>

    <meta-data android:name="io.flutter.embedding.android.NormalTheme" android:resource="@style/NormalTheme" />
    <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
    </intent-filter>
</activity>
```

### 4.2 Android — `android/app/build.gradle.kts`

```kotlin
android {
    namespace = "com.example.mercado_app"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.example.mercado_app"
        minSdk = 24
        targetSdk = 34
        versionCode = 2004
        versionName = "1.0.0"
        
        // Para Google Sign-In
        resValue("string", "default_web_client_id", "SEU_WEB_CLIENT_ID.apps.googleusercontent.com")
    }

    signingConfigs {
        create("release") {
            storeFile = file("seu_keystore.jks")
            storePassword = "sua_senha"
            keyAlias = "seu_alias"
            keyPassword = "sua_senha"
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            minifyEnabled = true
            shrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

dependencies {
    implementation("com.google.android.gms:play-services-auth:21.0.0")
    implementation(platform("com.google.firebase:firebase-bom:33.1.0"))
    implementation("com.google.firebase:firebase-analytics")
}
```

### 4.3 iOS — `ios/Runner/Info.plist`

```xml
<!-- Deep Links -->
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>somaai</string>
      <string>com.googleusercontent.apps.SEU_CLIENT_ID_INVERTIDO</string>
      <string>com.seudominio.somaai</string>
    </array>
  </dict>
</array>

<!-- Sign in with Apple -->
<key>com.apple.developer.applesignin</key>
<array>
  <string>Default</string>
</array>

<!-- LSApplicationQueriesSchemes para Google Sign-In -->
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>googlechrome</string>
  <string>googlechrome-x-callback</string>
</array>
```

### 4.4 `pubspec.yaml` — Dependências já adicionadas

```yaml
dependencies:
  # ... existentes ...
  google_sign_in: ^6.2.1
  sign_in_with_apple: ^6.1.0
  pin_code_fields: ^8.0.1
```

> Rode `flutter pub get` após alterar.

---

## 5️⃣ TWILIO (SMS OTP) — Opcional se usar provedor próprio

### 5.1 Criar Conta Twilio

1. https://www.twilio.com/try-twilio
2. Verifique número de telefone → ganha $15 créditos trial.
3. No Console: **Account SID** + **Auth Token** → Copie para Supabase.

### 5.2 Comprar Número de Telefone

1. **Phone Numbers > Manage > Buy a number**
2. Escolha país **Brazil (+55)** → Tipo **SMS** → Compre.
3. Copie o número (formato E.164: `+5511999999999`) → Cole no Supabase.

### 5.3 Configurar Messaging Service (Recomendado)

1. **Messaging > Services > Create Messaging Service**
2. **Service Name**: `SomaAí OTP`
3. **Use case**: `One-time passwords`
4. Adicione o número comprado.
5. **Integration** → **Supabase** (ou use a API direta).

---

## 6️⃣ TESTES LOCAIS

### 6.1 Android Emulador / Device

```bash
flutter run --flavor dev
# ou
flutter run
```

Teste:
1. Abra app → LoginScreen
2. Clique **Continuar com o Google** → Deve abrir seletor de contas
3. Clique **Entrar com Celular** → Digite número → Receba SMS → Digite OTP
4. Verifique se navega para `AppShell`

### 6.2 iOS Simulador / Device

```bash
cd ios && pod install && cd ..
flutter run
```

> ⚠️ **Sign in with Apple NÃO funciona no simulador** (precisa de device físico).
> Google Sign-In funciona no simulador se configurado corretamente.

### 6.3 Logs Úteis

```bash
# Filtrar logs de auth
adb logcat | grep -i "somaai\|google\|auth\|supabase"

# iOS
xcrun simctl spawn booted log stream --predicate 'process == "Runner"' --level debug
```

---

## 7️⃣ CHECKLIST DE PRODUÇÃO

| Item | Status | Observação |
|------|--------|------------|
| [ ] Supabase: Google Provider habilitado + Client ID/Secret | ☐ | |
| [ ] Supabase: Apple Provider habilitado + Services ID/Key/Team | ☐ | |
| [ ] Supabase: Phone Provider habilitado + Twilio configurado | ☐ | |
| [ ] Supabase: Redirect URLs com `somaai://` | ☐ | |
| [ ] Supabase: SMTP customizado funcionando | ☐ | |
| [ ] Google Cloud: OAuth Consent Screen publicado (não "Testing") | ☐ | |
| [ ] Google Cloud: Web Client ID + Secret no Supabase | ☐ | |
| [ ] Google Cloud: Android SHA-1 (debug + release) | ☐ | |
| [ ] Google Cloud: iOS Bundle ID | ☐ | |
| [ ] Apple Developer: App ID com Sign In with Apple | ☐ | |
| [ ] Apple Developer: Services ID configurado | ☐ | |
| [ ] Apple Developer: Key .p8 baixada + Key ID no Supabase | ☐ | |
| [ ] Apple Developer: Team ID no Supabase | ☐ | |
| [ ] Xcode: Sign In with Apple capability | ☐ | |
| [ ] Android: `google-services.json` no projeto | ☐ | |
| [ ] Android: SHA-1 release no Google Cloud | ☐ | |
| [ ] Android: `android:scheme="somaai"` no Manifest | ☐ | |
| [ ] iOS: `CFBundleURLSchemes` com `somaai` | ☐ | |
| [ ] Twilio: Conta verificada + número + Messaging Service | ☐ | |
| [ ] Teste: Login Google em device Android | ☐ | |
| [ ] Teste: Login Apple em device iOS físico | ☐ | |
| [ ] Teste: OTP SMS recebido e verificado | ☐ | |
| [ ] Teste: Deep link `somaai://auth/callback` abre app | ☐ | |
| [ ] Teste: Recuperação de senha via email | ☐ | |

---

## 8️⃣ COMANDOS ÚTEIS

```bash
# Limpar e rebuild
flutter clean && flutter pub get && flutter build apk --release

# Ver SHA-1 do keystore de release
keytool -list -v -keystore android/keystore.jks -alias somaai

# Ver logs no device
adb logcat -s "SomaAí" "GoogleSignIn" "Supabase" "Flutter"

# iOS - abrir Xcode
open ios/Runner.xcworkspace
```

---

## 9️⃣ SUPORTE E DEBUG

### Erros Comuns

| Erro | Causa | Solução |
|------|-------|---------|
| `DEVELOPER_ERROR` (Google) | SHA-1 errado ou package name | Verifique SHA-1 no Google Cloud + `applicationId` no Gradle |
| `invalid_client` (Apple) | Services ID / Key / Team ID errados | Confira todos os 4 campos no Supabase |
| `redirect_uri_mismatch` | URL não bate | Supabase Redirect URLs = Google/Apple Authorized Redirect URIs |
| `OTP expired` | Código digitado após 10 min | Peça reenvio; aumente `OTP Expiry` no Supabase se necessário |
| `rate_limit_exceeded` (Phone) | Muitos SMS pro mesmo número | Aguarde 1h; configure rate limit no Supabase/Twilio |

### Logs de Debug no Código

Em `AuthService`, adicione logs temporários:
```dart
debugPrint('[Auth] Google ID Token: $idToken');
debugPrint('[Auth] Apple Identity Token: $identityToken');
debugPrint('[Auth] Phone normalized: $normalizedPhone');
```

---

## 🔟 PRÓXIMOS PASSOS (Pós-configuração)

1. **Teste completo** em devices Android + iOS físicos
2. **Configure Analytics** (Firebase/Amplitude) para trackear `sign_up`, `login`, `login_method`
3. **Implemente Analytics** no `AuthService`:
   ```dart
   // Exemplo
   FirebaseAnalytics.instance.logLogin(loginMethod: 'google');
   ```
4. **Adicione `deleteAccount`** via Edge Function com `service_role` (RLS não permite delete direto)
5. **Configure `apple_sign_in` entitlements** no `Runner.entitlements` (iOS)

---

---

**Dúvidas?** Consulte a documentação oficial:
- Supabase Auth: https://supabase.com/docs/guides/auth
- Google Sign-In Flutter: https://pub.dev/packages/google_sign_in
- Apple Sign-In Flutter: https://pub.dev/packages/sign_in_with_apple
- Twilio Verify: https://www.twilio.com/docs/verify/api