import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/call_log_model.dart';
import '../utils/date_label_utils.dart';
import '../utils/phone_utils.dart';

class CallLogTile extends StatefulWidget {
  final CallLogModel log;

  const CallLogTile({super.key, required this.log});

  @override
  State<CallLogTile> createState() => _CallLogTileState();
}

class _CallLogTileState extends State<CallLogTile> {
  String? _note;

  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    final style = _styleFor(log.kind);
    final title = log.name?.trim().isNotEmpty == true
        ? log.name!
        : log.number.isEmpty
        ? 'Unknown caller'
        : log.number;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      elevation: 1,
      color: Colors.white,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 2),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 21,
                  backgroundColor: style.color.withValues(alpha: 0.14),
                  child: Icon(style.icon, color: style.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        log.number,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.blueGrey.shade700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.sim_card_outlined, size: 18),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 16),
                      _actionButton(
                        icon: Icons.copy_all_outlined,
                        label: 'Copy number',
                        color: Colors.blueGrey,
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: log.number),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Number copied')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 16),
                      _actionButton(
                        icon: Icons.sms_outlined,
                        label: 'Send SMS',
                        color: Colors.blue,
                        onPressed: () =>
                            _launch(Uri(scheme: 'sms', path: log.number)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _actionWithDetail(
                    detail: DateLabelUtils.timeLabel(log.time),
                    icon: Icons.chat_outlined,
                    label: 'WhatsApp',
                    color: Colors.green,
                    onPressed: () {
                      final number = PhoneUtils.normalize(log.number);
                      return _launch(Uri.https('wa.me', '/$number'));
                    },
                  ),
                ),
                Expanded(
                  child: _actionWithDetail(
                    detail: PhoneUtils.formatDuration(log.durationSeconds),
                    icon: Icons.call_outlined,
                    label: 'Call',
                    color: Colors.blueGrey,
                    onPressed: () =>
                        _launch(Uri(scheme: 'tel', path: log.number)),
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.grey.shade200,
            child: InkWell(
              onTap: _editNote,
              child: SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 20,
                        color: Colors.blueGrey.shade400,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _note?.isNotEmpty == true
                              ? _note!
                              : 'Tap to add note & tag',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.blueGrey.shade600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Future<void> Function() onPressed,
  }) => IconButton(
    tooltip: label,
    onPressed: () => unawaited(onPressed()),
    icon: Icon(icon, color: color, size: 27),
  );

  Widget _actionWithDetail({
    required String detail,
    required IconData icon,
    required String label,
    required Color color,
    required Future<void> Function() onPressed,
  }) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(detail, maxLines: 1, style: const TextStyle(fontSize: 13)),
      _actionButton(
        icon: icon,
        label: label,
        color: color,
        onPressed: onPressed,
      ),
    ],
  );

  Future<void> _launch(Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the requested app')),
      );
    }
  }

  Future<void> _editNote() async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _CallNoteDialog(initialNote: _note),
    );
    if (note != null && mounted) setState(() => _note = note);
  }

  _CallStyle _styleFor(CallKind kind) {
    switch (kind) {
      case CallKind.incoming:
        return const _CallStyle(Icons.call_received, Colors.green, 'Incoming');
      case CallKind.outgoing:
        return const _CallStyle(Icons.call_made, Colors.blue, 'Outgoing');
      case CallKind.missed:
        return const _CallStyle(Icons.call_missed, Colors.red, 'Missed');
      case CallKind.rejected:
        return const _CallStyle(
          Icons.call_missed_outgoing,
          Colors.red,
          'Rejected',
        );
      case CallKind.blocked:
        return const _CallStyle(Icons.block, Colors.red, 'Blocked');
      case CallKind.other:
        return const _CallStyle(Icons.call, Colors.grey, 'Call');
    }
  }
}

class _CallStyle {
  final IconData icon;
  final Color color;
  final String label;
  const _CallStyle(this.icon, this.color, this.label);
}

class _CallNoteDialog extends StatefulWidget {
  const _CallNoteDialog({this.initialNote});

  final String? initialNote;

  @override
  State<_CallNoteDialog> createState() => _CallNoteDialogState();
}

class _CallNoteDialogState extends State<_CallNoteDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add note & tag'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      decoration: const InputDecoration(hintText: 'Enter a note'),
      maxLines: 2,
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        child: const Text('Save'),
      ),
    ],
  );
}
