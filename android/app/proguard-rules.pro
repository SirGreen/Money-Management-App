# Rules for Google ML Kit Text Recognition
-keep class com.google.mlkit.vision.text.chinese.** { *; }
-keep class com.google.mlkit.vision.text.devanagari.** { *; }
-keep class com.google.mlkit.vision.text.japanese.** { *; }
-keep class com.google.mlkit.vision.text.korean.** { *; }

# You can also add the -dontwarn rules to suppress any related warnings
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

-keep class * extends io.hive.TypeAdapter {
    *;
}

# Example for a hypothetical encryption library
-keep class com.example.encryption.** { *; }

# Keep your app's models (VERY IMPORTANT for Hive/serialization)
# Replace 'com.example.test_app' with your actual package name.
-keep class com.example.test_app.models.** { *; }