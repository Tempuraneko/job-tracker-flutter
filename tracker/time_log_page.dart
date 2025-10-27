// lib/tracker/time_log_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TimeLogPage extends StatelessWidget {
  final String jobId;
  const TimeLogPage({super.key, required this.jobId});

  @override
  Widget build(BuildContext context) {
    final logsRef = FirebaseFirestore.instance
        .collection('jobs')
        .doc(jobId)
        .collection('timeLogs')
        .orderBy('at', descending: true);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: logsRef.snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Text('Logs error: ${snap.error}');
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snap.data!.docs;
            if (docs.isEmpty) {
              return const Text('No time logs yet.');
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('Time Logs', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                ...docs.map((d) {
                  final m = d.data();
                  final op = (m['op'] ?? '').toString();
                  final ts = m['at'];
                  String when = '-';
                  if (ts is Timestamp) {
                    final dt = ts.toDate();
                    when =
                    '${_two(dt.day)}/${_two(dt.month)}/${dt.year} ${_two(dt.hour)}:${_two(dt.minute)}:${_two(dt.second)}';
                  }
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: const Icon(Icons.history),
                    title: Text(op.toUpperCase()),
                    subtitle: Text(when),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
}
