import 'package:flutter/material.dart';

Future<String?> promptAddSubstepDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const _AddSubstepDialog(),
  );
}

class _AddSubstepDialog extends StatefulWidget {
  const _AddSubstepDialog();

  @override
  State<_AddSubstepDialog> createState() => _AddSubstepDialogState();
}

class _AddSubstepDialogState extends State<_AddSubstepDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _closeDialog([String? value]) {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add substep'),
    scrollable: true,
    content: TextField(
      controller: _controller,
      autofocus: true,
      decoration: const InputDecoration(hintText: 'Substep title'),
      onSubmitted: (value) => _closeDialog(value.trim()),
    ),
    actions: [
      TextButton(onPressed: _closeDialog, child: const Text('Cancel')),
      TextButton(
        onPressed: () => _closeDialog(_controller.text.trim()),
        child: const Text('Add'),
      ),
    ],
  );
}
