// lib/tracker/job_timer_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class JobTimerService {
  final _db = FirebaseFirestore.instance;

  Future<void> ensureJobDoc(String jobId, Map<String, dynamic> details) async {
    final ref = _db.collection('jobs').doc(jobId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        tx.set(ref, {
          'jobId': jobId,
          'status': (details['status'] ?? 'idle').toString(),
          'category': details['category'],
          'jobDescription': details['jobDescription'] ?? details['description'],
          'vehicle': details['vehicle'] ?? details['title'],
          'customerId': details['customerId'] ?? details['customerID'],
          'assignedMechanic': details['assignedMechanic'] ?? details['mechanicId'],
          'serviceHistory': (details['serviceHistory'] as List?)?.cast<String>() ?? [],
          'accumulatedMs': 0,
          'active': false,
          'startedAt': null,
          'completedAt': null,
          'signaturePending': false, // default so later filter works
          'signatureBy': null,
          'signatureAt': null,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        tx.update(ref, {
          'jobId': jobId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Stream<Duration> elapsedStream(String jobId) {
    final ref = _db.collection('jobs').doc(jobId);
    final ticks = Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());

    return ref.snapshots().switchMap((snap) {
      final data = snap.data() ?? {};
      final baseMs = (data['accumulatedMs'] is int) ? data['accumulatedMs'] as int : 0;
      final active = data['active'] == true;
      final startedAt = data['startedAt'];
      if (!active || startedAt == null || startedAt is! Timestamp) {
        return Stream.value(Duration(milliseconds: baseMs));
      }
      final started = startedAt.toDate();
      return ticks.map((_) {
        final liveMs = DateTime.now().difference(started).inMilliseconds;
        return Duration(milliseconds: baseMs + (liveMs < 0 ? 0 : liveMs));
      });
    });
  }

  Future<void> _log(String jobId, String op) async {
    final logs = _db.collection('jobs').doc(jobId).collection('timeLogs');
    await logs.add({'op': op, 'at': FieldValue.serverTimestamp()});
  }

  Future<void> start(String jobId) async {
    final ref = _db.collection('jobs').doc(jobId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};
      if (data['active'] == true) return;
      tx.update(ref, {
        'status': 'running',
        'active': true,
        'startedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    await _log(jobId, 'start');
  }

  Future<void> pause(String jobId) async {
    final ref = _db.collection('jobs').doc(jobId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data()!;
      final accumulatedMs = (data['accumulatedMs'] is int) ? data['accumulatedMs'] as int : 0;
      final startedAt = data['startedAt'];
      int addMs = 0;
      if (startedAt is Timestamp) addMs = DateTime.now().difference(startedAt.toDate()).inMilliseconds;

      tx.update(ref, {
        'status': 'paused',
        'active': true,
        'accumulatedMs': accumulatedMs + (addMs < 0 ? 0 : addMs),
        'startedAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    await _log(jobId, 'pause');
  }

  Future<void> resume(String jobId) async {
    final ref = _db.collection('jobs').doc(jobId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      tx.update(ref, {
        'status': 'running',
        'active': true,
        'startedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    await _log(jobId, 'resume');
  }

  Future<void> complete(String jobId) async {
    final ref = _db.collection('jobs').doc(jobId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data()!;
      final accumulatedMs = (data['accumulatedMs'] is int) ? data['accumulatedMs'] as int : 0;
      final startedAt = data['startedAt'];
      int addMs = 0;
      if (startedAt is Timestamp) addMs = DateTime.now().difference(startedAt.toDate()).inMilliseconds;
      final totalMs = accumulatedMs + (addMs < 0 ? 0 : addMs);

      tx.update(ref, {
        'status': 'completed',
        'active': false,
        'accumulatedMs': totalMs,
        'startedAt': null,
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'totalSecs': (totalMs / 1000).floor(),
        // === flag for Signature Queue ===
        'signaturePending': true,
        'signatureBy': null,
        'signatureAt': null,
      });
    });
    await _log(jobId, 'complete');
  }
}

// tiny helper so we don't need rxdart
extension _SwitchMap<T> on Stream<T> {
  Stream<R> switchMap<R>(Stream<R> Function(T) project) {
    StreamController<R>? c;
    StreamSubscription<T>? outer;
    StreamSubscription<R>? inner;
    c = StreamController<R>(onListen: () {
      outer = listen((t) {
        inner?.cancel();
        inner = project(t).listen(c!.add, onError: c!.addError);
      }, onError: c!.addError, onDone: () async {
        await inner?.cancel();
        await c!.close();
      });
    }, onCancel: () async {
      await outer?.cancel();
      await inner?.cancel();
    });
    return c.stream;
  }
}
