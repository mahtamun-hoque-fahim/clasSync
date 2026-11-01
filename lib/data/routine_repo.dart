import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../model/routine.dart';

class InvalidRoutine implements Exception {
  final List<String> errors;

  const InvalidRoutine(this.errors);

  @override
  String toString() => 'Stored routine is invalid: $errors';
}

/// A missing doc is a new user. A doc that fails to parse keeps [last] on screen.
/// With no [last] it throws, because an empty routine would cancel every alert.
Routine decodeRoutine(Map<String, dynamic>? data, Routine? last) {
  if (data == null) return Routine.empty();
  final (routine, errors) = Routine.parse(data);
  if (routine != null) return routine;
  debugPrint('Stored routine is invalid: $errors');
  if (last != null) return last;
  throw InvalidRoutine(errors);
}

/// A cached "no routine" can be stale, and seeding on it would overwrite real edits.
bool shouldSeed({required bool exists, required bool fromCache}) =>
    !exists && !fromCache;

Future<Routine> loadDefaultRoutine() async {
  final text = await rootBundle.loadString('assets/default_routine.json');
  return Routine.parseText(text).$1!;
}

class RoutineRepo {
  final String uid;
  bool _seeded = false;

  RoutineRepo(this.uid);

  Future<void> _seed() async {
    if (_seeded) return;
    _seeded = true;
    try {
      await save(await loadDefaultRoutine());
    } on Object catch (e) {
      _seeded = false;
      debugPrint('Could not save the default routine: $e');
    }
  }

  DocumentReference<Map<String, dynamic>> get _doc =>
      FirebaseFirestore.instance.collection('routines').doc(uid);

  Stream<Routine> watch() {
    Routine? last;
    // Metadata changes included: the server confirming "no routine" changes no data,
    // so without them that confirmation would never arrive.
    return _doc.snapshots(includeMetadataChanges: true).map((snapshot) {
      if (shouldSeed(
        exists: snapshot.exists,
        fromCache: snapshot.metadata.isFromCache,
      )) {
        _seed();
      }
      return last = decodeRoutine(snapshot.data(), last);
    });
  }

  Future<void> save(Routine r) =>
      _doc.set({...r.toJson(), 'updatedAt': FieldValue.serverTimestamp()});
}
