package com.fitapp.fitapp

import io.flutter.embedding.android.FlutterFragmentActivity

/**
 * FlutterFragmentActivity is required by the Health Connect permission
 * contract. Health Connect's rationale / permission-usage intents open the
 * in-app privacy screen.
 */
class MainActivity : FlutterFragmentActivity() {
    override fun getInitialRoute(): String? {
        return when (intent?.action) {
            "androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE",
            "android.intent.action.VIEW_PERMISSION_USAGE" -> "/privacy"
            else -> super.getInitialRoute()
        }
    }
}
