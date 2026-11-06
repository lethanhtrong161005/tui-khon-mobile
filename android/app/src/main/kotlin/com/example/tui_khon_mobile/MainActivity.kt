package com.example.tui_khon_mobile

import android.content.Intent
import android.os.Bundle
import android.content.res.Configuration
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

// FlutterFragmentActivity is required by local_auth (biometric prompt).
class MainActivity : FlutterFragmentActivity() {
    private var widgetChannel: MethodChannel? = null
    private var pendingWidgetAction: Map<String, String>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        val savedId = savedInstanceState?.getString("widget_pending_id")
        val savedAction = savedInstanceState?.getString("widget_pending_action")
        if (savedId != null && savedAction in QuickRecordWidget.ACTIONS) {
            pendingWidgetAction = mapOf("id" to savedId, "action" to savedAction!!)
        }
        // Capture before the Dart engine starts. Remove the extra so Activity
        // recreation cannot replay an already consumed launch.
        captureWidgetAction(intent)
        super.onCreate(savedInstanceState)
    }

    override fun onSaveInstanceState(outState: Bundle) {
        pendingWidgetAction?.let {
            outState.putString("widget_pending_id", it["id"])
            outState.putString("widget_pending_action", it["action"])
        }
        super.onSaveInstanceState(outState)
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        QuickRecordWidget.updateAll(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        widgetChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "tui_khon/home_widget").also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "takePendingAction" -> {
                        val action = pendingWidgetAction
                        pendingWidgetAction = null
                        result.success(action)
                    }
                    "clearPendingAction" -> {
                        pendingWidgetAction = null
                        result.success(null)
                    }
                    "updateAppearance" -> {
                        QuickRecordWidget.updateAppearance(this, call.arguments as? Map<*, *>)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureWidgetAction(intent)
        widgetChannel?.invokeMethod("actionAvailable", null)
    }

    private fun captureWidgetAction(intent: Intent?) {
        val action = intent?.getStringExtra(QuickRecordWidget.EXTRA_ACTION)
        intent?.removeExtra(QuickRecordWidget.EXTRA_ACTION)
        if (action !in QuickRecordWidget.ACTIONS) return
        pendingWidgetAction = mapOf("id" to UUID.randomUUID().toString(), "action" to action!!)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        widgetChannel?.setMethodCallHandler(null)
        widgetChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
