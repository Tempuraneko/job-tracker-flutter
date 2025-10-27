import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../class/job.dart';
import 'job_tracker_page.dart';

class CustomerVehicle extends StatelessWidget {
  final Job job;

  const CustomerVehicle({super.key, required this.job});

  String _s(String? v) => (v == null || v.isEmpty) ? '—' : v;

  String _fmt(DateTime? dt) {
    if (dt == null) return '—';
    // e.g. Monday 02-12-24
    final d1 = DateFormat('EEEE dd/MM/yy').format(dt);
    // e.g. 8AM - 1PM not in data; omit or add your own time window
    return d1;
  }

  @override
  Widget build(BuildContext context) {
    // final contactName   = (job as dynamic).customerName as String?;
    // final contactMobile = (job as dynamic).contactMobile as String?;

    return Scaffold(
      appBar: AppBar(title: const Text('Job Summary')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Summary card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _fieldRow(
                      left: _fieldBox(context, 'Jobs', _s(job.jobId)),
                      right: _fieldBox(context, 'Customer', _s(job.customerId)),
                    ),
                    const SizedBox(height: 12),
                    _fieldBox(context, 'Description of work', _s(job.jobDescription), fullWidth: true),
                    const SizedBox(height: 12),
                     _fieldRow(
                       left: _fieldBox(context, 'Vehicle', _s(job.vehicle)),
                       right: _fieldBox(context, 'Mechanic In Change', _s(job.assignedMechanic)),
                     ),
                    const SizedBox(height: 12),
                    _fieldBox(
                      context,
                      'Service History',
                      job.serviceHistory.isEmpty
                          ? 'No history yet.'
                          : job.serviceHistory.map((e) => '• $e').join('\n'),
                      fullWidth: true,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.directions_car),
                  ),
                  title: Text(_s(job.category)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_fmt(job.createdAt)),
                      Text(_s(job.jobDescription)),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${_s(job.status)}',
                          style: Theme.of(context).textTheme.labelMedium),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Bottom CTA
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => JobTrackerPage(jobDetails: {
                        'jobId': job.jobId,
                        'vehicle': job.vehicle,
                        'status': 'Accepted',
                      }),
                    ),
                  );

                },
                child: const Text('Start your jobs'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- UI helpers ----------
  Widget _fieldRow({required Widget left, required Widget right}) {
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }

  Widget _fieldBox(BuildContext context, String label, String value, {bool fullWidth = false}) {
    final box = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Theme.of(context).hintColor)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );

    if (fullWidth) return box;
    return box;
  }
}
