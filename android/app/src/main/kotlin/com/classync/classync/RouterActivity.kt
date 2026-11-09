package com.classync.classync

import android.app.Activity
import android.content.Intent
import android.os.Bundle

/**
 * Holds MAIN/LAUNCHER for the package.
 *
 * flutter_local_notifications resolves its pending intent with
 * getLaunchIntentForPackage(), so whatever activity owns the launcher filter is
 * what a notification tap - and, more importantly, a full-screen intent -
 * actually opens. Routing it here is what lets an alert reach [AlertActivity]
 * instead of the dashboard.
 *
 * Notification launches carry the SELECT_NOTIFICATION action (the plugin
 * overwrites the launcher action before handing the intent to PendingIntent),
 * so that action is the only signal needed. A plain launcher tap, or anything
 * else, goes to the dashboard. This activity never draws: it forwards and
 * finishes in onCreate.
 */
class RouterActivity : Activity() {

    private companion object {
        /** FlutterLocalNotificationsPlugin.SELECT_NOTIFICATION. */
        const val SELECT_NOTIFICATION = "SELECT_NOTIFICATION"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        forward(intent)
        finish()
        @Suppress("DEPRECATION")
        overridePendingTransition(0, 0)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        forward(intent)
        finish()
        @Suppress("DEPRECATION")
        overridePendingTransition(0, 0)
    }

    private fun forward(intent: Intent?) {
        val fromAlert = intent?.action == SELECT_NOTIFICATION
        val next = if (fromAlert) {
            Intent(this, AlertActivity::class.java).apply {
                putExtra(
                    AlertActivity.EXTRA_PAYLOAD,
                    intent?.getStringExtra(AlertActivity.EXTRA_PAYLOAD),
                )
                // The alert should be there when the screen wakes, not slide in.
                addFlags(Intent.FLAG_ACTIVITY_NO_ANIMATION)
            }
        } else {
            Intent(this, MainActivity::class.java)
        }
        // MainActivity owns its own task, so it must be started as one.
        next.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(next)
    }
}
