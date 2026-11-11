package com.classync.classync

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.ColorStateList
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.Typeface
import android.os.Build
import android.text.Spannable
import android.text.SpannableStringBuilder
import android.text.style.ForegroundColorSpan
import android.text.style.StyleSpan
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

/**
 * The full-width, 2-row home-screen widget: the class running now and the next.
 *
 * Dart owns the data (lib/widget/widget_sync.dart): it serializes the whole
 * week into one JSON snapshot and hands it over the `classync/widget` channel,
 * which stores it in SharedPreferences below. The provider never needs the
 * Flutter process: it renders straight from the snapshot and re-arms an exact
 * alarm for the next boundary (a class start or end), so "now"/"next" roll
 * over on their own across launcher kills and reboots.
 */
class ClassWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        super.onUpdate(context, manager, ids)
        refresh(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        // Covers BOOT_COMPLETED, MY_PACKAGE_REPLACED and [ACTION_REFRESH];
        // harmless duplication for APPWIDGET_* broadcasts handled by super.
        refresh(context)
    }

    companion object {
        private const val PREFS_NAME = "classync_widget"
        private const val SNAPSHOT_KEY = "snapshot"
        private const val ACTION_REFRESH = "com.classync.classync.WIDGET_REFRESH"
        private const val REQUEST_CODE = 6314

        /** Calendar.DAY_OF_WEEK -> the schedule key used in the snapshot. */
        private val WEEK_DAY = mapOf(
            Calendar.SUNDAY to "Sun",
            Calendar.MONDAY to "Mon",
            Calendar.TUESDAY to "Tue",
            Calendar.WEDNESDAY to "Wed",
            Calendar.THURSDAY to "Thu",
            Calendar.FRIDAY to "Fri",
            Calendar.SATURDAY to "Sat",
        )

        private fun prefs(context: Context): SharedPreferences =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        /** Stores a snapshot produced by WidgetSync and redraws right away. */
        fun push(context: Context, json: String) {
            prefs(context).edit().putString(SNAPSHOT_KEY, json).apply()
            refresh(context)
        }

        /** Drops the snapshot; the widget falls back to its placeholder. */
        fun clear(context: Context) {
            prefs(context).edit().remove(SNAPSHOT_KEY).apply()
            refresh(context)
        }

        private fun widgetIds(context: Context): IntArray =
            AppWidgetManager.getInstance(context).getAppWidgetIds(
                ComponentName(context, ClassWidgetProvider::class.java)
            )

        private fun refresh(context: Context) {
            val ids = widgetIds(context)
            if (ids.isEmpty()) return
            val snapshot = prefs(context).getString(SNAPSHOT_KEY, null)
            AppWidgetManager.getInstance(context).updateAppWidget(ids, buildViews(context, snapshot))
            scheduleNext(context, snapshot)
        }

        // ---- Rendering ----

        private class Slot(
            val start: String,
            val startMinute: Int,
            val end: String,
            val endMinute: Int,
            val course: String,
            val teacher: String,
            val room: String,
        )

        private fun minutes(hhmm: String): Int =
            hhmm.substring(0, 2).toInt() * 60 + hhmm.substring(3).toInt()

        private fun parseDay(raw: JSONArray?): List<Slot> {
            if (raw == null) return emptyList()
            val out = mutableListOf<Slot>()
            for (i in 0 until raw.length()) {
                val o = raw.optJSONObject(i) ?: continue
                val start = o.optString("s")
                val end = o.optString("e")
                // Dart validated both as HH:mm with start < end.
                out.add(
                    Slot(
                        start, minutes(start),
                        end, minutes(end),
                        o.optString("c"), o.optString("t"), o.optString("r"),
                    )
                )
            }
            return out
        }

        /** "NOW" in the accent + the rest dimmer, in one line. */
        private fun labeled(label: String, rest: String, accent: Int, dim: Int): CharSequence {
            val sb = SpannableStringBuilder(label)
            sb.setSpan(ForegroundColorSpan(accent), 0, label.length, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE)
            sb.setSpan(StyleSpan(Typeface.BOLD), 0, label.length, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE)
            if (rest.isNotEmpty()) {
                sb.append("  ").append(rest)
                sb.setSpan(ForegroundColorSpan(dim), label.length, sb.length, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE)
            }
            return sb
        }

        private fun buildViews(context: Context, snapshot: String?): RemoteViews {
            val rv = RemoteViews(context.packageName, R.layout.class_widget)

            // The snapshot carries the app's actual Material 3 palette for
            // both modes, so the widget is literally the app's theme and dark
            // mode is the soft M3 dark surface, not pure black. The
            // configuration-resourced pairs below are only a fallback.
            val configNight =
                (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
                        Configuration.UI_MODE_NIGHT_YES

            // Parse fails leave the placeholder text; editing the routine in the
            // app overwrites the snapshot shortly afterwards anyway.
            val root = runCatching { snapshot?.let(::JSONObject) }.getOrNull()
            val days = root?.optJSONObject("days")
            val themePref = root?.optString("theme", "system") ?: "system"
            val effectiveDark = when (themePref) {
                "light" -> false
                "dark" -> true
                else -> configNight
            }
            val scheme = root?.optJSONObject("palette")
                ?.optJSONObject(if (effectiveDark) "dark" else "light")

            fun snapColor(name: String, fallback: Int): Int =
                scheme?.optString(name)
                    ?.takeIf { it.isNotEmpty() }
                    ?.let { runCatching { Color.parseColor(it) }.getOrNull() }
                    ?: fallback

            val onBg = snapColor(
                "onBg",
                context.getColor(
                    if (effectiveDark) R.color.widget_on_bg_dark else R.color.widget_on_bg_light
                ),
            )
            val dim = snapColor(
                "dim",
                context.getColor(
                    if (effectiveDark) R.color.widget_dim_dark else R.color.widget_dim_light
                ),
            )
            val accent = snapColor(
                "accent",
                context.getColor(
                    if (effectiveDark) R.color.widget_accent_dark else R.color.widget_accent_light
                ),
            )
            val bgColor = scheme?.optString("bg")
                ?.takeIf { it.isNotEmpty() }
                ?.let { runCatching { Color.parseColor(it) }.getOrNull() }
            if (bgColor != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // The exact scheme color wins: an SRC_IN tint over the opaque
                // shape replaces its solid while the drawable keeps the corners.
                rv.setColorStateList(
                    R.id.widgetRoot,
                    "setBackgroundTintList",
                    ColorStateList.valueOf(bgColor),
                )
            } else {
                rv.setInt(
                    R.id.widgetRoot, "setBackgroundResource",
                    if (effectiveDark) R.drawable.widget_bg_dark else R.drawable.widget_bg,
                )
            }

            if (root == null || days == null) {
                rv.setTextViewText(R.id.nowLine, labeled("CLASYNC", "", dim, dim))
                rv.setTextViewText(R.id.nowMain, "Open ClasSync")
                rv.setTextColor(R.id.nowMain, onBg)
                rv.setTextViewText(R.id.nextLine, "")
                rv.setViewVisibility(R.id.nextLine, android.view.View.GONE)
            } else {
                val now = Calendar.getInstance()
                val minute = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
                val slots = parseDay(days.optJSONArray(WEEK_DAY[now.get(Calendar.DAY_OF_WEEK)]))
                val running = slots.firstOrNull { it.startMinute <= minute && minute < it.endMinute }
                val next = slots.firstOrNull { it.startMinute > minute }

                if (running != null) {
                    rv.setTextViewText(R.id.nowLine, labeled("NOW", "${running.start}–${running.end}", accent, dim))
                    rv.setTextViewText(R.id.nowMain, running.course)
                    rv.setTextColor(R.id.nowMain, onBg)
                    if (next != null) {
                        val detail = listOf(next.course, next.room, next.start)
                            .filter { it.isNotBlank() }.joinToString(" · ")
                        rv.setTextViewText(R.id.nextLine, labeled("NEXT", detail, accent, dim))
                        rv.setViewVisibility(R.id.nextLine, android.view.View.VISIBLE)
                    } else {
                        rv.setViewVisibility(R.id.nextLine, android.view.View.GONE)
                    }
                } else if (next != null) {
                    rv.setTextViewText(R.id.nowLine, labeled("NEXT", next.start, accent, dim))
                    rv.setTextViewText(R.id.nowMain, next.course)
                    rv.setTextColor(R.id.nowMain, onBg)
                    rv.setTextViewText(R.id.nextLine, "")
                    rv.setViewVisibility(R.id.nextLine, android.view.View.GONE)
                } else {
                    val headline = if (slots.isEmpty()) "No classes today" else "No classes left today"
                    rv.setTextViewText(R.id.nowLine, "")
                    rv.setTextViewText(R.id.nowMain, headline)
                    rv.setTextColor(R.id.nowMain, onBg)
                    rv.setTextViewText(R.id.nextLine, "")
                    rv.setViewVisibility(R.id.nextLine, android.view.View.GONE)
                }
            }

            // Tapping the widget opens the dashboard (RouterActivity forwards on).
            rv.setOnClickPendingIntent(
                R.id.widgetRoot,
                PendingIntent.getActivity(
                    context,
                    0,
                    Intent(context, RouterActivity::class.java)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )
            return rv
        }

        // ---- Scheduling ----

        private fun dayAt(base: Calendar, offsetDays: Int): Calendar =
            (base.clone() as Calendar).apply {
                add(Calendar.DAY_OF_YEAR, offsetDays)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }

        /** A date-only calendar plus a minute-of-day -> an epoch instant. */
        private fun atMinute(date: Calendar, minuteOfDay: Int): Long =
            date.timeInMillis + minuteOfDay * 60_000L

        /**
         * Picks the next moment the widget changes appearance: every class
         * start or end left today, otherwise the first class of the following
         * days, otherwise a midnight re-render for the day roll.
         */
        private fun scheduleNext(context: Context, snapshot: String?) {
            val days = runCatching {
                snapshot?.let { JSONObject(it).optJSONObject("days") }
            }.getOrNull()
            if (days == null) return // Nothing to render until the app pushes.

            val base = Calendar.getInstance()
            var trigger: Long? = null

            for (offset in 0 until 8) {
                val date = dayAt(base, offset)
                val slots = runCatching {
                    parseDay(days.optJSONArray(WEEK_DAY[date.get(Calendar.DAY_OF_WEEK)]))
                }.getOrNull() ?: emptyList()
                trigger = if (slots.isEmpty()) {
                    null
                } else if (offset == 0) {
                    slots.flatMap {
                        listOf(atMinute(date, it.startMinute), atMinute(date, it.endMinute))
                    }.filter { it > System.currentTimeMillis() }.minOrNull()
                } else {
                    atMinute(date, slots.first().startMinute)
                }
                if (trigger != null) break
            }

            // A schedule week with zero classes at all: re-render after midnight
            // only, so the greeting rolls over to the new day.
            if (trigger == null) {
                val tomorrow = dayAt(base, 1).timeInMillis + 2 * 60_000L
                if (tomorrow > System.currentTimeMillis()) trigger = tomorrow
            }
            if (trigger == null) return

            val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val canExact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
                alarms.canScheduleExactAlarms()
            val pending = PendingIntent.getBroadcast(
                context,
                REQUEST_CODE,
                Intent(context, ClassWidgetProvider::class.java).setAction(ACTION_REFRESH),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            if (canExact) alarms.setExactAndAllowWhileIdle(AlarmManager.RTC, trigger, pending)
            else alarms.set(AlarmManager.RTC, trigger, pending)
        }
    }
}
