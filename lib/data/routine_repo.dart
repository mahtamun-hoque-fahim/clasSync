import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

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

class RoutineRepo {
  final String uid;

  RoutineRepo(this.uid);

  DocumentReference<Map<String, dynamic>> get _doc =>
      FirebaseFirestore.instance.collection('routines').doc(uid);

  Stream<Routine> watch() {
    Routine? last;
    return _doc.snapshots().map((snapshot) {
      return last = decodeRoutine(snapshot.data(), last);
    });
  }

  Future<void> save(Routine r) =>
      _doc.set({...r.toJson(), 'updatedAt': FieldValue.serverTimestamp()});
}
