import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/map_screen/utils/task_priority_color.dart';

void main() {
  test('today and tomorrow are green, and IMP is yellow', () {
    const green = Color(0xFF2E7D32);
    const yellow = Color(0xFFB38600);

    expect(taskPriorityColor('Today'), green);
    expect(taskPriorityColor('Tomorrow'), green);
    expect(taskPriorityColor('IMP'), yellow);
  });
}
