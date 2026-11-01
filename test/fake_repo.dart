import 'dart:async';

import 'package:classync/data/routine_repo.dart';
import 'package:classync/model/routine.dart';

class FakeRepo implements RoutineRepo {
  @override
  final String uid = 'test';
  final controller = StreamController<Routine>.broadcast();
  final Routine initial;
  Routine? saved;

  FakeRepo(this.initial);

  @override
  Stream<Routine> watch() async* {
    yield saved ?? initial;
    yield* controller.stream;
  }

  @override
  Future<void> save(Routine r) async {
    saved = r;
    controller.add(r);
  }
}
