// lib/signature_capture_page.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:assignment29/class/job.dart';
import 'package:assignment29/services/job_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignatureCapturePage extends StatefulWidget {
  final Job job;
  final bool readOnly;
  final IJobRepository? repository;


  const SignatureCapturePage({
    super.key,
    required this.job,
    this.readOnly = false,
    this.repository,
  });

  @override
  State<SignatureCapturePage> createState() => _SignatureCapturePageState();
}

class _SignatureCapturePageState extends State<SignatureCapturePage> {
  late final IJobRepository repo;
  late SignatureController _controller;
  final TextEditingController _emailCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    repo = widget.repository ?? JobRepository();
    _controller = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
    final preset = widget.job.notifyEmail?.trim();
    if (preset != null && preset.isNotEmpty) {
      _emailCtl.text = preset;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailCtl.dispose();
    super.dispose();
  }

  Future<void> _sendEmail() async {
    final email = _emailCtl.text.trim();
    if (email.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a customer email first.')),
      );
      return;
    }

    try {
      await repo.sendCompletedEmail(jobId: widget.job.jobId, toEmail: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Email sent to $email')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Send failed: $e ')),
      );
    }
  }

  Future<void> _saveSignature() async {
    if (_controller.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a signature first. ')),
      );
      return;
    }
    final Uint8List? png = await _controller.toPngBytes();
    if (png == null) return;

    await repo.saveSignatureAndMarkFinished(
      jobId: widget.job.jobId,
      signaturePngBytes: png,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Signature saved. Marked as Finished.')),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final notifyEmail =
    (job.notifyEmail?.trim().isNotEmpty ?? false) ? job.notifyEmail!.trim() : 'none';

    return Scaffold(
      appBar: AppBar(title: const Text('Job Signature')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ===== Job Detail =====
          _sectionTitle('Job Detail '),
          _detailRow('Job ID', job.jobId),
          _detailRow('Customer ID', job.customerId),
          _detailRow('Customer Name',
              (job.customerName?.trim().isNotEmpty ?? false) ? job.customerName!.trim() : '—'),
          _detailRow('Customer Phone',
              (job.customerPhone?.trim().isNotEmpty ?? false) ? job.customerPhone!.trim() : '—'),
          _detailRow('Category', job.category),
          _detailRow('Vehicle', job.vehicle),
          _detailRow('Mechanic', job.assignedMechanic),
          _detailRow('Status', job.status),
          _detailRow('Email', notifyEmail),
          const SizedBox(height: 12),
          const Divider(height: 24),

          // ===== Notes & Photos =====
          _sectionTitle('Notes & Photos '),
          const SizedBox(height: 8),
          _NotesAndPhotos(jobId: job.jobId),
          const SizedBox(height: 16),
          const Divider(height: 24),

          // ===== Time Logs =====
          _sectionTitle('Time Logs '),
          const SizedBox(height: 8),
          _TimeLogs(jobId: job.jobId),
          const SizedBox(height: 16),
          const Divider(height: 24),

          if (widget.readOnly) ...[
            _sectionTitle('Saved Signature '),
            const SizedBox(height: 8),
            if (job.signatureBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(job.signatureBytes!, height: 220),
              )
            else
              const Text('No signature found '),
          ] else ...[
            _sectionTitle('Want to notify Customer ? (optional)'),
            const SizedBox(height: 8),
            TextField(
              controller: _emailCtl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Customer email',
                hintText: 'example@gmail.com',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _sendEmail,
                icon: const Icon(Icons.send),
                label: const Text('Send Email'),
              ),
            ),

            const SizedBox(height: 16),
            _sectionTitle('Please sign below '),
            const SizedBox(height: 8),
            Container(
              height: 220,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: Signature(controller: _controller, backgroundColor: Colors.white),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _controller.clear(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Clear '),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saveSignature,
                    icon: const Icon(Icons.save),
                    label: const Text('Save & Mark Finished '),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) =>
      Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600));

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text('$label:')),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _NotesAndPhotos extends StatelessWidget {
  final String jobId;
  const _NotesAndPhotos({required this.jobId});

  @override
  Widget build(BuildContext context) {
    final notesRef = FirebaseFirestore.instance
        .collection('jobs')
        .doc(jobId)
        .collection('notes')
        .orderBy('createdAt', descending: true);

    final topPhotosRef = FirebaseFirestore.instance
        .collection('jobs')
        .doc(jobId)
        .collection('photos')
        .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: notesRef.snapshots(),
      builder: (context, notesSnap) {
        final noteDocs = notesSnap.data?.docs ?? [];
        final hasNotes = noteDocs.isNotEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!hasNotes) const Text('No notes yet.'),
            ...noteDocs.map((ndoc) {
              final n = ndoc.data();
              final title = (n['title'] ?? '').toString().trim();
              final text = (n['note'] ?? n['text'] ?? n['content'] ?? '').toString().trim();
              final ts = n['createdAt'] as Timestamp?;
              final timeStr = ts != null ? ts.toDate().toString() : '';

              final photosRef = ndoc.reference
                  .collection('photos')
                  .orderBy('createdAt', descending: true);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty)
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (text.isNotEmpty || timeStr.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• '),
                            Expanded(child: Text(text.isEmpty ? '-' : text)),
                            if (timeStr.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Text(timeStr,
                                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              ),
                          ],
                        ),
                      ),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: photosRef.snapshots(),
                      builder: (context, ps) {
                        final photoDocs = ps.data?.docs ?? [];
                        if (photoDocs.isEmpty) return const SizedBox.shrink();
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: photoDocs.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                          ),
                          itemBuilder: (context, i) {
                            final p = photoDocs[i].data();
                            return _PhotoTile.fromMap(p);
                          },
                        );
                      },
                    ),
                  ],
                ),
              );
            }),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: topPhotosRef.snapshots(),
              builder: (context, snap) {
                final photoDocs = snap.data?.docs ?? [];
                if (photoDocs.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    const Text('More Photos ', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: photoDocs.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 6,
                        mainAxisSpacing: 6,
                      ),
                      itemBuilder: (context, i) {
                        final p = photoDocs[i].data();
                        return _PhotoTile.fromMap(p);
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final Widget child;
  const _PhotoTile(this.child, {super.key});

  factory _PhotoTile.fromMap(Map<String, dynamic> p) {
    final url = (p['downloadURL'] ?? p['url'] ?? '').toString().trim();
    final b64 = (p['imageBase64'] ?? p['base64'] ?? '').toString().trim();
    Widget content;
    if (url.isNotEmpty) {
      content = Image.network(url, fit: BoxFit.cover);
    } else if (b64.isNotEmpty) {
      final pure = b64.contains(',') ? b64.split(',').last : b64;
      Uint8List? bytes;
      try {
        bytes = base64Decode(pure);
      } catch (_) {}
      content = (bytes != null)
          ? Image.memory(bytes, fit: BoxFit.cover)
          : const Center(child: Icon(Icons.broken_image));
    } else {
      content = const Center(child: Icon(Icons.broken_image));
    }
    return _PhotoTile(content);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: InteractiveViewer(
              child: AspectRatio(
                aspectRatio: 1,
                child: FittedBox(fit: BoxFit.contain, child: child),
              ),
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: child,
      ),
    );
  }
}

class _TimeLogs extends StatelessWidget {
  final String jobId;
  const _TimeLogs({required this.jobId});

  @override
  Widget build(BuildContext context) {
    final logsRef = FirebaseFirestore.instance
        .collection('jobs')
        .doc(jobId)
        .collection('timeLogs')
        .orderBy('at', descending: false);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: logsRef.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: SizedBox(height: 32, child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return Text('Failed to load logs: ${snap.error}');
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const Text('No time logs yet.');
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, i) {
            final m = docs[i].data();
            final ts = m['at'];
            final op = (m['op'] ?? '').toString().trim().toLowerCase();
            final dt = (ts is Timestamp) ? ts.toDate() : null;
            final timeStr = dt == null ? '-' : _fmtDateTime(dt);
            final icon = _iconForOp(op);
            final color = _colorForOp(op);
            final label = _labelForOp(op);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: [
                        TextSpan(text: '$timeStr  '),
                        TextSpan(
                          text: label,
                          style: TextStyle(
                              fontWeight: FontWeight.w600, color: color),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static String _fmtDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm:$ss';
  }

  static IconData _iconForOp(String op) {
    switch (op) {
      case 'start':
        return Icons.play_arrow_rounded;
      case 'pause':
        return Icons.pause_circle_filled_rounded;
      case 'resume':
        return Icons.play_circle_fill_rounded;
      case 'complete':
      case 'finish':
      case 'finished':
        return Icons.check_circle_rounded;
      default:
        return Icons.access_time_rounded;
    }
  }

  static Color _colorForOp(String op) {
    switch (op) {
      case 'start':
        return Colors.blue;
      case 'pause':
        return Colors.orange;
      case 'resume':
        return Colors.teal;
      case 'complete':
      case 'finish':
      case 'finished':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  static String _labelForOp(String op) {
    switch (op) {
      case 'start':
        return 'start';
      case 'pause':
        return 'pause';
      case 'resume':
        return 'resume';
      case 'complete':
      case 'finish':
      case 'finished':
        return 'complete';
      default:
        return op.isEmpty ? 'unknown' : op;
    }
  }
}
