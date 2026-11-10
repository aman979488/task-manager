import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'flash_alert_service.dart';

Future<FlashDraft?> showFlashComposeSheet(
  BuildContext context, {
  DateTime? reminderAt,
  String? senderUid,
  Future<DateTime?> Function()? pickTime,
}) {
  return showDialog<FlashDraft>(
    context: context,
    builder: (dialogContext) {
      final mediaQuery = MediaQuery.of(dialogContext);
      final maxDialogHeight =
          (mediaQuery.size.height - mediaQuery.viewInsets.bottom - 48)
              .clamp(120.0, mediaQuery.size.height)
              .toDouble();
      return Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 440,
            maxHeight: maxDialogHeight,
          ),
          child: _ComposeSheet(
            reminderAt: reminderAt,
            senderUid: senderUid,
            pickTime: pickTime,
          ),
        ),
      );
    },
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
  final _messageFocusNode = FocusNode();
  List<Staff> _staff = [];
  List<FlashTemplate> _templates = FlashAlertService.defaultTemplates;
  Staff? _recipient;
  bool _sendNow = true;
  bool _isLoadingStaff = true;
  String? _loadError;
  DateTime? _when;
  String? _selectedTemplateLabel;

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
    _messageFocusNode.dispose();
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
    if (selected != null && mounted) {
      setState(() => _when = selected);
    }
  }

  String _formatDateTime(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final amPm = value.hour >= 12 ? 'PM' : 'AM';
    return '${value.day}/${value.month} $hour:$minute $amPm';
  }

  Widget _buildTemplateOption(FlashTemplate template) {
    final selected = _textController.text == template.text;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        setState(() {
          _selectedTemplateLabel = template.label;
          _textController.text = template.text;
        });
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.amber.withValues(alpha: 0.12) : Colors.white,
          border: Border.all(
            color: selected ? Colors.amber.shade800 : Colors.black12,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              template.label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 3),
            Text(
              template.text,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSend =
        _recipient != null &&
        _textController.text.trim().isNotEmpty &&
        (_sendNow || (_when != null && _when!.isAfter(DateTime.now())));

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚡ Flash message',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 12),
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
            const Text(
              'Templates',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            for (final template in _templates) _buildTemplateOption(template),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                setState(() {
                  _selectedTemplateLabel = 'Others';
                  _textController.clear();
                });
                _messageFocusNode.requestFocus();
              },
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Others - write your own message',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            TextField(
              controller: _textController,
              focusNode: _messageFocusNode,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Selected message (you can edit it)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
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
                          templateLabel:
                              _selectedTemplateLabel ?? 'Custom message',
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
