import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/task.dart';

class TaskFilesSection extends StatelessWidget {
  final Task task;
  final VoidCallback onChanged;
  final Color secondaryColor;

  const TaskFilesSection({
    super.key,
    required this.task,
    required this.onChanged,
    this.secondaryColor = const Color(0xFF6B5800),
  });

  Future<void> _openFile(BuildContext context, TaskFile file) async {
    if (kIsWeb) {
      if (file.path != null && file.path!.isNotEmpty) {
        final uri = Uri.parse(file.path!);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File cannot be opened on web.')),
          );
        }
      }
    } else {
      if (file.path != null && file.path!.isNotEmpty) {
        final uri = Uri.file(file.path!);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Cannot open file: ${file.name}')),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (task.files.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Uploaded Files",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ...task.files.asMap().entries.map((entry) {
          final index = entry.key;
          final file = entry.value;
          return InkWell(
            onTap: () => _openFile(context, file),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.grey.shade300,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.insert_drive_file,
                    color: secondaryColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${(file.size / 1024).toStringAsFixed(1)} KB",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      task.files.removeAt(index);
                      onChanged();
                    },
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }
}
