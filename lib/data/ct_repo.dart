import 'package:cloud_firestore/cloud_firestore.dart';

import '../alerts/build_ct_alerts.dart';
import '../model/ct.dart';

class CtRepo {
  final String uid;

  CtRepo(this.uid);

  CollectionReference<Map<String, dynamic>> get _cts => FirebaseFirestore
      .instance
      .collection('routines')
      .doc(uid)
      .collection('cts');

  /// Upcoming CTs, soonest first. CTs whose time has passed are permanently deleted here.
  Stream<List<Ct>> watch() => _cts.snapshots().map((snapshot) {
        final all = [
          for (final doc in snapshot.docs) Ct.fromJson(doc.id, doc.data()),
        ];
        final now = DateTime.now();
        final expired = expiredCts(all, now);
        for (final ct in expired) {
          delete(ct.id);
        }
        return all.where((ct) => ct.at.isAfter(now)).toList()
          ..sort((a, b) => a.at.compareTo(b.at));
      });

  Future<void> save(Ct ct) =>
      (ct.id.isEmpty ? _cts.doc() : _cts.doc(ct.id)).set(ct.toJson());

  Future<void> delete(String id) => _cts.doc(id).delete();
}
