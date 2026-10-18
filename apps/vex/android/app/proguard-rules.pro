# shared_preferences_android 2.5 uses JNI lookups by exact class, method and
# parameter names. R8 cannot discover those references inside Dart AOT code.
-keep,includedescriptorclasses class io.flutter.plugins.sharedpreferences.** { *; }
# The JNI coroutine bridge also resolves these Kotlin runtime types from Dart.
-keep class kotlin.coroutines.** { *; }
-keep class kotlin.Result** { *; }
-keep class kotlin.Unit { *; }
