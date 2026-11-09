package com.classync.classync

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import org.json.JSONException
import org.json.JSONObject

/**
 * The lock-screen alert: one glanceable line over the keyguard, gone in twenty
 * seconds.
 *
 * This is deliberately a plain [Activity] and not a Flutter route.
 * flutter_local_notifications builds its pending intent from
 * getLaunchIntentForPackage(), and a full-screen intent waits for the first
 * frame, so a Flutter screen would spend about a second booting the engine.
 * A native window draws immediately, and it cannot show the timetable by
 * accident.
 */
class AlertActivity : Activity() {

    companion object {
        /** Same key the notification plugin puts on the pending intent. */
        const val EXTRA_PAYLOAD = "payload"

        private const val AUTO_DISMISS_MS = 20_000L

        /** Ignore the touch that woke the screen; the next one dismisses. */
        private const val TOUCH_GUARD_MS = 400L
    }

    private val handler = Handler(Looper.getMainLooper())
    private val dismiss = Runnable { close() }

    private var ignoreTouchesUntil = 0L

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_alert)
        showOverKeyguard()
        installDismissGesture()
        bind(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        bind(intent)
    }

    override fun onDestroy() {
        handler.removeCallbacks(dismiss)
        super.onDestroy()
    }

    /** Real, visible over the keyguard, and awake long enough to be read. */
    private fun showOverKeyguard() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    /** Tap anywhere, or swipe: either one dismisses. Always returns consumed. */
    @SuppressLint("ClickableViewAccessibility")
    private fun installDismissGesture() {
        findViewById<View>(R.id.alert_root).setOnTouchListener { _, event ->
            if (event.actionMasked == MotionEvent.ACTION_UP &&
                SystemClock.elapsedRealtime() >= ignoreTouchesUntil
            ) {
                close()
            }
            true
        }
    }

    /** Reads the two lines and restarts the auto-dismiss clock. */
    private fun bind(intent: Intent?) {
        val payload = intent?.getStringExtra(EXTRA_PAYLOAD)

        findViewById<TextView>(R.id.alert_title).text =
            payloadField(payload, "t") ?: getString(R.string.alert_fallback_title)

        val body = findViewById<TextView>(R.id.alert_body)
        val time = payloadField(payload, "b")
        body.text = time
        body.visibility = if (time == null) View.GONE else View.VISIBLE

        ignoreTouchesUntil = SystemClock.elapsedRealtime() + TOUCH_GUARD_MS
        handler.removeCallbacks(dismiss)
        handler.postDelayed(dismiss, AUTO_DISMISS_MS)
    }

    private fun payloadField(payload: String?, key: String): String? {
        if (payload.isNullOrEmpty()) return null
        return try {
            JSONObject(payload).optString(key).ifBlank { null }
        } catch (e: JSONException) {
            null
        }
    }

    private fun close() {
        handler.removeCallbacks(dismiss)
        finishAndRemoveTask()
    }
}
