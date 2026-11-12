import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../model/ct.dart';
import '../model/routine.dart';
import '../theme.dart';
import 'widget_timeline.dart';

/// One class rendered on the home-screen widget.
///
/// Adjacent periods holding the same course, teacher and room (a lab block)
/// are merged into a single slot with the last period's end time, so the
/// widget shows one unbroken "now" instead of per-period rows.
class WidgetSlot {
  final Period period;
  final ClassCell cell;

  const WidgetSlot(this.period, this.cell);

  Map<String, dynamic> toJson() => {
        's': period.start,
        'e': period.end,
        'c': cell.course,
        't': cell.teacher,
        'r': cell.room,
      };
}

/// The widget's rendering-safe slots for one day, in period order.
List<WidgetSlot> widgetSlots(Routine r, String day) {
  final row = r.row(day);
  final out = <WidgetSlot>[];
  for (var i = 0; i < row.length; i++) {
    final cell = row[i];
    if (cell == null) continue;
    var start = r.periods[i].start;
    var end = r.periods[i].end;
    while (i + 1 < row.length && (row[i + 1]?.sameClass(cell) ?? false)) {
      i++;
      end = r.periods[i].end;
    }
    out.add(WidgetSlot(Period(start, end), cell));
  }
  return out;
}

/// Hex like "#009688", parsed natively with android.graphics.Color.
String _hex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// The widget's palette for one brightness, taken from the app's theme: the
/// accent is the raw swatch the user picked (never a derived or pale tone),
/// onSurface for the main line and onSurfaceVariant for secondary text. The
/// background itself goes through the bg drawables, whose solids are set to
/// the card-surface tone — a runtime tint never survives the launcher host.
/// Computed in Dart because ColorScheme.fromSeed lives there; the values
/// freeze into the snapshot.
Map<String, String> _palette(ColorScheme cs, Color accent) => {
      'onBg': _hex(cs.onSurface),
      'dim': _hex(cs.onSurfaceVariant),
      'accent': _hex(accent),
    };

/// Full snapshot: the weekly class grid for the Next row, and date-keyed
/// state timelines for the Now card, so the widget resolves every state for
/// any day without the app running. A day with no classes is included as an
/// empty list, so "no classes today" is instant.
Map<String, dynamic> widgetSnapshot(Routine r, [List<Ct> cts = const []]) {
  final accent = accentFill(r.accent);
  return {
    // The widget keeps a fixed white (light) card regardless of the app's or
    // the system's dark mode; only the accent follows the app, shipped as the
    // raw swatch of the chosen seed.
    'palette': {
      'light': _palette(
        ColorScheme.fromSeed(seedColor: accent),
        accent,
      ),
    },
    'days': {
      for (final day in validDays)
        day: [for (final s in widgetSlots(r, day)) s.toJson()],
    },
    // State timelines for the next three weeks: exam countdowns and near /
    // incoming windows depend on real dates, so they freeze in here.
    'timeline': widgetTimeline(r, cts),
  };
}

/// The native side owns a SharedPreferences-backed widget provider; the
/// channel only ships the frozen JSON and asks it to redraw.
class WidgetSync {
  static const _channel = MethodChannel('classync/widget');

  /// Stores the snapshot and refreshes the widget; silently a no-op where the
  /// channel does not exist, e.g. the web dashboard.
  static Future<void> push(Routine r, [List<Ct> cts = const []]) =>
      _send('push', widgetSnapshot(r, cts));

  /// Drops the snapshot; the widget falls back to its placeholder.
  static Future<void> clear() => _send('clear', null);

  static Future<void> _send(String method, Map<String, dynamic>? data) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>(
        method,
        data == null ? null : jsonEncode(data),
      );
    } catch (e) {
      debugPrint('Widget $method failed: $e');
    }
  }
}
