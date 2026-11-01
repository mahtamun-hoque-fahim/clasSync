import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../model/routine.dart';

/// A missing doc is a new user. A doc that fails to parse keeps [last] on screen.
Routine decodeRoutine(Map<String, dynamic>? data, Routine last) {
  if (data == null) return Routine.empty();
  final (routine, errors) = Routine.parse(data);
  if (routine == null) {
    debugPrint('Stored routine is invalid: $errors');
    return last;
  }
  return routine;
}

class RoutineRepo {
  final String uid;

  RoutineRepo(this.uid);

  DocumentReference<Map<String, dynamic>> get _doc =>
      FirebaseFirestore.instance.collection('routines').doc(uid);

  Stream<Routine> watch() {
    var last = Routine.empty();
    return _doc.snapshots().map((snapshot) {
      return last = decodeRoutine(snapshot.data(), last);
    });
  }

  Future<void> save(Routine r) =>
      _doc.set({...r.toJson(), 'updatedAt': FieldValue.serverTimestamp()});
}
