import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/map_screen/models/task.dart';

void main() {
  test('Task model initialization smoke test', () {
    final task = Task(
      'Smoke Test Task',
      priority: 'High',
    );

    expect(task.title, 'Smoke Test Task');
    expect(task.priority, 'High');
    expect(task.isDone, isFalse);

    final map = task.toMap();
    expect(map['title'], 'Smoke Test Task');
    expect(map['priority'], 'High');
  });
}
