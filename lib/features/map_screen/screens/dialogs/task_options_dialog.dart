import 'package:flutter/material.dart';

Future<void> chooseTaskOptionDialog({
  required BuildContext context,
  required String title,
  required List<String> options,
  required String selected,
  required ValueChanged<String> onSelected,
}) async {
  final value = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      scrollable: true,
      content: SizedBox(
        height: options.length.clamp(1, 3).toDouble() * 56.0,
        width: 280,
        child: ListView.builder(
          itemCount: options.length,
          itemExtent: 56,
          itemBuilder: (context, index) {
            final option = options[index];
            return RadioListTile<String>(
              value: option,
              // ignore: deprecated_member_use
              groupValue: selected,
              title: Text(option),
              // ignore: deprecated_member_use
              onChanged: (val) => Navigator.pop(context, val),
            );
          },
        ),
      ),
    ),
  );
  if (value != null) onSelected(value);
}
