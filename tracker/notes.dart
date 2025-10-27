import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class JobNotesPhotoScreen extends StatefulWidget {
  final String jobId;
  final VoidCallback onFinished;

  const JobNotesPhotoScreen({super.key, required this.jobId, required this.onFinished});

  @override
  _JobNotesPhotoScreenState createState() => _JobNotesPhotoScreenState();
}

class _JobNotesPhotoScreenState extends State<JobNotesPhotoScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final List<Map<String, String>> _photos = [];
  bool _saving = false;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile == null) return;

    final file = File(pickedFile.path);
    final bytes = await file.readAsBytes();
    final base64Image = base64Encode(bytes);

    final label = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text("Select Label"),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, "Damaged"),
            child: const Text("Damaged"),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, "Repaired"),
            child: const Text("Repaired"),
          ),
        ],
      ),
    );
    if (label == null) return;

    setState(() {
      _photos.add({"imageBase64": base64Image, "label": label});
    });
  }

  Future<void> _saveNote() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final String title = _titleController.text.trim();
      final String noteText = _noteController.text.trim();
      final String jobId = widget.jobId;

      if (title.isEmpty && noteText.isEmpty && _photos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add a title, note, or photo.')),
        );
        setState(() => _saving = false);
        return;
      }

      // Create the main note document
      final docRef = await FirebaseFirestore.instance
          .collection('jobs')
          .doc(jobId)
          .collection('notes')
          .add({
        'title': title.isEmpty ? 'Untitled Note' : title,
        'note': noteText,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Save photos under the note
      for (var photo in _photos) {
        await FirebaseFirestore.instance
            .collection('jobs')
            .doc(jobId)
            .collection('notes')
            .doc(docRef.id)
            .collection('photos')
            .add({
          'imageBase64': photo['imageBase64'],
          'label': photo['label'],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note saved successfully!')),
      );
      widget.onFinished();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notes & Photos')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: "Title",
                border: OutlineInputBorder(),
                hintText: "Enter note title...",
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: "Description",
                border: OutlineInputBorder(),
                hintText: "Write your notes here...",
              ),
            ),
            const SizedBox(height: 16),
            if (_photos.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: _photos.length,
                itemBuilder: (context, index) {
                  final photo = _photos[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FullscreenImagePage(
                            imageBytes: base64Decode(photo["imageBase64"]!),
                            timestamp: DateTime.now(),
                          ),
                        ),
                      );
                    },
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            base64Decode(photo["imageBase64"]!),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: photo["label"] == "Damaged" 
                                  ? Colors.red.shade600 
                                  : Colors.green.shade600,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              photo["label"] ?? "",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _photos.removeAt(index);
                              });
                            },
                            child: const CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.red,
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _saveNote,
                icon: _saving ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ) : const Icon(Icons.save),
                label: Text(_saving ? 'Saving...' : 'Save Note'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onFinished,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: Colors.grey.shade600,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Cancel & Go Back'),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FloatingActionButton.extended(
                heroTag: "camera",
                onPressed: () => _pickImage(ImageSource.camera),
                label: const Text("Camera"),
                icon: const Icon(Icons.camera_alt),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              const SizedBox(height: 10),
              FloatingActionButton.extended(
                heroTag: "gallery",
                onPressed: () => _pickImage(ImageSource.gallery),
                label: const Text("Gallery"),
                icon: const Icon(Icons.photo),
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ----------------------------
/// Fullscreen Image Viewer
/// ----------------------------
class FullscreenImagePage extends StatelessWidget {
  final Uint8List imageBytes;
  final DateTime? timestamp;

  const FullscreenImagePage({
    super.key,
    required this.imageBytes,
    this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final tsText = _formatDateTime(timestamp);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text("Photo"),
      ),
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5,
              child: Image.memory(imageBytes),
            ),
          ),
          if (tsText.isNotEmpty)
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tsText,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// ----------------------------
/// Notes List Page
/// ----------------------------
class NotesListPage extends StatelessWidget {
  final String jobId;

  const NotesListPage({super.key, required this.jobId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Notes & Photos")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("jobs/$jobId/notes")
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final notes = snapshot.data!.docs;

          if (notes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.note_alt_outlined,
                      size: 72,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "No notes yet",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Tap the add button to create your first note with photos.",
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => JobNotesPhotoScreen(
                              jobId: jobId,
                              onFinished: () => Navigator.pop(context),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text("Add Note"),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              final title = note['title'] ?? 'Untitled';
              final noteText = note['note'] ?? '';
              final createdAt = note['createdAt'];
              String timeStr = '';
              if (createdAt is Timestamp) {
                timeStr = _formatDateTime(createdAt.toDate());
              }

              return Dismissible(
                key: ValueKey(note.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  color: Colors.red.shade400,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (_) async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text("Delete Note"),
                      content: const Text(
                        "Are you sure you want to delete this note?",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text("Delete"),
                        ),
                      ],
                    ),
                  );
                  return confirm == true;
                },
                onDismissed: (_) {
                  FirebaseFirestore.instance
                      .collection("jobs/$jobId/notes")
                      .doc(note.id)
                      .delete();
                },
                child: Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      child: const Icon(Icons.description, color: Colors.white),
                    ),
                    title: Text(title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (noteText.isNotEmpty)
                          Text(
                            noteText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (timeStr.isNotEmpty)
                          Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NoteDetailPage(
                            jobId: jobId,
                            noteId: note.id,
                            readOnly: false, // Allow editing when tapping from list
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => JobNotesPhotoScreen(
                jobId: jobId,
                onFinished: () => Navigator.pop(context),
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// ----------------------------
/// Note Detail Page (Read + Edit)
/// ----------------------------
class NoteDetailPage extends StatefulWidget {
  final String jobId;
  final String noteId;
  final bool readOnly;

  const NoteDetailPage({
    super.key,
    required this.jobId,
    required this.noteId,
    required this.readOnly,
  });

  @override
  State<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends State<NoteDetailPage> {
  final picker = ImagePicker();
  bool _isEditing = false;

  final titleController = TextEditingController();
  final noteController = TextEditingController();

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile == null) return;

    final file = File(pickedFile.path);
    final bytes = await file.readAsBytes();
    final base64Image = base64Encode(bytes);

    final label = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text("Select Label"),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, "Damaged"),
            child: const Text("Damaged"),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, "Repaired"),
            child: const Text("Repaired"),
          ),
        ],
      ),
    );
    if (label == null) return;

    await FirebaseFirestore.instance
        .collection("jobs/${widget.jobId}/notes")
        .doc(widget.noteId)
        .collection("photos")
        .add({
      "imageBase64": base64Image,
      "label": label,
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> _saveNote() async {
    await FirebaseFirestore.instance
        .collection("jobs/${widget.jobId}/notes")
        .doc(widget.noteId)
        .update({
      "title": titleController.text,
      "note": noteController.text,
    });

    if (mounted) {
      setState(() {
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Note updated successfully")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Note Details"),
        actions: [
          if (!widget.readOnly) ...[
            if (_isEditing)
              IconButton(icon: const Icon(Icons.save), onPressed: _saveNote)
            else
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => setState(() => _isEditing = true),
              ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("Delete Note"),
                    content: const Text(
                      "Are you sure you want to delete this note? This action cannot be undone.",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text("Delete"),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await FirebaseFirestore.instance
                      .collection("jobs/${widget.jobId}/notes")
                      .doc(widget.noteId)
                      .delete();
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Note deleted successfully")),
                    );
                  }
                }
              },
            ),
          ],
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection("jobs/${widget.jobId}/notes")
            .doc(widget.noteId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final note = snapshot.data!;
          final title = note["title"] ?? "";
          final noteText = note["note"] ?? "";

          if (!_isEditing) {
            titleController.text = title;
            noteController.text = noteText;
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _isEditing
                        ? TextField(
                            controller: titleController,
                            decoration: const InputDecoration(
                              labelText: "Title",
                            ),
                          )
                        : Text(
                            "Title: $title",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                    const SizedBox(height: 10),
                    _isEditing
                        ? TextField(
                            controller: noteController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: "Description",
                            ),
                          )
                        : Text("Description: $noteText"),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("jobs/${widget.jobId}/notes")
                      .doc(widget.noteId)
                      .collection("photos")
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final photos = snapshot.data!.docs;
                    if (photos.isEmpty) {
                      return const Center(child: Text("No photos yet"));
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.all(10),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                          ),
                      itemCount: photos.length,
                      itemBuilder: (context, index) {
                        final photo = photos[index];
                        final base64Image = photo["imageBase64"];
                        final label = photo["label"] ?? "";
                        final createdAtTs = photo["createdAt"];
                        DateTime? createdAt;
                        if (createdAtTs is Timestamp) {
                          createdAt = createdAtTs.toDate();
                        }
                        final createdStr = _formatDateTime(createdAt);
                        return InkWell(
                          onTap: () {
                            if (base64Image != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FullscreenImagePage(
                                    imageBytes: base64Decode(base64Image),
                                    timestamp: createdAt,
                                  ),
                                ),
                              );
                            }
                          },
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Expanded(
                                  child: base64Image != null
                                      ? Image.memory(
                                          base64Decode(base64Image),
                                          fit: BoxFit.cover,
                                        )
                                      : const Icon(Icons.broken_image),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Text(
                                    label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (createdStr.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6.0),
                                    child: Text(
                                      createdStr,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ),
                                if (_isEditing && !widget.readOnly)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: const Text("Delete Photo"),
                                          content: const Text(
                                            "Are you sure you want to delete this photo?",
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text("Cancel"),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text("Delete"),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        FirebaseFirestore.instance
                                            .collection("jobs/${widget.jobId}/notes")
                                            .doc(widget.noteId)
                                            .collection("photos")
                                            .doc(photo.id)
                                            .delete();
                                      }
                                    },
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _isEditing && !widget.readOnly
          ? Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FloatingActionButton.extended(
                      heroTag: "detail_camera",
                      onPressed: () => _pickImage(ImageSource.camera),
                      label: const Text("Camera"),
                      icon: const Icon(Icons.camera_alt),
                    ),
                    const SizedBox(height: 10),
                    FloatingActionButton.extended(
                      heroTag: "detail_gallery",
                      onPressed: () => _pickImage(ImageSource.gallery),
                      label: const Text("Gallery"),
                      icon: const Icon(Icons.photo),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

String _formatDateTime(DateTime? dt) {
  if (dt == null) return "";
  final local = dt.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return "$y-$m-$d $hh:$mm";
}
