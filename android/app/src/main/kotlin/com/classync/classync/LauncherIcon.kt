package com.classync.classync

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager

/**
 * The launcher icon's background follows the accent swatch. The manifest
 * carries one activity alias per swatch, each pointing at RouterActivity
 * with its own icon; exactly one is enabled at a time, and the launcher
 * renders that one. Enable/disable runs with DONT_KILL_APP so the process
 * keeps running, but a switch can still be heavy on some launchers, so the
 * caller only invokes it when the accent actually changed.
 */
object LauncherIcon {
    private val aliases = mapOf(
        "blue" to ".IconBlue",
        "indigo" to ".IconIndigo",
        "teal" to ".IconTeal",
        "green" to ".IconGreen",
        "orange" to ".IconOrange",
        "pink" to ".IconPink",
        "purple" to ".IconPurple",
    )

    /**
     * Enables the alias for [accent], disables the rest. Returns true when
     * anything changed - pending alert intents keep the alias component they
     * were created with, so the caller re-runs the alert reschedule then.
     */
    fun setAccent(context: Context, accent: String): Boolean {
        val wanted = aliases[accent] ?: aliases.getValue("teal")
        val pm = context.packageManager
        var changed = false
        for ((_, alias) in aliases) {
            val component = ComponentName(context.packageName, context.packageName + alias)
            val active = alias == wanted
            val setting = pm.getComponentEnabledSetting(component)
            // DEFAULT means the manifest value: true only for the teal alias.
            val enabled =
                setting == PackageManager.COMPONENT_ENABLED_STATE_ENABLED ||
                    (setting == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT &&
                        alias == aliases.getValue("teal"))
            if (enabled == active) continue
            pm.setComponentEnabledSetting(
                component,
                if (active) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP,
            )
            changed = true
        }
        return changed
    }
}
