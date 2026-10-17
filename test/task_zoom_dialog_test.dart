import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/map_screen/screens/dialogs/task_zoom_dialog.dart';

void main() {
  testWidgets('zoom slider previews each change immediately', (tester) async {
    final zoomValues = <double>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                showTaskZoomDialog(
                  context,
                  currentZoom: 1,
                  onZoomChanged: zoomValues.add,
                );
              },
              child: const Text('Open zoom'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open zoom'));
    await tester.pumpAndSettle();

    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.divisions, isNull);
    expect(slider.value, 1);

    await tester.drag(find.byType(Slider), const Offset(100, 0));
    await tester.pump();

    expect(zoomValues, isNotEmpty);
    expect(zoomValues.last, greaterThan(1));
    expect(find.text('${(zoomValues.last * 100).round()}%'), findsOneWidget);
  });
}
