import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task_manager/features/map_screen/models/task.dart';
import 'package:task_manager/features/map_screen/screens/views/my_work_view.dart';

void main() {
  testWidgets('restores expanded work sections after app restart', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final sections = {
      'Urgent Works': [Task('Urgent task')],
      'Today Works': [Task('Today task')],
    };

    Widget buildApp() => MaterialApp(
      home: Scaffold(
        body: MyWorkView(
          sections: sections,
          taskResultsBuilder: (tasks) =>
              Column(children: [for (final task in tasks) Text(task.title)]),
        ),
      ),
    );

    await tester.pumpWidget(buildApp());
    final sectionHeader = find.ancestor(
      of: find.text('TODAY').last,
      matching: find.byType(InkWell),
    );
    tester.widget<InkWell>(sectionHeader.last).onTap!();
    await tester.pumpAndSettle();

    expect(find.text('Today task'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getStringList('my_work_expanded_sections'), [
      'Today Works',
    ]);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Today task'), findsOneWidget);
    expect(find.text('Urgent task'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all work section headers use compact consistent spacing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MyWorkView(
            sections: {
              'Urgent Works': [Task('Urgent task')],
              'Today Works': [Task('Today task')],
              'Overdue Works': [Task('Overdue task')],
            },
            taskResultsBuilder: (tasks) => const SizedBox.shrink(),
          ),
        ),
      ),
    );

    for (final label in ['URGENT', 'TODAY', 'OVERDUE']) {
      expect(
        tester
            .getSize(
              find
                  .ancestor(
                    of: find.text(label),
                    matching: find.byType(SizedBox),
                  )
                  .first,
            )
            .height,
        48,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('section counts stay smaller than labels for large numbers', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MyWorkView(
            sections: {
              'Urgent Works': List.generate(
                120,
                (index) => Task('Task $index'),
              ),
            },
            taskResultsBuilder: (tasks) => const SizedBox.shrink(),
          ),
        ),
      ),
    );

    final count = find.text('120');
    final label = tester.widget<Text>(find.text('URGENT'));
    final countText = tester.widget<Text>(count);

    expect(countText.style?.fontSize, 10);
    expect(countText.style?.fontSize, lessThan(label.style?.fontSize ?? 0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('triple-tapping blank space expands the first two sections', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MyWorkView(
            sections: {
              'Urgent Works': [Task('Urgent task')],
              'Today Works': [Task('Today task')],
            },
            taskResultsBuilder: (tasks) =>
                Column(children: [for (final task in tasks) Text(task.title)]),
          ),
        ),
      ),
    );

    final scrollViewRect = tester.getRect(find.byType(CustomScrollView));
    final blankSpaceTapPoint = Offset(
      scrollViewRect.left + 20,
      scrollViewRect.top + 300,
    );
    await tester.tapAt(blankSpaceTapPoint);
    await tester.tapAt(blankSpaceTapPoint);
    await tester.tapAt(blankSpaceTapPoint);
    await tester.pump(const Duration(milliseconds: 351));
    await tester.pumpAndSettle();

    expect(find.text('Urgent task'), findsOneWidget);
    expect(find.text('Today task'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
