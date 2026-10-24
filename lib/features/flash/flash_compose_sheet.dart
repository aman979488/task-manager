import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'flash_alert_service.dart';

Future<FlashDraft?> showFlashComposeSheet(
  BuildContext context, {
  DateTime? reminderAt,
  String? senderUid,
  Future<DateTime?> Function()? pickTime,
}) {
  return showModalBottomSheet<FlashDraft>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => _ComposeSheet(
      reminderAt: reminderAt,
      senderUid: senderUid,
      pickTime: pickTime,
    ),
  );
}

class _ComposeSheet extends StatefulWidget {
  const _ComposeSheet({this.reminderAt, this.senderUid, this.pickTime});

  final DateTime? reminderAt;
  final String? senderUid;
  final Future<DateTime?> Function()? pickTime;

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  final _textController = TextEditingController();
  List<Staff> _staff = [];
  List<String> _templates = FlashAlertService.defaultTemplates;
  Staff? _recipient;
  bool _sendNow = true;
  bool _isLoadingStaff = true;
  String? _loadError;
  DateTime? _when;

  @override
  void initState() {
    super.initState();
    _when = widget.reminderAt;
    _textController.addListener(_refresh);
    _loadOptions();
  }

  @override
  void dispose() {
    _textController
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _loadOptions() async {
    try {
      final staff = await FlashAlertService.loadStaff(
        excludingUid: widget.senderUid,
      );
      final templates = await FlashAlertService.loadTemplates();
      if (!mounted) return;
      setState(() {
        _staff = staff;
        _templates = templates;
        _isLoadingStaff = false;
        _loadError = null;
      });
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingStaff = false;
        _loadError = 'Staff list could not be loaded: ${error.message}';
      });
    }
  }

  Future<void> _pickWhen() async {
    final selected = await widget.pickTime?.call();
    if (selected != null && mounted) setState(() => _when = selected);
  }

  String _formatDateTime(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final amPm = value.hour >= 12 ? 'PM' : 'AM';
    return '${value.day}/${value.month} $hour:$minute $amPm';
  }

  @override
  Widget build(BuildContext context) {
    final canSend =
        _recipient != null &&
        _textController.text.trim().isNotEmpty &&
        (_sendNow || (_when != null && _when!.isAfter(DateTime.now())));

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚡ Flash message',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            if (_isLoadingStaff)
              const Center(child: CircularProgressIndicator()),
            if (!_isLoadingStaff && _loadError != null)
              Text(_loadError!, style: const TextStyle(color: Colors.red)),
            if (!_isLoadingStaff && _loadError == null)
              DropdownButtonFormField<Staff>(
                initialValue: _recipient,
                decoration: const InputDecoration(
                  labelText: 'Send to',
                  border: OutlineInputBorder(),
                ),
                items: _staff
                    .map(
                      (staff) => DropdownMenuItem(
                        value: staff,
                        child: Text(staff.name),
                      ),
                    )
                    .toList(),
                onChanged: _staff.isEmpty
                    ? null
                    : (staff) => setState(() => _recipient = staff),
              ),
            if (!_isLoadingStaff && _staff.isEmpty && _loadError == null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('No other staff accounts found.'),
              ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('Send now'),
                  icon: Icon(Icons.bolt),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('Schedule'),
                  icon: Icon(Icons.alarm),
                ),
              ],
              selected: {_sendNow},
              onSelectionChanged: (selection) async {
                setState(() => _sendNow = selection.first);
                if (!_sendNow && _when == null) await _pickWhen();
                if (!_sendNow && _when == null && mounted) {
                  setState(() => _sendNow = true);
                }
              },
            ),
            if (!_sendNow && _when != null) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: Text('Will be sent: ${_formatDateTime(_when!)}'),
                trailing: const Icon(Icons.edit, size: 18),
                onTap: _pickWhen,
              ),
              if (!_when!.isAfter(DateTime.now()))
                const Text(
                  'Scheduled time must be in the future.',
                  style: TextStyle(color: Colors.red),
                ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Templates',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _templates
                  .map(
                    (template) => ActionChip(
                      label: Text(template),
                      onPressed: () => _textController.text = template,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Or write your own message',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canSend
                    ? () => Navigator.pop(
                        context,
                        FlashDraft(
                          recipient: _recipient!,
                          text: _textController.text.trim(),
                          sendAt: _sendNow ? null : _when,
                        ),
                      )
                    : null,
                child: Text(_sendNow ? 'Send now' : 'Schedule message'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}