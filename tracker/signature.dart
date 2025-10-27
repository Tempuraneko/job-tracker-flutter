// lib/signature.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:assignment29/class/job.dart';
import 'package:assignment29/services/job_repository.dart';
import 'signature_capture_page.dart';

enum SigTab { completedUnsigned, finished }

class SignaturePage extends StatefulWidget {
  final IJobRepository? repository;

  const SignaturePage({super.key, this.repository});

  @override
  State<SignaturePage> createState() => _SignaturePageState();
}

class _SignaturePageState extends State<SignaturePage> {
  late final IJobRepository repo;
  SigTab current = SigTab.completedUnsigned;

  String? _uid;
  String? _email;

  @override
  void initState() {
    super.initState();
    repo = widget.repository ?? JobRepository();
    final user = FirebaseAuth.instance.currentUser;
    _uid = user?.uid?.trim();
    _email = user?.email?.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Signature')),
      body: Column(
        children: [
          _FilterBar(
            current: current,
            onChanged: (v) => setState(() => current = v),
          ),
          Expanded(
            child: StreamBuilder<List<Job>>(
              stream: current == SigTab.completedUnsigned
                  ? repo.streamCompletedUnsigned()
                  : repo.streamFinished(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final all = snapshot.data ?? const <Job>[];
                final jobs = all.where((j) {
                  final am = j.assignedMechanic.trim();
                  // Match either UID or email (depends how you store it)
                  final byUid = (_uid != null && _uid!.isNotEmpty && am == _uid);
                  final byEmail = (_email != null && _email!.isNotEmpty && am == _email);
                  return byUid || byEmail;
                }).toList();

                if (jobs.isEmpty) {
                  return const Center(child: Text('No jobs found.'));
                }
                return ListView.builder(
                  itemCount: jobs.length,
                  itemBuilder: (context, index) {
                    final job = jobs[index];
                    final title = (job.category.isNotEmpty ? job.category : 'Job') +
                        (job.vehicle.isNotEmpty ? ' • ${job.vehicle}' : '');
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text(title),
                        subtitle: Text('Job ID: ${job.jobId}  |  Status: ${job.status}'),
                        trailing: current == SigTab.completedUnsigned
                            ? const Icon(Icons.edit)
                            : const Icon(Icons.visibility),
                        onTap: () async {
                          if (current == SigTab.completedUnsigned) {
                            final ok = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SignatureCapturePage(
                                  job: job,
                                  repository: repo,
                                ),
                              ),
                            );
                            if (ok == true) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Updated.')),
                              );
                            }
                          } else {
                            // Finished: view-only
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SignatureCapturePage(
                                  job: job,
                                  readOnly: true,
                                  repository: repo,
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final SigTab current;
  final ValueChanged<SigTab> onChanged;

  const _FilterBar({required this.current, required this.onChanged, super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            _chip('Completed (unsigned)', current == SigTab.completedUnsigned,
                    () => onChanged(SigTab.completedUnsigned)),
            _chip('Finished', current == SigTab.finished,
                    () => onChanged(SigTab.finished)),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
