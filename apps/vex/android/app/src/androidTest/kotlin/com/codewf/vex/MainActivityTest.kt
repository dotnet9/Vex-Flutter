package com.codewf.vex

import androidx.test.rule.ActivityTestRule
import dev.flutter.plugins.integration_test.FlutterTestRunner
import dev.flutter.plugins.integration_test.IntegrationTestPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterView
import org.junit.Rule
import org.junit.runner.RunWith

@RunWith(FlutterTestRunner::class)
class MainActivityTest {
    @Rule
    @JvmField
    val rule = object : ActivityTestRule<MainActivity>(MainActivity::class.java, true, false) {
        override fun afterActivityLaunched() {
            val engine = requireNotNull(
                activity.findViewById<FlutterView>(FlutterActivity.FLUTTER_VIEW_ID).attachedFlutterEngine
            )
            if (!engine.plugins.has(IntegrationTestPlugin::class.java)) {
                activity.runOnUiThread { engine.plugins.add(IntegrationTestPlugin()) }
            }
        }
    }
}
