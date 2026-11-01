import '../model/ct.dart';
import '../model/routine.dart';
import 'build_alerts.dart';
import 'build_ct_alerts.dart';

/// Keeps the latest routine and CTs, and schedules alerts from them.
class AlertSync {
  final void Function(List<Alert>, List<CtAlert>) _schedule;
  Routine? _routine;
  List<Ct>? _cts;

  AlertSync(this._schedule);

  set routine(Routine value) {
    _routine = value;
    refresh();
  }

  set cts(List<Ct> value) {
    _cts = value;
    refresh();
  }

  /// Waits for both lists, because scheduling replaces every alert.
  void refresh() {
    final routine = _routine;
    final cts = _cts;
    if (routine == null || cts == null) return;
    _schedule(buildAlerts(routine), buildCtAlerts(cts, DateTime.now()));
  }
}
