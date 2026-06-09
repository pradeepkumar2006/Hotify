# ============================================================
# ProGuard / R8 rules for Hotify (audio_service + just_audio)
# ============================================================

# --- Suppress warnings for missing Play Core classes (Flutter references them but they are optional) ---
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# --- Keep audio_service internals (notification, MediaBrowserService, etc.) ---
-keep class com.ryanheise.audioservice.** { *; }

# --- Keep AndroidX Media / MediaCompat classes used by audio_service ---
-keep class androidx.media.** { *; }
-keep class android.support.v4.media.** { *; }
-keep class androidx.media.app.NotificationCompat$MediaStyle { *; }
-keep class androidx.core.app.NotificationCompat** { *; }

# --- Keep MediaSession classes (needed for rich notification with album art & colored bg) ---
-keep class android.media.session.** { *; }
-keep class android.media.MediaMetadata { *; }
-keep class android.media.MediaMetadata$Builder { *; }

# --- Keep just_audio / ExoPlayer classes ---
-keep class com.ryanheise.just_audio.** { *; }
-keep class com.google.android.exoplayer2.** { *; }
-keep class androidx.media3.** { *; }

# --- Keep Flutter plugin registrant ---
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }

# --- General Flutter ---
-keep class io.flutter.app.** { *; }
-keep class io.flutter.embedding.** { *; }

# --- Firebase ---
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# --- Keep attributes for serialization ---
-keepattributes Signature
-keepattributes *Annotation*
