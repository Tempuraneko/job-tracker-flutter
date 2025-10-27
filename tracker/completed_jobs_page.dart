// lib/tracker/completed_jobs_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CompletedJobsPage extends StatelessWidget {
  const CompletedJobsPage({super.key});

  String _fmtMs(int ms) {
    final d = Duration(milliseconds: ms);
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  DateTime? _asDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  DateTime? _pickBestDate(Map<String, dynamic> data) {
    return _asDate(data['completedAt']) ??
        _asDate(data['finishedAt']) ??
        _asDate(data['createdAt']);
  }

  Query<Map<String, dynamic>> _query() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final col = FirebaseFirestore.instance.collection('jobs');
    if (uid == null) {
      return col.where('assignedMechanic', isEqualTo: '__no_user__');
    }
    return col.where('assignedMechanic', isEqualTo: uid).limit(200);
  }

  int _extractTotalMs(Map<String, dynamic> data) {
    final v = data['accumulatedMs'] ?? data['totalMs'];
    if (v is int) return v;
    if (v is num) return v.toInt();

    final secs = data['totalSecs'];
    if (secs is int) return secs * 1000;
    if (secs is num) return (secs * 1000).toInt();

    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final q = _query().where('status', whereIn: ['completed', 'Completed', 'finished', 'Finished']);

    return Scaffold(
      appBar: AppBar(title: const Text('Repaired Jobs')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = [...(snap.data?.docs ?? [])];
          docs.sort((a, b) {
            final ad = _pickBestDate(a.data()) ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bd = _pickBestDate(b.data()) ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bd.compareTo(ad);
          });

          if (docs.isEmpty) {
            return const Center(child: Text('No completed jobs'));
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data();

              final title = (data['title'] ?? data['jobId'] ?? d.id).toString();
              final totalMs = _extractTotalMs(data);
              final shownDate = _asDate(data['completedAt']) ?? _asDate(data['finishedAt']);
              final notifyEmail = (data['notifyEmail'] ?? '').toString().trim();

              final subtitleLines = <String>[
                'Total time: ${_fmtMs(totalMs)}',
                if (shownDate != null) 'Completed at: $shownDate',
                if (notifyEmail.isNotEmpty) 'Notified: $notifyEmail',
              ];

              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.check_circle)),
                title: Text(title),
                subtitle: Text(subtitleLines.join('\n')),
              );
            },
          );
        },
      ),
    );
  }
}

