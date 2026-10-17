import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/tasks/widgets/task_toolbar_dialogs.dart';

void main() {
  testWidgets('toolbar menu opens and zoom starts at 50%', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _ToolbarHarness()));

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    expect(find.text('Adjust zoom'), findsOneWidget);

    await tester.tap(find.text('Adjust zoom'));
    await tester.pumpAndSettle();

    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.min, 0.5);
    expect(slider.value, 0.5);
  });
}

class _ToolbarHarness extends StatefulWidget {
  const _ToolbarHarness();

  @override
  State<_ToolbarHarness> createState() => _ToolbarHarnessState();
}

class _ToolbarHarnessState extends State<_ToolbarHarness> {
  double _zoom = 0.5;

  Future<void> _showMenu(BuildContext buttonContext) async {
    final action = await showTaskToolbarMenu(
      buttonContext,
      sortBy: 'Priority',
      groupBy: 'Assignee',
      viewType: 'Detailed list',
      zoom: _zoom,
    );
    if (!mounted || action != 'zoom') return;

    final zoom = await showZoomAdjustDialog(context, initialZoom: _zoom);
    if (zoom != null && mounted) setState(() => _zoom = zoom);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          Builder(
            builder: (buttonContext) => IconButton(
              tooltip: 'More options',
              onPressed: () => _showMenu(buttonContext),
              icon: const Icon(Icons.more_vert),
            ),
          ),
        ],
      ),
      body: Center(child: Text('Zoom: ${(_zoom * 100).round()}%')),
    );
  }
}
