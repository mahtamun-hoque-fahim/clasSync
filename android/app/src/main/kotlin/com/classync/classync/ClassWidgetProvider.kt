package com.classync.classync

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RectF
import android.graphics.Typeface
import android.os.Build
import android.text.Spannable
import android.text.SpannableStringBuilder
import android.text.style.ForegroundColorSpan
import android.text.style.StyleSpan
import android.widget.ImageView
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

        /** One frozen state card point: minute-of-day + the full card text. */
        private class Point(
            val minute: Int,
            val title: String,
            val subtitle: String,
            val icon: String,
        )

        private fun parseTimeline(raw: JSONObject?): Map<String, List<Point>> {
            if (raw == null) return emptyMap()
            val out = mutableMapOf<String, List<Point>>()
            val keys = raw.keys()
            while (keys.hasNext()) {
                val date = keys.next()
                val list = mutableListOf<Point>()
                val arr = raw.optJSONArray(date) ?: continue
                for (i in 0 until arr.length()) {
                    val o = arr.optJSONObject(i) ?: continue
                    list.add(
                        Point(
                            o.optInt("m"),
                            o.optString("t"),
                            o.optString("s"),
                            o.optString("i"),
                        )
                    )
                }
                out[date] = list
            }
            return out
        }

        /** yyyy-MM-dd of a calendar, matching the timeline keys from Dart. */
        private fun dateKey(cal: Calendar): String {
            fun two(v: Int) = v.toString().padStart(2, '0')
            return "${cal.get(Calendar.YEAR)}-${two(cal.get(Calendar.MONTH) + 1)}-${two(cal.get(Calendar.DAY_OF_MONTH))}"
        }

        /** The state card active at [minute] on [date], or null. */
        private fun pointAt(timeline: Map<String, List<Point>>, date: Calendar, minute: Int): Point? {
            val day = timeline[dateKey(date)] ?: return null
            return day.lastOrNull { it.minute <= minute }
        }

        /**
         * The icon tile: the accent gradient (70% top, full accent bottom,
         * the app's reference formula) rounded, with the state's white glyph
         * drawn over it. One bitmap, so RemoteViews carries it whole.
         */
        private fun iconTile(context: Context, icon: String, accent: Int): Bitmap? {
            val res = context.resources
            val id = res.getIdentifier("state_$icon", "drawable", context.packageName)
                .takeIf { it != 0 } ?: return null
            val density = res.displayMetrics.density
            val size = (64 * density).toInt().coerceAtLeast(1)
            val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            val radius = size * 0.28f

            val top = Color.argb((0.7f * 255).toInt(), Color.red(accent), Color.green(accent), Color.blue(accent))
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = android.graphics.LinearGradient(
                    0f, 0f, 0f, size.toFloat(),
                    top, accent,
                    android.graphics.Shader.TileMode.CLAMP,
                )
            }
            canvas.drawRoundRect(RectF(0f, 0f, size.toFloat(), size.toFloat()), radius, radius, paint)

            // The glyph keeps its own white gradient; drawn inside with padding.
            // A plain PNG needs no AppCompat inflater, so the platform API does.
            val glyph = context.getDrawable(id) ?: return null
            val pad = (size * 0.18f).toInt()
            val src = android.graphics.Rect(0, 0, glyph.intrinsicWidth, glyph.intrinsicHeight)
            val dst = android.graphics.Rect(pad, pad, size - pad, size - pad)
            glyph.bounds = dst
            glyph.draw(canvas)
            return bitmap
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

            // The snapshot's palette comes from the app's Material 3 scheme;
            // the configuration-resourced colors below are only a fallback.

            // Parse fails leave the placeholder text; editing the routine in the
            // app overwrites the snapshot shortly afterwards anyway.
            val root = runCatching { snapshot?.let(::JSONObject) }.getOrNull()
            val days = root?.optJSONObject("days")
            // The widget is locked to the light theme: white card and dark ink
            // forever, no toggling with the app's or the system's dark mode.
            // Only the accent follows the app (palette.light).
            val scheme = root?.optJSONObject("palette")?.optJSONObject("light")

            fun snapColor(name: String, fallback: Int): Int =
                scheme?.optString(name)
                    ?.takeIf { it.isNotEmpty() }
                    ?.let { runCatching { Color.parseColor(it) }.getOrNull() }
                    ?: fallback

            val onBg = snapColor("onBg", context.getColor(R.color.widget_on_bg))
            val dim = snapColor("dim", context.getColor(R.color.widget_dim))
            val accent = snapColor("accent", context.getColor(R.color.widget_accent))
            // The background goes through a resource on the inner card view,
            // never the layout root: the MIUI host keeps the initial-layout
            // root background and ignores runtime swaps of it, while
            // child-view updates apply fine.
            rv.setInt(R.id.widgetCard, "setBackgroundResource", R.drawable.widget_bg)

            val timeline = runCatching {
                parseTimeline(root?.optJSONObject("timeline"))
            }.getOrNull() ?: emptyMap()

            val now = Calendar.getInstance()
            val minute = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
            val slots = days?.let {
                runCatching {
                    parseDay(it.optJSONArray(WEEK_DAY[now.get(Calendar.DAY_OF_WEEK)]))
                }.getOrNull()
            } ?: emptyList()
            val running = slots.firstOrNull { it.startMinute <= minute && minute < it.endMinute }
            val next = slots.firstOrNull { it.startMinute > minute }
            val point = pointAt(timeline, now, minute)

            when {
                // The date-keyed state card: the same states the app's Now card
                // renders, frozen into the snapshot so no Dart is needed.
                point != null -> {
                    rv.setTextViewText(R.id.nowLine, labeled("NOW", "", accent, dim))
                    rv.setTextViewText(R.id.nowMain, point.title)
                    rv.setTextColor(R.id.nowMain, onBg)
                    if (point.subtitle.isEmpty()) {
                        rv.setTextViewText(R.id.stateSub, "")
                        rv.setViewVisibility(R.id.stateSub, android.view.View.GONE)
                    } else {
                        rv.setTextViewText(R.id.stateSub, point.subtitle)
                        rv.setTextColor(R.id.stateSub, dim)
                        rv.setViewVisibility(R.id.stateSub, android.view.View.VISIBLE)
                    }
                    val tile = runCatching { iconTile(context, point.icon, accent) }.getOrNull()
                    if (tile == null) {
                        rv.setViewVisibility(R.id.stateIcon, android.view.View.GONE)
                    } else {
                        rv.setImageViewBitmap(R.id.stateIcon, tile)
                        rv.setViewVisibility(R.id.stateIcon, android.view.View.VISIBLE)
                    }
                    // The next class later today, from the weekly grid; only
                    // while one is running, the non-running states already
                    // carry "Next · ..." in their subtitle.
                    if (running != null && next != null) {
                        val detail = listOf(next.course, next.room, next.start)
                            .filter { it.isNotBlank() }.joinToString(" · ")
                        rv.setTextViewText(R.id.nextLine, labeled("NEXT", detail, accent, dim))
                        rv.setViewVisibility(R.id.nextLine, android.view.View.VISIBLE)
                    } else {
                        rv.setViewVisibility(R.id.nextLine, android.view.View.GONE)
                    }
                }

                root == null || days == null -> {
                    rv.setTextViewText(R.id.nowLine, labeled("CLASYNC", "", dim, dim))
                    rv.setTextViewText(R.id.nowMain, "Open ClasSync")
                    rv.setTextColor(R.id.nowMain, onBg)
                    rv.setViewVisibility(R.id.stateSub, android.view.View.GONE)
                    rv.setViewVisibility(R.id.stateIcon, android.view.View.GONE)
                    rv.setTextViewText(R.id.nextLine, "")
                    rv.setViewVisibility(R.id.nextLine, android.view.View.GONE)
                }

                running != null -> {
                    rv.setTextViewText(R.id.nowLine, labeled("NOW", "${running.start}–${running.end}", accent, dim))
                    rv.setTextViewText(R.id.nowMain, running.course)
                    rv.setTextColor(R.id.nowMain, onBg)
                    rv.setViewVisibility(R.id.stateSub, android.view.View.GONE)
                    rv.setViewVisibility(R.id.stateIcon, android.view.View.GONE)
                    if (next != null) {
                        val detail = listOf(next.course, next.room, next.start)
                            .filter { it.isNotBlank() }.joinToString(" · ")
                        rv.setTextViewText(R.id.nextLine, labeled("NEXT", detail, accent, dim))
                        rv.setViewVisibility(R.id.nextLine, android.view.View.VISIBLE)
                    } else {
                        rv.setViewVisibility(R.id.nextLine, android.view.View.GONE)
                    }
                }

                next != null -> {
                    rv.setTextViewText(R.id.nowLine, labeled("NEXT", next.start, accent, dim))
                    rv.setTextViewText(R.id.nowMain, next.course)
                    rv.setTextColor(R.id.nowMain, onBg)
                    rv.setViewVisibility(R.id.stateSub, android.view.View.GONE)
                    rv.setViewVisibility(R.id.stateIcon, android.view.View.GONE)
                    rv.setTextViewText(R.id.nextLine, "")
                    rv.setViewVisibility(R.id.nextLine, android.view.View.GONE)
                }

                else -> {
                    val headline = if (slots.isEmpty()) "No classes today" else "No classes left today"
                    rv.setTextViewText(R.id.nowLine, "")
                    rv.setTextViewText(R.id.nowMain, headline)
                    rv.setTextColor(R.id.nowMain, onBg)
                    rv.setViewVisibility(R.id.stateSub, android.view.View.GONE)
                    rv.setViewVisibility(R.id.stateIcon, android.view.View.GONE)
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
         * Picks the next moment the widget changes appearance: from the
         * date-keyed timeline when the snapshot carries one (its own change
         * points today, then each later date's first), else from the weekly
         * grid (class starts/ends), otherwise a midnight re-render for the
         * day roll.
         */
        private fun scheduleNext(context: Context, snapshot: String?) {
            val root = runCatching { snapshot?.let(::JSONObject) }.getOrNull()
            val timeline = runCatching {
                parseTimeline(root?.optJSONObject("timeline"))
            }.getOrNull() ?: emptyMap()

            val base = Calendar.getInstance()
            var trigger: Long? = null

            if (timeline.isNotEmpty()) {
                for (offset in 0 until 22) {
                    val date = dayAt(base, offset)
                    val day = timeline[dateKey(date)] ?: continue
                    trigger = day
                        .map { atMinute(date, it.minute) }
                        .filter { it > System.currentTimeMillis() }
                        .minOrNull()
                    if (trigger != null) break
                }
            } else {
                val days = root?.optJSONObject("days")
                if (days == null) return // Nothing to render until the app pushes.

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
