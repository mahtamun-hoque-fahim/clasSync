package com.classync.classync

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.os.Build
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

/**
 * The 250dp x 180dp home-screen widget: the class running now and the next one.
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
            AppWidgetManager.getInstance(context)
                .updateAppWidget(ids, buildViews(context, prefs(context).getString(SNAPSHOT_KEY, null)))
            scheduleNext(context, prefs(context).getString(SNAPSHOT_KEY, null))
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
                // Dart validated both as HH:mm and start < end.
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

        private fun detail(teacher: String, room: String, time: String): String {
            val parts = listOf(teacher, room).filter { it.isNotBlank() }
            return (parts.joinToString(" · ") + " · " + time).trim(' ', '·')
        }

        private fun buildViews(context: Context, snapshot: String?): RemoteViews {
            val rv = RemoteViews(context.packageName, R.layout.class_widget)
            val night =
                (context.resources.configuration.uiMode and
                        android.content.res.Configuration.UI_MODE_NIGHT_MASK) ==
                        android.content.res.Configuration.UI_MODE_NIGHT_YES
            rv.setInt(
                R.id.widgetRoot, "setBackgroundResource",
                if (night) R.drawable.widget_bg_night else R.drawable.widget_bg,
            )
            val onBg = context.getColor(R.color.widget_on_bg)
            val dim = context.getColor(R.color.widget_dim)

            // Parse fails leave the placeholder text; editing the routine in the
            // app overwrites the snapshot shortly afterwards anyway.
            val days = runCatching {
                snapshot?.let { JSONObject(it).optJSONObject("days") }
            }.getOrNull()

            var accent = if (night) 0xFF7ED9CE.toInt() else Color.parseColor("#006A60")
            val slots: List<Slot>
            if (days != null) {
                val raw = JSONObject(snapshot!!).optString("accent")
                accent = runCatching { Color.parseColor(raw) }.getOrDefault(accent)
                val darkRaw = JSONObject(snapshot).optString("accentOnDark")
                if (night && darkRaw.isNotEmpty()) {
                    accent = runCatching { Color.parseColor(darkRaw) }.getOrDefault(accent)
                }
                slots = parseDay(days.optJSONArray(WEEK_DAY[today().get(Calendar.DAY_OF_WEEK)]))
            } else {
                slots = emptyList()
            }

            val now = Calendar.getInstance()
            val minute = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
            val running = slots.firstOrNull { it.startMinute <= minute && minute < it.endMinute }
            val next = slots.firstOrNull { it.startMinute > minute }

            if (days == null) {
                rv.setTextViewText(R.id.nowLabel, "CLASYNC")
                rv.setTextViewText(R.id.nowMain, "Open ClasSync")
                rv.setTextViewText(R.id.nowSub, "Your routine has not reached the widget yet")
                rv.setTextColor(R.id.nowLabel, dim)
                rv.setTextColor(R.id.nowMain, onBg)
                rv.setTextColor(R.id.nowSub, dim)
                rv.setViewVisibility(R.id.nextRow, android.view.View.GONE)
                return rv
            }

            if (running != null) {
                rv.setTextViewText(R.id.nowLabel, "NOW")
                rv.setTextViewText(R.id.nowMain, running.course)
                rv.setTextViewText(
                    R.id.nowSub,
                    detail(running.teacher, running.room, "${running.start}–${running.end}"),
                )
                rv.setTextColor(R.id.nowLabel, accent)
                rv.setTextColor(R.id.nowMain, onBg)
                rv.setTextColor(R.id.nowSub, dim)
            } else {
                val headline = when {
                    next != null -> "Next class"
                    slots.isEmpty() -> "No classes today"
                    else -> "No classes left today"
                }
                rv.setTextViewText(R.id.nowLabel, "")
                rv.setTextViewText(R.id.nowMain, headline)
                if (next != null) rv.setTextViewText(
                    R.id.nowSub,
                    "${next.course} at ${next.start} · ${next.room}",
                ) else rv.setTextViewText(R.id.nowSub, "")
                rv.setTextColor(R.id.nowMain, onBg)
                rv.setTextColor(R.id.nowSub, dim)
            }

            if (next != null) {
                rv.setViewVisibility(R.id.nextRow, android.view.View.VISIBLE)
                rv.setTextViewText(R.id.nextLabel, "NEXT")
                rv.setTextViewText(R.id.nextMain, next.course)
                rv.setTextViewText(
                    R.id.nextSub,
                    detail(next.teacher, next.room, "${next.start}–${next.end}"),
                )
                rv.setTextColor(R.id.nextLabel, accent)
                rv.setTextColor(R.id.nextMain, onBg)
                rv.setTextColor(R.id.nextSub, dim)
            } else {
                rv.setViewVisibility(R.id.nextRow, android.view.View.GONE)
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

        private fun today(): Calendar = Calendar.getInstance()

        // ---- Scheduling ----

        private fun dayAt(base: Calendar, offsetDays: Int): Calendar =
            (base.clone() as Calendar).apply {
                add(Calendar.DAY_OF_YEAR, offsetDays)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }

        /** Midnight-less epochs: the calendar stays a date, minutes are added. */
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
