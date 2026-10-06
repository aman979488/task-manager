import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import '../features/map_screen/models/task.dart';

const _widgetProviderName =
    'com.example.task_manager.TaskManagerWidgetProvider';
const _widgetTaskLimit = 3;

Future<void> updateTaskHomeWidget(List<Task> tasks) async {
  if (defaultTargetPlatform != TargetPlatform.android) return;

  final allPendingTasks = tasks.where((task) => !task.isDone).toList();
  final pendingTasks = allPendingTasks.take(_widgetTaskLimit);

  try {
    Future<void> saveData<T>(String key, T? value) async {
      final saved = await HomeWidget.saveWidgetData<T>(key, value);
      if (saved != true) {
        throw PlatformException(
          code: 'widget-data-save-failed',
          message: 'Could not save "$key" for the Android task widget.',
        );
      }
    }

    await saveData<int>('pending_count', allPendingTasks.length);
    await saveData<bool>('has_loaded_tasks', true);
    var index = 0;
    for (final task in pendingTasks) {
      await saveData<String>('task_$index', task.title);
      index++;
    }
    for (; index < _widgetTaskLimit; index++) {
      await saveData<String>('task_$index', null);
    }

    final updated = await HomeWidget.updateWidget(
      androidName: _widgetProviderName,
    );
    if (updated != true) {
      debugPrint('Android task widget update was not accepted.');
    }
  } on PlatformException catch (error, stackTrace) {
    debugPrint('Could not update Android task widget: $error\n$stackTrace');
  }
}
