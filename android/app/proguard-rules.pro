# ============================================================================
# SomaAí — regras ProGuard/R8 para o build de release
#
# Sem estas regras o R8 pode remover classes acessadas por reflexão/JNI
# (plugins do Flutter, ML Kit, Supabase e shared_preferences via JNI),
# resultando em crash silencioso ou tela preta na abertura.
# ============================================================================

# --- Flutter core & plugins -------------------------------------------------
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.** { *; }

# Handlers de plugin chamados por reflexão a partir do engine
-keep class * implements io.flutter.plugin.common.MethodChannel$MethodCallHandler { *; }
-keep class * extends io.flutter.plugin.common.MethodChannel$MethodCallHandler { *; }

# shared_preferences 2.5+ chama métodos Kotlin suspend via JNI. O R8 renomeava
# o tipo do parâmetro Continuation (assinatura virava "(...Lse;)..."), causando
# NoSuchMethodError no release. `includedescriptorclasses` preserva também os
# tipos usados nas assinaturas dos métodos que mantemos.
-keepclasseswithmembers,includedescriptorclasses class io.flutter.plugins.sharedpreferences.** { *; }
-keepclasseswithmembers,includedescriptorclasses class io.flutter.plugins.** { *; }
-keep class kotlin.coroutines.Continuation { *; }
-keep class kotlin.coroutines.** { *; }
-keep class kotlin.jvm.internal.** { *; }
-keep class kotlin.Result { *; }
-keep class kotlin.Result$* { *; }
-keep class kotlin.Unit { *; }
-keep class kotlin.Triple { *; }
-keep class kotlin.Pair { *; }
-keep class kotlinx.coroutines.** { *; }
-keepattributes RuntimeVisibleAnnotations,RuntimeVisibleParameterAnnotations,AnnotationDefault

# --- ML Kit / Google Play Services -----------------------------------------
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**

# --- Supabase ---------------------------------------------------------------
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**

# --- JNI (shared_preferences_android / path_provider_android usam jni) ------
-keep class com.github.dart_lang.jni.** { *; }
-keepclasseswithmembernames class * {
    native <methods>;
}

# --- Metadados usados por anotação/reflexão --------------------------------
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
-keepattributes RuntimeVisibleAnnotations,RuntimeVisibleParameterAnnotations
-keepattributes AnnotationDefault,Exceptions

# --- OCR: recognizers de scripts que o app não usa --------------------------
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# --- Play Core split install (não usado neste APK) --------------------------
-dontwarn com.google.android.play.core.**
