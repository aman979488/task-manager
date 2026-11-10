import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/flash/flash_alert_service.dart';

void main() {
  test('default flash templates cover the requested work statuses', () {
    final templates = FlashAlertService.defaultTemplates;

    expect(templates.map((template) => template.label).toList(), [
      'Flash call',
      'Work update',
      'Finished',
      'In process',
      'Will take time',
      'Forgot',
    ]);
    expect(templates.map((template) => template.text).toList(), [
      'Please call me when you are free.',
      'Work update: I am working on it.',
      'Work update: The task is finished.',
      'Work update: This task is in progress.',
      'Work update: This will take more time.',
      'I forgot about this. I will follow up shortly.',
    ]);
  });
}
