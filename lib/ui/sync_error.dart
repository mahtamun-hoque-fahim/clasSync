import 'package:flutter/material.dart';

/// Shown when the routine can't be loaded. Scheduled alerts are left as they were.
class SyncError extends StatelessWidget {
  const SyncError({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        'Your routine could not be read, so nothing was changed and your alerts '
        'stay as they were. Check your connection. If this continues, import '
        'your routine again in Settings.',
        textAlign: TextAlign.center,
      ),
    );
  }
}
