import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task_manager/features/map_screen/models/task.dart';
import 'package:task_manager/features/map_screen/screens/views/my_work_view.dart';

void main() {
  testWidgets('Urgent section can be collapsed after it is expanded', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MyWorkView(
            sections: {
              'Urgent Works': [Task('Urgent task')],
            },
            taskResultsBuilder: (tasks) =>
                Column(children: [for (final task in tasks) Text(task.title)]),
          ),
        ),
      ),
    );

    Future<void> tapUrgentHeader() async {
      final header = find.ancestor(
        of: find.text('URGENT').first,
        matching: find.byType(InkWell),
      );
      tester.widget<InkWell>(header.first).onTap!();
      await tester.pumpAndSettle();
    }

    if (find.text('Urgent task').evaluate().isEmpty) await tapUrgentHeader();
    expect(find.text('Urgent task'), findsOneWidget);

    await tapUrgentHeader();
    expect(find.text('Urgent task'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanded section builds task rows lazily', (tester) async {
    SharedPreferences.setMockInitialValues({});
    var builtTaskRows = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MyWorkView(
            sections: {
              'Urgent Works': [Task('Urgent task')],
              'Overdue Works': List.generate(
                300,
                (index) => Task('Overdue task $index'),
              ),
            },
            taskResultsBuilder: (_) => const SizedBox.shrink(),
            expandedTasksSliverBuilder: (tasks) => SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                builtTaskRows++;
                return Text(tasks[index].title);
              }, childCount: tasks.length),
            ),
          ),
        ),
      ),
    );

    final header = find.ancestor(
      of: find.text('OVERDUE'),
      matching: find.byType(InkWell),
    );
    tester.widget<InkWell>(header.first).onTap!();
    await tester.pump();

    expect(find.text('Overdue task 0'), findsOneWidget);
    expect(find.text('Urgent task'), findsNothing);
    expect(builtTaskRows, lessThan(300));
    expect(tester.takeException(), isNull);
  });

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

  testWidgets('Today and IMP section headers use their priority colors', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MyWorkView(
            sections: {
              'Today Works': [Task('Today task')],
              'IMP Works': [Task('Important task')],
            },
            taskResultsBuilder: (tasks) => const SizedBox.shrink(),
          ),
        ),
      ),
    );

    final todayLabel = tester.widget<Text>(find.text('TODAY'));
    final impLabel = tester.widget<Text>(find.text('IMP'));

    expect(todayLabel.style?.color, const Color(0xFF2E7D32));
    expect(impLabel.style?.color, const Color(0xFFB38600));
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
