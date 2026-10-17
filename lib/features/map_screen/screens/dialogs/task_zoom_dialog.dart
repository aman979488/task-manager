import 'package:flutter/material.dart';

Future<void> showTaskZoomDialog(
  BuildContext context, {
  required double currentZoom,
  required ValueChanged<double> onZoomChanged,
}) async {
  var zoom = currentZoom;
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Adjust zoom'),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Slider(
              min: 0.8,
              max: 1.4,
              divisions: 6,
              value: zoom,
              label: '${(zoom * 100).round()}%',
              onChanged: (value) {
                setDialogState(() => zoom = value);
                onZoomChanged(value);
              },
            ),
            Text('${(zoom * 100).round()}%'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    ),
  );
}
