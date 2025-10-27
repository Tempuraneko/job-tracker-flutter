// lib/tracker/job_tracker_page.dart
import 'dart:convert';
import 'package:assignment29/tracker/signature.dart';
import 'package:assignment29/tracker/signature_capture_page.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Use your actual paths here:
import 'package:assignment29/services//job_timer_service.dart';
import 'package:assignment29/tracker/time_log_page.dart';
import 'package:assignment29/tracker/notes.dart';

import '../class/job.dart';

class JobTrackerPage extends StatefulWidget {
  final String? jobId;
  final Map<String, dynamic> jobDetails;

  const JobTrackerPage({super.key, this.jobId, required this.jobDetails});

  @override
  State<JobTrackerPage> createState() => _JobTrackerPageState();
}

class _JobTrackerPageState extends State<JobTrackerPage>
    with AutomaticKeepAliveClientMixin {
  final _service = JobTimerService();

  String? _jobId;
  DocumentReference<Map<String, dynamic>>? _docRef;
  Stream<Duration>? _elapsed$;

  bool _ready = false;
  String? _error;
  bool _busy = false;

  @override
  bool get wantKeepAlive => true;

  // ---------- helpers ----------
  String _stableKey(Map<String, dynamic> j) {
    final v = (j['vehicle'] ?? '').toString().trim();
    final i = (j['issue'] ?? '').toString().trim();
    final p = (j['parts'] ?? '').toString().trim();
    return '$v|$i|$p';
  }

  String _hashId(String key) {
    final bytes = utf8.encode(key);
    return sha1.convert(bytes).toString();
  }

  String _fmt(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Widget _chip(String status, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        status,
        style: TextStyle(color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }

  /// Map variants to canonical states: idle | running | paused | completed
  String _normalizeStatus(String? raw, {bool? active, int? totalSecs}) {
    final s = (raw ?? '').trim().toLowerCase();

    switch (s) {
      case 'in progress':
      case 'in_progress':
      case 'started':
        return 'running';
      case 'pending':
      case 'new':
      case 'open':
      case 'created':
      case 'accepted':
      case '':
        return 'idle';
      case 'pause':
      case 'paused':
        return 'paused';
      case 'done':
      case 'complete':
      case 'completed':
        return 'completed';
      default:
        return s;
    }
  }

  // ---------- init ----------
  @override
  void initState() {
    super.initState();
    _initAsync();
  }

  Future<void> _initAsync() async {
    try {
      // Prefer Firestore jobId (e.g., "J002"); then explicit param; finally hash-fallback
      final detailsId = (widget.jobDetails['jobId'] ?? '').toString().trim();
      if (detailsId.isNotEmpty) {
        _jobId = detailsId;
      } else if (widget.jobId != null && widget.jobId!.trim().isNotEmpty) {
        _jobId = widget.jobId!.trim();
      } else {
        final key = _stableKey(widget.jobDetails);
        _jobId = _hashId(key);
      }

      _docRef = FirebaseFirestore.instance.collection('jobs').doc(_jobId);

      // Ensure the doc exists (noop if already exists)
      await _service.ensureJobDoc(_jobId!, widget.jobDetails);

      _elapsed$ = _service.elapsedStream(_jobId!);

      if (!mounted) return;
      setState(() {
        _ready = true;
        _error = null;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Firebase error: ${e.code} — ${e.message}';
        _ready = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Init failed: $e';
        _ready = false;
      });
    }
  }

  // ---------- UI parts ----------
  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value.isEmpty ? '-' : value)),
        ],
      ),
    );
  }

  Widget _detailsCard(Map<String, dynamic> live) {
    final j = {...widget.jobDetails, ...live}; // prefer live Firestore fields
    final id = (j['jobId'] ?? _jobId ?? '').toString();
    final cust = (j['customerId'] ?? j['customerID'] ?? '').toString();
    final mech = (j['assignedMechanic'] ?? j['mechanicId'] ?? '').toString();
    final cat = (j['category'] ?? '').toString();
    final desc = (j['jobDescription'] ?? j['description'] ?? '').toString();
    final veh = (j['vehicle'] ?? j['title'] ?? '').toString();
    final hist = (j['serviceHistory'] as List?)?.cast<String>() ?? const [];
    final rawStatus = (j['status'] ?? 'idle').toString();
    final active = j['active'] == true;
    final status = _normalizeStatus(rawStatus, active: active);

    Color bg = Colors.grey.shade300;
    Color fg = Colors.black87;
    switch (status) {
      case 'running':
        bg = Colors.orange.shade100;
        fg = Colors.orange.shade900;
        break;
      case 'paused':
        bg = Colors.blue.shade100;
        fg = Colors.blue.shade900;
        break;
      case 'completed':
        bg = Colors.green.shade100;
        fg = Colors.green.shade900;
        break;
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Job Id: ${id.isEmpty ? _jobId ?? '' : id}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _chip(rawStatus, bg, fg), // show the raw label user sees in DB
              ],
            ),
            const SizedBox(height: 14),
            _row('Customer ID', cust),
            _row('Mechanic', mech),
            _row('Category', cat),
            _row('Vehicle', veh),
            _row('Description', desc),
            const SizedBox(height: 8),
            if (hist.isNotEmpty) ...[
              const Text(
                'Service History',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              ...hist.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Text(
                        '•  ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Expanded(child: Text(e)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _do(Future<void> Function() action, String failMsg) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$failMsg: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Job Tracker')),
        body: Center(
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }
    if (!_ready || _docRef == null || _jobId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Job Tracker')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Job Tracker')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _docRef!.snapshots(),
        builder: (context, s) {
          if (s.hasError) {
            return Center(child: Text('Load error: ${s.error}'));
          }
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final live = s.data!.data() ?? {};
          final rawStatus = (live['status'] ?? 'idle').toString();
          final active = live['active'] == true;
          final status = _normalizeStatus(rawStatus, active: active);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _detailsCard(live),
              const SizedBox(height: 16),

              // Timer card
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Notes & Photos button (above timer)
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: (_jobId == null)
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          NotesListPage(jobId: _jobId!),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.note_add_outlined),
                          label: const Text('Notes & Photos'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      StreamBuilder<Duration>(
                        stream: _elapsed$,
                        builder: (context, t) {
                          if (!t.hasData) return const Text('⏱ --:--:--');
                          return Text(
                            '⏱ ${_fmt(t.data ?? Duration.zero)}',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      // ======== Controls ========
                      // Show START whenever job is not active (regardless of text like "in progress")
                      if (!active && status != 'completed'&& status != 'finished' )
                        Center(
                          child: ElevatedButton(
                            onPressed: _busy
                                ? null
                                : () => _do(
                                    () => _service.start(_jobId!),
                                    'Start failed',
                                  ),
                            child: const Text("Start Job"),
                          ),
                        ),

                      if (active && status == 'running') ...[
                        Center(
                          child: ElevatedButton(
                            onPressed: _busy
                                ? null
                                : () => _do(
                                    () => _service.pause(_jobId!),
                                    'Pause failed',
                                  ),
                            child: const Text("Pause (Break)"),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            onPressed: _busy
                                ? null
                                : () => _do(
                                    () => _service.complete(_jobId!),
                                    'Complete failed',
                                  ),
                            child: const Text("End Job (Complete)"),
                          ),
                        ),
                      ],

                      if (active && status == 'paused') ...[
                        Center(
                          child: ElevatedButton(
                            onPressed: _busy
                                ? null
                                : () => _do(
                                    () => _service.resume(_jobId!),
                                    'Resume failed',
                                  ),
                            child: const Text("Resume"),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            onPressed: _busy
                                ? null
                                : () => _do(
                                    () => _service.complete(_jobId!),
                                    'Complete failed',
                                  ),
                            child: const Text("End Job (Complete)"),
                          ),
                        ),
                      ],

                      if (status == 'completed') ...[
                        Center(
                          child: ElevatedButton(
                            onPressed: () async {
                              final id = _jobId; // ✅ use the computed id
                              if (id == null || id.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Job ID is missing')),
                                );
                                return;
                              }

                              // Optional tiny loader
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => const Center(child: CircularProgressIndicator()),
                              );

                              try {
                                // You already have _docRef, use it (or fetch by id)
                                final doc = await (_docRef ?? FirebaseFirestore.instance.collection('jobs').doc(id)).get();

                                if (!doc.exists || doc.data() == null) {
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Job $id not found')),
                                    );
                                  }
                                  return;
                                }

                                final job = Job.fromDoc(doc);
                                if (!context.mounted) return;
                                Navigator.of(context).pop(); // close loader

                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => SignatureCapturePage(job: job),
                                  ),
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to open signature: $e')),
                                );
                              }
                            },
                            child: const Text('Process Signature'),
                          ),
                        ),
                      ]

                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Time logs list for this job
              TimeLogPage(jobId: _jobId!),
            ],
          );
        },
      ),
    );
  }
}
