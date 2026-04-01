# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Supabase / GoTrue / PostgREST
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**

# Google Sign-In
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# In-App Billing
-keep class com.android.vending.billing.** { *; }

# RevenueCat
-keep class com.revenuecat.purchases.** { *; }
-dontwarn com.revenuecat.purchases.**

# Google Play Core (deferred components referenced by Flutter engine)
-dontwarn com.google.android.play.core.**

# Keep annotations
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keepattributes Signature
-keepattributes Exceptions

# Gson / JSON serialization (if used by plugins)
-keep class com.google.gson.** { *; }
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# OkHttp (used by some plugins)
-dontwarn okhttp3.**
-dontwarn okio.**

# Kotlin
-keep class kotlin.** { *; }
-dontwarn kotlin.**

# Stripe (flutter_stripe)
-keep class com.stripe.android.** { *; }
-dontwarn com.stripe.android.**
-keep class com.reactnativestripesdk.** { *; }
-dontwarn com.reactnativestripesdk.**

# Kotlin Coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembernames class kotlinx.** {
    volatile <fields>;
}
-dontwarn kotlinx.coroutines.**

# Kotlinx Serialization
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
-keepclassmembers class kotlinx.serialization.json.** {
    *** Companion;
}
-keepclasseswithmembers class kotlinx.serialization.** {
    kotlinx.serialization.KSerializer serializer(...);
}

# Ktor (used by Supabase)
-keep class io.ktor.** { *; }
-dontwarn io.ktor.**

# home_widget
-keep class es.antonborri.home_widget.** { *; }
-dontwarn es.antonborri.home_widget.**

# speech_to_text
-keep class com.csdcorp.speech_to_text.** { *; }
-dontwarn com.csdcorp.speech_to_text.**

# Suppress R8 warnings for missing Play Store classes
-dontwarn com.google.android.play.**
