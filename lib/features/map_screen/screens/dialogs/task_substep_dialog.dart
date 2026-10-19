import 'package:flutter/material.dart';

Future<void> promptAddSubstepDialog(
  BuildContext context, {
  required Future<void> Function(String title) onAdd,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _AddSubstepDialog(onAdd: onAdd),
  );
}

class _AddSubstepDialog extends StatefulWidget {
  const _AddSubstepDialog({required this.onAdd});

  final Future<void> Function(String title) onAdd;

  @override
  State<_AddSubstepDialog> createState() => _AddSubstepDialogState();
}

class _AddSubstepDialogState extends State<_AddSubstepDialog> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isAdding = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _closeDialog() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop();
  }

  Future<void> _addSubstep() async {
    if (_isAdding) return;
    final title = _controller.text.trim();
    if (title.isEmpty) {
      _focusNode.requestFocus();
      return;
    }

    setState(() => _isAdding = true);
    try {
      await widget.onAdd(title);
      if (!mounted) return;
      _controller.clear();
      setState(() => _isAdding = false);
      _focusNode.requestFocus();
    } finally {
      if (mounted && _isAdding) {
        setState(() => _isAdding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Row(
      children: [
        const Expanded(child: Text('Add substep')),
        IconButton(
          tooltip: 'Close',
          onPressed: _isAdding ? null : _closeDialog,
          icon: const Icon(Icons.close),
        ),
      ],
    ),
    scrollable: true,
    content: TextField(
      controller: _controller,
      focusNode: _focusNode,
      autofocus: true,
      decoration: const InputDecoration(hintText: 'Substep title'),
      textInputAction: TextInputAction.next,
      onSubmitted: (_) => _addSubstep(),
    ),
    actions: [
      TextButton(
        onPressed: _isAdding ? null : _closeDialog,
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: _isAdding ? null : _addSubstep,
        child: _isAdding
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Add'),
      ),
    ],
  );
}
