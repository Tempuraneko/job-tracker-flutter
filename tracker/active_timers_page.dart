// lib/tracker/active_timers_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'job_tracker_page.dart';

class ActiveTimersPage extends StatelessWidget {
  const ActiveTimersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('jobs')
        .where('active', isEqualTo: true);

    if (uid != null) {
      q = q.where('assignedMechanic', isEqualTo: uid);
    } else {
      q = q.where('assignedMechanic', isEqualTo: '__no_user__');
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Active Jobs')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = [...snap.data!.docs];
          docs.sort((a, b) {
            final ta = a.data()['updatedAt'];
            final tb = b.data()['updatedAt'];
            final da = (ta is Timestamp) ? ta.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
            final db = (tb is Timestamp) ? tb.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
            return db.compareTo(da);
          });

          if (docs.isEmpty) {
            return const Center(child: Text('No active jobs'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final d = docs[i];
              final m = d.data();
              final jobId = (m['jobId'] ?? d.id).toString();
              final title = (m['category'] ?? '').toString();
              final desc = (m['jobDescription'] ?? '').toString();
              final vehicle = (m['vehicle'] ?? '').toString();
              final status = (m['status'] ?? '').toString();

              Color chipBg = Colors.grey.shade200;
              Color chipFg = Colors.grey.shade800;
              switch (status.toLowerCase()) {
                case 'running':
                case 'in progress':
                case 'in_progress':
                  chipBg = Colors.orange.shade100; chipFg = Colors.orange.shade900; break;
                case 'paused':
                  chipBg = Colors.blue.shade100; chipFg = Colors.blue.shade900; break;
                case 'completed':
                  chipBg = Colors.green.shade100; chipFg = Colors.green.shade900; break;
              }

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(jobId, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.green)),
                      const SizedBox(height: 4),
                      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (desc.isNotEmpty) Text(desc),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(child: Text(vehicle, style: const TextStyle(color: Colors.black54))),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Status', style: TextStyle(fontSize: 12, color: Colors.black45)),
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: chipBg,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(status, style: TextStyle(color: chipFg, fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  trailing: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => JobTrackerPage(jobId: jobId, jobDetails: m),
                      ));
                    },
                    child: const Text('View'),
                  ),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => JobTrackerPage(jobId: jobId, jobDetails: m),
                    ));
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
