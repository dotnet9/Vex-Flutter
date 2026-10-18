# These entry points are loaded by the Android instrumentation framework.
# This file is only applied with -PvexReleaseTests=true, never to shipped APKs.
-keep class androidx.test.** { *; }
-keep class org.junit.** { *; }
-keep class dev.flutter.plugins.integration_test.** { *; }
-keep,includedescriptorclasses class io.flutter.embedding.android.FlutterActivity { *; }
-keep,includedescriptorclasses class io.flutter.embedding.android.FlutterView { *; }
-keep,includedescriptorclasses class io.flutter.embedding.engine.FlutterEngine { *; }
-keep,includedescriptorclasses interface io.flutter.embedding.engine.plugins.PluginRegistry { *; }
-keep class com.codewf.vex.MainActivityTest** { *; }
