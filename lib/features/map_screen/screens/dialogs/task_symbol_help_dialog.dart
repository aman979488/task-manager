import 'package:flutter/material.dart';

import '../../utils/task_constants.dart';

Future<void> showTaskSymbolHelpDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      title: const Text('Task shortcuts'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 360,
          maxHeight: (MediaQuery.sizeOf(dialogContext).height * 0.42)
              .clamp(0.0, 180.0)
              .toDouble(),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (symbol, title, description) in TaskConstants.shortcutsHelp)
                ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(vertical: -2),
                  contentPadding: EdgeInsets.zero,
                  leading: SizedBox(
                    width: 28,
                    child: Text(
                      symbol,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(title, style: const TextStyle(fontSize: 13)),
                  subtitle: Text(
                    description,
                    style: const TextStyle(fontSize: 11, height: 1.1),
                  ),
                ),
              const ListTile(
                dense: true,
                visualDensity: VisualDensity(vertical: -2),
                contentPadding: EdgeInsets.zero,
                leading: SizedBox(
                  width: 28,
                  child: Icon(Icons.folder_outlined, size: 20),
                ),
                title: Text('Folder', style: TextStyle(fontSize: 13)),
                subtitle: Text(
                  'Folder does not have a text shortcut symbol.',
                  style: TextStyle(fontSize: 11, height: 1.1),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
