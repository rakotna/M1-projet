# Flutter-specific rules.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.embedding.android.**  { *; }
-keep class io.flutter.embedding.engine.**  { *; }
-keep class io.flutter.embedding.engine.plugins.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# TensorFlow Lite rules
-keep class org.tensorflow.lite.** { *; }
-keep class com.google.android.play.core.** { *; }
-keep class org.tensorflow.** { *; }
-dontwarn com.google.android.play.core.**
-dontwarn org.tensorflow.lite.gpu.**
